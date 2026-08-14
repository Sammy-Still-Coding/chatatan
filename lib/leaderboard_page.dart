import 'package:flutter/material.dart';

import 'app_states.dart';
import 'chatatan_theme.dart';
import 'db_helper.dart';

class LeaderboardPage extends StatefulWidget {
  const LeaderboardPage({super.key});

  @override
  State<LeaderboardPage> createState() => _LeaderboardPageState();
}

class _LeaderboardPageState extends State<LeaderboardPage> {
  final _db = DbHelper();
  List<Map<String, dynamic>> _leaders = [];
  int? _myRank;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _db.getExpLeaderboard(limit: 100),
        _db.getMyExpRank(),
      ]);
      if (!mounted) return;
      setState(() {
        _leaders = List<Map<String, dynamic>>.from(results[0] as List);
        _myRank = results[1] as int?;
      });
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: ChatatanColors.background,
    appBar: AppBar(title: const Text('Top 100 Leaderboard')),
    body: ChatatanAmbientBackground(
      child: _loading
          ? const AppLoadingState(label: 'Memuat peringkat EXP...')
          : _error != null
          ? AppErrorState(message: _error, onRetry: _load)
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                children: [
                  ChatatanGlass(
                    padding: const EdgeInsets.all(18),
                    radius: 25,
                    child: const Row(
                      children: [
                        Icon(
                          Icons.emoji_events_rounded,
                          color: Color(0xFFFFB51B),
                          size: 34,
                        ),
                        SizedBox(width: 13),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Peringkat pembelajar',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              SizedBox(height: 3),
                              Text(
                                'Diurutkan dari total EXP tertinggi.',
                                style: TextStyle(color: ChatatanColors.muted),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_myRank != null && _myRank! > 100) ...[
                    const SizedBox(height: 12),
                    ChatatanGlass(
                      opacity: .76,
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          const CircleAvatar(
                            backgroundColor: Color(0xFFE9E5FF),
                            child: Icon(
                              Icons.person_rounded,
                              color: ChatatanColors.primary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Peringkat kamu saat ini #$_myRank',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  if (_leaders.isEmpty)
                    const AppEmptyState(
                      icon: Icons.leaderboard_rounded,
                      title: 'Belum ada peringkat',
                      message: 'Kumpulkan EXP agar namamu tampil di sini.',
                    )
                  else
                    ..._leaders.map(_rankCard),
                ],
              ),
            ),
    ),
  );

  Widget _rankCard(Map<String, dynamic> user) {
    final rank =
        int.tryParse(user['rank']?.toString() ?? '') ??
        (_leaders.indexOf(user) + 1);
    final isMe = user['user_id']?.toString() == _db.currentUser?.id;
    final avatar = user['avatar_url']?.toString();
    final medalColor = rank == 1
        ? const Color(0xFFFFB51B)
        : rank == 2
        ? const Color(0xFFA5ADBD)
        : rank == 3
        ? const Color(0xFFC97945)
        : ChatatanColors.primary;
    return ChatatanGlass(
      margin: const EdgeInsets.only(bottom: 9),
      radius: 20,
      opacity: isMe ? .80 : .58,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          SizedBox(
            width: 40,
            child: Text(
              '#$rank',
              style: TextStyle(color: medalColor, fontWeight: FontWeight.w900),
            ),
          ),
          CircleAvatar(
            radius: 20,
            backgroundColor: const Color(0xFFE9E5FF),
            backgroundImage: avatar?.isNotEmpty == true
                ? NetworkImage(avatar!)
                : null,
            child: avatar?.isNotEmpty == true
                ? null
                : const Icon(
                    Icons.person_rounded,
                    color: ChatatanColors.primary,
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '${user['username'] ?? 'Pengguna'}${isMe ? ' (Kamu)' : ''}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: isMe ? ChatatanColors.primary : ChatatanColors.ink,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Text(
            '${user['total_points'] ?? 0}',
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.star_rounded, color: Color(0xFFFFB51B), size: 18),
        ],
      ),
    );
  }
}
