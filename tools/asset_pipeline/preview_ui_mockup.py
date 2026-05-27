from __future__ import annotations

from pathlib import Path

try:
	from PIL import Image, ImageDraw, ImageFilter, ImageFont
except ImportError as error:
	raise SystemExit("Pillow is required. Install with: python -m pip install pillow") from error


PIPELINE_DIR = Path(__file__).resolve().parent
PROJECT_ROOT = PIPELINE_DIR.parents[1]
PREVIEW_DIR = PIPELINE_DIR / "previews"
PREVIEW_PATH = PREVIEW_DIR / "memory_ui_preview.png"

BACKGROUND_PATH = PROJECT_ROOT / "assets/backgrounds/bg_memory_game_cartoon.png"
BUTTON_DIR = PROJECT_ROOT / "assets/ui/buttons"
CARD_DIR = PROJECT_ROOT / "assets/ui/cards"
ICON_DIR = PROJECT_ROOT / "assets/ui/icons"
PANEL_DIR = PROJECT_ROOT / "assets/ui/panels"
REWARD_DIR = PROJECT_ROOT / "assets/ui/rewards"


def open_rgba(path: Path) -> Image.Image:
	if not path.exists():
		raise FileNotFoundError(f"Missing asset: {path}")
	return Image.open(path).convert("RGBA")


def fit_cover(image: Image.Image, size: tuple[int, int]) -> Image.Image:
	target_w, target_h = size
	scale = max(target_w / image.width, target_h / image.height)
	new_size = (int(image.width * scale), int(image.height * scale))
	resized = image.resize(new_size, Image.Resampling.LANCZOS)
	left = (resized.width - target_w) // 2
	top = (resized.height - target_h) // 2
	return resized.crop((left, top, left + target_w, top + target_h))


def fit_contain(image: Image.Image, size: tuple[int, int]) -> Image.Image:
	image = image.copy()
	image.thumbnail(size, Image.Resampling.LANCZOS)
	canvas = Image.new("RGBA", size, (0, 0, 0, 0))
	canvas.alpha_composite(image, ((size[0] - image.width) // 2, (size[1] - image.height) // 2))
	return canvas


def paste_asset(base: Image.Image, path: Path, box: tuple[int, int, int, int], cover: bool = False, stretch: bool = False) -> None:
	asset = open_rgba(path)
	size = (box[2] - box[0], box[3] - box[1])
	if stretch:
		asset = asset.resize(size, Image.Resampling.LANCZOS)
	else:
		asset = fit_cover(asset, size) if cover else fit_contain(asset, size)
	base.alpha_composite(asset, (box[0], box[1]))


def get_font(size: int, bold: bool = False) -> ImageFont.ImageFont:
	candidates = [
		"C:/Windows/Fonts/arialbd.ttf" if bold else "C:/Windows/Fonts/arial.ttf",
		"C:/Windows/Fonts/segoeuib.ttf" if bold else "C:/Windows/Fonts/segoeui.ttf",
	]
	for candidate in candidates:
		path = Path(candidate)
		if path.exists():
			return ImageFont.truetype(str(path), size)
	return ImageFont.load_default()


def draw_center_text(draw: ImageDraw.ImageDraw, text: str, box: tuple[int, int, int, int], font: ImageFont.ImageFont, fill) -> None:
	bounds = draw.textbbox((0, 0), text, font=font)
	width = bounds[2] - bounds[0]
	height = bounds[3] - bounds[1]
	x = box[0] + (box[2] - box[0] - width) // 2
	y = box[1] + (box[3] - box[1] - height) // 2
	draw.text((x, y), text, font=font, fill=fill)


def draw_center_text_shadow(draw: ImageDraw.ImageDraw, text: str, box: tuple[int, int, int, int], font: ImageFont.ImageFont, fill) -> None:
	bounds = draw.textbbox((0, 0), text, font=font)
	width = bounds[2] - bounds[0]
	height = bounds[3] - bounds[1]
	x = box[0] + (box[2] - box[0] - width) // 2
	y = box[1] + (box[3] - box[1] - height) // 2
	draw.text((x + 1, y + 2), text, font=font, fill=(35, 48, 68, 70))
	draw.text((x, y), text, font=font, fill=fill)


def draw_soft_rect_shadow(base: Image.Image, box: tuple[int, int, int, int], radius: int, blur: int, offset_y: int, alpha: int) -> None:
	mask = Image.new("L", base.size, 0)
	draw = ImageDraw.Draw(mask)
	x1, y1, x2, y2 = box
	draw.rounded_rectangle((x1, y1 + offset_y, x2, y2 + offset_y), radius=radius, fill=alpha)
	mask = mask.filter(ImageFilter.GaussianBlur(blur))
	shadow = Image.new("RGBA", base.size, (28, 42, 55, alpha))
	base.alpha_composite(Image.composite(shadow, Image.new("RGBA", base.size, (0, 0, 0, 0)), mask))


def draw_button(base: Image.Image, draw: ImageDraw.ImageDraw, box: tuple[int, int, int, int], icon_name: str, text: str) -> None:
	paste_asset(base, BUTTON_DIR / "button_small_orange.png", box, stretch=True)
	icon_box = (box[0] + 18, box[1] + 12, box[0] + 60, box[1] + 54)
	paste_asset(base, ICON_DIR / icon_name, icon_box)
	font = get_font(21, bold=True)
	draw_center_text(draw, text, (box[0] + 52, box[1] + 2, box[2] - 12, box[3] - 4), font, (255, 255, 255, 255))


def draw_stat(base: Image.Image, draw: ImageDraw.ImageDraw, box: tuple[int, int, int, int], icon_name: str, text: str) -> None:
	paste_asset(base, PANEL_DIR / "panel_stats.png", box, stretch=True)
	paste_asset(base, ICON_DIR / icon_name, (box[0] + 22, box[1] + 17, box[0] + 64, box[1] + 59))
	font = get_font(23, bold=True)
	draw.text((box[0] + 74, box[1] + 22), text, font=font, fill=(30, 45, 66, 255))


def draw_card_grid(base: Image.Image) -> None:
	card_back = CARD_DIR / "card_back_default.png"
	card_front = CARD_DIR / "card_front_default.png"
	shadow = CARD_DIR / "card_shadow.png"
	animal_paths = [
		PROJECT_ROOT / "assets/sprites/animals/animal_dog.png",
		PROJECT_ROOT / "assets/sprites/animals/animal_cat.png",
		PROJECT_ROOT / "assets/sprites/animals/animal_duck.png",
		PROJECT_ROOT / "assets/sprites/animals/animal_bear.png",
	]
	start_x = 118
	start_y = 174
	cell_w = 178
	cell_h = 136
	card_w = 142
	card_h = 124
	for row in range(3):
		for col in range(4):
			x = start_x + col * cell_w
			y = start_y + row * cell_h
			draw_soft_rect_shadow(base, (x + 8, y + 8, x + card_w - 8, y + card_h - 8), 20, 9, 11, 44)
			paste_asset(base, shadow, (x + 0, y + 100, x + card_w, y + 134), stretch=True)
			if row == 0 and col < 2:
				paste_asset(base, card_front, (x, y, x + card_w, y + card_h), stretch=True)
				if col < len(animal_paths) and animal_paths[col].exists():
					paste_asset(base, animal_paths[col], (x + 26, y + 24, x + card_w - 26, y + card_h - 18))
			else:
				paste_asset(base, card_back, (x, y, x + card_w, y + card_h), stretch=True)


def build_preview() -> None:
	canvas_size = (1280, 720)
	if BACKGROUND_PATH.exists():
		canvas = fit_cover(open_rgba(BACKGROUND_PATH), canvas_size)
	else:
		canvas = Image.new("RGBA", canvas_size, (105, 184, 255, 255))
	draw = ImageDraw.Draw(canvas)

	veil = Image.new("RGBA", canvas_size, (255, 243, 216, 28))
	canvas.alpha_composite(veil)

	draw_soft_rect_shadow(canvas, (58, 134, 888, 632), 48, 24, 16, 56)
	paste_asset(canvas, PANEL_DIR / "panel_board.png", (58, 134, 888, 632), stretch=True)
	draw.rounded_rectangle((98, 174, 848, 592), radius=34, fill=(255, 250, 232, 34), outline=(255, 255, 255, 60), width=2)
	draw_card_grid(canvas)

	for stat_box in [(924, 138, 1196, 222), (924, 244, 1196, 328), (924, 350, 1196, 434)]:
		draw_soft_rect_shadow(canvas, stat_box, 28, 12, 8, 38)
	draw_stat(canvas, draw, (924, 138, 1196, 222), "icon_attempts.png", "Intentos: 2")
	draw_stat(canvas, draw, (924, 244, 1196, 328), "icon_pairs.png", "Pares: 1/6")
	draw_stat(canvas, draw, (924, 350, 1196, 434), "icon_best_score.png", "Mejor: 9")

	draw_soft_rect_shadow(canvas, (946, 472, 1198, 662), 34, 14, 9, 38)
	paste_asset(canvas, PANEL_DIR / "panel_stars.png", (946, 472, 1198, 662), stretch=True)
	font_title = get_font(25, bold=True)
	draw_center_text_shadow(draw, "Estrellas", (968, 490, 1176, 526), font_title, (255, 255, 255, 255))
	for index in range(3):
		paste_asset(canvas, REWARD_DIR / "reward_star_full.png", (1002 + index * 58, 536, 1056 + index * 58, 590))
	font_small = get_font(18, bold=True)
	draw_center_text(draw, "Encuentra pares", (968, 612, 1176, 640), font_small, (36, 55, 82, 255))

	draw_soft_rect_shadow(canvas, (330, 22, 950, 78), 26, 10, 5, 28)
	paste_asset(canvas, PANEL_DIR / "panel_message.png", (330, 22, 950, 78), stretch=True)
	font_header = get_font(31, bold=True)
	draw_center_text_shadow(draw, "Memorice Infantil", (410, 26, 870, 76), font_header, (36, 55, 82, 255))
	draw_button(canvas, draw, (56, 24, 202, 78), "icon_menu.png", "Menu")
	draw_button(canvas, draw, (1046, 24, 1238, 78), "icon_restart.png", "Reiniciar")

	PREVIEW_DIR.mkdir(parents=True, exist_ok=True)
	canvas.convert("RGB").save(PREVIEW_PATH)
	print(f"WRITE: {PREVIEW_PATH}")


if __name__ == "__main__":
	build_preview()
