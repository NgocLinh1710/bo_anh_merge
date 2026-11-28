# Image delivery

Game images are generated from `assets/collections/` into
`assets/collections_webp/`. Originals are retained in the repository but are not
included in the Flutter asset bundle. Levels retain the numeric order of their
original filenames.

After adding or changing originals, run:

```sh
python -m pip install -r tool/image-requirements.txt
python tool/optimize_images.py
flutter test
flutter build web --release
```

Commit the generated image files together with source changes. The generator uses
EXIF orientation, preserves aspect ratio and transparency, limits the longest
edge to 768 pixels, and encodes at quality 82. Review image clarity on a phone
after changing conversion settings. Remove the matching generated file manually
when deleting an original; update pubspec.yaml when adding a collection folder.

GIF originals are copied unchanged into `assets/collections_webp/` with a content
hash and the `.gif` extension, preserving every frame, frame duration and loop.
The folder name is retained for compatibility with asset loading and cache rules.
Only files directly inside `assets/collections/collection_N/` are generated;
place playable images there with a numeric filename prefix and a real supported
extension (`.jpg`, `.jpeg`, `.png`, `.webp`, `.gif`). Subfolders can hold references
or alternate images without creating extra game levels.

Collection configuration belongs in `lib/services/collection_service.dart`.
Collections 7 (BƠ XÉ, 111 coins) and 8 (BƠ ÁO MAY Ô, 142 coins) support free and
timed play. Collection 7 has three levels; its final image is `3.gif`.
Collection 8 has four levels. Their source images are directly inside
`assets/collections/collection_7/` and `assets/collections/collection_8/`;
neither collection requires a named subfolder.
Both use the default free-play spawn tuning and default reward of 11 coins per
14 merges; timed rewards remain 10 coins per 5 merges. Secret audio is mapped to
`assets/sounds/sound_secret/Sound 7.mp3` and `Sound 8.mp3`.

Each generated filename includes a hash of its bytes. `vercel.json` sets a
one-year immutable browser cache only for this generated image directory. New
image content gets a new URL, so it does not reuse a cached older image. Keep
these names content-addressed; do not apply this policy to HTML or manifests.
Ensure Vercel's output directory remains `build/web` and that project-level
configuration does not override these headers.

All collection images share an asset bundle that deduplicates pending requests,
limits downloads to three, and retries failed loads twice after 500 and 1500 ms.
Only current-board images, starting levels, and next merge levels are prefetched.
Prefetching does not block gameplay or the timer. Image decode errors still show
the existing fallback; retry is intended for asset loading failures.

After deployment, use browser Network tools with a cold cache and throttled
network to check image requests: WebP/GIF URLs, status 200, the immutable header,
and reduced transfer size. Reload with browser cache enabled to check reuse.
Test opening each collection, merging, dragging and the final-image dialog.
Check Vercel usage and HTTP errors during busy periods if failures persist.
The concurrency limit applies per browser session, not across all players.
