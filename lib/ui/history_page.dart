import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/history_service.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  List<HistoryEntry> _entries = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final entries = await HistoryService.getEntries();
    if (mounted) {
      setState(() {
        _entries = entries;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Geçiş Geçmişi'),
        actions: [
          if (_entries.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Geçmişi Temizle'),
                    content: const Text('Tüm geçiş kayıtları silinecek.'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('İptal'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Temizle'),
                      ),
                    ],
                  ),
                );
                if (confirmed == true) {
                  await HistoryService.clearHistory();
                  _loadHistory();
                }
              },
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _entries.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.history, size: 64, color: colorScheme.outline),
                      const SizedBox(height: 16),
                      Text(
                        'Henüz geçiş kaydı yok',
                        style: TextStyle(
                          fontSize: 18,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _entries.length,
                  itemBuilder: (context, index) {
                    final entry = _entries[index];
                    final isEntry = entry.action == 'entry';
                    final timeStr = DateFormat('HH:mm').format(entry.timestamp);
                    final dateStr = DateFormat('dd MMM yyyy').format(entry.timestamp);

                    // Tarih ayirici
                    final showDateHeader = index == 0 ||
                        DateFormat('yyyy-MM-dd').format(_entries[index - 1].timestamp) !=
                            DateFormat('yyyy-MM-dd').format(entry.timestamp);

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (showDateHeader)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                            child: Text(
                              dateStr,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: colorScheme.primary,
                              ),
                            ),
                          ),
                        ListTile(
                          leading: CircleAvatar(
                            backgroundColor: isEntry
                                ? Colors.green.withOpacity(0.1)
                                : Colors.orange.withOpacity(0.1),
                            child: Icon(
                              isEntry ? Icons.login : Icons.logout,
                              color: isEntry ? Colors.green : Colors.orange,
                            ),
                          ),
                          title: Text(
                            entry.doorName,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            isEntry ? 'Giriş' : 'Çıkış',
                            style: TextStyle(
                              color: isEntry ? Colors.green : Colors.orange,
                            ),
                          ),
                          trailing: Text(
                            timeStr,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
    );
  }
}
