import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../main.dart';
import '../../history_page.dart';

class MessageSettingsDrawer extends StatefulWidget {
  const MessageSettingsDrawer({super.key});

  @override
  State<MessageSettingsDrawer> createState() => _MessageSettingsDrawerState();
}

class _MessageSettingsDrawerState extends State<MessageSettingsDrawer> {
  String _configuredCardNumber = 'Henüz kart konfigürasyonu yapılmadı';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadConfiguredCard();
  }

  Future<void> _loadConfiguredCard() async {
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final cardNumber = prefs.getString('configured_card_number');
      if (cardNumber != null && cardNumber.isNotEmpty) {
        setState(() {
          _configuredCardNumber = cardNumber;
        });
      } else {
        setState(() {
          _configuredCardNumber = 'Henüz kart konfigürasyonu yapılmadı';
        });
      }
    } catch (e) {
      print('Kart numarası yükleme hatası: $e');
      setState(() {
        _configuredCardNumber = 'Hata: Kart numarası yüklenemedi';
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Drawer(
      backgroundColor: colorScheme.surface,
      child: SafeArea(
        child: Column(
          children: [
            // Modern Header with ENKA Logo
            Container(
              width: double.infinity,
              height: 200, // Fixed height for the header image
              decoration: const BoxDecoration(
                color: Color(0xFF002A5C), // ENKA Blue
                image: DecorationImage(
                  image: AssetImage('assets/images/enka_logo.png'),
                  fit: BoxFit.cover,
                ),
              ),
            ),

            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Card Number Section
                    _buildSectionTitle(
                      context,
                      icon: Icons.numbers,
                      title: 'Kart Numarası',
                    ),
                    const SizedBox(height: 12),
                    _buildCardNumberCard(context),
                    const SizedBox(height: 24),

                    // Refresh Button
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _isLoading ? null : _loadConfiguredCard,
                        icon: _isLoading
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.refresh),
                        label: Text(_isLoading ? 'Yükleniyor...' : 'Yenile'),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Theme Settings Section
                    _buildSectionTitle(
                      context,
                      icon: Icons.brightness_6,
                      title: 'Görünüm',
                    ),
                    const SizedBox(height: 12),
                    Container(
                      decoration: BoxDecoration(
                        color: colorScheme.secondaryContainer.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: colorScheme.outline.withOpacity(0.2),
                        ),
                      ),
                      child: SwitchListTile(
                        title: const Text('Karanlık Tema'),
                        secondary: Icon(
                          Theme.of(context).brightness == Brightness.dark
                              ? Icons.dark_mode
                              : Icons.light_mode,
                          color: colorScheme.primary,
                        ),
                        value: Theme.of(context).brightness == Brightness.dark,
                        onChanged: (value) {
                          MyApp.of(context).toggleTheme();
                        },
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Gecis Gecmisi
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(context); // Drawer'i kapat
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const HistoryPage(),
                            ),
                          );
                        },
                        icon: const Icon(Icons.history),
                        label: const Text('Geçiş Geçmişi'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Info Section
                    _buildSectionTitle(
                      context,
                      icon: Icons.info_outline,
                      title: 'Bilgi',
                    ),
                    const SizedBox(height: 12),
                    _buildInfoCard(context),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context,
      {required IconData icon, required String title}) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Row(
      children: [
        Icon(icon, size: 20, color: colorScheme.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: colorScheme.onSurface,
          ),
        ),
      ],
    );
  }

  Widget _buildCardNumberCard(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surfaceVariant.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.outline.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // V2: Removed "Notify ile Gelen" label
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              _configuredCardNumber,
              style: textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.bold,
                fontFamily: 'monospace',
                color: colorScheme.onSurface,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    // V2: Updated info items
    final infoItems = [
      'Yeni kart tanımlamak için "Yeni Kart Ekle" butonuna basınız',
      'Kart numarası BLE cihazından alınır',
      'Giriş/Çıkış işlemlerinde bu numara kullanılacaktır',
      'Yalnızca bir kart kayıtlı olabilir, eski kartlar kayıtlı tutulmaz',
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: infoItems.map((info) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.check_circle_outline,
                  size: 18,
                  color: colorScheme.secondary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    info,
                    style: textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}
