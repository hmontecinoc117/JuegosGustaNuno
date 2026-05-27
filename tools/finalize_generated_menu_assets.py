from pathlib import Path
from PIL import Image


PROJECT = Path(r"D:\Proyectos\JuegoInfantilAndroid")
GENERATED_ROOT = Path(r"C:\Users\hecto\.codex\generated_images")

OUTPUTS = [
    PROJECT / "assets/ui/logo/logo_gustanuno_main.png",
    PROJECT / "assets/ui/buttons/button_juegos.png",
    PROJECT / "assets/ui/buttons/button_perfil.png",
    PROJECT / "assets/ui/buttons/button_opciones.png",
]


def remove_flat_key(source: Path, target: Path) -> None:
    image = Image.open(source).convert("RGBA")
    pixels = image.load()
    width, height = image.size

    key_samples = [
        pixels[0, 0],
        pixels[width - 1, 0],
        pixels[0, height - 1],
        pixels[width - 1, height - 1],
    ]
    key = tuple(sum(sample[i] for sample in key_samples) // len(key_samples) for i in range(3))

    for y in range(height):
        for x in range(width):
            r, g, b, a = pixels[x, y]
            delta = abs(r - key[0]) + abs(g - key[1]) + abs(b - key[2])
            if delta <= 42:
                pixels[x, y] = (0, 0, 0, 0)
            elif delta <= 100:
                alpha = int(255 * ((delta - 42) / 58))
                pixels[x, y] = (r, g, b, min(a, alpha))

    target.parent.mkdir(parents=True, exist_ok=True)
    image.save(target)


def main() -> None:
    generated = sorted(GENERATED_ROOT.rglob("*.png"), key=lambda path: path.stat().st_mtime, reverse=True)[:4]
    ordered = list(reversed(generated))
    for source, target in zip(ordered, OUTPUTS):
        remove_flat_key(source, target)
        print(f"{source} -> {target}")


if __name__ == "__main__":
    main()
