import 'package:flutter/material.dart';

import 'db_helper.dart';

/// In-app notification centre. OS push notifications are intentionally kept
/// separate: this page always works while the app is open and keeps a history
/// of messages and forum replies for the signed-in account.
class NotificationPage extends StatefulWidget {
  const NotificationPage({super.key});

  @override
  State<NotificationPage> createState() => _NotificationPageState();
}

class _NotificationPageState extends State<NotificationPage> {
  final DbHelper _db = DbHelper();
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final items = await _db.getNotifications();
      if (mounted) setState(() => _items = items);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memuat notifikasi: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _markAllRead() async {
    await _db.markAllNotificationsRead();
    if (!mounted) return;
    setState(() {
      _items = _items.map((item) {
        return {...item, 'is_read': true};
      }).toList();
    });
  }

  IconData _iconFor(String type) {
    switch (type) {
      case 'GROUP_MESSAGE':
        return Icons.groups_rounded;
      case 'FORUM_REPLY':
        return Icons.forum_rounded;
      default:
        return Icons.chat_bubble_rounded;
    }
  }

  String _timeAgo(dynamic raw) {
    final date = DateTime.tryParse(raw?.toString() ?? '')?.toLocal();
    if (date == null) return '';
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return 'baru saja';
    if (diff.inHours < 1) return '${diff.inMinutes} mnt';
    if (diff.inDays < 1) return '${diff.inHours} jam';
    if (diff.inDays < 7) return '${diff.inDays} hari';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7FB),
      appBar: AppBar(
        title: const Text('Notifikasi'),
        actions: [
          TextButton(
            onPressed: _items.any((item) => item['is_read'] != true)
                ? _markAllRead
                : null,
            child: const Text('Tandai dibaca'),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: _items.isEmpty
                  ? ListView(
                      children: const [
                        SizedBox(height: 150),
                        Icon(
                          Icons.notifications_none_rounded,
                          size: 54,
                          color: Colors.grey,
                        ),
                        SizedBox(height: 12),
                        Center(
                          child: Text(
                            'Belum ada notifikasi',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                      ],
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _items.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final item = _items[index];
                        final isRead = item['is_read'] == true;
                        return Material(
                          color: isRead
                              ? Colors.white
                              : const Color(0xFFEEECFF),
                          borderRadius: BorderRadius.circular(16),
                          child: ListTile(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            leading: CircleAvatar(
                              backgroundColor: const Color(0xFF6C63FF),
                              child: Icon(
                                _iconFor(item['type']?.toString() ?? ''),
                                color: Colors.white,
                              ),
                            ),
                            title: Text(
                              item['title']?.toString() ?? 'Notifikasi',
                              style: TextStyle(
                                fontWeight: isRead
                                    ? FontWeight.w500
                                    : FontWeight.bold,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if ((item['body']?.toString() ?? '').isNotEmpty)
                                  Text(
                                    item['body'].toString(),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                const SizedBox(height: 3),
                                Text(
                                  _timeAgo(item['created_at']),
                                  style: const TextStyle(fontSize: 11),
                                ),
                              ],
                            ),
                            onTap: () async {
                              final id = int.tryParse(item['id'].toString());
                              if (id != null && !isRead)
                                await _db.markNotificationRead(id);
                              if (mounted)
                                setState(
                                  () => _items[index] = {
                                    ...item,
                                    'is_read': true,
                                  },
                                );
                            },
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}
