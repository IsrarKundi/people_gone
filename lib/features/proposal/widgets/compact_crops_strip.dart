import 'package:flutter/material.dart';

import '../../../core/theme/theme_ext.dart';
import '../../../core/widgets/person_thumbnail.dart';
import '../../../services/processing/processing_api.dart';

/// Compact horizontal strip of small circular person crops (subject first,
/// kept-subject marked), synced both ways with canvas taps (G2.2/G3.2).
class CompactCropsStrip extends StatelessWidget {
  const CompactCropsStrip({
    super.key,
    required this.persons,
    required this.photoPath,
    required this.onTogglePerson,
  });

  final List<DetectedPerson> persons;
  final String photoPath;
  final ValueChanged<int> onTogglePerson;

  @override
  Widget build(BuildContext context) {
    final s = context.sizes;
    final sorted = persons.toList()
      ..sort((a, b) {
        if (a.isKeeper && !b.isKeeper) return -1;
        if (!a.isKeeper && b.isKeeper) return 1;
        return a.id.compareTo(b.id);
      });

    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: sorted.length,
        separatorBuilder: (_, _) => SizedBox(width: s.xs),
        itemBuilder: (context, index) {
          final person = sorted[index];
          return GestureDetector(
            onTap: () => onTogglePerson(person.id),
            child: PersonThumbnail(
              imagePath: photoPath,
              box: person.box,
              isKeeper: person.isKeeper,
              size: 40,
            ),
          );
        },
      ),
    );
  }
}
