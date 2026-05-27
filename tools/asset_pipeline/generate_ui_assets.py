from __future__ import annotations

import argparse
import json
import math
from pathlib import Path

try:
	from PIL import Image, ImageDraw, ImageFilter
except ImportError as error:
	raise SystemExit("Pillow is required. Install with: python -m pip install pillow") from error


PIPELINE_DIR = Path(__file__).resolve().parent
PROJECT_ROOT = PIPELINE_DIR.parents[1]
DESIGN_SYSTEM_PATH = PIPELINE_DIR / "design_system.json"

BUTTON_DIR = PROJECT_ROOT / "assets/ui/buttons"
ICON_DIR = PROJECT_ROOT / "assets/ui/icons"
CARD_DIR = PROJECT_ROOT / "assets/ui/cards"
PANEL_DIR = PROJECT_ROOT / "assets/ui/panels"
REWARD_DIR = PROJECT_ROOT / "assets/ui/rewards"


def load_design_system() -> dict:
	with DESIGN_SYSTEM_PATH.open("r", encoding="utf-8") as file:
		return json.load(file)


def ensure_dirs() -> None:
	for folder in [BUTTON_DIR, ICON_DIR, CARD_DIR, PANEL_DIR, REWARD_DIR]:
		folder.mkdir(parents=True, exist_ok=True)


def save_image(image: Image.Image, path: Path, overwrite: bool) -> None:
	if path.exists() and not overwrite:
		print(f"SKIP exists: {path}")
		return
	path.parent.mkdir(parents=True, exist_ok=True)
	image.save(path)
	print(f"WRITE: {path}")


def hex_to_rgba(value: str, alpha: int = 255) -> tuple[int, int, int, int]:
	value = value.lstrip("#")
	return (int(value[0:2], 16), int(value[2:4], 16), int(value[4:6], 16), alpha)


def clamp(value: int) -> int:
	return max(0, min(255, value))


def adjust_color(color: tuple[int, int, int, int], amount: int) -> tuple[int, int, int, int]:
	return (clamp(color[0] + amount), clamp(color[1] + amount), clamp(color[2] + amount), color[3])


def with_alpha(color: tuple[int, int, int, int], alpha: int) -> tuple[int, int, int, int]:
	return (color[0], color[1], color[2], alpha)


def solid_ui(color: tuple[int, int, int, int]) -> tuple[int, int, int, int]:
	return with_alpha(color, max(235, color[3]))


def mix_color(a: tuple[int, int, int, int], b: tuple[int, int, int, int], t: float) -> tuple[int, int, int, int]:
	return tuple(int(a[index] * (1.0 - t) + b[index] * t) for index in range(4))


def rounded_mask(size: tuple[int, int], radius: int) -> Image.Image:
	mask = Image.new("L", size, 0)
	draw = ImageDraw.Draw(mask)
	draw.rounded_rectangle((0, 0, size[0] - 1, size[1] - 1), radius=radius, fill=255)
	return mask


def vertical_gradient(size: tuple[int, int], top: tuple[int, int, int, int], bottom: tuple[int, int, int, int]) -> Image.Image:
	width, height = size
	image = Image.new("RGBA", size, (0, 0, 0, 0))
	pixels = image.load()
	for y in range(height):
		t = y / max(1, height - 1)
		color = mix_color(top, bottom, t)
		for x in range(width):
			pixels[x, y] = color
	return image


def radial_glow(size: tuple[int, int], color: tuple[int, int, int, int], center: tuple[float, float], radius: float) -> Image.Image:
	width, height = size
	image = Image.new("RGBA", size, (0, 0, 0, 0))
	pixels = image.load()
	for y in range(height):
		for x in range(width):
			distance = math.dist((x, y), center)
			t = max(0.0, 1.0 - distance / radius)
			alpha = int(color[3] * (t * t))
			pixels[x, y] = (color[0], color[1], color[2], alpha)
	return image


def paste_masked(base: Image.Image, layer: Image.Image, mask: Image.Image, xy: tuple[int, int]) -> None:
	base.paste(layer, xy, mask)


def add_soft_shadow(base: Image.Image, mask: Image.Image, xy: tuple[int, int], blur: int, offset_y: int, opacity: float) -> None:
	shadow_mask = Image.new("L", base.size, 0)
	shadow_mask.paste(mask, (xy[0], xy[1] + offset_y))
	shadow_mask = shadow_mask.filter(ImageFilter.GaussianBlur(blur))
	alpha = int(255 * min(0.42, opacity * 1.85))
	shadow = Image.new("RGBA", base.size, (34, 42, 52, alpha))
	base.alpha_composite(Image.composite(shadow, Image.new("RGBA", base.size, (0, 0, 0, 0)), shadow_mask))


def draw_inner_highlight(draw: ImageDraw.ImageDraw, rect: tuple[int, int, int, int], radius: int, alpha: int) -> None:
	x1, y1, x2, y2 = rect
	height = y2 - y1
	draw.rounded_rectangle(
		(x1 + 12, y1 + 10, x2 - 12, y1 + max(18, int(height * 0.24))),
		radius=max(8, radius // 2),
		fill=(255, 255, 255, max(80, alpha)),
	)


def tactile_rect(
	size: tuple[int, int],
	fill_top: tuple[int, int, int, int],
	fill_bottom: tuple[int, int, int, int],
	radius: int,
	border_color: tuple[int, int, int, int],
	border_width: int,
	system: dict,
	padding: int | None = None,
	inner_border: tuple[int, int, int, int] | None = None,
) -> Image.Image:
	width, height = size
	if padding is None:
		padding = max(10, min(width, height) // 14)
	shape_size = (width - padding * 2, height - padding * 2)
	shape_radius = min(radius, min(shape_size) // 2)
	image = Image.new("RGBA", size, (0, 0, 0, 0))
	mask = rounded_mask(shape_size, shape_radius)
	shadow = system["shadow"]
	add_soft_shadow(image, mask, (padding, padding), int(shadow["blur"]), int(shadow["offset_y"]), float(shadow["opacity"]))

	fill = vertical_gradient(shape_size, solid_ui(fill_top), solid_ui(fill_bottom))
	paste_masked(image, fill, mask, (padding, padding))
	draw = ImageDraw.Draw(image)
	rect = (padding, padding, width - padding - 1, height - padding - 1)
	draw.rounded_rectangle(rect, radius=shape_radius, outline=border_color, width=border_width)
	if inner_border:
		inset = padding + border_width + 6
		draw.rounded_rectangle(
			(inset, inset, width - inset - 1, height - inset - 1),
			radius=max(8, shape_radius - border_width - 6),
			outline=solid_ui(inner_border),
			width=max(2, border_width // 2),
		)
	if system["gloss"].get("enabled", True):
		draw_inner_highlight(draw, rect, shape_radius, int(255 * float(system["gloss"]["strength"])))
	return image


def draw_star(draw: ImageDraw.ImageDraw, center: tuple[float, float], outer: float, inner: float, fill, outline=None, width: int = 1) -> None:
	points = []
	for index in range(10):
		angle = -math.pi / 2 + index * math.pi / 5
		radius = outer if index % 2 == 0 else inner
		points.append((center[0] + math.cos(angle) * radius, center[1] + math.sin(angle) * radius))
	draw.polygon(points, fill=fill)
	if outline:
		draw.line(points + [points[0]], fill=outline, width=width, joint="curve")


def draw_paw(draw: ImageDraw.ImageDraw, x: int, y: int, scale: float, fill) -> None:
	draw.ellipse((x - 10 * scale, y - 5 * scale, x + 10 * scale, y + 13 * scale), fill=fill)
	for ox, oy in [(-13, -14), (-4, -20), (6, -20), (15, -14)]:
		draw.ellipse((x + (ox - 5) * scale, y + (oy - 5) * scale, x + (ox + 5) * scale, y + (oy + 5) * scale), fill=fill)


def draw_button_shadow(size: tuple[int, int], radius: int, padding: int) -> Image.Image:
	image = Image.new("RGBA", size, (0, 0, 0, 0))
	mask = rounded_mask((size[0] - padding * 2, size[1] - padding * 2), radius)
	add_soft_shadow(image, mask, (padding, padding), max(10, size[1] // 13), max(5, size[1] // 22), 0.22)
	return image


def draw_button_highlight(draw: ImageDraw.ImageDraw, rect: tuple[int, int, int, int], radius: int) -> None:
	x1, y1, x2, y2 = rect
	draw.rounded_rectangle(
		(x1 + 18, y1 + 12, x2 - 18, y1 + max(22, int((y2 - y1) * 0.32))),
		radius=max(12, radius // 2),
		fill=(255, 255, 255, 34),
	)
	draw.arc((x1 + 26, y1 + 16, x2 - 26, y2 - 12), 205, 335, fill=(255, 255, 255, 56), width=max(2, (y2 - y1) // 34))


def draw_button_icon_slot(draw: ImageDraw.ImageDraw, rect: tuple[int, int, int, int], radius: int) -> None:
	x1, y1, _x2, y2 = rect
	slot_size = int((y2 - y1) * 0.62)
	slot_x = x1 + 18
	slot_y = y1 + ((y2 - y1) - slot_size) // 2
	draw.rounded_rectangle(
		(slot_x, slot_y, slot_x + slot_size, slot_y + slot_size),
		radius=max(10, radius // 3),
		fill=(255, 255, 255, 26),
		outline=(255, 250, 226, 90),
		width=2,
	)


def draw_premium_button(system: dict, size: tuple[int, int], base: tuple[int, int, int, int], state: str = "normal") -> Image.Image:
	if state == "pressed":
		top = adjust_color(base, -2)
		bottom = adjust_color(base, -42)
		offset_y = 5
	elif state == "hover":
		top = adjust_color(base, 46)
		bottom = adjust_color(base, -8)
		offset_y = 0
	else:
		top = adjust_color(base, 34)
		bottom = adjust_color(base, -34)
		offset_y = 0

	width, height = size
	padding = max(12, height // 9)
	radius = max(10, height // 2 - padding)
	image = draw_button_shadow(size, radius, padding)
	rect = (padding, padding + offset_y, width - padding - 1, height - padding + offset_y - 1)
	shape_size = (rect[2] - rect[0] + 1, rect[3] - rect[1] + 1)
	mask = rounded_mask(shape_size, radius)
	fill = vertical_gradient(shape_size, solid_ui(top), solid_ui(bottom))
	paste_masked(image, fill, mask, (rect[0], rect[1]))

	draw = ImageDraw.Draw(image)
	draw.rounded_rectangle(rect, radius=radius, outline=(255, 244, 214, 255), width=max(5, height // 18))
	inner = padding + max(8, height // 18)
	draw.rounded_rectangle(
		(inner, inner + offset_y, width - inner - 1, height - inner + offset_y - 1),
		radius=max(10, (height - inner * 2) // 2),
		outline=(255, 255, 255, 205),
		width=max(2, height // 44),
	)
	highlight = Image.new("RGBA", size, (0, 0, 0, 0))
	draw_button_highlight(ImageDraw.Draw(highlight), rect, radius)
	image.alpha_composite(highlight)
	return image


def make_button(system: dict, size: tuple[int, int], base: tuple[int, int, int, int], state: str = "normal") -> Image.Image:
	return draw_premium_button(system, size, base, state)


def generate_buttons(system: dict, overwrite: bool) -> None:
	palette = system["palette"]
	buttons = [
		("button_primary_orange.png", (512, 160), hex_to_rgba(palette["warm_orange"])),
		("button_secondary_blue.png", (512, 160), hex_to_rgba(palette["primary_sky"])),
		("button_secondary_green.png", (512, 160), hex_to_rgba(palette["forest_green"])),
		("button_danger_red.png", (512, 160), hex_to_rgba(palette["danger_red"])),
		("button_small_orange.png", (320, 120), hex_to_rgba(palette["warm_orange"])),
		("button_disabled_gray.png", (512, 160), hex_to_rgba(palette["neutral_gray"])),
		("button_primary_orange_hover.png", (512, 160), hex_to_rgba(palette["warm_orange"]), "hover"),
		("button_primary_orange_pressed.png", (512, 160), hex_to_rgba(palette["warm_orange"]), "pressed"),
	]
	for item in buttons:
		name, size, color = item[0], item[1], item[2]
		state = item[3] if len(item) > 3 else "normal"
		save_image(make_button(system, size, color, state), BUTTON_DIR / name, overwrite)


def generate_cards(system: dict, overwrite: bool) -> None:
	palette = system["palette"]
	turquoise = hex_to_rgba(palette["primary_turquoise"])
	sky = hex_to_rgba(palette["primary_sky"])
	cream = hex_to_rgba(palette["cream"])
	gold = hex_to_rgba(palette["soft_gold"])
	green = hex_to_rgba(palette["forest_green"])
	red = hex_to_rgba(palette["danger_red"])
	card_size = (512, 640)
	card_radius = int(system["radius"]["card"]) + 8

	back = Image.new("RGBA", card_size, (0, 0, 0, 0))
	outer_mask = rounded_mask((462, 590), 52)
	add_soft_shadow(back, outer_mask, (25, 25), 16, 7, 0.22)
	paste_masked(back, vertical_gradient((462, 590), adjust_color(gold, 28), adjust_color(gold, -28)), outer_mask, (25, 22))
	draw = ImageDraw.Draw(back)
	draw.rounded_rectangle((38, 34, 474, 606), radius=46, fill=(255, 226, 114, 255))
	turquoise_mask = rounded_mask((400, 528), 40)
	turquoise_fill = vertical_gradient((400, 528), adjust_color(turquoise, 54), adjust_color(turquoise, -30))
	paste_masked(back, turquoise_fill, turquoise_mask, (56, 58))
	back.alpha_composite(radial_glow(card_size, (255, 255, 255, 58), (168, 130), 240))
	draw = ImageDraw.Draw(back)
	draw.rounded_rectangle((54, 56, 458, 588), radius=42, outline=(255, 248, 224, 255), width=8)
	draw.rounded_rectangle((70, 74, 442, 570), radius=32, outline=(255, 215, 84, 225), width=4)
	draw.rounded_rectangle((84, 90, 428, 554), radius=26, outline=(255, 255, 255, 135), width=2)
	back_highlight = Image.new("RGBA", card_size, (0, 0, 0, 0))
	highlight_draw = ImageDraw.Draw(back_highlight)
	highlight_draw.rounded_rectangle((82, 78, 430, 188), radius=28, fill=(255, 255, 255, 22))
	highlight_draw.arc((100, 92, 412, 316), 205, 333, fill=(255, 255, 255, 46), width=3)
	back.alpha_composite(back_highlight)
	draw = ImageDraw.Draw(back)
	draw.rounded_rectangle((86, 506, 426, 552), radius=18, fill=(0, 115, 138, 30))

	decorations = [
		(124, 132, "star"), (184, 138, "star"), (246, 126, "paw"), (318, 144, "star"), (382, 132, "paw"),
		(126, 214, "star"), (192, 228, "paw"), (326, 220, "star"), (390, 236, "star"),
		(132, 318, "paw"), (202, 336, "star"), (320, 330, "paw"), (382, 312, "star"),
		(126, 432, "star"), (196, 458, "paw"), (258, 444, "star"), (326, 468, "star"), (386, 430, "paw"),
	]
	for index, (x, y, kind) in enumerate(decorations):
		color = (255, 255, 255, 190) if kind == "star" else (255, 248, 220, 164)
		if index % 5 == 0:
			color = (255, 214, 83, 170)
		if kind == "star":
			draw_star(draw, (x, y), 13, 5, fill=color)
		else:
			draw_paw(draw, x, y, 0.50, color)

	seal_shadow = Image.new("RGBA", card_size, (0, 0, 0, 0))
	seal_draw = ImageDraw.Draw(seal_shadow)
	seal_draw.ellipse((178, 244, 334, 400), fill=(24, 80, 92, 78))
	seal_shadow = seal_shadow.filter(ImageFilter.GaussianBlur(6))
	back.alpha_composite(seal_shadow)
	draw = ImageDraw.Draw(back)
	draw.ellipse((180, 248, 332, 400), fill=(255, 220, 91, 255))
	draw.ellipse((196, 264, 316, 384), fill=(255, 243, 186, 255), outline=(255, 255, 246, 235), width=4)
	draw.ellipse((212, 280, 300, 368), fill=(255, 199, 54, 255))
	draw_star(draw, (256, 324), 43, 20, fill=(255, 252, 230, 255), outline=(208, 148, 30, 135), width=3)
	draw.ellipse((214, 260, 286, 304), fill=(255, 255, 255, 48))
	save_image(back, CARD_DIR / "card_back_default.png", overwrite)

	front = tactile_rect(card_size, adjust_color(cream, 4), adjust_color(cream, -8), card_radius, gold, 26, system, padding=22, inner_border=(255, 255, 255, 245))
	draw = ImageDraw.Draw(front)
	front.alpha_composite(radial_glow(card_size, (255, 255, 255, 46), (170, 120), 260))
	draw.rounded_rectangle((88, 110, 424, 512), radius=44, fill=(255, 243, 216, 255), outline=(245, 194, 74, 255), width=10)
	draw.rounded_rectangle((108, 134, 404, 488), radius=34, fill=(255, 249, 231, 255), outline=(255, 255, 255, 248), width=5)
	draw.rounded_rectangle((126, 154, 386, 268), radius=26, fill=(255, 255, 255, 58))
	save_image(front, CARD_DIR / "card_front_default.png", overwrite)

	success = tactile_rect(card_size, adjust_color(cream, 4), adjust_color(cream, -8), card_radius, gold, 26, system, padding=22, inner_border=(255, 255, 255, 245))
	success.alpha_composite(radial_glow(card_size, (*green[:3], 170), (256, 320), 330))
	draw = ImageDraw.Draw(success)
	draw.rounded_rectangle((82, 106, 430, 516), radius=44, fill=(255, 243, 216, 245), outline=adjust_color(green, 18), width=14)
	save_image(success, CARD_DIR / "card_front_success.png", overwrite)

	error = tactile_rect(card_size, adjust_color(cream, 4), adjust_color(cream, -8), card_radius, gold, 26, system, padding=22, inner_border=(255, 255, 255, 245))
	error.alpha_composite(radial_glow(card_size, (*red[:3], 170), (256, 320), 330))
	draw = ImageDraw.Draw(error)
	draw.rounded_rectangle((82, 106, 430, 516), radius=44, fill=(255, 243, 216, 245), outline=adjust_color(red, 12), width=14)
	save_image(error, CARD_DIR / "card_front_error.png", overwrite)

	selected = tactile_rect(card_size, adjust_color(cream, 10), adjust_color(cream, -10), card_radius, gold, 22, system, padding=24, inner_border=(255, 255, 255, 240))
	selected.alpha_composite(radial_glow(card_size, (*turquoise[:3], 130), (256, 320), 330))
	draw = ImageDraw.Draw(selected)
	draw.rounded_rectangle((70, 92, 442, 530), radius=42, outline=(255, 255, 255, 190), width=10)
	save_image(selected, CARD_DIR / "card_selected_state.png", overwrite)

	shadow = Image.new("RGBA", (512, 160), (0, 0, 0, 0))
	mask = Image.new("L", (512, 160), 0)
	ImageDraw.Draw(mask).ellipse((28, 34, 484, 134), fill=218)
	mask = mask.filter(ImageFilter.GaussianBlur(28))
	shadow_layer = Image.new("RGBA", (512, 160), (31, 47, 58, 138))
	shadow.alpha_composite(Image.composite(shadow_layer, Image.new("RGBA", (512, 160), (0, 0, 0, 0)), mask))
	save_image(shadow, CARD_DIR / "card_shadow.png", overwrite)


def generate_panels(system: dict, overwrite: bool) -> None:
	palette = system["palette"]
	cream = hex_to_rgba(palette["cream"], 255)
	turquoise = hex_to_rgba(palette["primary_turquoise"], 255)
	sky = hex_to_rgba(palette["primary_sky"], 255)
	gold = hex_to_rgba(palette["soft_gold"], 255)
	panel_radius = int(system["radius"]["panel"])
	specs = [
		("panel_logo.png", (1024, 360), adjust_color(cream, 4), adjust_color(cream, -8), panel_radius + 8, gold, 14),
		("panel_board.png", (1400, 900), adjust_color(cream, 1), adjust_color(cream, -6), panel_radius + 18, turquoise, 30),
		("panel_stats.png", (512, 180), adjust_color(cream, 4), adjust_color(cream, -6), panel_radius - 8, turquoise, 18),
		("panel_stars.png", (512, 420), adjust_color(cream, 3), adjust_color(cream, -8), panel_radius + 4, turquoise, 18),
		("panel_message.png", (900, 160), adjust_color(cream, 4), adjust_color(cream, -8), panel_radius, gold, 12),
		("panel_victory.png", (1200, 800), adjust_color(cream, 5), adjust_color(gold, 4), panel_radius + 20, gold, 20),
	]
	for name, size, top, bottom, radius, border, border_width in specs:
		image = tactile_rect(size, top, bottom, radius, border, border_width, system, inner_border=(245, 194, 74, 255))
		draw = ImageDraw.Draw(image)
		if name == "panel_board.png":
			draw.rounded_rectangle((64, 70, size[0] - 64, size[1] - 70), radius=54, fill=(255, 243, 216, 255), outline=(37, 198, 216, 255), width=10)
			draw.rounded_rectangle((88, 96, size[0] - 88, size[1] - 96), radius=44, fill=(255, 243, 216, 255), outline=(245, 194, 74, 255), width=9)
			draw.rounded_rectangle((122, 132, size[0] - 122, size[1] - 132), radius=36, fill=(255, 250, 232, 255), outline=(255, 255, 255, 248), width=4)
		if name == "panel_stats.png":
			draw.rounded_rectangle((38, 38, size[0] - 38, size[1] - 38), radius=32, fill=(255, 243, 216, 255), outline=(245, 194, 74, 255), width=5)
			draw.rounded_rectangle((58, 58, size[0] - 58, size[1] - 58), radius=24, fill=(255, 250, 232, 255), outline=(255, 255, 255, 245), width=3)
		if name == "panel_stars.png":
			draw.rounded_rectangle((38, 52, size[0] - 38, size[1] - 44), radius=38, fill=(255, 243, 216, 255), outline=(245, 194, 74, 255), width=7)
			draw.rounded_rectangle((60, 78, size[0] - 60, 126), radius=24, fill=adjust_color(turquoise, 8), outline=(255, 255, 255, 245), width=3)
			draw.rounded_rectangle((60, 142, size[0] - 60, size[1] - 76), radius=30, fill=(255, 250, 232, 255), outline=(255, 255, 255, 245), width=3)
			for x in [166, 256, 346]:
				draw_star(draw, (x, 214), 44, 20, fill=(255, 218, 74, 255), outline=(178, 108, 20, 245), width=5)
		save_image(image, PANEL_DIR / name, overwrite)


def draw_icon_base(size: tuple[int, int]) -> Image.Image:
	image = Image.new("RGBA", size, (0, 0, 0, 0))
	return image


def draw_icon_shadow(draw: ImageDraw.ImageDraw, points: list[tuple[float, float]], offset: float, fill) -> None:
	draw.line([(x + offset, y + offset) for x, y in points], fill=fill, width=max(2, int(offset * 2)), joint="curve")


def generate_icons(system: dict, overwrite: bool) -> None:
	palette = system["palette"]
	gold = hex_to_rgba(palette["soft_gold"])
	turquoise = hex_to_rgba(palette["primary_turquoise"])
	cream = hex_to_rgba(palette["cream"])
	icons = [
		("icon_play.png", (128, 128), "play"),
		("icon_profile.png", (128, 128), "profile"),
		("icon_options.png", (128, 128), "options"),
		("icon_exit.png", (128, 128), "exit"),
		("icon_restart.png", (128, 128), "restart"),
		("icon_menu.png", (128, 128), "menu"),
		("icon_next.png", (128, 128), "next"),
		("icon_attempts.png", (96, 96), "attempts"),
		("icon_pairs.png", (96, 96), "pairs"),
		("icon_best_score.png", (96, 96), "best"),
	]
	for name, size, kind in icons:
		image = draw_icon_base(size)
		draw = ImageDraw.Draw(image)
		scale = size[0] / 128
		stroke = max(5, int(9 * scale))
		shadow = (35, 45, 58, 70)
		main = (255, 255, 255, 245)
		accent = gold
		def sx(value: float) -> int:
			return int(value * scale)
		def ellipse(box, fill, outline=None, width=1):
			draw.ellipse(tuple(sx(v) for v in box), fill=fill, outline=outline, width=max(1, sx(width)))
		def rounded(box, radius, fill, outline=None, width=1):
			draw.rounded_rectangle(tuple(sx(v) for v in box), radius=sx(radius), fill=fill, outline=outline, width=max(1, sx(width)))
		def line(points, fill=main, width=stroke):
			draw.line([(sx(x), sx(y)) for x, y in points], fill=fill, width=max(1, int(width)), joint="curve")

		if kind == "play":
			draw.polygon([(sx(46), sx(32)), (sx(46), sx(96)), (sx(92), sx(64))], fill=shadow)
			draw.polygon([(sx(42), sx(28)), (sx(42), sx(100)), (sx(96), sx(64))], fill=main)
		elif kind == "profile":
			ellipse((44, 24, 84, 64), main)
			rounded((26, 72, 102, 112), 22, main)
			ellipse((54, 34, 62, 42), turquoise)
			ellipse((70, 34, 78, 42), turquoise)
		elif kind == "options":
			ellipse((37, 37, 91, 91), main)
			ellipse((54, 54, 74, 74), turquoise)
			for angle in range(0, 360, 45):
				x = 64 + math.cos(math.radians(angle)) * 36
				y = 64 + math.sin(math.radians(angle)) * 36
				ellipse((x - 7, y - 7, x + 7, y + 7), main)
		elif kind == "exit":
			rounded((30, 28, 80, 104), 10, None, main, 8)
			line([(70, 64), (104, 64), (90, 48)])
			line([(104, 64), (90, 80)])
		elif kind == "restart":
			draw.arc((sx(30), sx(30), sx(100), sx(100)), 30, 320, fill=main, width=stroke)
			draw.polygon([(sx(92), sx(24)), (sx(110), sx(48)), (sx(80), sx(52))], fill=main)
		elif kind == "menu":
			for y in [38, 64, 90]:
				line([(30, y), (98, y)])
		elif kind == "next":
			line([(36, 34), (78, 64), (36, 94)], main, stroke + 1)
			line([(74, 34), (110, 64), (74, 94)], main, stroke + 1)
		elif kind == "attempts":
			ellipse((18, 18, 78, 78), accent, cream, 5)
			ellipse((36, 36, 60, 60), cream)
			line([(66, 66), (88, 88)], accent, stroke)
		elif kind == "pairs":
			rounded((16, 24, 58, 78), 9, main)
			rounded((42, 42, 84, 96), 9, accent)
			rounded((49, 50, 77, 88), 6, (255, 255, 255, 82))
		else:
			draw_star(draw, (size[0] / 2, size[1] / 2), size[0] * 0.38, size[0] * 0.17, fill=accent, outline=(166, 103, 20, 230), width=max(2, sx(4)))
		save_image(image, ICON_DIR / name, overwrite)


def generate_rewards(system: dict, overwrite: bool) -> None:
	palette = system["palette"]
	gold = hex_to_rgba(palette["soft_gold"])
	gray = hex_to_rgba(palette["neutral_gray"])
	turquoise = hex_to_rgba(palette["primary_turquoise"])
	orange = hex_to_rgba(palette["warm_orange"])

	full = Image.new("RGBA", (256, 256), (0, 0, 0, 0))
	draw = ImageDraw.Draw(full)
	draw_star(draw, (132, 136), 98, 46, fill=(50, 42, 25, 55))
	draw_star(draw, (128, 128), 98, 46, fill=gold, outline=(170, 105, 18, 255), width=6)
	draw_star(draw, (104, 92), 24, 10, fill=(255, 255, 255, 145))
	save_image(full, REWARD_DIR / "reward_star_full.png", overwrite)

	empty = Image.new("RGBA", (256, 256), (0, 0, 0, 0))
	draw = ImageDraw.Draw(empty)
	draw_star(draw, (128, 128), 98, 46, fill=(*gray[:3], 65), outline=(181, 155, 81, 210), width=8)
	draw_star(draw, (128, 128), 72, 34, fill=(255, 255, 255, 40))
	save_image(empty, REWARD_DIR / "reward_star_empty.png", overwrite)

	coin = Image.new("RGBA", (256, 256), (0, 0, 0, 0))
	coin.alpha_composite(radial_glow((256, 256), (*gold[:3], 100), (128, 128), 120))
	draw = ImageDraw.Draw(coin)
	draw.ellipse((38, 30, 218, 226), fill=gold, outline=(166, 103, 20, 255), width=8)
	draw.ellipse((64, 56, 192, 200), outline=(255, 246, 190, 210), width=8)
	draw.arc((78, 64, 178, 190), 205, 335, fill=(255, 255, 255, 135), width=9)
	save_image(coin, REWARD_DIR / "reward_coin.png", overwrite)

	sparkle = Image.new("RGBA", (256, 256), (0, 0, 0, 0))
	sparkle.alpha_composite(radial_glow((256, 256), (*gold[:3], 120), (128, 128), 130))
	draw = ImageDraw.Draw(sparkle)
	draw_star(draw, (128, 128), 84, 17, fill=(255, 246, 140, 245), outline=(255, 190, 40, 190), width=4)
	draw_star(draw, (70, 74), 26, 8, fill=(255, 255, 255, 220))
	draw_star(draw, (190, 70), 20, 7, fill=(255, 255, 255, 190))
	save_image(sparkle, REWARD_DIR / "reward_sparkle.png", overwrite)

	confetti = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
	draw = ImageDraw.Draw(confetti)
	draw.rounded_rectangle((38, 18, 90, 110), radius=12, fill=orange)
	draw.polygon([(44, 24), (90, 40), (78, 110), (34, 92)], fill=turquoise)
	draw.polygon([(52, 34), (84, 46), (76, 86), (46, 78)], fill=gold)
	save_image(confetti, REWARD_DIR / "reward_confetti_piece.png", overwrite)


def parse_args() -> argparse.Namespace:
	parser = argparse.ArgumentParser(description="Generate coherent premium procedural UI PNG assets.")
	parser.add_argument("--all", action="store_true", help="Generate all UI assets.")
	parser.add_argument("--buttons", action="store_true", help="Generate buttons.")
	parser.add_argument("--cards", action="store_true", help="Generate cards.")
	parser.add_argument("--panels", action="store_true", help="Generate panels.")
	parser.add_argument("--icons", action="store_true", help="Generate icons.")
	parser.add_argument("--rewards", action="store_true", help="Generate rewards.")
	parser.add_argument("--premium-style", action="store_true", help="Use design_system.json premium style.")
	parser.add_argument("--overwrite", action="store_true", help="Overwrite existing files.")
	return parser.parse_args()


def main() -> None:
	args = parse_args()
	system = load_design_system()
	ensure_dirs()
	generate_all = args.all or not any([args.buttons, args.cards, args.panels, args.icons, args.rewards])
	print(f"Design system: {system['style_name']} ({system['theme']})")
	if generate_all or args.buttons:
		generate_buttons(system, args.overwrite)
	if generate_all or args.cards:
		generate_cards(system, args.overwrite)
	if generate_all or args.panels:
		generate_panels(system, args.overwrite)
	if generate_all or args.icons:
		generate_icons(system, args.overwrite)
	if generate_all or args.rewards:
		generate_rewards(system, args.overwrite)


if __name__ == "__main__":
	main()
