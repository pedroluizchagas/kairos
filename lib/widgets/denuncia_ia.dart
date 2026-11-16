import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/kairo_tema.dart';
import '../core/banco.dart';
import '../core/i18n.dart';

/// Denúncia de conteúdo gerado por IA — a política de Conteúdo Gerado por IA
/// do Google Play exige que o usuário possa denunciar sem sair do app.
///
/// Abre o sheet de motivos e grava a escolha em `denuncias_ia`
/// (scripts/15_denuncias_ia.sql). [origem]: 'mentor' (resposta do chat) ou
/// 'carta' (carta semanal); [conteudo] é o texto denunciado.
Future<void> denunciarConteudoIA(
  BuildContext context, {
  required String origem,
  required String conteudo,
}) async {
  if (conteudo.trim().isEmpty) return;
  HapticFeedback.lightImpact();

  final motivo = await showModalBottomSheet<String>(
    context: context,
    backgroundColor: KC.sumi,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(32, 24, 32, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Alça do sheet
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

            Text(T.denunciaTitulo, style: KT.titulo()),
            const SizedBox(height: 8),
            Text(T.denunciaAviso, style: KT.caption()),

            const SizedBox(height: 24),

            _OpcaoMotivo(
              rotulo: T.denunciaOfensivo,
              onTap: () => Navigator.pop(ctx, 'ofensivo'),
            ),
            _OpcaoMotivo(
              rotulo: T.denunciaPerigoso,
              onTap: () => Navigator.pop(ctx, 'perigoso'),
            ),
            _OpcaoMotivo(
              rotulo: T.denunciaOutro,
              onTap: () => Navigator.pop(ctx, 'outro'),
            ),
          ],
        ),
      ),
    ),
  );
  if (motivo == null || !context.mounted) return;

  final mensageiro = ScaffoldMessenger.of(context);
  String aviso;
  try {
    await BancoDenuncias.enviar(
      origem: origem,
      motivo: motivo,
      conteudo: conteudo,
    );
    aviso = T.denunciaEnviada;
  } catch (e) {
    debugPrint('[Denuncia] erro ao enviar: $e');
    aviso = T.erroGenerico;
  }

  mensageiro.showSnackBar(
    SnackBar(
      backgroundColor: KC.card,
      behavior: SnackBarBehavior.floating,
      content: Text(aviso, style: KT.caption(cor: KC.texto)),
    ),
  );
}

class _OpcaoMotivo extends StatelessWidget {
  final String rotulo;
  final VoidCallback onTap;

  const _OpcaoMotivo({required this.rotulo, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            Icon(Icons.outlined_flag, size: 20, color: KC.texto),
            const SizedBox(width: 16),
            Expanded(child: Text(rotulo, style: KT.body())),
          ],
        ),
      ),
    );
  }
}
