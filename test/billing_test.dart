// Testes da derivação pura de premium no client (lib/core/billing.dart).
// Mantém paridade EXATA com public.is_premium() no banco: premium ⇔
// status ∈ {active, trialing, grace} AND current_period_end > now.
// ('grace' = janela de retry de cobrança Apple/Google que ainda dá acesso.)

import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/billing_client_wrappers.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:kairo/core/billing.dart';

// ── Fábricas de dados da Play (cenário real do produto `premium`) ────────────

PricingPhaseWrapper _fase({
  required int micros,
  required String preco,
  required String periodo,
  required RecurrenceMode modo,
}) =>
    PricingPhaseWrapper(
      billingCycleCount: modo == RecurrenceMode.finiteRecurring ? 1 : 0,
      billingPeriod: periodo,
      formattedPrice: preco,
      priceAmountMicros: micros,
      priceCurrencyCode: 'BRL',
      recurrenceMode: modo,
    );

SubscriptionOfferDetailsWrapper _oferta({
  required String basePlanId,
  String? offerId,
  required List<PricingPhaseWrapper> fases,
}) =>
    SubscriptionOfferDetailsWrapper(
      basePlanId: basePlanId,
      offerId: offerId,
      offerTags: const [],
      offerIdToken: 'token-$basePlanId-${offerId ?? 'base'}',
      pricingPhases: fases,
    );

/// Reproduz a resposta da Play para o produto `premium` com base plans
/// mensal/anual, cada um com oferta de teste grátis de 7 dias: o plugin
/// expande CADA oferta numa ProductDetails própria (4 entradas no total).
List<ProductDetails> _produtosPlay({bool comTeste = true}) {
  final mensalBase = _fase(
    micros: 34900000,
    preco: r'R$ 34,90',
    periodo: 'P1M',
    modo: RecurrenceMode.infiniteRecurring,
  );
  final anualBase = _fase(
    micros: 299000000,
    preco: r'R$ 299,00',
    periodo: 'P1Y',
    modo: RecurrenceMode.infiniteRecurring,
  );
  final gratis = _fase(
    micros: 0,
    preco: 'Grátis',
    periodo: 'P1W',
    modo: RecurrenceMode.finiteRecurring,
  );
  final wrapper = ProductDetailsWrapper(
    description: 'Kairo Premium',
    name: 'Kairo Premium',
    productId: 'premium',
    productType: ProductType.subs,
    title: 'Kairo Premium (Kairo)',
    subscriptionOfferDetails: [
      if (comTeste)
        _oferta(basePlanId: 'mensal', offerId: 'teste7', fases: [gratis, mensalBase]),
      _oferta(basePlanId: 'mensal', fases: [mensalBase]),
      if (comTeste)
        _oferta(basePlanId: 'anual', offerId: 'teste7', fases: [gratis, anualBase]),
      _oferta(basePlanId: 'anual', fases: [anualBase]),
    ],
  );
  return GooglePlayProductDetails.fromProductDetails(wrapper);
}

ProductDetails _produtoApple({required String id, required double preco}) =>
    ProductDetails(
      id: id,
      title: 'Kairo Premium',
      description: 'Kairo Premium',
      price: 'R\$ $preco',
      rawPrice: preco,
      currencyCode: 'BRL',
      currencySymbol: r'R$',
    );

void main() {
  final agora = DateTime(2025, 6, 15, 12, 0);

  group('Billing.mapearPlanos — Play (uma ProductDetails POR OFERTA)', () {
    test('4 ofertas viram 2 planos, com preço recorrente (nunca "Grátis")', () {
      final planos = Billing.mapearPlanos(_produtosPlay());

      expect(planos, hasLength(2));
      final mensal = planos[0];
      final anual = planos[1]; // ordenados por preço crescente

      expect(mensal.periodo, PeriodoPlano.mensal);
      expect(mensal.preco, r'R$ 34,90');
      expect(mensal.precoBruto, closeTo(34.90, 0.001));
      expect(mensal.temTeste, isTrue);

      expect(anual.periodo, PeriodoPlano.anual);
      expect(anual.preco, r'R$ 299,00');
      expect(anual.precoBruto, closeTo(299.0, 0.001));
      expect(anual.temTeste, isTrue);
    });

    test('a compra aponta para a OFERTA com teste grátis (offerToken)', () {
      final planos = Billing.mapearPlanos(_produtosPlay());
      for (final plano in planos) {
        final produto = plano.produto as GooglePlayProductDetails;
        expect(produto.offerToken, contains('teste7'));
      }
    });

    test('título perde o "(Kairo)" que a Play acrescenta', () {
      final planos = Billing.mapearPlanos(_produtosPlay());
      expect(planos.every((p) => p.titulo == 'Kairo Premium'), isTrue);
    });

    test('sem elegibilidade a teste: base plan puro, temTeste=false', () {
      final planos = Billing.mapearPlanos(_produtosPlay(comTeste: false));

      expect(planos, hasLength(2));
      expect(planos.every((p) => !p.temTeste), isTrue);
      expect(planos[0].preco, r'R$ 34,90');
      expect(planos[1].preco, r'R$ 299,00');
    });
  });

  group('Billing.mapearPlanos — iOS/override (um produto por plano)', () {
    test('período inferido do id e ordenação por preço', () {
      final planos = Billing.mapearPlanos([
        _produtoApple(id: 'app.kairo.premium.anual', preco: 299.0),
        _produtoApple(id: 'app.kairo.premium.monthly', preco: 34.90),
      ]);

      expect(planos, hasLength(2));
      expect(planos[0].periodo, PeriodoPlano.mensal);
      expect(planos[1].periodo, PeriodoPlano.anual);
      expect(planos.every((p) => p.temTeste), isTrue);
    });
  });

  group('Billing.derivarPremium — status habilitantes', () {
    test('active + period_end no futuro → true', () {
      expect(
        Billing.derivarPremium(
          status: 'active',
          periodoFim: agora.add(const Duration(days: 7)),
          agora: agora,
        ),
        isTrue,
      );
    });

    test('trialing + period_end no futuro → true', () {
      expect(
        Billing.derivarPremium(
          status: 'trialing',
          periodoFim: agora.add(const Duration(hours: 1)),
          agora: agora,
        ),
        isTrue,
      );
    });

    test('grace + period_end no futuro → true', () {
      expect(
        Billing.derivarPremium(
          status: 'grace',
          periodoFim: agora.add(const Duration(days: 3)),
          agora: agora,
        ),
        isTrue,
      );
    });
  });

  group('Billing.derivarPremium — status NÃO habilitantes', () {
    for (final s in [
      'none',
      'incomplete',
      'incomplete_expired',
      'past_due',
      'canceled',
      'unpaid',
      'paused',
      'expired',
    ]) {
      test('$s → false mesmo com period_end no futuro', () {
        expect(
          Billing.derivarPremium(
            status: s,
            periodoFim: agora.add(const Duration(days: 30)),
            agora: agora,
          ),
          isFalse,
        );
      });
    }

    test('null → false', () {
      expect(
        Billing.derivarPremium(
          status: null,
          periodoFim: agora.add(const Duration(days: 30)),
          agora: agora,
        ),
        isFalse,
      );
    });
  });

  group('Billing.derivarPremium — vencimento', () {
    test('active com period_end no passado (expirado) → false', () {
      expect(
        Billing.derivarPremium(
          status: 'active',
          periodoFim: agora.subtract(const Duration(seconds: 1)),
          agora: agora,
        ),
        isFalse,
      );
    });

    test('active com period_end exatamente == agora → false (estrita)', () {
      // Critério SQL é `> now()`, estritamente — testamos a mesma fronteira.
      expect(
        Billing.derivarPremium(
          status: 'active',
          periodoFim: agora,
          agora: agora,
        ),
        isFalse,
      );
    });

    test('active sem period_end (null) → false', () {
      expect(
        Billing.derivarPremium(
          status: 'active',
          periodoFim: null,
          agora: agora,
        ),
        isFalse,
      );
    });

    test('trialing expirado → false', () {
      expect(
        Billing.derivarPremium(
          status: 'trialing',
          periodoFim: agora.subtract(const Duration(minutes: 1)),
          agora: agora,
        ),
        isFalse,
      );
    });
  });
}
