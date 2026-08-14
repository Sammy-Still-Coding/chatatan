import 'package:flutter/material.dart';

import 'db_helper.dart';
import 'chatatan_theme.dart';

class NotificationSettingsPage extends StatefulWidget {
  const NotificationSettingsPage({super.key});

  @override
  State<NotificationSettingsPage> createState() =>
      _NotificationSettingsPageState();
}

class _NotificationSettingsPageState extends State<NotificationSettingsPage> {
  final _db = DbHelper();
  bool _loading = true;
  bool _master = true;
  bool _private = true;
  bool _group = true;
  bool _forum = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final values = await _db.getNotificationPreferences();
      if (!mounted) return;
      setState(() {
        _master = values['notification_enabled'] != false;
        _private = values['notify_private_messages'] != false;
        _group = values['notify_group_messages'] != false;
        _forum = values['notify_forum_replies'] != false;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    await _db.updateNotificationPreferences(
      enabled: _master,
      privateMessages: _private,
      groupMessages: _group,
      forumReplies: _forum,
    );
  }

  Future<void> _toggle(String kind, bool value) async {
    setState(() {
      switch (kind) {
        case 'master':
          _master = value;
        case 'private':
          _private = value;
        case 'group':
          _group = value;
        case 'forum':
          _forum = value;
      }
    });
    try {
      await _save();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pengaturan belum tersimpan. Coba lagi.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: ChatatanColors.background,
    appBar: AppBar(title: const Text('Pengaturan Notifikasi')),
    body: ChatatanAmbientBackground(
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text(
                  'Notifikasi perangkat',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Riwayat notifikasi tetap tersedia di aplikasi.',
                  style: TextStyle(color: Color(0xFF6B7280)),
                ),
                const SizedBox(height: 12),
                Card(
                  child: SwitchListTile(
                    secondary: const Icon(Icons.notifications_active_outlined),
                    title: const Text('Izinkan push notification'),
                    value: _master,
                    onChanged: (value) => _toggle('master', value),
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Jenis notifikasi',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),
                Card(
                  child: Column(
                    children: [
                      SwitchListTile(
                        secondary: const Icon(
                          Icons.chat_bubble_outline_rounded,
                        ),
                        title: const Text('Pesan pribadi'),
                        subtitle: const Text(
                          'Saat seseorang mengirim chat langsung',
                        ),
                        value: _private,
                        onChanged: _master
                            ? (value) => _toggle('private', value)
                            : null,
                      ),
                      const Divider(height: 1),
                      SwitchListTile(
                        secondary: const Icon(Icons.groups_outlined),
                        title: const Text('Pesan grup'),
                        subtitle: const Text('Saat ada pesan baru di grup'),
                        value: _group,
                        onChanged: _master
                            ? (value) => _toggle('group', value)
                            : null,
                      ),
                      const Divider(height: 1),
                      SwitchListTile(
                        secondary: const Icon(Icons.forum_outlined),
                        title: const Text('Balasan forum'),
                        subtitle: const Text(
                          'Saat diskusi Anda mendapat balasan',
                        ),
                        value: _forum,
                        onChanged: _master
                            ? (value) => _toggle('forum', value)
                            : null,
                      ),
                    ],
                  ),
                ),
              ],
            ),
    ),
  );
}
