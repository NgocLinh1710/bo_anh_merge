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

Commit the generated WebP files together with source changes. The generator uses
EXIF orientation, preserves aspect ratio and transparency, limits the longest
edge to 768 pixels, and encodes at quality 82. Review image clarity on a phone
after changing conversion settings. Remove the matching generated file manually
when deleting an original; update pubspec.yaml when adding a collection folder.

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
network to check image requests: WebP URLs, status 200, the immutable header,
and reduced transfer size. Reload with browser cache enabled to check reuse.
Test opening each collection, merging, dragging and the final-image dialog.
Check Vercel usage and HTTP errors during busy periods if failures persist.
The concurrency limit applies per browser session, not across all players.
