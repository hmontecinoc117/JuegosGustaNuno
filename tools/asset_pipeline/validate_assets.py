from __future__ import annotations

import argparse
import json
import struct
import sys
from pathlib import Path


PIPELINE_DIR = Path(__file__).resolve().parent
PROJECT_ROOT = PIPELINE_DIR.parents[1]
MANIFEST_PATH = PIPELINE_DIR / "asset_manifest.json"
PNG_SIGNATURE = b"\x89PNG\r\n\x1a\n"
TEST_CATEGORIES = {"visual_test"}


def load_manifest() -> dict:
	with MANIFEST_PATH.open("r", encoding="utf-8") as file:
		return json.load(file)


def read_png_size(path: Path) -> tuple[int, int]:
	with path.open("rb") as file:
		signature = file.read(8)
		if signature != PNG_SIGNATURE:
			raise ValueError("not a PNG file")
		length = struct.unpack(">I", file.read(4))[0]
		chunk_type = file.read(4)
		if chunk_type != b"IHDR" or length < 8:
			raise ValueError("missing PNG IHDR")
		width, height = struct.unpack(">II", file.read(8))
		return width, height


def selected_assets(manifest: dict, category: str | None, all_assets: bool, include_test: bool) -> list[dict]:
	assets = manifest.get("assets", [])
	if all_assets:
		if not include_test:
			return [asset for asset in assets if asset.get("category") not in TEST_CATEGORIES]
		return assets
	if category:
		return [asset for asset in assets if asset.get("category") == category]
	if not include_test:
		return [asset for asset in assets if asset.get("category") not in TEST_CATEGORIES]
	return assets


def validate_asset(asset: dict) -> list[str]:
	errors: list[str] = []
	output_path = PROJECT_ROOT / asset["output_folder"] / asset["file_name"]

	if output_path.suffix.lower() != ".png":
		errors.append(f"invalid extension: {output_path}")

	if not output_path.exists():
		errors.append(f"missing: {output_path}")
		return errors

	try:
		width, height = read_png_size(output_path)
	except Exception as error:
		errors.append(f"invalid png: {output_path} ({error})")
		return errors

	expected_width = int(asset["width"])
	expected_height = int(asset["height"])
	if width != expected_width or height != expected_height:
		errors.append(
			f"wrong size: {output_path} expected {expected_width}x{expected_height}, got {width}x{height}"
		)

	return errors


def parse_args() -> argparse.Namespace:
	parser = argparse.ArgumentParser(description="Validate generated PNG assets.")
	group = parser.add_mutually_exclusive_group()
	group.add_argument("--category", help="Validate one category.")
	group.add_argument("--all", action="store_true", help="Validate all assets.")
	parser.add_argument("--include-test", action="store_true", help="Include temporary test categories when validating all assets.")
	return parser.parse_args()


def main() -> int:
	args = parse_args()
	manifest = load_manifest()
	assets = selected_assets(manifest, args.category, args.all, args.include_test)
	all_errors: list[str] = []

	for asset in assets:
		all_errors.extend(validate_asset(asset))

	if all_errors:
		print("Asset validation failed:")
		for error in all_errors:
			print(f"- {error}")
		return 1

	print(f"Asset validation passed. Checked {len(assets)} asset(s).")
	return 0


if __name__ == "__main__":
	sys.exit(main())
