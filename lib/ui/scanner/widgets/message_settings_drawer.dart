/*import 'package:flutter/material.dart';

class MessageSettingsDrawer extends StatelessWidget {
  final TextEditingController controller;
  final void Function(String message) onSave;

  const MessageSettingsDrawer({
    super.key,
    required this.controller,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Column(
        children: [
          const DrawerHeader(
            decoration: BoxDecoration(
              color: Color(0xFF1976D2),
            ),
            child: Center(
              child: Text(
                'Mesaj Ayarları',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Giriş/Çıkış Mesajı',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Bu mesaj BLE cihazına gönderilecektir:',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: controller,
                    decoration: const InputDecoration(
                      labelText: 'Mesaj',
                      hintText: 'Örn: AC, 123456, vb.',
                      border: OutlineInputBorder(),
                    ),
                    maxLength: 50,
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        onSave(controller.text);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Mesaj kaydedildi'),
                            backgroundColor: Colors.green,
                          ),
                        );
                        Navigator.pop(context);
                      },
                      icon: const Icon(Icons.save),
                      label: const Text('Kaydet'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1976D2),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}*/
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MessageSettingsDrawer extends StatefulWidget {
  const MessageSettingsDrawer({super.key});

  @override
  State<MessageSettingsDrawer> createState() => _MessageSettingsDrawerState();
}

class _MessageSettingsDrawerState extends State<MessageSettingsDrawer> {
  String _configuredCardNumber = 'Henüz kart konfigürasyonu yapılmadı';

  @override
  void initState() {
    super.initState();
    _loadConfiguredCard();
  }

  Future<void> _loadConfiguredCard() async {
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
    }
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Column(
        children: [
          DrawerHeader(
            decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary),
            child: const Center(
              child: Text('Kart Bilgileri', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Konfigüre Edilmiş Kart Numarası',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceVariant,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Theme.of(context).dividerColor),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Notify ile Gelen Kart Numarası:',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _configuredCardNumber,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _loadConfiguredCard,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Yenile'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Theme.of(context).colorScheme.onPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Bilgi:',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '• Bu kart numarası "Kart Konfigürasyonu" butonu ile alınmıştır\n'
                    '• Notify ile BLE cihazından gelen kart numarasıdır\n'
                    '• Giriş/Çıkış işlemlerinde bu numara kullanılacaktır\n'
                    '• Her yeni kart numarası öncekileri siler',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}


