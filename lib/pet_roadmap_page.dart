import 'package:flutter/material.dart';

import 'db_helper.dart';

class PetRoadmapPage extends StatefulWidget {
  const PetRoadmapPage({super.key});
  @override
  State<PetRoadmapPage> createState() => _PetRoadmapPageState();
}

class _PetRoadmapPageState extends State<PetRoadmapPage> {
  final _db = DbHelper();
  late Future<Map<String, dynamic>> _data = _load();

  Future<Map<String, dynamic>> _load() async {
    final petData = await _db.getPets();
    final game = await _db.getMyGamification() ?? <String, dynamic>{};
    return {'pets': petData, 'game': game};
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Roadmap Pet & Streak')),
    body: FutureBuilder<Map<String, dynamic>>(
      future: _data,
      builder: (_, snapshot) {
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());
        final game = snapshot.data!['game'] as Map<String, dynamic>;
        final pets = snapshot.data!['pets'] as List<Map<String, dynamic>>;
        final streak = [
          game['current_streak'],
          game['longest_streak'],
        ].map((v) => int.tryParse('$v') ?? 0).reduce((a, b) => a > b ? a : b);
        return ListView(
          padding: const EdgeInsets.all(18),
          children: [
            Text(
              'Streak terbaikmu: $streak hari',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            const Text(
              'Scan atau klaim aktivitas belajar setiap hari untuk menjaga streak. Token AI diisi ulang tiap minggu dengan kapasitas sesuai milestone.',
            ),
            const SizedBox(height: 20),
            ...[0, 10, 30, 50, 100].map((milestone) {
              final unlocked = streak >= milestone;
              final pet = pets
                  .cast<Map<String, dynamic>>()
                  .where((item) => (item['min_streak'] ?? 0) == milestone)
                  .cast<Map<String, dynamic>>()
                  .firstOrNull;
              final tokenText = milestone == 0
                  ? 'Kapasitas awal: 100 token/minggu'
                  : milestone == 10
                  ? '+10 kapasitas token/minggu'
                  : milestone == 30
                  ? '+15 kapasitas token/minggu'
                  : milestone == 50
                  ? '+25 kapasitas token/minggu'
                  : '+25 kapasitas token/minggu + Model Pro AI';
              return Card(
                color: unlocked ? const Color(0xFFEEEAFE) : null,
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: unlocked
                        ? const Color(0xFF6C63FF)
                        : Colors.grey.shade300,
                    child: Icon(
                      unlocked ? Icons.check : Icons.lock_outline,
                      color: Colors.white,
                    ),
                  ),
                  title: Text(
                    '$milestone hari${milestone == 100 ? ' · Milestone legenda' : ''}',
                  ),
                  subtitle: Text(
                    '$tokenText${pet == null ? '' : '\nPet: ${pet['name']}'}',
                  ),
                  trailing: unlocked
                      ? const Icon(
                          Icons.check_circle_outline,
                          color: Color(0xFF6C63FF),
                        )
                      : null,
                ),
              );
            }),
            const SizedBox(height: 14),
            const Text(
              'Setiap kelipatan 100 hari setelahnya menambah +25 kapasitas token AI mingguan.',
              style: TextStyle(color: Colors.black54),
            ),
          ],
        );
      },
    ),
  );
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
