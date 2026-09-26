import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/app_constants.dart';
import '../providers/settings_provider.dart';
import '../theme/app_colors.dart';

/// Settings screen for API credentials, audio preferences, and application compliance details.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
          children: [
            // Screen Header
            const Text(
              'Settings',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 26,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.8,
              ),
            ),
            const SizedBox(height: 16),

            // Audius API Configuration Section
            _buildSectionTitle('Audius API Configuration'),
            const SizedBox(height: 8),
            _buildCard([
              // App Name field
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                leading: const Icon(Icons.apps_rounded, color: AppColors.primaryLight),
                title: const Text('API App Name', style: TextStyle(color: AppColors.textPrimary, fontSize: 14.5)),
                subtitle: Text(
                  settings.appName,
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                ),
                trailing: const Icon(Icons.edit_rounded, color: AppColors.textMuted, size: 18),
                onTap: () => _showEditAppNameDialog(context, settings),
              ),
              const Divider(color: AppColors.border, height: 1),

              // API Key field
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                leading: const Icon(Icons.vpn_key_rounded, color: AppColors.secondary),
                title: const Text('Audius API Key', style: TextStyle(color: AppColors.textPrimary, fontSize: 14.5)),
                subtitle: Text(
                  settings.apiKey != null && settings.apiKey!.isNotEmpty
                      ? '••••••••${settings.apiKey!.substring((settings.apiKey!.length - 4).clamp(0, settings.apiKey!.length))}'
                      : 'Optional (public endpoints active)',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                ),
                trailing: const Icon(Icons.edit_rounded, color: AppColors.textMuted, size: 18),
                onTap: () => _showEditApiKeyDialog(context, settings),
              ),
              const Divider(color: AppColors.border, height: 1),

              // Test Connection Row
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                leading: const Icon(Icons.network_check_rounded, color: AppColors.accentGreen),
                title: const Text('Test Audius Connection', style: TextStyle(color: AppColors.textPrimary, fontSize: 14.5)),
                subtitle: settings.testMessage.isNotEmpty
                    ? Text(
                        settings.testMessage,
                        style: TextStyle(
                          color: settings.testStatus == ConnectionTestStatus.error
                              ? AppColors.error
                              : AppColors.accentGreen,
                          fontSize: 12,
                        ),
                      )
                    : const Text(
                        'Ping discovery nodes on the decentralized network',
                        style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                      ),
                trailing: settings.testStatus == ConnectionTestStatus.testing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                      )
                    : ElevatedButton(
                        onPressed: () => settings.testAudiusConnection(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.surfaceElevated,
                          foregroundColor: AppColors.textPrimary,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          minimumSize: Size.zero,
                          side: const BorderSide(color: AppColors.border),
                        ),
                        child: const Text('Ping', style: TextStyle(fontSize: 12)),
                      ),
              ),
            ]),

            const SizedBox(height: 24),

            // Audio Settings Placeholder Section
            _buildSectionTitle('Audio & Playback'),
            const SizedBox(height: 8),
            _buildCard([
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                leading: const Icon(Icons.graphic_eq_rounded, color: AppColors.accentAmber),
                title: const Text('Streaming Quality', style: TextStyle(color: AppColors.textPrimary, fontSize: 14.5)),
                subtitle: Text(
                  settings.audioQuality,
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                ),
                trailing: const Icon(Icons.arrow_forward_ios_rounded, color: AppColors.textMuted, size: 14),
                onTap: () => _showAudioQualityDialog(context, settings),
              ),
              const Divider(color: AppColors.border, height: 1),
              const ListTile(
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                leading: Icon(Icons.surround_sound_rounded, color: AppColors.primaryLight),
                title: Text('Equalizer & Loudness', style: TextStyle(color: AppColors.textPrimary, fontSize: 14.5)),
                subtitle: Text('Default (Neutral balanced)', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
              ),
              const Divider(color: AppColors.border, height: 1),
              const ListTile(
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                leading: Icon(Icons.cached_rounded, color: AppColors.textMuted),
                title: Text('Audio Cache & Buffer', style: TextStyle(color: AppColors.textPrimary, fontSize: 14.5)),
                subtitle: Text('Fast network prefetch enabled', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
              ),
            ]),

            const SizedBox(height: 24),

            // Application Information Section
            _buildSectionTitle('Application & Legal'),
            const SizedBox(height: 8),
            _buildCard([
              const ListTile(
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                leading: Icon(Icons.info_outline_rounded, color: AppColors.textSecondary),
                title: Text('GoTune', style: TextStyle(color: AppColors.textPrimary, fontSize: 14.5, fontWeight: FontWeight.bold)),
                subtitle: Text('Version ${AppConstants.appVersion} (Personal Edition)', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
              ),
              const Divider(color: AppColors.border, height: 1),
              const ListTile(
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                leading: Icon(Icons.hub_rounded, color: AppColors.secondary),
                title: Text('Audius Open Protocol', style: TextStyle(color: AppColors.textPrimary, fontSize: 14.5)),
                subtitle: Text('Catalog powered by Audius decentralized discovery network.', style: TextStyle(color: AppColors.textSecondary, fontSize: 12.5)),
              ),
              const Divider(color: AppColors.border, height: 1),
              const ListTile(
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                leading: Icon(Icons.shield_rounded, color: AppColors.accentGreen),
                title: Text('Compliance Standards', style: TextStyle(color: AppColors.textPrimary, fontSize: 14.5)),
                subtitle: Text(
                  '100% Official documented APIs only • No scraping • No DRM bypass • Zero ads',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: AppColors.textMuted,
        fontSize: 12,
        fontWeight: FontWeight.bold,
        letterSpacing: 0.8,
      ),
    );
  }

  Widget _buildCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: children,
      ),
    );
  }

  void _showEditAppNameDialog(BuildContext context, SettingsProvider settings) {
    final controller = TextEditingController(text: settings.appName);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Edit API App Name', style: TextStyle(color: AppColors.textPrimary, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Audius requests require an app_name parameter for analytics and rate attribution.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12.5),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: const InputDecoration(hintText: 'e.g. GoTune'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
          ),
          ElevatedButton(
            onPressed: () {
              settings.updateAppName(controller.text);
              Navigator.of(ctx).pop();
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showEditApiKeyDialog(BuildContext context, SettingsProvider settings) {
    final controller = TextEditingController(text: settings.apiKey ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Configure Audius API Key', style: TextStyle(color: AppColors.textPrimary, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Public endpoints function without a key. To get dedicated high rate limits, register your app at api.audius.co/plans and enter the key here.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12.5),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: const InputDecoration(hintText: 'Enter API key or leave blank'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
          ),
          ElevatedButton(
            onPressed: () {
              settings.updateApiKey(controller.text);
              Navigator.of(ctx).pop();
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showAudioQualityDialog(BuildContext context, SettingsProvider settings) {
    final options = ['Auto (High)', '320 kbps (Lossless HQ)', '160 kbps (Standard)', '96 kbps (Data Saver)'];
    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        backgroundColor: AppColors.surfaceElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Streaming Quality Preference', style: TextStyle(color: AppColors.textPrimary, fontSize: 16)),
        children: options.map((opt) {
          final isSelected = settings.audioQuality == opt;
          return SimpleDialogOption(
            onPressed: () {
              settings.updateAudioQuality(opt);
              Navigator.of(ctx).pop();
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  opt,
                  style: TextStyle(
                    color: isSelected ? AppColors.primaryLight : AppColors.textPrimary,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                if (isSelected)
                  const Icon(Icons.check_rounded, color: AppColors.primaryLight, size: 20),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}
