import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/billing_client_wrappers.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import '../main.dart';

/// Eventos de compra observáveis pela UI (TelaPremium escuta [Billing.eventos]).
/// `nadaParaRestaurar`: restauração concluída sem nenhuma compra anterior —
/// caso comum em conta nova; sem ele a UI ficaria muda (exigência de UX e de
/// review da Apple: "Restore" precisa dar feedback sempre).
enum BillingEvento { processando, sucesso, restaurado, cancelada, erro, nadaParaRestaurar }

/// Período de cobrança de um plano, derivado dos dados da loja (Android:
/// `billingPeriod` ISO-8601 do base plan; iOS: heurística do product id).
enum PeriodoPlano { mensal, anual, indefinido }

/// Um plano exibível no paywall — exatamente UM cartão por plano.
///
/// Existe porque a Play devolve UMA [ProductDetails] POR OFERTA: um produto
/// `premium` com base plans mensal/anual, cada um com oferta de teste grátis,
/// chega como 4 entradas — e nas de teste `price` é o da PRIMEIRA fase
/// ("Grátis"), não o do plano. Renderizar a lista crua duplica cartões e
/// esconde o preço real. Aqui as ofertas voltam a ser planos: [produto] é a
/// instância exata a comprar (carrega o offerToken do teste grátis, quando o
/// usuário é elegível) e [preco] é sempre o preço RECORRENTE.
class PlanoPremium {
  const PlanoPremium({
    required this.produto,
    required this.titulo,
    required this.preco,
    required this.precoBruto,
    required this.periodo,
    required this.temTeste,
  });

  /// Instância a passar em [Billing.comprar] — no Android define a oferta.
  final ProductDetails produto;

  /// Título da loja sem o sufixo "(Kairo)" que a Play acrescenta.
  final String titulo;

  /// Preço recorrente formatado na moeda do usuário (ex.: "R$ 34,90").
  final String preco;

  /// Valor numérico de [preco] — ordenação e cálculo de economia do anual.
  final double precoBruto;

  final PeriodoPlano periodo;

  /// Se a oferta escolhida inclui período de teste grátis (badge/CTA da UI).
  final bool temTeste;
}

/// Camada de billing do client (In-App Purchase). A verdade da assinatura vive
/// em `public.subscriptions` (escrita só por service role via webhooks /
/// verify-purchase). Esta classe:
///   • lê o próprio estado (SELECT own, autorizado por RLS) — só display;
///   • lista os produtos das lojas e dispara a compra IAP nativa;
///   • após a compra, chama a Edge Function `verify-purchase` para desbloqueio
///     imediato (os webhooks Apple/Google são a fonte de verdade de renovação).
///
/// **Nunca** use `isPremium()` para decisão de cobrança/recurso pago — quem
/// decide é o servidor via `is_premium()` (ex.: gating no mentor-chat). Este
/// getter é só para exibição.
///
/// Conformidade Apple/Google: a compra é SEMPRE via IAP. Nenhum link externo de
/// pagamento (anti-steering). Um Premium comprado na web (Stripe) é honrado
/// silenciosamente pela leitura do entitlement.
class Billing {
  Billing._();
  static final Billing instance = Billing._();

  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _sub;

  /// Product IDs por loja. iOS usa dois produtos de assinatura; Android usa um
  /// produto de assinatura (`premium`) cujos base plans mensal/anual vêm como
  /// ofertas. Devem casar com a App Store Connect / Play Console.
  static const Set<String> _idsApple  = {
    'app.kairo.premium.monthly',
    'app.kairo.premium.anual',
  };
  static const Set<String> _idsGoogle = {'premium'};

  bool? _cache;
  DateTime? _periodoFim;
  String? _statusBruto;

  // Estado da restauração em andamento (ver [restaurar]).
  bool _restaurando = false;
  bool _streamAtivoNaRestauracao = false;

  /// SOMENTE para testes/screenshots (integration_test). Quando setado,
  /// [produtos] devolve esta lista em vez de consultar a loja — a paywall
  /// renderiza com preços de exemplo no Simulador iOS, sem StoreKit/Play.
  /// NUNCA afeta entitlement: [refresh]/[cachePremium] continuam vindo do
  /// servidor.
  @visibleForTesting
  List<ProductDetails>? debugProdutosOverride;

  /// Estado da última operação de compra, para a UI reagir (snackbar/aviso).
  final ValueNotifier<BillingEvento?> eventos = ValueNotifier<BillingEvento?>(null);

  /// Emite um evento garantindo a notificação mesmo quando repetido:
  /// ValueNotifier não notifica valor igual ao anterior, então dois "erro"
  /// seguidos deixariam a UI muda. O null intermediário é ignorado pelos
  /// listeners (todos fazem early-return em null).
  void _emitir(BillingEvento e) {
    eventos.value = null;
    eventos.value = e;
  }

  /// Última leitura conhecida do premium. `null` enquanto não consultado.
  bool? get cachePremium => _cache;
  /// Fim do período pago (apenas display).
  DateTime? get periodoFim => _periodoFim;
  /// Status bruto do entitlement (active/trialing/grace/...). Diagnóstico.
  String? get statusBruto => _statusBruto;

  Set<String> get _ids =>
      defaultTargetPlatform == TargetPlatform.android ? _idsGoogle : _idsApple;

  /// Inicia o listener global do `purchaseStream`. Chamar uma vez no boot
  /// (após `Supabase.initialize`). Idempotente.
  void init() {
    _sub ??= _iap.purchaseStream.listen(
      _aoAtualizarCompras,
      onError: (e) => debugPrint('[Billing] purchaseStream erro: $e'),
    );
  }

  void dispose() {
    _sub?.cancel();
    _sub = null;
  }

  /// Lojas disponíveis (false em emulador sem conta/loja configurada).
  Future<bool> disponivel() => _iap.isAvailable();

  /// Lista os produtos de assinatura ofertados, ordenados por preço crescente
  /// (mensal antes de anual). Vazio se a loja estiver indisponível.
  Future<List<ProductDetails>> produtos() async {
    if (debugProdutosOverride != null) return debugProdutosOverride!;
    if (!await _iap.isAvailable()) {
      debugPrint('[Billing] loja indisponível (sem conta da loja no aparelho?)');
      return const [];
    }
    final resp = await _iap.queryProductDetails(_ids);
    if (resp.error != null) {
      debugPrint('[Billing] queryProductDetails: ${resp.error}');
    }
    if (resp.notFoundIDs.isNotEmpty) {
      // A loja respondeu mas não reconheceu estes IDs. No iOS as causas
      // típicas são: Paid Apps Agreement inativo, produto sem metadata
      // completa ("Ready to Submit"), ou produto recém-criado (propagação).
      debugPrint('[Billing] produtos NÃO encontrados na loja: ${resp.notFoundIDs}');
    }
    final lista = resp.productDetails.toList()
      ..sort((a, b) => a.rawPrice.compareTo(b.rawPrice));
    return lista;
  }

  /// Planos prontos para o paywall: um por plano (mensal/anual), com preço
  /// recorrente e a oferta certa para a compra. Vazio se a loja estiver
  /// indisponível. É ESTA a lista que as telas renderizam — nunca a crua de
  /// [produtos] (ver [PlanoPremium]).
  Future<List<PlanoPremium>> planos() async => mapearPlanos(await produtos());

  /// Função pura (testável sem loja): converte a lista crua de [produtos] em
  /// planos de exibição. Entradas da Play são reagrupadas por base plan; as
  /// demais (iOS e o override de testes) viram um plano cada.
  @visibleForTesting
  static List<PlanoPremium> mapearPlanos(List<ProductDetails> produtos) {
    final porBasePlan = <String, List<GooglePlayProductDetails>>{};
    final planos = <PlanoPremium>[];
    for (final p in produtos) {
      final indice = p is GooglePlayProductDetails ? p.subscriptionIndex : null;
      if (p is! GooglePlayProductDetails || indice == null) {
        planos.add(_planoGenerico(p));
        continue;
      }
      final oferta = p.productDetails.subscriptionOfferDetails![indice];
      porBasePlan.putIfAbsent(oferta.basePlanId, () => []).add(p);
    }
    planos.addAll(porBasePlan.values.map(_planoGoogle));
    planos.sort((a, b) => a.precoBruto.compareTo(b.precoBruto));
    return planos;
  }

  /// Colapsa as ofertas de um mesmo base plan num único plano. A compra usa a
  /// oferta com teste grátis quando presente (a Play só lista ofertas para as
  /// quais o usuário é elegível; quem já usou o teste recebe só o base plan).
  /// O preço exibido é o da última fase PAGA — a fase "grátis" do teste vem
  /// antes e nunca é o preço do plano.
  static PlanoPremium _planoGoogle(List<GooglePlayProductDetails> grupo) {
    SubscriptionOfferDetailsWrapper ofertaDe(GooglePlayProductDetails p) =>
        p.productDetails.subscriptionOfferDetails![p.subscriptionIndex!];
    bool comTeste(GooglePlayProductDetails p) =>
        ofertaDe(p).pricingPhases.any((f) => f.priceAmountMicros == 0);

    final escolhida = grupo.firstWhere(
      comTeste,
      orElse: () => grupo.firstWhere(
        (p) => ofertaDe(p).offerId == null, // base plan puro, sem oferta
        orElse: () => grupo.first,
      ),
    );
    final fases = ofertaDe(escolhida).pricingPhases;
    final faseBase = fases.lastWhere(
      (f) => f.priceAmountMicros > 0,
      orElse: () => fases.last,
    );
    return PlanoPremium(
      produto: escolhida,
      titulo: _tituloLimpo(escolhida.title),
      preco: faseBase.formattedPrice,
      precoBruto: faseBase.priceAmountMicros / 1000000.0,
      periodo: _periodoIso8601(faseBase.billingPeriod),
      temTeste: comTeste(escolhida),
    );
  }

  /// iOS (1 produto por plano) e override de testes: o período sai do product
  /// id ('app.kairo.premium.monthly'/'.anual'). O teste de 7 dias existe nos
  /// dois produtos como introductory offer da App Store Connect.
  static PlanoPremium _planoGenerico(ProductDetails p) {
    final id = p.id.toLowerCase();
    final anual = id.contains('year') || id.contains('anu');
    final mensal = id.contains('month') || id.contains('mens');
    return PlanoPremium(
      produto: p,
      titulo: _tituloLimpo(p.title),
      preco: p.price,
      precoBruto: p.rawPrice,
      periodo: anual
          ? PeriodoPlano.anual
          : (mensal ? PeriodoPlano.mensal : PeriodoPlano.indefinido),
      temTeste: true,
    );
  }

  /// `billingPeriod` ISO-8601 do base plan: "P1M" mensal, "P1Y"/"P12M" anual.
  static PeriodoPlano _periodoIso8601(String periodo) {
    if (periodo.contains('Y') || periodo == 'P12M') return PeriodoPlano.anual;
    if (periodo.contains('M')) return PeriodoPlano.mensal;
    return PeriodoPlano.indefinido;
  }

  /// A Play entrega o título como "Kairo Premium (Kairo)" — o "(app)" final é
  /// acréscimo da loja, não parte do nome do produto.
  static String _tituloLimpo(String titulo) =>
      titulo.replaceFirst(RegExp(r'\s*\([^()]*\)\s*$'), '').trim();

  /// Dispara a compra nativa do produto. A identidade do usuário viaja na
  /// compra: iOS `appAccountToken` / Android `obfuscatedAccountId` (ambos
  /// mapeados de `applicationUserName = user.id`, que é o UUID do Supabase).
  /// O resultado chega pelo `purchaseStream` ([_aoAtualizarCompras]).
  Future<void> comprar(ProductDetails p) async {
    final user = supabase.auth.currentUser;
    if (user == null) {
      _emitir(BillingEvento.erro);
      return;
    }
    final param = PurchaseParam(productDetails: p, applicationUserName: user.id);
    try {
      final abriu = await _iap.buyNonConsumable(purchaseParam: param);
      // Android devolve false quando a folha de compra NEM ABRE (ex.: já
      // existe assinatura ativa nesta conta Google) — e nesse caso nada chega
      // no purchaseStream. Sem emitir erro aqui o toque morre em silêncio;
      // "Restaurar compras" é o caminho para reassociar a assinatura.
      if (!abriu) _emitir(BillingEvento.erro);
    } on PlatformException catch (e) {
      debugPrint('[Billing] buyNonConsumable ${e.code}: ${e.message}');
      _emitir(BillingEvento.erro);
    }
  }

  /// Reassocia compras anteriores (troca de aparelho / reinstalação). Os
  /// resultados chegam pelo `purchaseStream` como `restored` — mas quando NÃO
  /// há compra anterior o iOS não entrega NADA no stream (o plugin não expõe
  /// o "restore finished" do StoreKit). Por isso: emitimos `processando` já,
  /// e se o stream ficar mudo por uma janela curta, `nadaParaRestaurar` — a
  /// UI nunca fica sem resposta. Um `restored` que chegue depois da janela
  /// ainda é processado normalmente pelo handler.
  Future<void> restaurar() async {
    if (_restaurando) return; // ignora toque duplo durante a janela
    _restaurando = true;
    _streamAtivoNaRestauracao = false;
    _emitir(BillingEvento.processando);
    try {
      await _iap.restorePurchases();
    } catch (e) {
      debugPrint('[Billing] restorePurchases falhou: $e');
      _restaurando = false;
      _emitir(BillingEvento.erro);
      return;
    }
    await Future<void>.delayed(const Duration(seconds: 4));
    _restaurando = false;
    if (!_streamAtivoNaRestauracao) {
      _emitir(BillingEvento.nadaParaRestaurar);
    }
  }

  /// "Já comprei na web": reconcilia a assinatura Stripe (landing/checkout-first)
  /// do usuário logado pelo PRÓPRIO e-mail, via a Edge Function `restore-stripe`.
  /// Cobre ter assinado na web e o stripe-webhook ainda não ter convergido (ou
  /// um pendente que não reconciliou no signup). Emite os MESMOS eventos do
  /// restore de IAP (restaurado/nadaParaRestaurar/erro) — o portão já reage.
  Future<void> restaurarWeb() async {
    final user = supabase.auth.currentUser;
    if (user == null) {
      _emitir(BillingEvento.erro);
      return;
    }
    _emitir(BillingEvento.processando);
    try {
      final resp = await supabase.functions.invoke('restore-stripe');
      if (resp.status != 200) {
        debugPrint('[Billing] restore-stripe ${resp.status}: ${resp.data}');
        _emitir(BillingEvento.erro);
        return;
      }
      await refresh();
      final data = resp.data;
      final encontrado =
          (data is Map && data['encontrado'] == true) || _cache == true;
      _emitir(encontrado
          ? BillingEvento.restaurado
          : BillingEvento.nadaParaRestaurar);
    } catch (e) {
      debugPrint('[Billing] restaurarWeb falhou: $e');
      _emitir(BillingEvento.erro);
    }
  }

  // ── Handler do purchaseStream ──────────────────────────────────────────────
  Future<void> _aoAtualizarCompras(List<PurchaseDetails> compras) async {
    // Qualquer entrega do stream durante uma restauração cancela o fallback
    // "nadaParaRestaurar" — o resultado real (restaurado/erro) prevalece.
    if (compras.isNotEmpty) _streamAtivoNaRestauracao = true;
    for (final c in compras) {
      switch (c.status) {
        case PurchaseStatus.pending:
          _emitir(BillingEvento.processando);
          break;
        case PurchaseStatus.error:
          _emitir(BillingEvento.erro);
          if (c.pendingCompletePurchase) await _iap.completePurchase(c);
          break;
        case PurchaseStatus.canceled:
          _emitir(BillingEvento.cancelada);
          if (c.pendingCompletePurchase) await _iap.completePurchase(c);
          break;
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          final ok = await _verificarNoServidor(c);
          if (c.pendingCompletePurchase) await _iap.completePurchase(c);
          _emitir(ok
              ? (c.status == PurchaseStatus.restored
                  ? BillingEvento.restaurado
                  : BillingEvento.sucesso)
              : BillingEvento.erro);
          break;
      }
    }
  }

  /// Envia o token à `verify-purchase` (re-busca o estado no provider, valida
  /// ownership e grava o entitlement) e atualiza o cache. Retorna true se o
  /// usuário ficou premium.
  Future<bool> _verificarNoServidor(PurchaseDetails c) async {
    try {
      final isGoogle = c is GooglePlayPurchaseDetails;
      final provider = isGoogle ? 'google' : 'apple';
      final token = isGoogle
          ? c.billingClientPurchase.purchaseToken
          : (c.purchaseID ?? '');
      if (token.isEmpty) {
        debugPrint('[Billing] compra sem token utilizável');
        return false;
      }
      final resp = await supabase.functions.invoke(
        'verify-purchase',
        body: {'provider': provider, 'token': token},
      );
      if (resp.status != 200) {
        debugPrint('[Billing] verify-purchase ${resp.status}: ${resp.data}');
        return false;
      }
      await refresh();
      return _cache == true;
    } catch (e) {
      debugPrint('[Billing] _verificarNoServidor falhou: $e');
      return false;
    }
  }

  // ── Leitura do entitlement (display) ───────────────────────────────────────

  /// Lê o estado atual da assinatura (sem cache). Critério premium idêntico ao
  /// `public.is_premium()`: status in ('active','trialing','grace') AND
  /// current_period_end > now.
  Future<bool> refresh() async {
    final user = supabase.auth.currentUser;
    if (user == null) {
      _cache = false;
      _periodoFim = null;
      _statusBruto = null;
      return false;
    }
    try {
      final row = await supabase
          .from('subscriptions')
          .select('status, current_period_end')
          .eq('user_id', user.id)
          .maybeSingle();

      if (row == null) {
        _cache = false;
        _periodoFim = null;
        _statusBruto = 'none';
        return false;
      }

      final status = row['status'] as String?;
      final fimRaw = row['current_period_end'] as String?;
      final fim = fimRaw != null ? DateTime.tryParse(fimRaw) : null;

      _statusBruto = status;
      _periodoFim = fim;
      final ativo = derivarPremium(
        status: status,
        periodoFim: fim,
        agora: DateTime.now(),
      );
      _cache = ativo;
      return ativo;
    } catch (e) {
      debugPrint('[Billing] refresh falhou: $e');
      return _cache ?? false;
    }
  }

  /// Premium do cache se disponível; senão dispara um refresh.
  Future<bool> isPremium() async {
    final c = _cache;
    if (c != null) return c;
    return refresh();
  }

  /// Limpa o cache. Útil em logout, ou após o webhook ter convergido.
  void limparCache() {
    _cache = null;
    _periodoFim = null;
    _statusBruto = null;
  }

  /// Função pura — testável sem mockar Supabase. Mantém paridade EXATA com
  /// `public.is_premium()`: premium = status in (active, trialing, grace) AND
  /// current_period_end > now. Demais status (past_due/canceled/incomplete/
  /// unpaid/paused/expired/none) e período expirado NÃO concedem premium.
  /// `grace` = janela de retry de cobrança (Apple/Google) que ainda dá acesso.
  static bool derivarPremium({
    required String? status,
    required DateTime? periodoFim,
    required DateTime agora,
  }) {
    if (status != 'active' && status != 'trialing' && status != 'grace') {
      return false;
    }
    if (periodoFim == null) return false;
    return periodoFim.isAfter(agora);
  }
}
