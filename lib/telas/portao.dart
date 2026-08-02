import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/kairo_tema.dart';
import '../core/billing.dart';
import '../core/i18n.dart';
import '../main.dart';
import 'home.dart';

// URLs legais exigidas pela Apple/Google no paywall — páginas reais da
// landing (lp-kairo), publicadas em /termos e /privacidade.
const String kUrlTermos = 'https://thekairo.app/termos';
const String kUrlPrivacidade = 'https://thekairo.app/privacidade';

/// Portão de assinatura (hard paywall). Fica ENTRE o login e o app: sem
/// entitlement (`active`/`trialing`), o usuário não entra. Substitui as antigas
/// entradas diretas em [TelaHome] (splash, pós-login, pós-onboarding).
///
/// Conformidade: a compra é via IAP (Billing). Sem link externo de pagamento.
/// O usuário SEMPRE pode "Sair" (Apple não permite prender) e "Restaurar
/// compras". Um Premium comprado na web (Stripe) é honrado e passa direto.
class TelaPortao extends StatefulWidget {
  const TelaPortao({super.key});

  @override
  State<TelaPortao> createState() => _TelaPortaoState();
}

class _TelaPortaoState extends State<TelaPortao> {
  bool _checando = true;
  bool _processando = false;
  List<PlanoPremium> _planos = const [];
  String? _erro;
  String? _aviso;

  @override
  void initState() {
    super.initState();
    Billing.instance.eventos.addListener(_aoEvento);
    _verificarEntrar();
  }

  @override
  void dispose() {
    Billing.instance.eventos.removeListener(_aoEvento);
    super.dispose();
  }

  // Verifica o entitlement: se já tem acesso (inclusive da web), entra direto;
  // senão carrega os produtos e mostra o paywall.
  Future<void> _verificarEntrar() async {
    final premium = await Billing.instance.refresh();
    if (!mounted) return;
    if (premium) {
      _entrarNoApp();
      return;
    }
    final planos = await Billing.instance.planos();
    if (!mounted) return;
    setState(() {
      _planos = planos;
      _checando = false;
    });
  }

  void _entrarNoApp() {
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (_, _, _) => const TelaHome(),
        transitionsBuilder: (_, anim, _, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  void _aoEvento() {
    final ev = Billing.instance.eventos.value;
    if (ev == null || !mounted) return;
    switch (ev) {
      case BillingEvento.processando:
        setState(() {
          _processando = true;
          _erro = null;
          _aviso = null;
        });
        break;
      case BillingEvento.sucesso:
      case BillingEvento.restaurado:
        // Compra/restauração ok — reavalia e entra no app se virou premium.
        setState(() => _processando = false);
        _verificarEntrar();
        break;
      case BillingEvento.cancelada:
        setState(() => _processando = false);
        break;
      case BillingEvento.nadaParaRestaurar:
        // Restauração terminou sem compra anterior: informa em tom neutro
        // (não é erro — é o esperado para conta nova).
        setState(() {
          _processando = false;
          _aviso = T.premiumNadaRestaurar;
        });
        break;
      case BillingEvento.erro:
        setState(() {
          _processando = false;
          _erro = T.assinaturaErro;
        });
        break;
    }
  }

  Future<void> _assinar(PlanoPremium plano) async {
    setState(() {
      _erro = null;
      _aviso = null;
    });
    await Billing.instance.comprar(plano.produto);
  }

  Future<void> _restaurar() async {
    setState(() {
      _erro = null;
      _aviso = null;
    });
    await Billing.instance.restaurar();
  }

  // "Já comprei na web": reconcilia a assinatura Stripe (landing) pelo e-mail
  // do usuário logado. Reusa os eventos do restore (restaurado → entra no app).
  Future<void> _restaurarWeb() async {
    setState(() {
      _erro = null;
      _aviso = null;
    });
    await Billing.instance.restaurarWeb();
  }

  Future<void> _sair() async {
    await supabase.auth.signOut();
    Billing.instance.limparCache();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const TelaBoasVindas()),
      (route) => false,
    );
  }

  Future<void> _abrirLink(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Elegibilidade ao teste grátis: quem já TEVE assinatura (status expirado/
    // cancelado no entitlement) já consumiu a introductory offer — prometer
    // "7 dias grátis" seria enganoso (Apple 3.1.2): o StoreKit cobraria na
    // hora. O iOS não expõe a elegibilidade real, então usamos o histórico do
    // entitlement como proxy conservador: só 'none' CONFIRMADO libera a
    // promessa (null = leitura falhou → falha fechado; o StoreKit ainda
    // aplica o trial na compra se o usuário for de fato elegível). No
    // Android a Play já resolve isso nas ofertas (temTeste).
    final elegivelTeste = Billing.instance.statusBruto == 'none';

    // Identifica mensal/anual para destacar o "melhor valor" (% de economia do
    // anual frente a 12× o mensal). Só aparece quando ambos os planos carregam.
    PlanoPremium? mensal;
    PlanoPremium? anual;
    for (final pl in _planos) {
      if (pl.periodo == PeriodoPlano.mensal) {
        mensal = pl;
      } else if (pl.periodo == PeriodoPlano.anual) {
        anual = pl;
      }
    }
    int? economiaPct;
    final m = mensal, a = anual;
    if (m != null && a != null && m.precoBruto > 0) {
      final pct = (100 * (1 - a.precoBruto / (m.precoBruto * 12))).round();
      if (pct > 0) economiaPct = pct;
    }

    // PopScope(canPop:false): o portão não é dispensável pelo botão voltar.
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: KC.sumi,
        body: _checando
            ? Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 1.5, color: KC.kin),
                ),
              )
            : SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 48),
                              Text(T.portaoTitulo, style: KT.displayL()),
                              const SizedBox(height: 16),
                              Text(
                                elegivelTeste ? T.portaoChamada : T.premiumChamada,
                                style: KT.bodySerif(cor: KC.cinza),
                              ),

                              const SizedBox(height: 40),
                              KT.divisor(),
                              const SizedBox(height: 28),

                              _Beneficio(texto: T.premiumBeneficioMentor),
                              const SizedBox(height: 14),
                              _Beneficio(texto: T.premiumBeneficioCarta),
                              const SizedBox(height: 14),
                              _Beneficio(texto: T.premiumBeneficioLimites),

                              const SizedBox(height: 36),

                              if (_planos.isEmpty) ...[
                                Text(T.premiumSemProdutos, style: KT.caption(cor: KC.fumo)),
                                const SizedBox(height: 12),
                                // Sem retry o usuário ficaria preso numa tela
                                // morta (a consulta à loja só rodava no boot).
                                TextButton(
                                  onPressed: _processando
                                      ? null
                                      : () {
                                          setState(() => _checando = true);
                                          _verificarEntrar();
                                        },
                                  style: TextButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                    alignment: Alignment.centerLeft,
                                  ),
                                  child: Text(
                                    T.premiumTentarNovamente,
                                    style: KT.caption(cor: KC.kin),
                                  ),
                                ),
                              ] else
                                ..._planos.map((pl) {
                                  final ehAnual = pl.periodo == PeriodoPlano.anual;
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: _CartaoPlano(
                                      plano: pl,
                                      destaque: ehAnual,
                                      economiaPct: ehAnual ? economiaPct : null,
                                      habilitado: !_processando,
                                      mostrarTeste: pl.temTeste && elegivelTeste,
                                      onTap: () => _assinar(pl),
                                    ),
                                  );
                                }),

                              if (_aviso != null) ...[
                                const SizedBox(height: 16),
                                Text(_aviso!, style: KT.caption(cor: KC.cinza)),
                              ],
                              if (_erro != null) ...[
                                const SizedBox(height: 16),
                                Text(_erro!, style: KT.caption(cor: KC.aka)),
                              ],

                              const SizedBox(height: 20),
                              // Divulgação obrigatória (Apple 3.1.2 / Google).
                              // Sem elegibilidade, a versão SEM menção a teste.
                              Text(
                                elegivelTeste
                                    ? T.portaoRenovacao
                                    : T.premiumRenovacaoSemTeste,
                                style: KT.caption(cor: KC.fumo),
                              ),
                              const SizedBox(height: 12),
                              _LinhaLegal(onTermos: () => _abrirLink(kUrlTermos),
                                  onPrivacidade: () => _abrirLink(kUrlPrivacidade)),
                            ],
                          ),
                        ),
                      ),

                      // Já assinou na web (Stripe): reconcilia pelo e-mail.
                      // SÓ no Android — no iOS qualquer menção a compra fora
                      // da loja fere o anti-steering da Guideline 3.1.1
                      // (rejeição de 07/2026). Quem assinou na landing segue
                      // coberto pela reconciliação automática no signup e
                      // pelo refresh do entitlement na entrada do portão.
                      if (defaultTargetPlatform == TargetPlatform.android)
                        Center(
                          child: TextButton(
                            onPressed: _processando ? null : _restaurarWeb,
                            child: Text(T.premiumJaCompreiWeb,
                                style: KT.caption(cor: KC.fumo)),
                          ),
                        ),

                      // Restaurar + Sair (escape obrigatório).
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          TextButton(
                            onPressed: _processando ? null : _restaurar,
                            child: Text(T.premiumRestaurar, style: KT.caption(cor: KC.cinza)),
                          ),
                          TextButton(
                            onPressed: _processando ? null : _sair,
                            child: Text(T.sair, style: KT.caption(cor: KC.cinza)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}

/// Cartão de plano: nome + preço destacado, badge de teste e, no anual, o selo
/// "melhor valor · economize X%". Tocar inicia a compra do plano.
class _CartaoPlano extends StatelessWidget {
  final PlanoPremium plano;
  final bool destaque;
  final int? economiaPct;
  final bool habilitado;
  /// Se o badge/CTA de teste grátis deve aparecer — combina a oferta do
  /// plano ([PlanoPremium.temTeste]) com a elegibilidade do usuário.
  final bool mostrarTeste;
  final VoidCallback onTap;
  const _CartaoPlano({
    required this.plano,
    required this.destaque,
    required this.economiaPct,
    required this.habilitado,
    required this.mostrarTeste,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Mensal/Anual como rótulo do cartão: o título da loja não distingue os
    // planos (na Play ambos chegam como "Kairo Premium").
    final titulo = switch (plano.periodo) {
      PeriodoPlano.mensal => T.planoMensal,
      PeriodoPlano.anual => T.planoAnual,
      PeriodoPlano.indefinido => plano.titulo,
    };
    final periodo = switch (plano.periodo) {
      PeriodoPlano.mensal => T.periodoMes,
      PeriodoPlano.anual => T.periodoAno,
      PeriodoPlano.indefinido => '',
    };
    final selo = destaque
        ? (economiaPct != null
              ? '${T.portaoMelhorValor} · ${T.portaoEconomizar(economiaPct!)}'
              : T.portaoMelhorValor)
        : null;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: habilitado ? onTap : null,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: KC.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: destaque ? KC.kin : KC.linha,
              width: destaque ? 1.5 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(titulo, style: KT.caption(cor: KC.cinza)),
                  ),
                  if (selo != null) _Pilula(texto: selo),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(plano.preco, style: KT.titulo(cor: KC.texto)),
                  if (periodo.isNotEmpty)
                    Text(' /$periodo', style: KT.caption(cor: KC.cinza)),
                ],
              ),
              const SizedBox(height: 14),
              // Sem teste grátis disponível (ex.: usuário já o consumiu),
              // o CTA vira "Assinar" — prometer teste seria enganoso.
              Row(
                children: [
                  if (mostrarTeste) _Pilula(texto: T.portaoTesteBadge),
                  const Spacer(),
                  Text(
                    mostrarTeste ? T.portaoComecarTeste : T.premiumAssinar,
                    style: KT.caption(cor: KC.kin),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.arrow_forward, size: 14, color: KC.kin),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Pílula em cobre translúcido (selo "melhor valor" / badge de teste grátis).
class _Pilula extends StatelessWidget {
  final String texto;
  const _Pilula({required this.texto});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: KC.kin.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(texto, style: KT.micro(cor: KC.kin)),
    );
  }
}

class _LinhaLegal extends StatelessWidget {
  final VoidCallback onTermos;
  final VoidCallback onPrivacidade;
  const _LinhaLegal({required this.onTermos, required this.onPrivacidade});

  @override
  Widget build(BuildContext context) {
    final estilo = KT.caption(cor: KC.fumo);
    final link = KT.caption(cor: KC.cinza);
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text('${T.portaoAoAssinar} ', style: estilo),
        GestureDetector(onTap: onTermos, child: Text(T.termosDeUso, style: link)),
        Text(' ${T.conectorE} ', style: estilo),
        GestureDetector(onTap: onPrivacidade, child: Text(T.politicaPrivacidade, style: link)),
        Text('.', style: estilo),
      ],
    );
  }
}

class _Beneficio extends StatelessWidget {
  final String texto;
  const _Beneficio({required this.texto});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 6, right: 12),
          child: Container(
            width: 4,
            height: 4,
            decoration: BoxDecoration(
              color: KC.kin,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        Expanded(child: Text(texto, style: KT.body())),
      ],
    );
  }
}
