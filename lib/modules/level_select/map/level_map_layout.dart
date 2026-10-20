import 'dart:math' as math;
import 'dart:ui';

import '../../../game/config/difficulty_curve.dart';

/// One world's slice of the map: a gate area at the bottom followed by one
/// row per level.
class MapSection {
  final CampaignWorld world;

  /// Last level shown in this section (the world's last level, capped at the
  /// campaign length).
  final int lastLevel;

  /// Distance of the section's bottom edge from the bottom of the map.
  final double bottom;
  final double height;

  const MapSection({
    required this.world,
    required this.lastLevel,
    required this.bottom,
    required this.height,
  });

  int get firstLevel => world.firstLevel;
  int get levelCount => lastLevel - firstLevel + 1;
  double get top => bottom + height;
}

/// Geometry of the level map, independent of widgets so it can be tested.
///
/// The map is laid out bottom to top: a start camp, one [MapSection] per
/// world, then a summit. Every y coordinate here is a distance from the
/// bottom of the map, which is also the scroll offset of a reversed list.
class LevelMapLayout {
  static const double rowHeight = 118;
  static const double gateHeight = 230;
  static const double startHeight = 240;
  static const double summitHeight = 460;

  /// Distance of the summit flag below the top of the map, leaving room for
  /// the header and the end card above it.
  static const double summitPointFromTop = 340;

  /// Where a focused level sits in the viewport, from its bottom edge.
  static const double focusFraction = 0.42;

  final double width;
  final int totalLevels;
  late final List<MapSection> sections;
  late final double totalHeight;

  LevelMapLayout({
    required this.width,
    required this.totalLevels,
    List<CampaignWorld>? worlds,
  }) {
    final source = worlds ?? DifficultyCurve.worlds;
    final list = <MapSection>[];
    var y = startHeight;
    for (var i = 0; i < source.length; i++) {
      final w = source[i];
      if (w.firstLevel > totalLevels) break;
      final isLast = i == source.length - 1;
      // The last world absorbs any levels past the defined worlds.
      final last = isLast ? totalLevels : math.min(w.lastLevel, totalLevels);
      final h = gateHeight + (last - w.firstLevel + 1) * rowHeight;
      list.add(MapSection(world: w, lastLevel: last, bottom: y, height: h));
      y += h;
    }
    sections = list;
    totalHeight = y + summitHeight;
  }

  /// List items: start camp, sections, summit.
  int get itemCount => sections.length + 2;
  int get summitIndex => sections.length + 1;

  double itemExtent(int index) {
    if (index == 0) return startHeight;
    if (index == summitIndex) return summitHeight;
    return sections[index - 1].height;
  }

  double itemBottom(int index) {
    if (index == 0) return 0;
    if (index == summitIndex) return totalHeight - summitHeight;
    return sections[index - 1].bottom;
  }

  /// Index of the section holding [level] (levels outside the campaign are
  /// clamped to the first or last section).
  int sectionIndexFor(int level) {
    for (var i = 0; i < sections.length; i++) {
      if (level <= sections[i].lastLevel) return i;
    }
    return sections.length - 1;
  }

  double get _amplitude => (width * 0.28).clamp(70.0, 140.0);

  double nodeX(int level) {
    final i = level - 1;
    final offset = math.sin(i * 0.48) * 0.75 + math.sin(i * 0.18) * 0.25;
    return width / 2 + offset * _amplitude;
  }

  double nodeY(int level) {
    final s = sections[sectionIndexFor(level)];
    final row = level.clamp(s.firstLevel, s.lastLevel) - s.firstLevel;
    return s.bottom + gateHeight + (row + 0.5) * rowHeight;
  }

  /// Trail anchor for [level]. Level 0 is the start camp and
  /// `totalLevels + 1` the summit, so the trail runs from camp to summit.
  Offset point(int level) {
    if (level <= 0) return Offset(width / 2, startHeight * 0.5);
    if (level > totalLevels) {
      return Offset(width / 2, totalHeight - summitPointFromTop);
    }
    return Offset(nodeX(level), nodeY(level));
  }

  /// Point at [t] (0–1) along the trail from [level] to the next anchor.
  /// Same cubic as the painted trail.
  Offset trailPoint(int level, double t) {
    final a = point(level);
    final b = point(level + 1);
    final mid = (a.dy + b.dy) / 2;
    final u = 1 - t;
    final x =
        u * u * u * a.dx +
        3 * u * u * t * a.dx +
        3 * u * t * t * b.dx +
        t * t * t * b.dx;
    final y =
        u * u * u * a.dy +
        3 * u * u * t * mid +
        3 * u * t * t * mid +
        t * t * t * b.dy;
    return Offset(x, y);
  }

  /// Trail x at height [y]. The trail never turns back down, so each height
  /// crosses it once.
  double trailXAt(double y) {
    var level = 0;
    while (level <= totalLevels && point(level + 1).dy < y) {
      level++;
    }
    if (level > totalLevels) return point(totalLevels + 1).dx;
    if (y <= point(level).dy) return point(level).dx;
    var lo = 0.0, hi = 1.0;
    for (var i = 0; i < 18; i++) {
      final m = (lo + hi) / 2;
      if (trailPoint(level, m).dy < y) {
        lo = m;
      } else {
        hi = m;
      }
    }
    return trailPoint(level, (lo + hi) / 2).dx;
  }

  double maxScroll(double viewportHeight) =>
      math.max(0, totalHeight - viewportHeight);

  /// Scroll offset that frames a point at height [y].
  double scrollOffsetForY(double y, double viewportHeight) =>
      (y - viewportHeight * focusFraction).clamp(
        0.0,
        maxScroll(viewportHeight),
      );

  double scrollOffsetFor(int level, double viewportHeight) =>
      scrollOffsetForY(nodeY(level), viewportHeight);

  /// Section index under the focus line at scroll offset [offset].
  int sectionIndexAtOffset(double offset, double viewportHeight) {
    final y = offset + viewportHeight * focusFraction;
    for (var i = 0; i < sections.length; i++) {
      if (y < sections[i].top) return i;
    }
    return sections.length - 1;
  }

  /// Height of a section's gate centre (where the arch stands).
  double gateArchY(int sectionIndex) =>
      sections[sectionIndex].bottom + gateHeight * 0.25;

  /// Height of a section's banner.
  double gateBannerY(int sectionIndex) =>
      sections[sectionIndex].bottom + gateHeight * 0.76;
}
