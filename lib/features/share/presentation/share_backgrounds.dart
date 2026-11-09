/// Bundled photos for the "Today" share cards.
///
/// Free photos from Unsplash (Unsplash License: free to use, no
/// attribution required), cropped to 1080 × 1920 WebP in
/// `assets/share/`. Sources are listed in `docs/SHARE_PHOTOS.md`.
///
/// To add one: drop a 1080 × 1920 WebP into `assets/share/`, add a line
/// below, and list it in docs/SHARE_PHOTOS.md. Nothing else needs to change.
library;

/// What a photo suits: walking/outdoors (steps) or the gym.
enum ShareBgKind { steps, gym }

class ShareBackground {
  const ShareBackground(this.id, this.label, this.kind);

  /// File name in `assets/share/` without `.webp`.
  final String id;
  final String label;
  final ShareBgKind kind;

  String get asset => 'assets/share/$id.webp';
}

const shareBackgrounds = <ShareBackground>[
  // Steps / outdoors.
  ShareBackground('steps_desert_road', 'Desert road', ShareBgKind.steps),
  ShareBackground('steps_sunrise', 'Sunrise', ShareBgKind.steps),
  ShareBackground('steps_night_run', 'Night run', ShareBgKind.steps),
  ShareBackground('steps_open_road', 'Open road', ShareBgKind.steps),
  ShareBackground('steps_golden_hour', 'Golden hour', ShareBgKind.steps),
  ShareBackground('steps_hilltop', 'Hilltop', ShareBgKind.steps),
  ShareBackground('steps_forest_trail', 'Forest', ShareBgKind.steps),
  ShareBackground('steps_city', 'City', ShareBgKind.steps),
  // Gym.
  ShareBackground('gym_spotlight', 'Spotlight', ShareBgKind.gym),
  ShareBackground('gym_pull_up', 'Pull-up', ShareBgKind.gym),
  ShareBackground('gym_rack', 'Rack', ShareBgKind.gym),
  ShareBackground('gym_deadlift', 'Deadlift', ShareBgKind.gym),
  ShareBackground('gym_barbell', 'Barbell', ShareBgKind.gym),
  ShareBackground('gym_overhead', 'Overhead', ShareBgKind.gym),
  ShareBackground('gym_dumbbells', 'Dumbbells', ShareBgKind.gym),
  ShareBackground('gym_curl', 'Curl', ShareBgKind.gym),
];

/// Every photo, the ones that suit the day first: gym photos on a workout
/// day, outdoor ones on a rest day.
List<ShareBackground> backgroundsFor({required bool workoutDay}) {
  final first = workoutDay ? ShareBgKind.gym : ShareBgKind.steps;
  return [
    ...shareBackgrounds.where((b) => b.kind == first),
    ...shareBackgrounds.where((b) => b.kind != first),
  ];
}

/// Today's suggested photo: rotates through the matching ones by date so
/// consecutive days don't look the same.
ShareBackground suggestedBackground({
  required bool workoutDay,
  required int dayOfYear,
}) {
  final kind = workoutDay ? ShareBgKind.gym : ShareBgKind.steps;
  final matching = shareBackgrounds.where((b) => b.kind == kind).toList();
  return matching[dayOfYear % matching.length];
}
