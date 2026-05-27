# Asset Pipeline Automatic1111

Pipeline local para generar assets PNG del proyecto `JuegoInfantilAndroid` usando Stable Diffusion Automatic1111.

## Requisitos

- Windows.
- Python 3.10 o superior.
- Stable Diffusion Automatic1111 instalado localmente.
- API de Automatic1111 activa en `http://127.0.0.1:7860`.
- Pillow solo para placeholders:

```powershell
python -m pip install pillow
```

## Activar API de Automatic1111

Iniciar Automatic1111 con API habilitada:

```powershell
webui-user.bat --api
```

Si usas argumentos en `webui-user.bat`, agrega `--api` en `COMMANDLINE_ARGS`.

Endpoint usado por defecto:

```text
http://127.0.0.1:7860/sdapi/v1/txt2img
```

## Archivos del pipeline

- `asset_manifest.json`: lista de assets, resoluciones, carpetas, prompts y parametros.
- `style_bible.md`: direccion artistica global.
- `design_system.json`: sistema visual premium centralizado para UI procedural.
- `generate_prompts.py`: genera `prompts_generated.md`.
- `sd_batch_generate.py`: genera PNG reales usando Automatic1111.
- `generate_ui_assets.py`: genera UI procedural con Pillow sin Stable Diffusion.
- `preview_ui_mockup.py`: genera un mockup PNG para aprobar la UI antes de tocar escenas.
- `create_placeholders.py`: crea PNG placeholder para assets faltantes.
- `validate_assets.py`: valida existencia, extension y resolucion.

## UI procedural con Pillow

Usa `generate_ui_assets.py` para generar botones, cartas base, paneles, iconos y recompensas sin depender de Stable Diffusion. La version premium lee `design_system.json` para mantener una sola direccion visual: formas redondeadas, sombras suaves, gloss, paleta forestal y acentos dorados.

Instalar Pillow si hace falta:

```powershell
python -m pip install pillow
```

Generar toda la UI procedural premium:

```powershell
python generate_ui_assets.py --all --premium-style --overwrite
```

Generar por grupo:

```powershell
python generate_ui_assets.py --buttons --overwrite
python generate_ui_assets.py --cards --overwrite
python generate_ui_assets.py --panels --overwrite
python generate_ui_assets.py --icons --overwrite
python generate_ui_assets.py --rewards --overwrite
```

Generar preview visual del memorice:

```powershell
python preview_ui_mockup.py
```

Salida:

```text
tools/asset_pipeline/previews/memory_ui_preview.png
```

Carpetas generadas:

```text
assets/ui/buttons
assets/ui/icons
assets/ui/cards
assets/ui/panels
assets/ui/rewards
```

Flujo recomendado:

- Stable Diffusion: personajes, animales y fondos.
- `generate_ui_assets.py --all --premium-style --overwrite`: botones, cartas base, paneles, iconos y recompensas UI.
- `preview_ui_mockup.py`: aprobacion visual antes de integrar en escenas Godot.

## Generar prompts

Desde la raiz del proyecto:

```powershell
cd D:\Proyectos\JuegoInfantilAndroid\tools\asset_pipeline
python generate_prompts.py
```

Salida:

```text
tools/asset_pipeline/prompts_generated.md
```

## Crear placeholders

Crear placeholders para todos los assets faltantes:

```powershell
python create_placeholders.py --all
```

Crear placeholders solo para animales:

```powershell
python create_placeholders.py --category animals
```

Sobrescribir placeholders existentes:

```powershell
python create_placeholders.py --all --overwrite
```

## Generar una categoria con Stable Diffusion

Revisar la API con `/sdapi/v1/sd-models` y detectar el endpoint `txt2img`:

```powershell
python sd_batch_generate.py --check-api
```

Dry run sin llamar a Automatic1111:

```powershell
python sd_batch_generate.py --category animals --dry-run
```

Generar animales:

```powershell
python sd_batch_generate.py --category animals
```

Generar cartas:

```powershell
python sd_batch_generate.py --category cards
```

Generar todo:

```powershell
python sd_batch_generate.py --all
```

Sobrescribir PNG existentes:

```powershell
python sd_batch_generate.py --category animals --overwrite
```

Usar otro endpoint:

```powershell
python sd_batch_generate.py --category animals --api-url http://127.0.0.1:7860/sdapi/v1/txt2img
```

## Validar assets

Validar todo:

```powershell
python validate_assets.py --all
```

Validar una categoria:

```powershell
python validate_assets.py --category backgrounds
```

La validacion revisa:

- Archivo existente.
- Extension `.png`.
- Resolucion exacta segun manifest.
- Firma PNG valida.

## Integracion en Godot

1. Generar placeholders o assets finales.
2. Abrir el proyecto en Godot.
3. Esperar que Godot importe los PNG.
4. Usar los archivos desde:

```text
res://assets/sprites/characters
res://assets/sprites/animals
res://assets/ui/buttons
res://assets/ui/icons
res://assets/ui/cards
res://assets/ui/panels
res://assets/ui/rewards
res://assets/backgrounds
```

## Categorias disponibles

- `characters`
- `animals`
- `cards`
- `buttons`
- `icons`
- `backgrounds`
- `panels`
- `rewards`

## Recomendacion de flujo

```powershell
python generate_prompts.py
python create_placeholders.py --all
python validate_assets.py --all
python sd_batch_generate.py --category animals
python validate_assets.py --category animals
```

Este flujo permite que Godot no falle mientras los assets finales se generan por categoria.

## Prueba visual controlada SD 1.5

Antes de generar todos los assets masivamente, usa una prueba visual pequena con el modelo `v1-5-pruned-emaonly`.

1. En Automatic1111, seleccionar el checkpoint:

```text
v1-5-pruned-emaonly
```

2. Confirmar API:

```powershell
python sd_batch_generate.py --check-api
```

3. Generar la categoria de prueba:

```powershell
python sd_batch_generate.py --category visual_test --overwrite
```

4. Revisar resultados en:

```text
assets/test/visual_test
```

5. Ajustar `style_bible.md` o los prompts del manifest si hace falta.

6. Generar categorias reales:

```powershell
python sd_batch_generate.py --category characters --overwrite
python sd_batch_generate.py --category animals --overwrite
python sd_batch_generate.py --category cards --overwrite
python sd_batch_generate.py --category buttons --overwrite
python sd_batch_generate.py --category icons --overwrite
python sd_batch_generate.py --category panels --overwrite
python sd_batch_generate.py --category rewards --overwrite
python sd_batch_generate.py --category backgrounds --overwrite
```
