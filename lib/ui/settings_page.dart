import 'package:flutter/material.dart';
import '../services/settings_service.dart';
import '../services/background_scan_service.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _autoOpenEnabled = false;
  int _rssiThreshold = -55;
  int _cooldownSeconds = 30;
  bool _requireBiometric = false;
  bool _entryOnly = true;
  bool _backgroundScanEnabled = false;
  bool _notificationEnabled = false;
  bool _notificationSound = true;
  bool _notificationVibrate = true;
  bool _quickModeEnabled = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final autoOpen = await SettingsService.isAutoOpenEnabled();
    final rssi = await SettingsService.getAutoOpenRssiThreshold();
    final cooldown = await SettingsService.getAutoOpenCooldownSeconds();
    final biometric = await SettingsService.isAutoOpenBiometricRequired();
    final entryOnly = await SettingsService.isAutoOpenEntryOnly();
    final bgScan = await SettingsService.isBackgroundScanEnabled();
    final notif = await SettingsService.isNotificationEnabled();
    final notifSound = await SettingsService.isNotificationSoundEnabled();
    final notifVibrate = await SettingsService.isNotificationVibrateEnabled();
    final quickMode = await SettingsService.isQuickModeEnabled();

    if (mounted) {
      setState(() {
        _autoOpenEnabled = autoOpen;
        _rssiThreshold = rssi;
        _cooldownSeconds = cooldown;
        _requireBiometric = biometric;
        _entryOnly = entryOnly;
        _backgroundScanEnabled = bgScan;
        _notificationEnabled = notif;
        _notificationSound = notifSound;
        _notificationVibrate = notifVibrate;
        _quickModeEnabled = quickMode;
        _loading = false;
      });
    }
  }

  String _rssiLabel(int rssi) {
    if (rssi >= -40) return 'Cok Yakin';
    if (rssi >= -50) return 'Yakin';
    if (rssi >= -60) return 'Orta';
    return 'Uzak';
  }

  String _cooldownLabel(int seconds) {
    if (seconds < 60) return '${seconds}sn';
    return '${seconds ~/ 60}dk';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ayarlar'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                // --- Bolum 1: Otomatik Acma ---
                _buildSectionHeader(
                  context,
                  icon: Icons.near_me,
                  title: 'Yaklasim ile Otomatik Acma',
                ),
                _buildCard(
                  context,
                  children: [
                    SwitchListTile(
                      title: const Text('Yaklasinca Kapi Ac'),
                      subtitle: const Text(
                          'Favori kapiya yaklasinca otomatik giris yapar'),
                      secondary: Icon(Icons.sensors,
                          color: _autoOpenEnabled
                              ? colorScheme.primary
                              : colorScheme.outline),
                      value: _autoOpenEnabled,
                      onChanged: (value) async {
                        setState(() => _autoOpenEnabled = value);
                        await SettingsService.setAutoOpenEnabled(value);
                      },
                    ),
                    if (_autoOpenEnabled) ...[
                      const Divider(height: 1),
                      // RSSI Slider
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                        child: Row(
                          children: [
                            const Icon(Icons.signal_cellular_alt, size: 20),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Algilama Mesafesi: ${_rssiLabel(_rssiThreshold)}',
                                    style:
                                        Theme.of(context).textTheme.bodyMedium,
                                  ),
                                  Text(
                                    '${_rssiThreshold} dBm',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                            color:
                                                colorScheme.onSurfaceVariant),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Slider(
                        value: _rssiThreshold.toDouble(),
                        min: -70,
                        max: -35,
                        divisions: 7,
                        label: '${_rssiLabel(_rssiThreshold)} ($_rssiThreshold dBm)',
                        onChanged: (value) {
                          setState(() => _rssiThreshold = value.round());
                        },
                        onChangeEnd: (value) async {
                          await SettingsService.setAutoOpenRssiThreshold(
                              value.round());
                        },
                      ),
                      const Divider(height: 1),
                      // Cooldown
                      ListTile(
                        leading: const Icon(Icons.timer, size: 20),
                        title: const Text('Bekleme Suresi'),
                        subtitle: const Text(
                            'Ayni kapi icin tekrar tetikleme araligi'),
                        trailing: DropdownButton<int>(
                          value: _cooldownSeconds,
                          underline: const SizedBox(),
                          items: [15, 30, 60, 120].map((sec) {
                            return DropdownMenuItem<int>(
                              value: sec,
                              child: Text(_cooldownLabel(sec)),
                            );
                          }).toList(),
                          onChanged: (value) async {
                            if (value == null) return;
                            setState(() => _cooldownSeconds = value);
                            await SettingsService.setAutoOpenCooldownSeconds(
                                value);
                          },
                        ),
                      ),
                      const Divider(height: 1),
                      // Biyometrik
                      SwitchListTile(
                        title: const Text('Parmak Izi / Yuz Onay'),
                        subtitle: const Text(
                            'Otomatik acmadan once biyometrik dogrulama iste'),
                        secondary: const Icon(Icons.fingerprint, size: 20),
                        value: _requireBiometric,
                        onChanged: (value) async {
                          setState(() => _requireBiometric = value);
                          await SettingsService.setAutoOpenBiometricRequired(
                              value);
                        },
                      ),
                      const Divider(height: 1),
                      // Sadece giris
                      SwitchListTile(
                        title: const Text('Sadece Giris'),
                        subtitle: const Text(
                            'Kapali: hem giris hem cikis otomatik yapilir'),
                        secondary: const Icon(Icons.login, size: 20),
                        value: _entryOnly,
                        onChanged: (value) async {
                          setState(() => _entryOnly = value);
                          await SettingsService.setAutoOpenEntryOnly(value);
                        },
                      ),
                    ],
                  ],
                ),

                const SizedBox(height: 8),

                // --- Bolum 2: Arka Plan Tarama ---
                _buildSectionHeader(
                  context,
                  icon: Icons.radar,
                  title: 'Arka Plan Tarama',
                ),
                _buildCard(
                  context,
                  children: [
                    SwitchListTile(
                      title: const Text('Arka Planda Tara'),
                      subtitle: const Text(
                          'Uygulama kapali olsa bile kapi algilandiginda bildirim gonderir'),
                      secondary: Icon(Icons.radar,
                          color: _backgroundScanEnabled
                              ? colorScheme.primary
                              : colorScheme.outline),
                      value: _backgroundScanEnabled,
                      onChanged: (value) async {
                        setState(() => _backgroundScanEnabled = value);
                        await SettingsService.setBackgroundScanEnabled(value);
                        // Foreground service baslat/durdur
                        if (value) {
                          await BackgroundScanService.start();
                          _showInfoSnackbar('Arka plan tarama baslatildi');
                        } else {
                          await BackgroundScanService.stop();
                          _showInfoSnackbar('Arka plan tarama durduruldu');
                        }
                      },
                    ),
                    if (_backgroundScanEnabled)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                        child: Text(
                          'Bildirim cubugunuzda kalici bir bildirim gorunecektir. '
                          'Bu, Android\'in arka plan taramayi durdurmasini engeller.',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: colorScheme.onSurfaceVariant),
                        ),
                      ),
                  ],
                ),

                const SizedBox(height: 8),

                // --- Bolum 3: Bildirimler ---
                _buildSectionHeader(
                  context,
                  icon: Icons.notifications_active,
                  title: 'Bildirimler',
                ),
                _buildCard(
                  context,
                  children: [
                    SwitchListTile(
                      title: const Text('Kapi Bildirimleri'),
                      subtitle: const Text(
                          'Kapi yakininda bildirim goster, bildirimden giris yap'),
                      secondary: Icon(Icons.notifications_active,
                          color: _notificationEnabled
                              ? colorScheme.primary
                              : colorScheme.outline),
                      value: _notificationEnabled,
                      onChanged: (value) async {
                        setState(() => _notificationEnabled = value);
                        await SettingsService.setNotificationEnabled(value);
                      },
                    ),
                    if (_notificationEnabled) ...[
                      const Divider(height: 1),
                      SwitchListTile(
                        title: const Text('Bildirim Sesi'),
                        secondary: const Icon(Icons.volume_up, size: 20),
                        value: _notificationSound,
                        onChanged: (value) async {
                          setState(() => _notificationSound = value);
                          await SettingsService.setNotificationSoundEnabled(
                              value);
                        },
                      ),
                      const Divider(height: 1),
                      SwitchListTile(
                        title: const Text('Bildirim Titresimi'),
                        secondary: const Icon(Icons.vibration, size: 20),
                        value: _notificationVibrate,
                        onChanged: (value) async {
                          setState(() => _notificationVibrate = value);
                          await SettingsService.setNotificationVibrateEnabled(
                              value);
                        },
                      ),
                    ],
                  ],
                ),

                const SizedBox(height: 8),

                // --- Bolum 4: Hizli Mod ---
                _buildSectionHeader(
                  context,
                  icon: Icons.flash_on,
                  title: 'Hizli Mod',
                ),
                _buildCard(
                  context,
                  children: [
                    SwitchListTile(
                      title: const Text('Onay Ekrani Olmadan Gonder'),
                      subtitle: const Text(
                          'Giris/Cikis butonuna basinca dogrudan gonderir'),
                      secondary: Icon(Icons.flash_on,
                          color: _quickModeEnabled
                              ? colorScheme.primary
                              : colorScheme.outline),
                      value: _quickModeEnabled,
                      onChanged: (value) async {
                        setState(() => _quickModeEnabled = value);
                        await SettingsService.setQuickModeEnabled(value);
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 24),
              ],
            ),
    );
  }

  Widget _buildSectionHeader(BuildContext context,
      {required IconData icon, required String title}) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Row(
        children: [
          Icon(icon, size: 20, color: colorScheme.primary),
          const SizedBox(width: 8),
          Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.primary,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(BuildContext context, {required List<Widget> children}) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }

  void _showInfoSnackbar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 2),
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}
