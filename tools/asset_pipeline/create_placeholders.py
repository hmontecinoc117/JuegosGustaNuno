from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path


PIPELINE_DIR = Path(__file__).resolve().parent
PROJECT_ROOT = PIPELINE_DIR.parents[1]
MANIFEST_PATH = PIPELINE_DIR / "asset_manifest.json"


def load_manifest() -> dict:
	with MANIFEST_PATH.open("r", encoding="utf-8") as file:
		return json.load(file)


def selected_assets(manifest: dict, category: str | None, all_assets: bool) -> list[dict]:
	assets = manifest.get("assets", [])
	if all_assets:
		return assets
	if category:
		return [asset for asset in assets if asset.get("category") == category]
	return assets


def make_placeholder(asset: dict, overwrite: bool) -> bool:
	try:
		from PIL import Image, ImageDraw, ImageFont
	except ImportError:
		print("ERROR: Pillow is required for placeholders. Install with: python -m pip install pillow")
		return False

	width = int(asset["width"])
	height = int(asset["height"])
	output_path = PROJECT_ROOT / asset["output_folder"] / asset["file_name"]
	if output_path.exists() and not overwrite:
		print(f"SKIP exists: {output_path}")
		return True

	output_path.parent.mkdir(parents=True, exist_ok=True)
	background = (116, 163, 236, 190) if asset.get("transparent", False) else (116, 163, 236, 255)
	image = Image.new("RGBA", (width, height), background)
	draw = ImageDraw.Draw(image)

	border_color = (255, 255, 255, 230)
	draw.rounded_rectangle(
		(8, 8, width - 9, height - 9),
		radius=max(16, min(width, height) // 12),
		outline=border_color,
		width=max(4, min(width, height) // 80),
	)

	label = asset["file_name"]
	category = asset["category"]
	font = ImageFont.load_default()
	lines = [category, label, f"{width}x{height}"]
	line_height = 16
	total_height = len(lines) * line_height
	y = (height - total_height) // 2
	for line in lines:
		text_width = draw.textlength(line, font=font)
		x = (width - text_width) // 2
		draw.text((x, y), line, fill=(255, 255, 255, 255), font=font)
		y += line_height

	image.save(output_path)
	print(f"PLACEHOLDER: {output_path}")
	return True


def parse_args() -> argparse.Namespace:
	parser = argparse.ArgumentParser(description="Create PNG placeholders for missing assets.")
	group = parser.add_mutually_exclusive_group()
	group.add_argument("--category", help="Create placeholders for one category.")
	group.add_argument("--all", action="store_true", help="Create placeholders for all assets.")
	parser.add_argument("--overwrite", action="store_true", help="Overwrite existing PNG files.")
	return parser.parse_args()


def main() -> int:
	args = parse_args()
	manifest = load_manifest()
	assets = selected_assets(manifest, args.category, args.all)
	ok = True
	for asset in assets:
		ok = make_placeholder(asset, args.overwrite) and ok
	return 0 if ok else 1


if __name__ == "__main__":
	sys.exit(main())
