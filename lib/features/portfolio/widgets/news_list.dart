import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:solver/core/theme/app_theme.dart';
import 'package:solver/core/theme/app_tokens.dart';
import 'package:solver/features/portfolio/models/company_news.dart';
import 'package:solver/shared/widgets/app_panel.dart';
import 'package:url_launcher/url_launcher.dart';

class NewsList extends StatelessWidget {
  final List<CompanyNews> news;

  const NewsList({super.key, required this.news});

  @override
  Widget build(BuildContext context) {
    return AppPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Actualites recentes',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppSpacing.sm),
          if (news.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
              child: Text('Aucune actualite recente.'),
            )
          else
            ...news
                .take(10)
                .map(
                  (item) => ListTile(
                    onTap: () => _openUrl(item.url),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: kIsWeb || item.image == null || item.image!.isEmpty
                        ? const Icon(Icons.article_outlined)
                        : ClipRRect(
                            borderRadius: BorderRadius.circular(AppRadius.r8),
                            child: Image.network(
                              item.image!,
                              width: 46,
                              height: 46,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) =>
                                  const Icon(Icons.article_outlined),
                            ),
                          ),
                    title: Text(
                      item.headline,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      [
                        if ((item.source ?? '').isNotEmpty) item.source!,
                        if (item.datetime != null) _formatTime(item.datetime!),
                      ].join(' | '),
                    ),
                    trailing: const Icon(Icons.open_in_new, size: 16),
                  ),
                ),
        ],
      ),
    );
  }

  Future<void> _openUrl(String? rawUrl) async {
    if (rawUrl == null || rawUrl.isEmpty) return;
    final uri = Uri.tryParse(rawUrl);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  String _formatTime(DateTime value) {
    final now = DateTime.now().toUtc();
    final dt = value.toUtc();
    final diff = now.difference(dt);

    if (diff.inMinutes < 1) return 'a l instant';
    if (diff.inHours < 1) return 'il y a ${diff.inMinutes} min';
    if (diff.inDays < 1) return 'il y a ${diff.inHours} h';
    if (diff.inDays < 7) return 'il y a ${diff.inDays} j';

    return DateFormat('dd/MM/yyyy HH:mm').format(value.toLocal());
  }
}
