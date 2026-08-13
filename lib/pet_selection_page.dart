import 'package:flutter/material.dart';

import 'db_helper.dart';
import 'pet_roadmap_page.dart';

class PetSelectionPage extends StatefulWidget {
  const PetSelectionPage({super.key});
  @override
  State<PetSelectionPage> createState() => _PetSelectionPageState();
}

class _PetSelectionPageState extends State<PetSelectionPage> {
  final _db = DbHelper();
  late Future<Map<String, dynamic>> _data = _load();

  Future<Map<String, dynamic>> _load() async => {
    'pets': await _db.getPets(),
    'game': await _db.getMyGamification() ?? <String, dynamic>{},
  };

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Pilih Pet'),
      actions: [
        TextButton.icon(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const PetRoadmapPage()),
          ),
          icon: const Icon(Icons.map_outlined),
          label: const Text('Roadmap'),
        ),
      ],
    ),
    body: FutureBuilder<Map<String, dynamic>>(
      future: _data,
      builder: (_, snapshot) {
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());
        final game = snapshot.data!['game'] as Map<String, dynamic>;
        final pets = snapshot.data!['pets'] as List<Map<String, dynamic>>;
        final streak = [game['current_streak'], game['longest_streak']]
            .map((item) => int.tryParse('$item') ?? 0)
            .reduce((a, b) => a > b ? a : b);
        final active = game['pet_id']?.toString();
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Pilih teman belajarmu',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            Text(
              'Streak terbaik: $streak hari',
              style: const TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 12),
            ...pets.map((pet) {
              final minimum = int.tryParse('${pet['min_streak']}') ?? 0;
              final unlocked = streak >= minimum;
              final isActive = active == pet['id']?.toString();
              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: unlocked
                        ? const Color(0xFFEEEAFE)
                        : Colors.grey.shade200,
                    child: Icon(
                      unlocked ? Icons.pets_rounded : Icons.lock_outline,
                      color: unlocked ? const Color(0xFF6C63FF) : Colors.grey,
                    ),
                  ),
                  title: Text(pet['name']?.toString() ?? 'Pet'),
                  subtitle: Text(
                    unlocked
                        ? '${pet['description'] ?? ''}\n+10 EXP per streak harian'
                        : 'Terbuka pada streak $minimum hari',
                  ),
                  isThreeLine: unlocked,
                  trailing: isActive
                      ? const Icon(Icons.check_circle, color: Colors.deepPurple)
                      : unlocked
                      ? FilledButton(
                          onPressed: () =>
                              _choose(int.parse(pet['id'].toString())),
                          child: const Text('Pilih'),
                        )
                      : null,
                ),
              );
            }),
          ],
        );
      },
    ),
  );

  Future<void> _choose(int petId) async {
    try {
      await _db.choosePet(petId);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Pet aktif diperbarui.')));
      setState(() => _data = _load());
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$error')));
    }
  }
}
