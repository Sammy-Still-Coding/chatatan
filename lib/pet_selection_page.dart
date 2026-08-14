import 'package:flutter/material.dart';

import 'db_helper.dart';
import 'pet_roadmap_page.dart';
import 'chatatan_theme.dart';

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
    backgroundColor: ChatatanColors.background,
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
    body: ChatatanAmbientBackground(
      child: FutureBuilder<Map<String, dynamic>>(
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
                final petName = pet['name']?.toString() ?? 'Pet';
                final reward = _petExpReward(petName);
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 78,
                          height: 78,
                          child: unlocked
                              ? Image.asset(
                                  _petAsset(petName),
                                  fit: BoxFit.contain,
                                  errorBuilder: (_, _, _) => const Icon(
                                    Icons.pets_rounded,
                                    color: ChatatanColors.primary,
                                    size: 42,
                                  ),
                                )
                              : const Icon(
                                  Icons.lock_outline,
                                  color: Colors.grey,
                                  size: 40,
                                ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                petName,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                unlocked
                                    ? '${pet['description'] ?? ''}\n+$reward EXP per streak harian'
                                    : 'Terbuka pada streak $minimum hari',
                                style: const TextStyle(height: 1.35),
                              ),
                            ],
                          ),
                        ),
                        if (isActive)
                          const Icon(
                            Icons.check_circle,
                            color: ChatatanColors.primary,
                          )
                        else if (unlocked)
                          FilledButton(
                            onPressed: () =>
                                _choose(int.parse(pet['id'].toString())),
                            child: const Text('Pilih'),
                          ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          );
        },
      ),
    ),
  );

  Future<void> _choose(int petId) async {
    try {
      await _db.choosePet(petId);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Pet aktif diperbarui.')));
      // `setState` must be synchronous. Assign the new Future first, then
      // notify Flutter that the FutureBuilder needs to rebuild.
      _data = _load();
      setState(() {});
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$error')));
    }
  }

  int _petExpReward(String name) {
    final normalized = name.toLowerCase();
    if (normalized.contains('astra')) return 18;
    if (normalized.contains('nori')) return 15;
    return 10;
  }

  String _petAsset(String name) {
    final normalized = name.toLowerCase();
    if (normalized.contains('lumi')) return 'assets/images/pet_lumi.png';
    if (normalized.contains('kucing')) return 'assets/images/pet_kucing.png';
    if (normalized.contains('piko')) return 'assets/images/pet_piko.png';
    if (normalized.contains('nori')) return 'assets/images/pet_nori.png';
    if (normalized.contains('astra')) return 'assets/images/pet_astra.png';
    return 'assets/images/chatatan_study_pet.png';
  }
}
