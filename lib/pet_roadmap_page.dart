import 'package:flutter/material.dart';

import 'chatatan_theme.dart';
import 'db_helper.dart';

class PetRoadmapPage extends StatefulWidget {
  const PetRoadmapPage({super.key});

  @override
  State<PetRoadmapPage> createState() => _PetRoadmapPageState();
}

class _PetRoadmapPageState extends State<PetRoadmapPage> {
  final _db = DbHelper();
  late final Future<Map<String, dynamic>> _data = _load();

  Future<Map<String, dynamic>> _load() async {
    final petData = await _db.getPets();
    final game = await _db.getMyGamification() ?? <String, dynamic>{};
    return {'pets': petData, 'game': game};
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
    appBar: AppBar(title: const Text('Roadmap Pet & Streak')),
    body: ChatatanAmbientBackground(
      child: FutureBuilder<Map<String, dynamic>>(
        future: _data,
        builder: (_, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final game = snapshot.data!['game'] as Map<String, dynamic>;
          final pets = snapshot.data!['pets'] as List<Map<String, dynamic>>;
          final streakValues = [
            game['current_streak'],
            game['longest_streak'],
          ].map((value) => int.tryParse('$value') ?? 0);
          final streak = streakValues.reduce((a, b) => a > b ? a : b);
          final milestones = _milestones(pets);
          final reachedCount = milestones
              .where((item) => streak >= item.days)
              .length;

          return ListView(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 30),
            children: [
              ChatatanGlass(
                padding: const EdgeInsets.all(18),
                child: Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF6258FF), Color(0xFF9A65FF)],
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.route_rounded,
                        color: Colors.white,
                        size: 30,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Streak terbaik: $streak hari',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Jaga aktivitas harian untuk menyalakan seluruh jalur hadiah.',
                            style: TextStyle(color: ChatatanColors.muted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              LayoutBuilder(
                builder: (context, constraints) {
                  const stepHeight = 178.0;
                  final height = milestones.length * stepHeight + 35;
                  return SizedBox(
                    height: height,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: CustomPaint(
                            painter: _RoadmapPathPainter(
                              itemCount: milestones.length,
                              reachedCount: reachedCount,
                            ),
                          ),
                        ),
                        for (var index = 0; index < milestones.length; index++)
                          _MilestoneNode(
                            milestone: milestones[index],
                            index: index,
                            unlocked: streak >= milestones[index].days,
                            width: constraints.maxWidth,
                            top: index * stepHeight + 8,
                          ),
                      ],
                    ),
                  );
                },
              ),
              ChatatanGlass(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 13,
                ),
                child: const Row(
                  children: [
                    Icon(Icons.auto_awesome_rounded, color: Color(0xFF6258FF)),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Setiap kelipatan 100 hari berikutnya memberi +25 kapasitas token AI mingguan.',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    ),
  );

  List<_Milestone> _milestones(List<Map<String, dynamic>> pets) {
    const days = [0, 10, 30, 50, 100];
    const rewards = [
      '100 token per minggu',
      '+10 kapasitas token',
      '+15 kapasitas token',
      '+25 kapasitas token',
      '+25 token & Model Pro AI',
    ];
    const icons = [
      Icons.rocket_launch_rounded,
      Icons.pets_rounded,
      Icons.bolt_rounded,
      Icons.workspace_premium_rounded,
      Icons.auto_awesome_rounded,
    ];
    return List.generate(days.length, (index) {
      final pet = pets
          .where((item) => (item['min_streak'] ?? 0) == days[index])
          .firstOrNull;
      return _Milestone(
        days: days[index],
        reward: rewards[index],
        icon: icons[index],
        petName: pet?['name']?.toString(),
      );
    });
  }
}

class _Milestone {
  const _Milestone({
    required this.days,
    required this.reward,
    required this.icon,
    this.petName,
  });

  final int days;
  final String reward;
  final IconData icon;
  final String? petName;
}

class _MilestoneNode extends StatelessWidget {
  const _MilestoneNode({
    required this.milestone,
    required this.index,
    required this.unlocked,
    required this.width,
    required this.top,
  });

  final _Milestone milestone;
  final int index;
  final bool unlocked;
  final double width;
  final double top;

  @override
  Widget build(BuildContext context) {
    final leftSide = index.isEven;
    const cardWidth = 174.0;
    return Positioned(
      top: top,
      left: leftSide ? 0 : width - cardWidth,
      width: cardWidth,
      child: ChatatanGlass(
        radius: 24,
        opacity: unlocked ? .72 : .48,
        padding: const EdgeInsets.all(13),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: unlocked
                    ? const LinearGradient(
                        colors: [Color(0xFF6258FF), Color(0xFFA25CFF)],
                      )
                    : null,
                color: unlocked ? null : const Color(0xFFD5DAE8),
                boxShadow: unlocked
                    ? [
                        BoxShadow(
                          color: const Color(0xFF7B61FF).withValues(alpha: .55),
                          blurRadius: 18,
                          spreadRadius: 2,
                        ),
                      ]
                    : null,
              ),
              child: Icon(
                unlocked ? milestone.icon : Icons.lock_outline_rounded,
                color: Colors.white,
                size: 25,
              ),
            ),
            const SizedBox(height: 9),
            Text(
              milestone.days == 0 ? 'Mulai' : '${milestone.days} hari',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 3),
            Text(
              milestone.reward,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: ChatatanColors.muted,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (milestone.petName != null)
              Text(
                'Pet: ${milestone.petName}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: unlocked
                      ? const Color(0xFF6258FF)
                      : ChatatanColors.muted,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _RoadmapPathPainter extends CustomPainter {
  const _RoadmapPathPainter({
    required this.itemCount,
    required this.reachedCount,
  });

  final int itemCount;
  final int reachedCount;

  @override
  void paint(Canvas canvas, Size size) {
    const stepHeight = 178.0;
    const leftNodeX = 37.0;
    const rightNodeInset = 137.0;
    final points = List.generate(itemCount, (index) {
      final left = index.isEven;
      return Offset(
        left ? leftNodeX : size.width - rightNodeInset,
        index * stepHeight + 45,
      );
    });
    if (points.length < 2) return;

    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var index = 1; index < points.length; index++) {
      final previous = points[index - 1];
      final current = points[index];
      final middleY = (previous.dy + current.dy) / 2;
      path.cubicTo(
        previous.dx,
        middleY,
        current.dx,
        middleY,
        current.dx,
        current.dy,
      );
    }

    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFFB8C5E6)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 7,
    );

    if (reachedCount <= 0) return;
    final metric = path.computeMetrics().first;
    final progress = itemCount == 1
        ? 1.0
        : ((reachedCount - 1) / (itemCount - 1)).clamp(0.04, 1.0);
    final activePath = metric.extractPath(0, metric.length * progress);
    canvas.drawPath(
      activePath,
      Paint()
        ..color = const Color(0xFF8A6BFF).withValues(alpha: .55)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 18
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
    );
    canvas.drawPath(
      activePath,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFF62D8FF), Color(0xFF7A5CFF), Color(0xFFC05CFF)],
        ).createShader(Offset.zero & size)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 7,
    );
  }

  @override
  bool shouldRepaint(covariant _RoadmapPathPainter oldDelegate) =>
      oldDelegate.reachedCount != reachedCount ||
      oldDelegate.itemCount != itemCount;
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
