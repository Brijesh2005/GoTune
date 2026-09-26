import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/app_constants.dart';
import '../providers/settings_provider.dart';
import '../theme/app_colors.dart';

/// Redesigned Profile & Settings screen matching the Pulse dark aesthetic.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _smartDownloads = true;
  bool _notifications = true;
  bool _darkAppearance = true;
  bool _showAdvancedApi = false;

  void _showEditAppNameDialog(BuildContext context, SettingsProvider settings) {
    final controller = TextEditingController(text: settings.appName);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Edit App Name', style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: const InputDecoration(hintText: 'App name identifier'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                settings.updateAppName(controller.text.trim());
                Navigator.pop(ctx);
              }
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
        title: const Text('Audius API Key', style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: const InputDecoration(hintText: 'Leave empty for public access'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
          ),
          ElevatedButton(
            onPressed: () {
              settings.updateApiKey(controller.text.trim().isEmpty ? null : controller.text.trim());
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 20, 18, 120),
          children: [
            // Screen Header
            const Text(
              'Profile',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 30,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.6,
              ),
            ),
            const SizedBox(height: 20),

            // Profile Card matching prototype
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0x1AFFFFFF), width: 1),
              ),
              child: Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: Text(
                        'G',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'GoTune Listener',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'listener@gotune.app',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13.5,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // Playback & Preferences Section Title
            const Text(
              'Playback & preferences',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),

            // Surface Card for Settings
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0x1AFFFFFF), width: 1),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  // Audio Quality Dropdown
                  Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Audio quality',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 14.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          decoration: BoxDecoration(
                            color: const Color(0xFF242A31),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: settings.audioQuality == '320'
                                  ? 'High · 320 kbps'
                                  : settings.audioQuality == '160'
                                      ? 'Standard · 160 kbps'
                                      : 'High · 320 kbps',
                              isExpanded: true,
                              dropdownColor: AppColors.surfaceElevated,
                              style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                              icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.textSecondary),
                              items: const [
                                DropdownMenuItem(value: 'High · 320 kbps', child: Text('High · 320 kbps')),
                                DropdownMenuItem(value: 'Standard · 160 kbps', child: Text('Standard · 160 kbps')),
                                DropdownMenuItem(value: 'Data saver · 96 kbps', child: Text('Data saver · 96 kbps')),
                              ],
                              onChanged: (val) {
                                if (val != null) {
                                  if (val.contains('320')) {
                                    settings.updateAudioQuality('320');
                                  } else if (val.contains('160')) {
                                    settings.updateAudioQuality('160');
                                  } else {
                                    settings.updateAudioQuality('96');
                                  }
                                }
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(color: Color(0x1AFFFFFF), height: 1),

                  // Smart Downloads Toggle
                  _buildToggleRow(
                    title: 'Smart downloads',
                    subtitle: 'Save recent favourites offline',
                    value: _smartDownloads,
                    onChanged: (v) => setState(() => _smartDownloads = v),
                  ),
                  const Divider(color: Color(0x1AFFFFFF), height: 1),

                  // New Music Notifications Toggle
                  _buildToggleRow(
                    title: 'New music notifications',
                    subtitle: 'Releases and playlist updates',
                    value: _notifications,
                    onChanged: (v) => setState(() => _notifications = v),
                  ),
                  const Divider(color: Color(0x1AFFFFFF), height: 1),

                  // Dark Appearance Toggle
                  _buildToggleRow(
                    title: 'Dark appearance',
                    subtitle: 'Easy on the eyes, day or night',
                    value: _darkAppearance,
                    onChanged: (v) => setState(() => _darkAppearance = v),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Advanced API Configuration (collapsible)
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0x1AFFFFFF), width: 1),
              ),
              child: ExpansionTile(
                title: const Text(
                  'API & Network Diagnostics',
                  style: TextStyle(color: AppColors.textPrimary, fontSize: 14.5, fontWeight: FontWeight.w600),
                ),
                subtitle: const Text(
                  'Decentralized nodes & credentials',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                ),
                leading: const Icon(Icons.tune_rounded, color: AppColors.primaryLight),
                children: [
                  ListTile(
                    title: const Text('API Client Name', style: TextStyle(color: AppColors.textPrimary, fontSize: 13.5)),
                    subtitle: Text(settings.appName, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                    trailing: const Icon(Icons.edit_rounded, color: AppColors.textMuted, size: 18),
                    onTap: () => _showEditAppNameDialog(context, settings),
                  ),
                  ListTile(
                    title: const Text('Audius API Key', style: TextStyle(color: AppColors.textPrimary, fontSize: 13.5)),
                    subtitle: Text(
                      settings.apiKey != null && settings.apiKey!.isNotEmpty ? '••••••••' : 'Optional (public endpoints)',
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                    ),
                    trailing: const Icon(Icons.edit_rounded, color: AppColors.textMuted, size: 18),
                    onTap: () => _showEditApiKeyDialog(context, settings),
                  ),
                  ListTile(
                    title: const Text('Test Network Connection', style: TextStyle(color: AppColors.textPrimary, fontSize: 13.5)),
                    subtitle: settings.testMessage.isNotEmpty
                        ? Text(
                            settings.testMessage,
                            style: TextStyle(
                              color: settings.testStatus == ConnectionTestStatus.error ? AppColors.error : AppColors.accentGreen,
                              fontSize: 12,
                            ),
                          )
                        : const Text('Ping discovery nodes', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                    trailing: ElevatedButton(
                      onPressed: () => settings.testAudiusConnection(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.surfaceElevated,
                        foregroundColor: AppColors.textPrimary,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        minimumSize: Size.zero,
                      ),
                      child: const Text('Test', style: TextStyle(fontSize: 12)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // App Footer
            const Center(
              child: Text(
                '${AppConstants.appName} v${AppConstants.appVersion}',
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToggleRow({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: AppColors.primary,
            activeTrackColor: AppColors.primarySoft,
            inactiveThumbColor: Colors.white,
            inactiveTrackColor: const Color(0xFF3B424C),
          ),
        ],
      ),
    );
  }
}
