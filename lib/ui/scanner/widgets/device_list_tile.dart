import 'package:flutter/material.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import '../managers/device_filter.dart';

/// BLE cihaz listesi için optimize edilmiş liste elemanı widget'ı
class DeviceListTile extends StatefulWidget {
  final DiscoveredDevice device;
  final bool isConnected;
  final bool buttonsDisabled;
  final VoidCallback onEntry;
  final VoidCallback onCardConfig;

  // Unused callbacks kept for interface compatibility if needed,
  // but unrelated buttons are removed from UI.
  final VoidCallback onExit;
  final VoidCallback onTest;

  const DeviceListTile({
    super.key,
    required this.device,
    required this.isConnected,
    required this.buttonsDisabled,
    required this.onEntry,
    required this.onExit,
    required this.onTest,
    required this.onCardConfig,
  });

  @override
  State<DeviceListTile> createState() => _DeviceListTileState();
}

class _DeviceListTileState extends State<DeviceListTile>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    // Setup pulsing animation for the bluetooth icon
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Bluetooth device name
    final deviceName = DeviceFilter.extractDeviceName(widget.device);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      elevation: widget.isConnected ? 8 : 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
            child: Row(
              children: [
                // Animated Large Bluetooth Icon
                ScaleTransition(
                  scale: _scaleAnimation,
                  child: Container(
                    width: 80, // Much larger
                    height: 80,
                    decoration: BoxDecoration(
                      color: widget.isConnected
                          ? Colors.green.withOpacity(0.1)
                          : colorScheme.primaryContainer.withOpacity(0.4),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      widget.isConnected
                          ? Icons.bluetooth_connected
                          : Icons.bluetooth,
                      size: 48, // Large Icon
                      color: widget.isConnected
                          ? Colors.green
                          : colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 24),
                // Device Name and Status
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        deviceName,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Prominent "READY" Text (Turkish: HAZIR)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: widget.isConnected
                              ? Colors.green
                              : colorScheme.primary,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          widget.isConnected ? 'BAĞLI' : 'HAZIR',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2.0,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // No diagnostic data (subtitle removed)

          const SizedBox(height: 16),

          // Action Buttons
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: widget.buttonsDisabled ? null : widget.onEntry,
                icon: const Icon(Icons.login, size: 28),
                label: const Text('GİRİŞ YAP',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                style: FilledButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  foregroundColor: colorScheme.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.tonalIcon(
                onPressed: widget.buttonsDisabled ? null : widget.onCardConfig,
                icon: const Icon(Icons.add_card),
                label: const Text('YENİ KART EKLE',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                style: FilledButton.styleFrom(
                  backgroundColor: colorScheme.secondaryContainer,
                  foregroundColor: colorScheme.onSecondaryContainer,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
