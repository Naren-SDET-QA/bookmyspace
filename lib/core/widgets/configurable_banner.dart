import 'package:flutter/material.dart';
import '../../features/admin/domain/admin_settings.dart';
import 'app_network_image.dart';

class ConfigurableBanner extends StatelessWidget {
  const ConfigurableBanner({super.key, required this.settings});
  final Map<String, dynamic> settings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final background = AdminSettings.color(
      settings['banner_background'],
      theme.colorScheme.primaryContainer,
    );
    final textColor = AdminSettings.color(
      settings['banner_text_color'],
      theme.colorScheme.onPrimaryContainer,
    );
    final text = AdminSettings.text(
      settings['banner_text'],
      'Find and book a space that works for you.',
    );
    final media = settings['banner_media_url']?.toString() ?? '';
    return Card(
      color: background,
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 88),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  text,
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  softWrap: true,
                ),
              ),
            ),
            if (media.isNotEmpty)
              SizedBox(
                width: 96,
                height: 72,
                child: AppNetworkImage(url: media),
              ),
          ],
        ),
      ),
    );
  }
}
