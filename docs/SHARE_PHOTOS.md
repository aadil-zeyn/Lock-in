# Share-card photos

Backgrounds for the "Today" share cards, bundled in `assets/share/` (1080 × 1920 WebP, ~2 MB total) and registered in `lib/features/share/presentation/share_backgrounds.dart`.

All from [Unsplash](https://unsplash.com) under the [Unsplash License](https://unsplash.com/license): free for personal and commercial use, no permission or attribution needed. They may not be sold unaltered or used to build a competing photo service.

## Adding a photo

1. Pick a free photo (Unsplash, Pexels, or public domain). Portrait works best; keep the subject in the middle, since the top and bottom get darkened for text.
2. Crop to 1080 × 1920 and save as WebP (quality ~70) in `assets/share/`, named `steps_*` or `gym_*`.
3. Add a `ShareBackground(...)` line in `share_backgrounds.dart` and a row below.

## Sources

| File | Source |
|---|---|
| `steps_open_road.webp` | https://images.unsplash.com/photo-1486218119243-13883505764c |
| `steps_desert_road.webp` | https://images.unsplash.com/photo-1500530855697-b586d89ba3ee |
| `steps_golden_hour.webp` | https://images.unsplash.com/photo-1513593771513-7b58b6c4af38 |
| `steps_hilltop.webp` | https://images.unsplash.com/photo-1530143311094-34d807799e8f |
| `steps_night_run.webp` | https://images.unsplash.com/photo-1552674605-db6ffd4facb5 |
| `steps_sunrise.webp` | https://images.unsplash.com/photo-1594882645126-14020914d58d |
| `steps_forest_trail.webp` | https://images.unsplash.com/photo-1441974231531-c6227db76b6e |
| `steps_city.webp` | https://images.unsplash.com/photo-1449824913935-59a10b8d2000 |
| `gym_deadlift.webp` | https://images.unsplash.com/photo-1517836357463-d25dfeac3438 |
| `gym_pull_up.webp` | https://images.unsplash.com/photo-1526506118085-60ce8714f8c5 |
| `gym_dumbbells.webp` | https://images.unsplash.com/photo-1534438327276-14e5300c3a48 |
| `gym_overhead.webp` | https://images.unsplash.com/photo-1541534741688-6078c6bfb5c5 |
| `gym_barbell.webp` | https://images.unsplash.com/photo-1574680096145-d05b474e2155 |
| `gym_rack.webp` | https://images.unsplash.com/photo-1576678927484-cc907957088c |
| `gym_spotlight.webp` | https://images.unsplash.com/photo-1605296867304-46d5465a13f1 |
| `gym_curl.webp` | https://images.unsplash.com/photo-1581009146145-b5ef050c2e1e |
