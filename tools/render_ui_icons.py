"""Render the vendored MDI SVGs as uncompressed RGBA TGA textures for WoW.

Requires Pillow and resvg-py. Run from any directory; no network access needed.
"""
from io import BytesIO
import json
from pathlib import Path

from PIL import Image
from resvg_py import svg_to_bytes

ROOT = Path(__file__).resolve().parents[1] / "assets" / "ui"


def main():
    manifest = json.loads((ROOT / "mdi" / "manifest.json").read_text(encoding="utf-8"))
    for name, source in manifest["icons"].items():
        svg = (ROOT / "mdi" / (source + ".svg")).read_text(encoding="utf-8")
        # Use the original paths, only changing the fill to the workshop's gold.
        png = svg_to_bytes(svg_string=svg, width=128, height=128,
                           style_sheet="path { fill: #efcd8d; }")
        icon = Image.open(BytesIO(png)).convert("RGBA").resize((32, 32), Image.Resampling.LANCZOS)
        icon.save(ROOT / (name + ".tga"), compression=None)
        assert icon.getchannel("A").getextrema() == (0, 255), name
        print(f"{name}.tga <- {source}.svg")


if __name__ == "__main__":
    main()
