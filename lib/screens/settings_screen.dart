import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/app_constants.dart';
import '../providers/settings_provider.dart';
import '../services/music_catalog_aggregator.dart';
import '../services/provider_execution.dart';
import '../theme/app_colors.dart';

/// Redesigned Profile & Settings screen matching the GoTune YouTube dark aesthetic.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notifications = true;
  bool _darkAppearance = true;

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
              'Profile & Settings',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 30,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.6,
              ),
            ),
            const SizedBox(height: 20),

            // Profile Card
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
                        'YouTube Music Player',
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
              'Preferences',
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
                  // Playback Quality Selection
                  Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Playback quality preference',
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
                                  ? 'High definition'
                                  : settings.audioQuality == '160'
                                      ? 'Standard'
                                      : 'High definition',
                              isExpanded: true,
                              dropdownColor: AppColors.surfaceElevated,
                              style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                              icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.textSecondary),
                              items: const [
                                DropdownMenuItem(value: 'High definition', child: Text('High definition (HD)')),
                                DropdownMenuItem(value: 'Standard', child: Text('Standard')),
                                DropdownMenuItem(value: 'Data saver', child: Text('Data saver')),
                              ],
                              onChanged: (val) {
                                if (val != null) {
                                  if (val.contains('High')) {
                                    settings.updateAudioQuality('320');
                                  } else if (val.contains('Standard')) {
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

                  // Notifications Toggle
                  _buildToggleRow(
                    title: 'Recommendations & updates',
                    subtitle: 'Weekly trending releases and radio discovery',
                    value: _notifications,
                    onChanged: (v) => setState(() => _notifications = v),
                  ),
                  const Divider(color: Color(0x1AFFFFFF), height: 1),

                  // Dark Appearance Toggle
                  _buildToggleRow(
                    title: 'Dark appearance',
                    subtitle: 'OLED-optimized high contrast dark theme',
                    value: _darkAppearance,
                    onChanged: (v) => setState(() => _darkAppearance = v),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Diagnostics and Cache (collapsible)
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0x1AFFFFFF), width: 1),
              ),
              child: ExpansionTile(
                title: const Text(
                  'Diagnostics & Storage',
                  style: TextStyle(color: AppColors.textPrimary, fontSize: 14.5, fontWeight: FontWeight.w600),
                ),
                subtitle: const Text(
                  'YouTube catalog cache & reliability',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                ),
                leading: const Icon(Icons.tune_rounded, color: AppColors.primaryLight),
                children: [
                  ListTile(
                    title: const Text(
                      'Catalog Provider Health',
                      style: TextStyle(color: AppColors.textPrimary, fontSize: 13.5),
                    ),
                    subtitle: const Text(
                      'Live reliability metrics for YouTube discovery',
                      style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                    ),
                    trailing: const Icon(Icons.monitor_heart_rounded, color: AppColors.primaryLight, size: 20),
                    onTap: () => _showProviderHealthSheet(context),
                  ),
                  ListTile(
                    title: const Text(
                      'Clear Catalog Cache',
                      style: TextStyle(color: AppColors.textPrimary, fontSize: 13.5),
                    ),
                    subtitle: const Text(
                      'Force browse and search to re-fetch freshest YouTube results',
                      style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                    ),
                    trailing: const Icon(Icons.restart_alt_rounded, color: AppColors.primaryLight, size: 20),
                    onTap: () {
                      MusicCatalogAggregator.active?.invalidateCatalogCaches();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('YouTube catalog cache cleared')),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // App Footer
            const Center(
              child: Text(
                '${AppConstants.appName} v${AppConstants.appVersion} • Powered by YouTube IFrame Player',
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showProviderHealthSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) {
        return AnimatedBuilder(
          animation: MusicDiagnostics.instance,
          builder: (context, _) {
            final diagnostics = MusicDiagnostics.instance;
            final health = diagnostics.allHealth
              ..sort((a, b) => b.totalCalls.compareTo(a.totalCalls));

            return DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.6,
              maxChildSize: 0.9,
              builder: (context, scrollController) {
                return ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 30),
                  children: [
                    const Text(
                      'Catalog Provider Health',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Recovered by retry: ${diagnostics.totalRecoveredByRetry}  •  '
                      'Stale cache serves: ${diagnostics.totalStaleCacheServes}',
                      style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                    ),
                    const SizedBox(height: 16),
                    if (health.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 30),
                        child: Text(
                          'No catalog calls yet. Browse or search to start collecting health data.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                        ),
                      ),
                    for (final entry in health) ...[
                      Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceElevated,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.border, width: 1),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    entry.displayName,
                                    style: const TextStyle(
                                      color: AppColors.textPrimary,
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                Text(
                                  _healthLabel(entry),
                                  style: TextStyle(
                                    color: _healthColor(entry),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${entry.totalCalls} calls  •  '
                              '${(entry.successRate * 100).round()}% success  •  '
                              '${entry.failureCount} failed  •  '
                              '${entry.timeoutCount} timed out  •  '
                              '${entry.emptyCount} empty  •  '
                              '${entry.retryCount} retries',
                              style: const TextStyle(color: AppColors.textMuted, fontSize: 11.5),
                            ),
                            if (entry.lastError != null) ...[
                              const SizedBox(height: 6),
                              Text(
                                'Last error: ${entry.lastError}',
                                style: const TextStyle(color: AppColors.error, fontSize: 11.5),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                    TextButton.icon(
                      onPressed: () {
                        MusicDiagnostics.instance.clear();
                        Navigator.pop(ctx);
                      },
                      icon: const Icon(Icons.restart_alt_rounded, size: 18),
                      label: const Text('Reset statistics'),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  String _healthLabel(ProviderHealth health) {
    if (health.totalCalls == 0) return 'Idle';
    if (health.isDegraded) return 'Degraded';
    return 'Healthy';
  }

  Color _healthColor(ProviderHealth health) {
    if (health.totalCalls == 0) return AppColors.textMuted;
    if (health.isDegraded) return AppColors.error;
    return AppColors.accentGreen;
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
            activeThumbColor: AppColors.primary,
            activeTrackColor: AppColors.primarySoft,
            inactiveThumbColor: Colors.white,
            inactiveTrackColor: const Color(0xFF3B424C),
          ),
        ],
      ),
    );
  }
}
