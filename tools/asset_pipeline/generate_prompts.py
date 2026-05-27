from __future__ import annotations

import json
from pathlib import Path


PIPELINE_DIR = Path(__file__).resolve().parent
MANIFEST_PATH = PIPELINE_DIR / "asset_manifest.json"
STYLE_BIBLE_PATH = PIPELINE_DIR / "style_bible.md"
OUTPUT_PATH = PIPELINE_DIR / "prompts_generated.md"


def load_manifest() -> dict:
	with MANIFEST_PATH.open("r", encoding="utf-8") as file:
		return json.load(file)


def load_style_bible() -> str:
	return STYLE_BIBLE_PATH.read_text(encoding="utf-8").strip()


def build_prompt(style_text: str, asset: dict, global_negative: str) -> tuple[str, str]:
	prompt_parts = [
		asset["prompt"].strip(),
		"cartoon premium infantil mobile game",
		"Disney Dreamworks inspired",
		"soft vivid colors",
		"soft shading",
		"rounded shapes",
		"centered composition",
		"Godot 4.x Android landscape ready",
		"no text",
	]
	if asset.get("transparent", False):
		prompt_parts.append("transparent background")

	prompt = ", ".join(part for part in prompt_parts if part)
	negative_extra = asset.get("negative_prompt", "").strip()
	negative_prompt = global_negative if not negative_extra else f"{global_negative}, {negative_extra}"
	return prompt, negative_prompt


def write_prompts(style_text: str, manifest: dict) -> None:
	global_negative = manifest.get("global_negative_prompt", "")
	lines: list[str] = [
		"# Generated Stable Diffusion Prompts",
		"",
		"## Style Source",
		"",
		"```text",
		style_text,
		"```",
		"",
	]

	for asset in manifest.get("assets", []):
		prompt, negative_prompt = build_prompt(style_text, asset, global_negative)
		lines.extend(
			[
				f"## {asset['category']} / {asset['file_name']}",
				"",
				f"- Size: {asset['width']}x{asset['height']}",
				f"- Transparent: {asset['transparent']}",
				f"- Output: `{asset['output_folder']}/{asset['file_name']}`",
				f"- Steps: {asset['steps']}",
				f"- CFG scale: {asset['cfg_scale']}",
				f"- Sampler: {asset['sampler']}",
				f"- Seed: {asset['seed']}",
				"",
				"### Prompt",
				"",
				"```text",
				prompt,
				"```",
				"",
				"### Negative Prompt",
				"",
				"```text",
				negative_prompt,
				"```",
				"",
			]
		)

	OUTPUT_PATH.write_text("\n".join(lines), encoding="utf-8")


def main() -> None:
	manifest = load_manifest()
	style_text = load_style_bible()
	write_prompts(style_text, manifest)
	print(f"Generated prompts: {OUTPUT_PATH}")


if __name__ == "__main__":
	main()
