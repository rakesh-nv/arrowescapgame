import 'dart:math';

import 'silhouette.dart';

/// Every silhouette a puzzle board can take. Coordinates are in a unit canvas
/// (x right, y down). To add a shape, append a [Silhouette] here: it is picked
/// up by level selection automatically once the board reaches its `minGrid`.
///
/// Appending changes which shape later campaign levels get, so bump
/// `AppConstants.levelGeneratorVersion` when the list changes.
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
  ];
}
