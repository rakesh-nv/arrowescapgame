import 'dart:math';

import 'silhouette.dart';

/// Every silhouette a puzzle board can take. Coordinates are in a unit canvas
/// (x right, y down). To add a shape, append a [Silhouette] here: it is picked
/// up by level selection automatically once the board reaches its `minGrid`
/// and the campaign reaches its `minLevel`.
///
/// A new shape must start past every shipped level (its `minLevel` greater
/// than the last level players may already have), otherwise it changes which
/// shape existing levels get; in that case bump
/// `AppConstants.levelGeneratorVersion`.
class SilhouetteLibrary {
  SilhouetteLibrary._();

  static Silhouette byId(String id) => all.firstWhere((s) => s.id == id);

  static final List<Silhouette> all = [
    // ── Animals ─────────────────────────────────────────────────────────────
    const Silhouette(
      id: 'cat',
      name: 'Cat',
      category: SilhouetteCategory.animal,
      minGrid: 16,
      parts: [
        SEllipse(0.40, 0.68, 0.27, 0.29), // body
        SEllipse(0.40, 0.30, 0.21, 0.18), // head
        SPoly([0.21, 0.24, 0.23, 0.01, 0.38, 0.15]), // ears
        SPoly([0.42, 0.15, 0.57, 0.01, 0.59, 0.24]),
        SLine(0.62, 0.90, 0.86, 0.82, 0.10), // tail
        SLine(0.86, 0.82, 0.90, 0.50, 0.10),
        Cut(SEllipse(0.33, 0.29, 0.04, 0.035)), // eyes
        Cut(SEllipse(0.47, 0.29, 0.04, 0.035)),
      ],
    ),
    const Silhouette(
      id: 'dog',
      name: 'Dog',
      category: SilhouetteCategory.animal,
      minGrid: 27,
      parts: [
        SRect(0.20, 0.38, 0.74, 0.64, 0.10), // body
        SLine(0.68, 0.48, 0.78, 0.30, 0.16), // neck
        SEllipse(0.80, 0.27, 0.14, 0.13), // head
        SRect(0.84, 0.25, 0.99, 0.39, 0.05), // snout
        SPoly([0.68, 0.18, 0.78, 0.16, 0.72, 0.46]), // ear
        SLine(0.24, 0.58, 0.24, 0.96, 0.075), // legs
        SLine(0.38, 0.58, 0.38, 0.96, 0.075),
        SLine(0.57, 0.58, 0.57, 0.96, 0.075),
        SLine(0.71, 0.58, 0.71, 0.96, 0.075),
        SLine(0.22, 0.44, 0.05, 0.20, 0.08), // tail
      ],
    ),
    const Silhouette(
      id: 'rabbit',
      name: 'Rabbit',
      category: SilhouetteCategory.animal,
      minGrid: 16,
      parts: [
        SEllipse(0.45, 0.70, 0.31, 0.25), // body
        SEllipse(0.68, 0.40, 0.17, 0.14), // head
        SEllipse(0.60, 0.15, 0.065, 0.16, -12), // ears
        SEllipse(0.76, 0.15, 0.065, 0.16, 12),
        SEllipse(0.13, 0.62, 0.08), // tail
        SEllipse(0.60, 0.94, 0.17, 0.055), // hind foot
        Cut(SEllipse(0.74, 0.37, 0.035)), // eye
      ],
    ),
    const Silhouette(
      id: 'butterfly',
      name: 'Butterfly',
      category: SilhouetteCategory.animal,
      minGrid: 16,
      mirrorable: false,
      parts: [
        SEllipse(0.26, 0.30, 0.25, 0.23, -20), // upper wings
        SEllipse(0.74, 0.30, 0.25, 0.23, 20),
        SEllipse(0.29, 0.75, 0.18, 0.18, 25), // lower wings
        SEllipse(0.71, 0.75, 0.18, 0.18, -25),
        Cut(SPoly([-0.01, 0.46, 0.43, 0.54, -0.01, 0.64])), // wing notches
        Cut(SPoly([1.01, 0.46, 0.57, 0.54, 1.01, 0.64])),
        Cut(SEllipse(0.24, 0.28, 0.065)), // wing spots
        Cut(SEllipse(0.76, 0.28, 0.065)),
        SRect(0.44, 0.16, 0.56, 0.94, 0.05), // body
        SLine(0.47, 0.18, 0.35, 0.01, 0.06), // antennae
        SLine(0.53, 0.18, 0.65, 0.01, 0.06),
      ],
    ),
    const Silhouette(
      id: 'fish',
      name: 'Fish',
      category: SilhouetteCategory.animal,
      minGrid: 16,
      parts: [
        SEllipse(0.42, 0.50, 0.34, 0.25), // body
        SPoly([0.68, 0.50, 0.98, 0.20, 0.98, 0.80]), // tail
        SPoly([0.30, 0.30, 0.50, 0.08, 0.62, 0.32]), // dorsal fin
        SPoly([0.38, 0.70, 0.48, 0.90, 0.58, 0.70]), // belly fin
        Cut(SEllipse(0.22, 0.44, 0.045)), // eye
      ],
    ),
    const Silhouette(
      id: 'bird',
      name: 'Bird',
      category: SilhouetteCategory.animal,
      minGrid: 24,
      parts: [
        SEllipse(0.48, 0.55, 0.30, 0.14, -8), // body
        SEllipse(0.79, 0.42, 0.12, 0.11), // head
        SPoly([0.88, 0.37, 0.995, 0.43, 0.88, 0.48]), // beak
        SPoly([0.34, 0.52, 0.56, 0.06, 0.72, 0.10, 0.62, 0.54]), // wing
        SPoly([0.24, 0.52, 0.01, 0.38, 0.04, 0.70]), // tail
        SLine(0.46, 0.66, 0.42, 0.86, 0.06), // legs
        SLine(0.56, 0.66, 0.58, 0.86, 0.06),
      ],
    ),
    const Silhouette(
      id: 'turtle',
      name: 'Turtle',
      category: SilhouetteCategory.animal,
      minGrid: 16,
      mirrorable: false,
      parts: [
        SEllipse(0.50, 0.52, 0.29, 0.32), // shell (top view)
        SEllipse(0.50, 0.12, 0.10, 0.11), // head
        SEllipse(0.22, 0.30, 0.10, 0.08, -30), // flippers
        SEllipse(0.78, 0.30, 0.10, 0.08, 30),
        SEllipse(0.24, 0.78, 0.10, 0.08, 30),
        SEllipse(0.76, 0.78, 0.10, 0.08, -30),
        SPoly([0.45, 0.82, 0.55, 0.82, 0.50, 0.98]), // tail
        Cut(SEllipse(0.50, 0.52, 0.07)), // shell plate
      ],
    ),
    const Silhouette(
      id: 'elephant',
      name: 'Elephant',
      category: SilhouetteCategory.animal,
      minGrid: 24,
      parts: [
        SEllipse(0.46, 0.44, 0.33, 0.25), // body
        SEllipse(0.80, 0.33, 0.15, 0.16), // head
        SEllipse(0.69, 0.36, 0.11, 0.16), // ear
        SLine(0.90, 0.38, 0.93, 0.74, 0.10), // trunk
        SLine(0.93, 0.74, 0.84, 0.86, 0.09),
        SRect(0.20, 0.54, 0.31, 0.96, 0.03), // legs
        SRect(0.36, 0.56, 0.47, 0.96, 0.03),
        SRect(0.55, 0.56, 0.66, 0.96, 0.03),
        SLine(0.14, 0.40, 0.05, 0.62, 0.06), // tail
        Cut(SEllipse(0.84, 0.28, 0.03)), // eye
      ],
    ),
    const Silhouette(
      id: 'lion',
      name: 'Lion',
      category: SilhouetteCategory.animal,
      minGrid: 24,
      parts: [
        SRect(0.22, 0.42, 0.76, 0.66, 0.10), // body
        SEllipse(0.78, 0.34, 0.19, 0.22), // mane
        SEllipse(0.66, 0.20, 0.09), // mane tufts
        SEllipse(0.92, 0.20, 0.08),
        SEllipse(0.64, 0.50, 0.09),
        SEllipse(0.95, 0.42, 0.06), // muzzle
        SRect(0.25, 0.58, 0.35, 0.96, 0.03), // legs
        SRect(0.39, 0.58, 0.49, 0.96, 0.03),
        SRect(0.56, 0.58, 0.66, 0.96, 0.03),
        SRect(0.68, 0.58, 0.78, 0.96, 0.03),
        SLine(0.23, 0.48, 0.08, 0.76, 0.06), // tail
        SEllipse(0.07, 0.80, 0.06), // tail tuft
        Cut(SEllipse(0.86, 0.30, 0.03)), // eye
      ],
    ),
    const Silhouette(
      id: 'dinosaur',
      name: 'Dinosaur',
      category: SilhouetteCategory.animal,
      minGrid: 24,
      parts: [
        SEllipse(0.46, 0.56, 0.25, 0.18), // body
        SLine(0.63, 0.48, 0.80, 0.14, 0.11), // neck
        SEllipse(0.86, 0.11, 0.10, 0.07), // head
        SPoly([0.24, 0.48, 0.01, 0.80, 0.08, 0.82, 0.30, 0.66]), // tail
        SRect(0.30, 0.62, 0.40, 0.96, 0.03), // legs
        SRect(0.52, 0.62, 0.62, 0.96, 0.03),
        SPoly([0.30, 0.40, 0.36, 0.30, 0.42, 0.39]), // back plates
        SPoly([0.42, 0.38, 0.48, 0.27, 0.54, 0.38]),
        SPoly([0.54, 0.40, 0.60, 0.30, 0.65, 0.42]),
      ],
    ),
    const Silhouette(
      id: 'owl',
      name: 'Owl',
      category: SilhouetteCategory.animal,
      minGrid: 16,
      mirrorable: false,
      parts: [
        SEllipse(0.50, 0.57, 0.31, 0.38), // body
        SPoly([0.20, 0.36, 0.22, 0.04, 0.42, 0.24]), // ear tufts
        SPoly([0.58, 0.24, 0.78, 0.04, 0.80, 0.36]),
        SRect(0.33, 0.92, 0.45, 0.99, 0.02), // feet
        SRect(0.55, 0.92, 0.67, 0.99, 0.02),
        // Eyes are holes: pupils inside them would be islands no arrow can
        // reach, so they are dropped from the board anyway.
        Cut(SEllipse(0.37, 0.38, 0.09)), // eyes
        Cut(SEllipse(0.63, 0.38, 0.09)),
        Cut(SPoly([0.46, 0.50, 0.54, 0.50, 0.50, 0.58])), // beak
      ],
    ),
    Silhouette(
      id: 'snake',
      name: 'Snake',
      category: SilhouetteCategory.animal,
      minGrid: 24,
      parts: [
        // The body ends mid-height, rising into the head, so the head stays
        // attached at every board size.
        ...strokePath([
          for (var i = 0; i <= 24; i++)
            (0.06 + 0.76 * i / 24, 0.56 + 0.26 * cos(2 * pi * 1.25 * i / 24)),
        ], 0.15),
        const SEllipse(0.86, 0.50, 0.11, 0.09), // head
        const SLine(0.95, 0.52, 0.995, 0.60, 0.04), // tongue
        const Cut(SEllipse(0.88, 0.46, 0.03)), // eye
      ],
    ),

    // ── Vehicles ────────────────────────────────────────────────────────────
    const Silhouette(
      id: 'car',
      name: 'Car',
      category: SilhouetteCategory.vehicle,
      minGrid: 16,
      parts: [
        SRect(0.03, 0.46, 0.97, 0.74, 0.07), // body
        SPoly([0.20, 0.48, 0.32, 0.20, 0.66, 0.20, 0.80, 0.48]), // cabin
        SEllipse(0.25, 0.76, 0.13), // wheels
        SEllipse(0.75, 0.76, 0.13),
        Cut(SPoly([0.31, 0.44, 0.38, 0.28, 0.47, 0.28, 0.47, 0.44])), // windows
        Cut(SPoly([0.54, 0.44, 0.54, 0.28, 0.62, 0.28, 0.70, 0.44])),
        Cut(SEllipse(0.25, 0.76, 0.045)), // hubs
        Cut(SEllipse(0.75, 0.76, 0.045)),
      ],
    ),
    const Silhouette(
      id: 'racecar',
      name: 'Racing Car',
      category: SilhouetteCategory.vehicle,
      minGrid: 24,
      parts: [
        SPoly([
          0.04, 0.70, 0.08, 0.52, 0.38, 0.46, 0.46, 0.30, 0.60, 0.30, //
          0.68, 0.46, 0.98, 0.54, 0.98, 0.68,
        ]),
        SRect(0.01, 0.26, 0.17, 0.34, 0.02), // rear wing
        SLine(0.09, 0.34, 0.09, 0.54, 0.06),
        SEllipse(0.22, 0.72, 0.14), // wheels
        SEllipse(0.80, 0.72, 0.14),
        Cut(SEllipse(0.22, 0.72, 0.05)),
        Cut(SEllipse(0.80, 0.72, 0.05)),
        Cut(SPoly([0.48, 0.44, 0.52, 0.34, 0.58, 0.34, 0.62, 0.44])), // cockpit
      ],
    ),
    const Silhouette(
      id: 'truck',
      name: 'Truck',
      category: SilhouetteCategory.vehicle,
      minGrid: 16,
      parts: [
        SRect(0.02, 0.18, 0.62, 0.72, 0.02), // cargo box
        SPoly([0.64, 0.72, 0.64, 0.32, 0.84, 0.32, 0.98, 0.52, 0.98, 0.72]),
        SRect(0.60, 0.62, 0.66, 0.72), // coupling
        SEllipse(0.18, 0.77, 0.11), // wheels
        SEllipse(0.44, 0.77, 0.11),
        SEllipse(0.82, 0.77, 0.11),
        Cut(SPoly([0.70, 0.38, 0.82, 0.38, 0.92, 0.52, 0.70, 0.52])), // window
      ],
    ),
    const Silhouette(
      id: 'bus',
      name: 'Bus',
      category: SilhouetteCategory.vehicle,
      minGrid: 24,
      parts: [
        SRect(0.02, 0.20, 0.98, 0.76, 0.07), // body
        SEllipse(0.24, 0.79, 0.11), // wheels
        SEllipse(0.76, 0.79, 0.11),
        Cut(SRect(0.08, 0.29, 0.25, 0.45, 0.02)), // windows
        Cut(SRect(0.31, 0.29, 0.48, 0.45, 0.02)),
        Cut(SRect(0.54, 0.29, 0.71, 0.45, 0.02)),
        Cut(SRect(0.77, 0.29, 0.92, 0.55, 0.02)), // windscreen + door
      ],
    ),
    const Silhouette(
      id: 'motorcycle',
      name: 'Motorcycle',
      category: SilhouetteCategory.vehicle,
      minGrid: 26,
      parts: [
        SEllipse(0.19, 0.70, 0.18), // wheels
        SEllipse(0.81, 0.70, 0.18),
        SPoly([
          0.20,
          0.66,
          0.34,
          0.44,
          0.70,
          0.40,
          0.82,
          0.66,
          0.62,
          0.64,
          0.42,
          0.66,
        ]),
        SRect(0.30, 0.32, 0.58, 0.42, 0.04), // seat
        SLine(0.68, 0.44, 0.74, 0.20, 0.07), // fork + handlebar
        SLine(0.66, 0.20, 0.84, 0.20, 0.06),
        Cut(SEllipse(0.19, 0.70, 0.075)),
        Cut(SEllipse(0.81, 0.70, 0.075)),
      ],
    ),
    const Silhouette(
      id: 'bicycle',
      name: 'Bicycle',
      category: SilhouetteCategory.vehicle,
      minGrid: 28,
      parts: [
        SEllipse(0.21, 0.66, 0.20), // wheels
        SEllipse(0.79, 0.66, 0.20),
        SLine(0.21, 0.66, 0.46, 0.66, 0.08), // frame
        SLine(0.46, 0.66, 0.68, 0.36, 0.08),
        SLine(0.34, 0.34, 0.68, 0.36, 0.08),
        SLine(0.34, 0.34, 0.21, 0.66, 0.08),
        SLine(0.34, 0.34, 0.46, 0.66, 0.08),
        SLine(0.68, 0.36, 0.79, 0.66, 0.08),
        SLine(0.26, 0.24, 0.42, 0.24, 0.07), // saddle
        SLine(0.34, 0.24, 0.34, 0.36, 0.07),
        SLine(0.66, 0.36, 0.62, 0.16, 0.07), // handlebar
        SLine(0.56, 0.16, 0.72, 0.16, 0.07),
        Cut(SEllipse(0.21, 0.66, 0.10)),
        Cut(SEllipse(0.79, 0.66, 0.10)),
      ],
    ),
    const Silhouette(
      id: 'airplane',
      name: 'Airplane',
      category: SilhouetteCategory.vehicle,
      minGrid: 16,
      mirrorable: false,
      parts: [
        SEllipse(0.50, 0.50, 0.08, 0.47), // fuselage
        SPoly([
          0.02, 0.58, 0.44, 0.34, 0.56, 0.34, 0.98, 0.58, //
          0.98, 0.66, 0.56, 0.54, 0.44, 0.54, 0.02, 0.66,
        ]), // wings
        SPoly([
          0.28, 0.92, 0.45, 0.80, 0.55, 0.80, 0.72, 0.92, //
          0.72, 0.97, 0.28, 0.97,
        ]), // tailplane
      ],
    ),
    const Silhouette(
      id: 'rocket',
      name: 'Rocket',
      category: SilhouetteCategory.vehicle,
      minGrid: 16,
      mirrorable: false,
      parts: [
        SRect(0.35, 0.26, 0.65, 0.80, 0.05), // body
        SPoly([0.35, 0.29, 0.50, 0.01, 0.65, 0.29]), // nose
        SPoly([0.35, 0.56, 0.12, 0.88, 0.12, 0.94, 0.37, 0.80]), // fins
        SPoly([0.65, 0.56, 0.88, 0.88, 0.88, 0.94, 0.63, 0.80]),
        SPoly([0.41, 0.80, 0.50, 0.99, 0.59, 0.80]), // flame
        Cut(SEllipse(0.50, 0.42, 0.075)), // porthole
      ],
    ),
    const Silhouette(
      id: 'ship',
      name: 'Ship',
      category: SilhouetteCategory.vehicle,
      minGrid: 16,
      parts: [
        SPoly([0.01, 0.58, 0.99, 0.58, 0.84, 0.88, 0.16, 0.88]), // hull
        SRect(0.24, 0.40, 0.76, 0.60, 0.03), // deck house
        SRect(0.32, 0.12, 0.46, 0.42, 0.03), // funnels
        SRect(0.54, 0.20, 0.68, 0.42, 0.03),
        Cut(SEllipse(0.30, 0.72, 0.045)), // portholes
        Cut(SEllipse(0.50, 0.72, 0.045)),
        Cut(SEllipse(0.70, 0.72, 0.045)),
      ],
    ),

    // ── Objects ─────────────────────────────────────────────────────────────
    const Silhouette(
      id: 'house',
      name: 'House',
      category: SilhouetteCategory.object,
      minGrid: 16,
      parts: [
        SPoly([0.02, 0.48, 0.50, 0.04, 0.98, 0.48]), // roof
        SRect(0.12, 0.44, 0.88, 0.97), // walls
        SRect(0.68, 0.08, 0.80, 0.36), // chimney
        Cut(SRect(0.42, 0.66, 0.58, 0.97, 0.02)), // door
        Cut(SRect(0.20, 0.56, 0.34, 0.70, 0.02)), // windows
        Cut(SRect(0.66, 0.56, 0.80, 0.70, 0.02)),
      ],
    ),
    const Silhouette(
      id: 'castle',
      name: 'Castle',
      category: SilhouetteCategory.object,
      minGrid: 24,
      mirrorable: false,
      parts: [
        SRect(0.06, 0.42, 0.94, 0.97), // curtain wall
        SRect(0.01, 0.22, 0.23, 0.97), // side towers
        SRect(0.77, 0.22, 0.99, 0.97),
        SRect(0.37, 0.08, 0.63, 0.97), // keep
        Cut(SRect(0.075, 0.22, 0.155, 0.29)), // battlements
        Cut(SRect(0.845, 0.22, 0.925, 0.29)),
        Cut(SRect(0.46, 0.08, 0.54, 0.15)),
        Cut(SRect(0.27, 0.42, 0.33, 0.48)),
        Cut(SRect(0.67, 0.42, 0.73, 0.48)),
        Cut(SRect(0.42, 0.74, 0.58, 0.97)), // gate
        Cut(SEllipse(0.50, 0.74, 0.08, 0.07)),
        Cut(SRect(0.46, 0.26, 0.54, 0.38, 0.02)), // keep window
      ],
    ),
    const Silhouette(
      id: 'crown',
      name: 'Crown',
      category: SilhouetteCategory.object,
      minGrid: 16,
      mirrorable: false,
      parts: [
        SPoly([
          0.02, 0.16, 0.26, 0.50, 0.33, 0.06, 0.50, 0.44, 0.67, 0.06, //
          0.74, 0.50, 0.98, 0.16, 0.90, 0.80, 0.10, 0.80,
        ]),
        SRect(0.10, 0.76, 0.90, 0.95, 0.03), // band
        Cut(SEllipse(0.30, 0.86, 0.045)), // gems in the band
        Cut(SEllipse(0.50, 0.86, 0.045)),
        Cut(SEllipse(0.70, 0.86, 0.045)),
      ],
    ),
    const Silhouette(
      id: 'robot',
      name: 'Robot',
      category: SilhouetteCategory.object,
      minGrid: 24,
      mirrorable: false,
      parts: [
        SRect(0.30, 0.06, 0.70, 0.30, 0.04), // head
        SLine(0.50, 0.08, 0.50, 0.01, 0.05), // antenna
        SRect(0.44, 0.28, 0.56, 0.36), // neck
        SRect(0.22, 0.34, 0.78, 0.72, 0.03), // body
        SRect(0.05, 0.36, 0.25, 0.48, 0.03), // arms
        SRect(0.75, 0.36, 0.95, 0.48, 0.03),
        SRect(0.05, 0.36, 0.15, 0.66, 0.03),
        SRect(0.85, 0.36, 0.95, 0.66, 0.03),
        SRect(0.30, 0.70, 0.44, 0.98, 0.02), // legs
        SRect(0.56, 0.70, 0.70, 0.98, 0.02),
        Cut(SEllipse(0.41, 0.17, 0.05)), // eyes
        Cut(SEllipse(0.59, 0.17, 0.05)),
        Cut(SRect(0.38, 0.44, 0.62, 0.60, 0.02)), // chest panel
      ],
    ),
    const Silhouette(
      id: 'note',
      name: 'Musical Note',
      category: SilhouetteCategory.object,
      minGrid: 16,
      parts: [
        SEllipse(0.31, 0.80, 0.20, 0.14, -20), // note head
        SRect(0.42, 0.08, 0.53, 0.80), // stem
        SPoly([0.53, 0.08, 0.86, 0.30, 0.84, 0.48, 0.53, 0.28]), // flag
      ],
    ),
    const Silhouette(
      id: 'diamond',
      name: 'Diamond',
      category: SilhouetteCategory.object,
      minGrid: 16,
      mirrorable: false,
      parts: [
        SPoly([0.22, 0.10, 0.78, 0.10, 0.98, 0.34, 0.50, 0.97, 0.02, 0.34]),
        Cut(SPoly([0.36, 0.14, 0.46, 0.14, 0.41, 0.28])), // facets
        Cut(SPoly([0.54, 0.14, 0.64, 0.14, 0.59, 0.28])),
      ],
    ),
    const Silhouette(
      id: 'face',
      name: 'Smiling Face',
      category: SilhouetteCategory.object,
      minGrid: 16,
      mirrorable: false,
      parts: [
        SEllipse(0.50, 0.53, 0.40, 0.44), // head
        SEllipse(0.10, 0.53, 0.07, 0.11), // ears
        SEllipse(0.90, 0.53, 0.07, 0.11),
        SPoly([
          0.14,
          0.34,
          0.26,
          0.06,
          0.74,
          0.06,
          0.86,
          0.34,
          0.50,
          0.20,
        ]), // hair
        Cut(SEllipse(0.36, 0.45, 0.06, 0.07)), // eyes
        Cut(SEllipse(0.64, 0.45, 0.06, 0.07)),
        Cut(SLine(0.33, 0.69, 0.50, 0.77, 0.06)), // smile
        Cut(SLine(0.50, 0.77, 0.67, 0.69, 0.06)),
      ],
    ),
    const Silhouette(
      id: 'footprint',
      name: 'Dinosaur Footprint',
      category: SilhouetteCategory.object,
      minGrid: 16,
      mirrorable: false,
      parts: [
        SEllipse(0.50, 0.70, 0.24, 0.27), // pad
        SEllipse(0.24, 0.36, 0.09, 0.22, -28), // toes
        SEllipse(0.50, 0.26, 0.09, 0.24),
        SEllipse(0.76, 0.36, 0.09, 0.22, 28),
        // Claws wide enough to survive rasterizing, overlapping the toe tips.
        SPoly([0.08, 0.24, 0.08, 0.02, 0.24, 0.16]), // claws
        SPoly([0.42, 0.08, 0.50, 0.00, 0.58, 0.08]),
        SPoly([0.76, 0.16, 0.92, 0.02, 0.92, 0.24]),
      ],
    ),

    // ── Nature ──────────────────────────────────────────────────────────────
    const Silhouette(
      id: 'tree',
      name: 'Tree',
      category: SilhouetteCategory.nature,
      minGrid: 16,
      parts: [
        SEllipse(0.50, 0.30, 0.30, 0.26), // canopy
        SEllipse(0.26, 0.48, 0.22, 0.18),
        SEllipse(0.74, 0.48, 0.22, 0.18),
        SEllipse(0.50, 0.56, 0.24, 0.16),
        SRect(0.42, 0.60, 0.58, 0.97), // trunk
        SPoly([0.32, 0.97, 0.42, 0.86, 0.58, 0.86, 0.68, 0.97]), // roots
      ],
    ),
    const Silhouette(
      id: 'pine',
      name: 'Pine Tree',
      category: SilhouetteCategory.nature,
      minGrid: 16,
      mirrorable: false,
      parts: [
        SPoly([0.50, 0.01, 0.76, 0.32, 0.24, 0.32]), // tiers
        SPoly([0.50, 0.18, 0.86, 0.56, 0.14, 0.56]),
        SPoly([0.50, 0.38, 0.96, 0.82, 0.04, 0.82]),
        SRect(0.42, 0.80, 0.58, 0.98), // trunk
      ],
    ),
    Silhouette(
      id: 'flower',
      name: 'Flower',
      category: SilhouetteCategory.nature,
      minGrid: 16,
      mirrorable: false,
      parts: [
        for (var i = 0; i < 5; i++)
          SEllipse(
            0.50 + 0.24 * cos(i * 2 * pi / 5 - pi / 2),
            0.34 + 0.24 * sin(i * 2 * pi / 5 - pi / 2),
            0.14,
          ),
        const SEllipse(0.50, 0.34, 0.13), // centre
        const Cut(SEllipse(0.50, 0.34, 0.055)),
        const SLine(0.50, 0.55, 0.50, 0.99, 0.09), // stem
        const SEllipse(0.33, 0.82, 0.16, 0.065, -30), // leaves
        const SEllipse(0.67, 0.74, 0.16, 0.065, 30),
      ],
    ),
    const Silhouette(
      id: 'moon',
      name: 'Crescent Moon',
      category: SilhouetteCategory.nature,
      minGrid: 16,
      parts: [SEllipse(0.48, 0.50, 0.46), Cut(SEllipse(0.70, 0.38, 0.36))],
    ),
    const Silhouette(
      id: 'planet',
      name: 'Ringed Planet',
      category: SilhouetteCategory.nature,
      minGrid: 26,
      parts: [
        SEllipse(0.50, 0.50, 0.50, 0.17, -18), // ring
        Cut(SEllipse(0.50, 0.50, 0.35, 0.06, -18)),
        SEllipse(0.50, 0.50, 0.25), // planet
      ],
    ),

    // ── Abstract (Kolam-inspired) ───────────────────────────────────────────
    const Silhouette(
      id: 'knot',
      name: 'Kolam Knot',
      category: SilhouetteCategory.abstract,
      minGrid: 16,
      mirrorable: false,
      parts: [
        SEllipse(0.50, 0.24, 0.22),
        SEllipse(0.50, 0.76, 0.22),
        SEllipse(0.24, 0.50, 0.22),
        SEllipse(0.76, 0.50, 0.22),
        SEllipse(0.50, 0.50, 0.16),
        Cut(SEllipse(0.50, 0.24, 0.08)),
        Cut(SEllipse(0.50, 0.76, 0.08)),
        Cut(SEllipse(0.24, 0.50, 0.08)),
        Cut(SEllipse(0.76, 0.50, 0.08)),
      ],
    ),
    Silhouette(
      id: 'starburst',
      name: 'Starburst',
      category: SilhouetteCategory.abstract,
      minGrid: 16,
      mirrorable: false,
      parts: [
        SPoly([
          for (var i = 0; i < 16; i++) ...[
            0.5 + (i.isEven ? 0.49 : 0.24) * cos(i * pi / 8 - pi / 2),
            0.5 + (i.isEven ? 0.49 : 0.24) * sin(i * pi / 8 - pi / 2),
          ],
        ]),
        const Cut(SEllipse(0.50, 0.50, 0.09)),
      ],
    ),
    Silhouette(
      id: 'spiral',
      name: 'Spiral',
      category: SilhouetteCategory.abstract,
      minGrid: 26,
      parts: strokePath([
        for (var i = 0; i <= 64; i++)
          (
            0.5 + (0.05 + 0.41 * i / 64) * cos(i / 64 * 2.0 * 2 * pi),
            0.5 + (0.05 + 0.41 * i / 64) * sin(i / 64 * 2.0 * 2 * pi),
          ),
      ], 0.10),
    ),

    // ── Extended campaign (levels 201+) ─────────────────────────────────────
    // These join after the classic 200 levels (minLevel), so classic boards
    // keep their pictures. Hearts, stars, flowers, Rangoli / Kolam motifs,
    // mazes, spirals, animals and everyday objects.
    const Silhouette(
      id: 'heart',
      name: 'Heart',
      category: SilhouetteCategory.object,
      minGrid: 16,
      mirrorable: false,
      minLevel: 201,
      parts: [
        SEllipse(0.29, 0.31, 0.25),
        SEllipse(0.71, 0.31, 0.25),
        SPoly([0.05, 0.38, 0.50, 0.96, 0.95, 0.38, 0.50, 0.28]),
      ],
    ),
    Silhouette(
      id: 'star',
      name: 'Star',
      category: SilhouetteCategory.abstract,
      minGrid: 16,
      mirrorable: false,
      minLevel: 201,
      parts: [_ring(10, 0.50, 0.24, 0.5, 0.54, -pi / 2)],
    ),
    Silhouette(
      id: 'mandala',
      name: 'Rangoli Mandala',
      category: SilhouetteCategory.abstract,
      minGrid: 24,
      mirrorable: false,
      minLevel: 201,
      parts: [
        for (var i = 0; i < 8; i++)
          SEllipse(
            0.5 + 0.31 * cos(i * pi / 4),
            0.5 + 0.31 * sin(i * pi / 4),
            0.18,
            0.11,
            i * 45.0,
          ),
        for (var i = 0; i < 8; i++)
          SEllipse(
            0.5 + 0.40 * cos(i * pi / 4 + pi / 8),
            0.5 + 0.40 * sin(i * pi / 4 + pi / 8),
            0.07,
          ),
        const SEllipse(0.5, 0.5, 0.20),
        const Cut(SEllipse(0.5, 0.5, 0.08)),
        for (var i = 0; i < 8; i++)
          Cut(
            SEllipse(
              0.5 + 0.32 * cos(i * pi / 4),
              0.5 + 0.32 * sin(i * pi / 4),
              0.05,
            ),
          ),
      ],
    ),
    Silhouette(
      id: 'rangoli_star',
      name: 'Rangoli Star',
      category: SilhouetteCategory.abstract,
      minGrid: 24,
      mirrorable: false,
      minLevel: 201,
      parts: [
        const SRect(0.15, 0.15, 0.85, 0.85),
        _ring(4, 0.49, 0.49, 0.5, 0.5, -pi / 2),
        const Cut(SEllipse(0.5, 0.5, 0.11)),
        for (var i = 0; i < 8; i++)
          Cut(
            SEllipse(
              0.5 + 0.27 * cos(i * pi / 4 + pi / 8),
              0.5 + 0.27 * sin(i * pi / 4 + pi / 8),
              0.045,
            ),
          ),
      ],
    ),
    Silhouette(
      id: 'rangoli_flower',
      name: 'Rangoli Flower',
      category: SilhouetteCategory.abstract,
      minGrid: 24,
      mirrorable: false,
      minLevel: 201,
      parts: [
        for (var i = 0; i < 4; i++)
          SEllipse(
            0.5 + 0.27 * cos(i * pi / 2),
            0.5 + 0.27 * sin(i * pi / 2),
            0.23,
            0.13,
            i * 90.0,
          ),
        for (var i = 0; i < 4; i++)
          SEllipse(
            0.5 + 0.25 * cos(i * pi / 2 + pi / 4),
            0.5 + 0.25 * sin(i * pi / 2 + pi / 4),
            0.17,
            0.09,
            i * 90.0 + 45,
          ),
        const SEllipse(0.5, 0.5, 0.15),
        for (var i = 0; i < 4; i++)
          Cut(
            SEllipse(
              0.5 + 0.31 * cos(i * pi / 2),
              0.5 + 0.31 * sin(i * pi / 2),
              0.10,
              0.04,
              i * 90.0,
            ),
          ),
        const Cut(SEllipse(0.5, 0.5, 0.06)),
      ],
    ),
    const Silhouette(
      id: 'maze',
      name: 'Maze',
      category: SilhouetteCategory.abstract,
      minGrid: 30,
      mirrorable: false,
      minLevel: 201,
      parts: [
        SRect(0.05, 0.05, 0.95, 0.95),
        // Walls: each group touches the border at most once, so every
        // corridor stays connected.
        Cut(SLine(0.00, 0.224, 0.592, 0.224, 0.07)),
        Cut(SLine(0.408, 0.224, 0.408, 0.408, 0.07)),
        Cut(SLine(0.776, 0.224, 1.00, 0.224, 0.07)),
        Cut(SLine(0.592, 0.408, 0.776, 0.408, 0.07)),
        Cut(SLine(0.776, 0.408, 0.776, 0.776, 0.07)),
        Cut(SLine(0.00, 0.592, 0.408, 0.592, 0.07)),
        Cut(SLine(0.224, 0.592, 0.224, 0.776, 0.07)),
        Cut(SLine(0.408, 0.776, 1.00, 0.776, 0.07)),
        Cut(SLine(0.592, 0.592, 0.592, 0.776, 0.07)),
        Cut(SLine(0.592, 0.00, 0.592, 0.12, 0.07)),
        Cut(SLine(0.00, 0.408, 0.224, 0.408, 0.07)),
        Cut(SLine(0.00, 0.776, 0.12, 0.776, 0.07)),
      ],
    ),
    Silhouette(
      id: 'labyrinth',
      name: 'Labyrinth',
      category: SilhouetteCategory.abstract,
      minGrid: 30,
      mirrorable: false,
      minLevel: 201,
      parts: [
        ...strokePath(_arc(0.5, 0.5, 0.43, 0.35, 2 * pi - 0.35), 0.10),
        ...strokePath(_arc(0.5, 0.5, 0.28, pi + 0.35, 3 * pi - 0.35), 0.10),
        ...strokePath(_arc(0.5, 0.5, 0.13, 0.35, 2 * pi - 0.35), 0.10),
        const SLine(0.5, 0.78, 0.5, 0.93, 0.10),
        const SLine(0.5, 0.22, 0.5, 0.37, 0.10),
        const SLine(0.5, 0.5, 0.5, 0.63, 0.10),
        const SEllipse(0.5, 0.5, 0.07),
      ],
    ),
    Silhouette(
      id: 'snail',
      name: 'Snail',
      category: SilhouetteCategory.animal,
      minGrid: 28,
      minLevel: 201,
      parts: [
        const SEllipse(0.56, 0.44, 0.32), // shell
        ...[
          for (final p in strokePath([
            for (var i = 0; i <= 40; i++)
              (
                0.56 + (0.03 + 0.24 * i / 40) * cos(i / 40 * 4 * pi),
                0.44 + (0.03 + 0.24 * i / 40) * sin(i / 40 * 4 * pi),
              ),
          ], 0.045))
            Cut(p),
        ],
        const SPoly([
          0.04,
          0.88,
          0.10,
          0.66,
          0.30,
          0.70,
          0.92,
          0.74,
          0.96,
          0.88,
        ]), // foot
        const SLine(0.12, 0.70, 0.06, 0.46, 0.05), // eye stalks
        const SLine(0.18, 0.70, 0.20, 0.46, 0.05),
      ],
    ),
    Silhouette(
      id: 'sun',
      name: 'Sun',
      category: SilhouetteCategory.nature,
      minGrid: 34,
      mirrorable: false,
      minLevel: 201,
      parts: [
        const SEllipse(0.5, 0.5, 0.26),
        for (var i = 0; i < 12; i++)
          SPoly([
            0.5 + 0.22 * cos(i * pi / 6 - 0.24),
            0.5 + 0.22 * sin(i * pi / 6 - 0.24),
            0.5 + 0.49 * cos(i * pi / 6),
            0.5 + 0.49 * sin(i * pi / 6),
            0.5 + 0.22 * cos(i * pi / 6 + 0.24),
            0.5 + 0.22 * sin(i * pi / 6 + 0.24),
          ]),
      ],
    ),
    Silhouette(
      id: 'snowflake',
      name: 'Snowflake',
      category: SilhouetteCategory.nature,
      minGrid: 30,
      mirrorable: false,
      minLevel: 201,
      parts: [
        for (var i = 0; i < 6; i++) ..._snowflakeArm(i * pi / 3 - pi / 2),
        const SEllipse(0.5, 0.5, 0.13),
      ],
    ),
    const Silhouette(
      id: 'lotus',
      name: 'Lotus',
      category: SilhouetteCategory.nature,
      minGrid: 20,
      mirrorable: false,
      minLevel: 201,
      parts: [
        SEllipse(0.50, 0.40, 0.13, 0.32),
        SEllipse(0.33, 0.48, 0.12, 0.29, -28),
        SEllipse(0.67, 0.48, 0.12, 0.29, 28),
        SEllipse(0.18, 0.60, 0.11, 0.25, -58),
        SEllipse(0.82, 0.60, 0.11, 0.25, 58),
        SEllipse(0.50, 0.78, 0.42, 0.13), // base
      ],
    ),
    Silhouette(
      id: 'sunflower',
      name: 'Sunflower',
      category: SilhouetteCategory.nature,
      minGrid: 24,
      mirrorable: false,
      minLevel: 201,
      parts: [
        for (var i = 0; i < 14; i++)
          SEllipse(
            0.5 + 0.34 * cos(i * 2 * pi / 14),
            0.5 + 0.34 * sin(i * 2 * pi / 14),
            0.15,
            0.065,
            i * 360 / 14,
          ),
        const SEllipse(0.5, 0.5, 0.23),
        const Cut(SEllipse(0.5, 0.5, 0.12)),
        const SEllipse(0.5, 0.5, 0.07),
        const SLine(0.5, 0.5, 0.5, 0.36, 0.05),
      ],
    ),
    const Silhouette(
      id: 'tulip',
      name: 'Tulip',
      category: SilhouetteCategory.nature,
      minGrid: 26,
      minLevel: 201,
      parts: [
        SEllipse(0.5, 0.36, 0.25, 0.22), // cup
        SPoly([
          0.25,
          0.36,
          0.28,
          0.04,
          0.42,
          0.22,
          0.50,
          0.01,
          0.58,
          0.22,
          0.72,
          0.04,
          0.75,
          0.36,
        ]),
        SLine(0.5, 0.55, 0.5, 0.98, 0.08), // stem
        SEllipse(0.35, 0.78, 0.16, 0.07, -40), // leaves
        SEllipse(0.65, 0.70, 0.16, 0.07, 40),
      ],
    ),
    const Silhouette(
      id: 'leaf',
      name: 'Leaf',
      category: SilhouetteCategory.nature,
      minGrid: 28,
      minLevel: 201,
      parts: [
        SEllipse(0.52, 0.44, 0.46, 0.24, -40),
        Cut(SLine(0.30, 0.64, 0.74, 0.26, 0.04)), // midrib
        SLine(0.20, 0.76, 0.06, 0.95, 0.07), // stem
      ],
    ),
    const Silhouette(
      id: 'mushroom',
      name: 'Mushroom',
      category: SilhouetteCategory.nature,
      minGrid: 20,
      minLevel: 201,
      parts: [
        SEllipse(0.5, 0.47, 0.48, 0.42), // cap
        Cut(SRect(0, 0.47, 1, 1)),
        SRect(0.35, 0.40, 0.65, 0.95, 0.08), // stem
        Cut(SEllipse(0.28, 0.30, 0.06)), // spots
        Cut(SEllipse(0.54, 0.18, 0.07)),
        Cut(SEllipse(0.74, 0.34, 0.055)),
      ],
    ),
    const Silhouette(
      id: 'cactus',
      name: 'Cactus',
      category: SilhouetteCategory.nature,
      minGrid: 24,
      minLevel: 201,
      parts: [
        SRect(0.39, 0.06, 0.61, 0.82, 0.11), // trunk
        SRect(0.14, 0.24, 0.26, 0.58, 0.06), // left arm
        SRect(0.14, 0.47, 0.44, 0.59, 0.06),
        SRect(0.74, 0.14, 0.86, 0.48, 0.06), // right arm
        SRect(0.56, 0.37, 0.86, 0.49, 0.06),
        SPoly([0.24, 0.78, 0.76, 0.78, 0.68, 0.99, 0.32, 0.99]), // pot
      ],
    ),
    const Silhouette(
      id: 'apple',
      name: 'Apple',
      category: SilhouetteCategory.nature,
      minGrid: 20,
      minLevel: 201,
      parts: [
        SEllipse(0.36, 0.60, 0.31, 0.36),
        SEllipse(0.64, 0.60, 0.31, 0.36),
        Cut(SEllipse(0.5, 0.25, 0.07)),
        SLine(0.50, 0.30, 0.55, 0.07, 0.07), // stem
        SEllipse(0.70, 0.13, 0.15, 0.07, -25), // leaf
      ],
    ),
    const Silhouette(
      id: 'mountains',
      name: 'Mountains',
      category: SilhouetteCategory.nature,
      minGrid: 18,
      minLevel: 201,
      parts: [
        SPoly([0.01, 0.94, 0.36, 0.12, 0.60, 0.60, 0.74, 0.36, 0.99, 0.94]),
        Cut(SPoly([0.29, 0.29, 0.36, 0.22, 0.43, 0.29, 0.36, 0.34])),
      ],
    ),
    Silhouette(
      id: 'umbrella',
      name: 'Umbrella',
      category: SilhouetteCategory.object,
      minGrid: 30,
      minLevel: 201,
      parts: [
        const SEllipse(0.5, 0.50, 0.49, 0.44), // canopy
        const Cut(SRect(0, 0.50, 1, 1)),
        const Cut(SEllipse(0.27, 0.51, 0.12, 0.06)), // scallops
        const Cut(SEllipse(0.73, 0.51, 0.12, 0.06)),
        const SLine(0.5, 0.40, 0.5, 0.86, 0.07), // shaft
        ...strokePath(_arc(0.41, 0.86, 0.09, 0, pi), 0.07), // handle
      ],
    ),
    Silhouette(
      id: 'anchor',
      name: 'Anchor',
      category: SilhouetteCategory.object,
      minGrid: 30,
      mirrorable: false,
      minLevel: 201,
      parts: [
        const SEllipse(0.5, 0.12, 0.115), // ring
        const Cut(SEllipse(0.5, 0.12, 0.045)),
        const SLine(0.5, 0.20, 0.5, 0.90, 0.14), // shank
        const SLine(0.24, 0.30, 0.76, 0.30, 0.12), // stock
        ...strokePath(_arc(0.5, 0.52, 0.38, 0.30, pi - 0.30), 0.14), // arms
        const SPoly([0.80, 0.56, 0.98, 0.52, 0.90, 0.72]), // flukes
        const SPoly([0.20, 0.56, 0.02, 0.52, 0.10, 0.72]),
      ],
    ),
    const Silhouette(
      id: 'bell',
      name: 'Bell',
      category: SilhouetteCategory.object,
      minGrid: 20,
      mirrorable: false,
      minLevel: 201,
      parts: [
        SEllipse(0.5, 0.40, 0.27, 0.30),
        SPoly([0.23, 0.40, 0.77, 0.40, 0.92, 0.80, 0.08, 0.80]),
        SRect(0.04, 0.75, 0.96, 0.86, 0.05), // lip
        SEllipse(0.5, 0.90, 0.10), // clapper
        SEllipse(0.5, 0.09, 0.08), // loop
      ],
    ),
    const Silhouette(
      id: 'teacup',
      name: 'Teacup',
      category: SilhouetteCategory.object,
      minGrid: 24,
      minLevel: 201,
      parts: [
        SPoly([0.08, 0.28, 0.76, 0.28, 0.68, 0.68, 0.16, 0.68]), // cup
        SEllipse(0.42, 0.66, 0.26, 0.09),
        SEllipse(0.82, 0.44, 0.14, 0.16), // handle
        Cut(SEllipse(0.84, 0.44, 0.065, 0.085)),
        SEllipse(0.44, 0.80, 0.43, 0.075), // saucer
        SLine(0.30, 0.32, 0.30, 0.04, 0.06), // steam
        SLine(0.50, 0.32, 0.50, 0.02, 0.06),
      ],
    ),
    const Silhouette(
      id: 'guitar',
      name: 'Guitar',
      category: SilhouetteCategory.object,
      minGrid: 24,
      mirrorable: false,
      minLevel: 201,
      parts: [
        SEllipse(0.5, 0.74, 0.27, 0.23), // lower bout
        SEllipse(0.5, 0.49, 0.20, 0.17), // upper bout
        SRect(0.455, 0.06, 0.545, 0.40), // neck
        SRect(0.40, 0.01, 0.60, 0.13, 0.03), // head
        Cut(SEllipse(0.5, 0.58, 0.075)), // sound hole
      ],
    ),
    const Silhouette(
      id: 'lighthouse',
      name: 'Lighthouse',
      category: SilhouetteCategory.object,
      minGrid: 24,
      mirrorable: false,
      minLevel: 201,
      parts: [
        SPoly([0.38, 0.30, 0.62, 0.30, 0.71, 0.90, 0.29, 0.90]), // tower
        SRect(0.28, 0.24, 0.72, 0.31), // gallery
        SRect(0.39, 0.12, 0.61, 0.25), // lantern room
        SPoly([0.35, 0.13, 0.50, 0.01, 0.65, 0.13]), // roof
        SRect(0.14, 0.87, 0.86, 0.98, 0.02), // base
        Cut(SRect(0.46, 0.44, 0.54, 0.53)), // windows
        Cut(SRect(0.46, 0.64, 0.54, 0.73)),
      ],
    ),
    const Silhouette(
      id: 'diya',
      name: 'Diya Lamp',
      category: SilhouetteCategory.object,
      minGrid: 24,
      mirrorable: false,
      minLevel: 201,
      parts: [
        SEllipse(0.5, 0.66, 0.46, 0.24), // bowl
        Cut(SRect(0, 0, 1, 0.64)),
        SEllipse(0.5, 0.65, 0.46, 0.05), // rim
        SEllipse(0.5, 0.45, 0.12, 0.17), // flame
        SPoly([0.39, 0.42, 0.50, 0.04, 0.61, 0.42]),
        SRect(0.46, 0.55, 0.54, 0.66), // wick
        SRect(0.36, 0.86, 0.64, 0.97, 0.03), // foot
      ],
    ),
    const Silhouette(
      id: 'balloon',
      name: 'Hot-Air Balloon',
      category: SilhouetteCategory.vehicle,
      minGrid: 30,
      mirrorable: false,
      minLevel: 201,
      parts: [
        SEllipse(0.5, 0.37, 0.37, 0.36), // envelope
        SPoly([0.17, 0.48, 0.83, 0.48, 0.62, 0.73, 0.38, 0.73]),
        Cut(SEllipse(0.5, 0.36, 0.05, 0.25)), // gore seam
        SLine(0.40, 0.72, 0.41, 0.86, 0.06), // ropes
        SLine(0.60, 0.72, 0.59, 0.86, 0.06),
        SRect(0.36, 0.84, 0.64, 0.98, 0.02), // basket
      ],
    ),
    const Silhouette(
      id: 'sailboat',
      name: 'Sailboat',
      category: SilhouetteCategory.vehicle,
      minGrid: 30,
      minLevel: 201,
      parts: [
        SPoly([0.04, 0.74, 0.96, 0.74, 0.80, 0.93, 0.20, 0.93]), // hull
        SRect(0.48, 0.04, 0.54, 0.76), // mast
        SPoly([0.52, 0.06, 0.52, 0.70, 0.92, 0.70]), // mainsail
        SPoly([0.50, 0.14, 0.50, 0.70, 0.12, 0.70]), // jib
      ],
    ),
    Silhouette(
      id: 'kite',
      name: 'Kite',
      category: SilhouetteCategory.object,
      minGrid: 32,
      minLevel: 201,
      parts: [
        const SPoly([0.40, 0.00, 0.79, 0.34, 0.40, 0.76, 0.01, 0.34]),
        ...strokePath([
          for (var i = 0; i <= 16; i++)
            (
              0.40 + 0.46 * i / 16 + 0.05 * sin(i * pi / 4),
              0.70 + 0.27 * i / 16,
            ),
        ], 0.075),
        const SPoly([0.58, 0.80, 0.66, 0.74, 0.66, 0.90]), // bows
        const SPoly([0.74, 0.86, 0.82, 0.80, 0.82, 0.96]),
      ],
    ),
    Silhouette(
      id: 'honeycomb',
      name: 'Honeycomb',
      category: SilhouetteCategory.abstract,
      minGrid: 30,
      mirrorable: false,
      minLevel: 201,
      parts: [
        _ring(6, 0.49, 0.49, 0.5, 0.5, 0),
        Cut(_ring(6, 0.085, 0.085, 0.5, 0.5, 0)),
        for (var i = 0; i < 6; i++)
          Cut(
            _ring(
              6,
              0.085,
              0.085,
              0.5 + 0.235 * cos(i * pi / 3 + pi / 6),
              0.5 + 0.235 * sin(i * pi / 3 + pi / 6),
              0,
            ),
          ),
      ],
    ),
    Silhouette(
      id: 'chakra',
      name: 'Chakra Wheel',
      category: SilhouetteCategory.abstract,
      minGrid: 32,
      mirrorable: false,
      minLevel: 201,
      parts: [
        const SEllipse(0.5, 0.5, 0.49),
        const Cut(SEllipse(0.5, 0.5, 0.38)),
        for (var i = 0; i < 12; i++)
          SLine(
            0.5,
            0.5,
            0.5 + 0.42 * cos(i * pi / 6),
            0.5 + 0.42 * sin(i * pi / 6),
            0.065,
          ),
        const SEllipse(0.5, 0.5, 0.12),
        const Cut(SEllipse(0.5, 0.5, 0.045)),
      ],
    ),
    Silhouette(
      id: 'infinity',
      name: 'Infinity',
      category: SilhouetteCategory.abstract,
      minGrid: 30,
      mirrorable: false,
      minLevel: 201,
      parts: strokePath([
        for (var i = 0; i <= 72; i++)
          (
            0.5 + 0.40 * cos(i * pi / 36) / (1 + pow(sin(i * pi / 36), 2)),
            0.5 +
                0.62 *
                    sin(i * pi / 36) *
                    cos(i * pi / 36) /
                    (1 + pow(sin(i * pi / 36), 2)),
          ),
      ], 0.15),
    ),
    const Silhouette(
      id: 'paisley',
      name: 'Paisley',
      category: SilhouetteCategory.abstract,
      minGrid: 26,
      minLevel: 201,
      parts: [
        SEllipse(0.42, 0.64, 0.32), // body
        SEllipse(0.56, 0.40, 0.19),
        SEllipse(0.68, 0.25, 0.12),
        SEllipse(0.74, 0.13, 0.08),
        SEllipse(0.71, 0.05, 0.05),
        Cut(SEllipse(0.42, 0.66, 0.15)),
        Cut(SEllipse(0.57, 0.40, 0.07)),
      ],
    ),
    const Silhouette(
      id: 'whale',
      name: 'Whale',
      category: SilhouetteCategory.animal,
      minGrid: 24,
      minLevel: 201,
      parts: [
        SEllipse(0.42, 0.58, 0.39, 0.25), // body
        SPoly([
          0.72,
          0.56,
          0.90,
          0.30,
          0.99,
          0.28,
          0.93,
          0.50,
          0.99,
          0.72,
          0.90,
          0.70,
        ]), // tail
        SEllipse(0.42, 0.80, 0.12, 0.06, 30), // fin
        SLine(0.30, 0.36, 0.28, 0.12, 0.06), // spout
        SLine(0.29, 0.20, 0.18, 0.08, 0.05),
        SLine(0.29, 0.20, 0.40, 0.08, 0.05),
        Cut(SEllipse(0.17, 0.54, 0.035)), // eye
      ],
    ),
    const Silhouette(
      id: 'penguin',
      name: 'Penguin',
      category: SilhouetteCategory.animal,
      minGrid: 24,
      minLevel: 201,
      parts: [
        SEllipse(0.5, 0.58, 0.28, 0.37), // body
        SEllipse(0.5, 0.22, 0.19, 0.17), // head
        SPoly([0.64, 0.20, 0.82, 0.25, 0.64, 0.30]), // beak
        SEllipse(0.23, 0.58, 0.07, 0.22, 20), // flippers
        SEllipse(0.77, 0.58, 0.07, 0.22, -20),
        SEllipse(0.40, 0.95, 0.11, 0.04), // feet
        SEllipse(0.60, 0.95, 0.11, 0.04),
        Cut(SEllipse(0.5, 0.63, 0.16, 0.25)), // belly
        Cut(SEllipse(0.45, 0.19, 0.03)), // eyes
        Cut(SEllipse(0.57, 0.19, 0.03)),
      ],
    ),
    const Silhouette(
      id: 'teddy',
      name: 'Teddy Bear',
      category: SilhouetteCategory.animal,
      minGrid: 22,
      mirrorable: false,
      minLevel: 201,
      parts: [
        SEllipse(0.5, 0.29, 0.21), // head
        SEllipse(0.30, 0.11, 0.09), // ears
        SEllipse(0.70, 0.11, 0.09),
        SEllipse(0.5, 0.69, 0.26, 0.26), // body
        SEllipse(0.22, 0.58, 0.09, 0.16, 35), // arms
        SEllipse(0.78, 0.58, 0.09, 0.16, -35),
        SEllipse(0.31, 0.90, 0.13, 0.09), // legs
        SEllipse(0.69, 0.90, 0.13, 0.09),
        Cut(SEllipse(0.42, 0.25, 0.03)), // eyes
        Cut(SEllipse(0.58, 0.25, 0.03)),
        Cut(SEllipse(0.5, 0.37, 0.045)), // nose
        Cut(SEllipse(0.5, 0.70, 0.12, 0.13)), // tummy
      ],
    ),
    Silhouette(
      id: 'octopus',
      name: 'Octopus',
      category: SilhouetteCategory.animal,
      minGrid: 34,
      mirrorable: false,
      minLevel: 201,
      parts: [
        const SEllipse(0.5, 0.30, 0.30, 0.28), // head
        for (var k = 0; k < 5; k++)
          ...strokePath([
            for (var j = 0; j <= 8; j++)
              (
                0.5 +
                    (k - 2) * (0.11 + 0.06 * j / 8) +
                    0.035 * sin(j * 0.9 + k),
                0.46 + j * 0.06,
              ),
          ], 0.085),
        const Cut(SEllipse(0.40, 0.30, 0.05)), // eyes
        const Cut(SEllipse(0.60, 0.30, 0.05)),
      ],
    ),
    const Silhouette(
      id: 'crab',
      name: 'Crab',
      category: SilhouetteCategory.animal,
      minGrid: 36,
      mirrorable: false,
      minLevel: 201,
      parts: [
        SEllipse(0.5, 0.60, 0.30, 0.20), // body
        SLine(0.30, 0.50, 0.18, 0.32, 0.08), // arms
        SLine(0.70, 0.50, 0.82, 0.32, 0.08),
        SEllipse(0.16, 0.24, 0.13, 0.11), // claws
        SEllipse(0.84, 0.24, 0.13, 0.11),
        Cut(SPoly([0.16, 0.24, 0.05, 0.06, 0.24, 0.07])),
        Cut(SPoly([0.84, 0.24, 0.95, 0.06, 0.76, 0.07])),
        SLine(0.26, 0.62, 0.06, 0.76, 0.06), // legs
        SLine(0.28, 0.70, 0.10, 0.88, 0.06),
        SLine(0.36, 0.76, 0.24, 0.96, 0.06),
        SLine(0.74, 0.62, 0.94, 0.76, 0.06),
        SLine(0.72, 0.70, 0.90, 0.88, 0.06),
        SLine(0.64, 0.76, 0.76, 0.96, 0.06),
        Cut(SEllipse(0.42, 0.54, 0.035)), // eyes
        Cut(SEllipse(0.58, 0.54, 0.035)),
      ],
    ),
    Silhouette(
      id: 'peacock',
      name: 'Peacock',
      category: SilhouetteCategory.animal,
      minGrid: 34,
      minLevel: 201,
      parts: [
        const SEllipse(0.62, 0.52, 0.36, 0.42), // tail fan
        for (final (r, n) in const [(0.32, 11), (0.20, 7)])
          for (var i = 0; i < n; i++)
            Cut(
              SEllipse(
                0.62 + r * cos(-2.7 + i * 3.6 / (n - 1)),
                0.52 + r * sin(-2.7 + i * 3.6 / (n - 1)),
                0.04,
              ),
            ), // feather eyes
        const SEllipse(0.36, 0.78, 0.15, 0.12, -15), // body
        const SLine(0.32, 0.72, 0.15, 0.36, 0.08), // neck
        const SEllipse(0.14, 0.31, 0.075), // head
        const SPoly([0.10, 0.26, 0.00, 0.35, 0.11, 0.38]), // beak
        const SLine(0.14, 0.25, 0.10, 0.12, 0.05), // crest
        const SLine(0.14, 0.25, 0.19, 0.12, 0.05),
        const SLine(0.32, 0.88, 0.30, 0.99, 0.05), // legs
        const SLine(0.42, 0.88, 0.44, 0.99, 0.05),
      ],
    ),
    const Silhouette(
      id: 'duck',
      name: 'Duck',
      category: SilhouetteCategory.animal,
      minGrid: 20,
      minLevel: 201,
      parts: [
        SEllipse(0.54, 0.66, 0.38, 0.24), // body
        SEllipse(0.28, 0.48, 0.10, 0.14), // neck
        SEllipse(0.27, 0.30, 0.17), // head
        SPoly([0.13, 0.28, 0.02, 0.36, 0.14, 0.40]), // beak
        SPoly([0.84, 0.58, 0.98, 0.40, 0.92, 0.68]), // tail
        Cut(SEllipse(0.24, 0.26, 0.035)), // eye
        Cut(SEllipse(0.60, 0.62, 0.16, 0.08, -10)), // wing
      ],
    ),
    Silhouette(
      id: 'swan',
      name: 'Swan',
      category: SilhouetteCategory.animal,
      minGrid: 28,
      minLevel: 201,
      parts: [
        const SEllipse(0.56, 0.72, 0.41, 0.23), // body
        const SPoly([0.70, 0.62, 0.98, 0.46, 0.92, 0.72]), // tail
        ...strokePath([
          for (var i = 0; i <= 20; i++)
            (0.36 - 0.14 * sin(i / 20 * 1.6 * pi), 0.66 - 0.52 * i / 20),
        ], 0.11), // neck
        const SEllipse(0.39, 0.15, 0.08, 0.065), // head
        const SPoly([0.44, 0.12, 0.58, 0.17, 0.44, 0.20]), // beak
        const Cut(SEllipse(0.62, 0.70, 0.18, 0.08, -8)), // wing
      ],
    ),
  ];

  /// Regular star or polygon: [points] vertices alternating between radius
  /// [outer] and [inner] (equal radii give a polygon), centred on ([cx],
  /// [cy]) and starting at angle [start].
  static SPoly _ring(
    int points,
    double outer,
    double inner,
    double cx,
    double cy,
    double start,
  ) {
    final step = 2 * pi / points;
    return SPoly([
      for (var i = 0; i < points; i++) ...[
        cx + (i.isEven ? outer : inner) * cos(start + i * step),
        cy + (i.isEven ? outer : inner) * sin(start + i * step),
      ],
    ]);
  }

  /// Points along a circular arc around ([cx], [cy]) of radius [r], from
  /// angle [a0] to [a1] (radians, y down).
  static List<(double, double)> _arc(
    double cx,
    double cy,
    double r,
    double a0,
    double a1,
  ) {
    final steps = max(8, ((a1 - a0).abs() * 12).round());
    return [
      for (var i = 0; i <= steps; i++)
        (
          cx + r * cos(a0 + (a1 - a0) * i / steps),
          cy + r * sin(a0 + (a1 - a0) * i / steps),
        ),
    ];
  }

  /// One snowflake arm pointing at angle [a], with a pair of side branches.
  static List<SilPart> _snowflakeArm(double a) {
    final bx = 0.5 + 0.28 * cos(a), by = 0.5 + 0.28 * sin(a);
    return [
      SLine(0.5, 0.5, 0.5 + 0.46 * cos(a), 0.5 + 0.46 * sin(a), 0.09),
      SLine(
        bx,
        by,
        bx + 0.15 * cos(a + pi / 4),
        by + 0.15 * sin(a + pi / 4),
        0.075,
      ),
      SLine(
        bx,
        by,
        bx + 0.15 * cos(a - pi / 4),
        by + 0.15 * sin(a - pi / 4),
        0.075,
      ),
    ];
  }
}
