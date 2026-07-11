import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../main.dart';
import 'cache.dart';
import 'i18n.dart';
import 'kairo_tema.dart';

/// Consentimento para envio de dados a provedores de IA (Anthropic/Groq),
/// exigido pela Apple (5.1.1(i)/5.1.2(i)): o app precisa dizer O QUE envia,
/// PARA QUEM, e obter permissão ANTES do primeiro envio.
///
/// O aceite é gravado em `profiles.consentimento_ia_em` (sobrevive a
/// reinstalação/troca de aparelho) com espelho no cache local. As telas de IA
/// chamam [garantir] antes de qualquer chamada que saia do aparelho: chat do
/// Mentor (texto e voz) e geração da carta semanal. O servidor reforça o mesmo
/// aceite na `relatorio-semanal` (cobre o cron de domingo).
class ConsentimentoIA {
  ConsentimentoIA._();

  static const _chaveCache = 'consentimento_ia';

  // Mesma URL do paywall (portao.dart) — duplicada aqui para o core não
  // depender de uma tela.
  static const _urlPrivacidade = 'https://thekairo.app/privacidade';

  /// Memória da sessão: evita reconsultar cache/servidor a cada mensagem.
  static bool _aceitoNaSessao = false;

  /// Diz se o usuário já consentiu (sessão → cache local → servidor).
  static Future<bool> aceito() async {
    if (_aceitoNaSessao) return true;
    if (CacheLocal.lerMapa(_chaveCache)?['aceito'] == true) {
      _aceitoNaSessao = true;
      return true;
    }
    // Reinstalação/novo aparelho: o aceite pode existir só no servidor.
    final user = supabase.auth.currentUser;
    if (user == null) return false;
    try {
      final perfil = await supabase
          .from('profiles')
          .select('consentimento_ia_em')
          .eq('id', user.id)
          .maybeSingle();
      if (perfil?['consentimento_ia_em'] != null) {
        _aceitoNaSessao = true;
        await CacheLocal.gravar(_chaveCache, {'aceito': true});
        return true;
      }
    } catch (_) {
      // Sem rede/coluna: trata como não consentido — o sheet pergunta de novo.
    }
    return false;
  }

  static Future<void> _registrar() async {
    _aceitoNaSessao = true;
    await CacheLocal.gravar(_chaveCache, {'aceito': true});
    final user = supabase.auth.currentUser;
    if (user == null) return;
    try {
      await supabase.from('profiles').upsert({
        'id': user.id,
        'consentimento_ia_em': DateTime.now().toUtc().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      // Best-effort: o cache local mantém o aceite; o servidor converge na
      // próxima gravação. (Sem a coluna — migration pendente — cai aqui.)
      debugPrint('[ConsentimentoIA] falha ao persistir no perfil: $e');
    }
  }

  /// Garante o consentimento antes de um recurso de IA. Se ainda não foi dado,
  /// mostra a folha de disclosure e aguarda a decisão. Retorna true quando o
  /// envio pode prosseguir.
  static Future<bool> garantir(BuildContext context) async {
    if (await aceito()) return true;
    if (!context.mounted) return false;

    final aceitou = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: KC.sumi,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(32, 24, 32, 32),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 32,
                    height: 3,
                    decoration: BoxDecoration(
                      color: KC.grafite,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                Text(T.iaConsentTitulo, style: KT.titulo()),
                const SizedBox(height: 12),
                Text(T.iaConsentTexto, style: KT.bodySerif(cor: KC.cinza)),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: () async {
                    final uri = Uri.tryParse(_urlPrivacidade);
                    if (uri != null) {
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                    }
                  },
                  child: Text(
                    T.politicaPrivacidade,
                    style: KT.caption(cor: KC.kin),
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: KC.washi,
                      foregroundColor: KC.sumi,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(T.iaConsentAceitar, style: KT.body(cor: KC.sumi)),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: KC.washi,
                      side: BorderSide(color: KC.grafite, width: 1),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(T.iaConsentAgoraNao, style: KT.body()),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (aceitou != true) return false;
    await _registrar();
    return true;
  }
}
