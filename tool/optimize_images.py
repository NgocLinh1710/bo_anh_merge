"""Generate game assets: python tool/optimize_images.py (requires Pillow)."""

from hashlib import sha256
from io import BytesIO
from pathlib import Path

from PIL import Image, ImageOps

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "assets" / "collections"
DEST = ROOT / "assets" / "collections_webp"


def main():
    source_bytes = output_bytes = count = 0
    for source in sorted(SOURCE.glob("collection_*/*")):
        if source.suffix.lower() not in {".jpg", ".jpeg", ".png", ".webp", ".gif"}:
            continue
        if source.suffix.lower() == ".gif":
            # Preserve frames, timing and looping instead of flattening animation.
            data = source.read_bytes()
            extension = ".gif"
        else:
            with Image.open(source) as original:
                image = ImageOps.exif_transpose(original)
                image.thumbnail((768, 768), Image.Resampling.LANCZOS)
                image = image.convert("RGBA" if "A" in image.getbands() else "RGB")
                buffer = BytesIO()
                image.save(buffer, "WEBP", quality=82, method=6)
            data = buffer.getvalue()
            extension = ".webp"
        digest = sha256(data).hexdigest()[:16]
        directory = DEST / source.parent.name
        directory.mkdir(parents=True, exist_ok=True)
        target = directory / f"{source.stem}.{digest}{extension}"
        target.write_bytes(data)
        # Remove only generated versions of this specific original image.
        for suffix in (".webp", ".gif"):
            for previous in directory.glob(f"{source.stem}.*{suffix}"):
                if previous != target:
                    previous.unlink()
        source_bytes += source.stat().st_size
        output_bytes += len(data)
        count += 1
    print(f"{count} images: {source_bytes:,} -> {output_bytes:,} bytes "
          f"({100 * (1 - output_bytes / source_bytes):.1f}% smaller)")


if __name__ == "__main__":
    main()
