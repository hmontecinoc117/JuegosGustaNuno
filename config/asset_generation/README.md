# Stable Diffusion Asset Generation

Sistema configurable para generar assets visuales de GustaNuno Gaming con Automatic1111 WebUI API.

## Requisitos

- Stable Diffusion Automatic1111 instalado localmente.
- WebUI iniciado con API:

```powershell
webui-user.bat --api
```

Endpoint esperado:

```text
http://127.0.0.1:7860/sdapi/v1/txt2img
```

## Archivos

- `sd_generation_config.json`: configuracion global de API y parametros por defecto.
- `sd_prompt_templates.json`: templates reutilizables por tipo de asset.
- `sd_jobs_minigames.json`: lista de jobs editables para fondos, iconos, botones y paneles.
- `tools/generate_assets_sdapi.py`: runner generico. No contiene prompts hardcodeados.

## Ejecutar todos los jobs

Desde la raiz del proyecto:

```powershell
python tools/generate_assets_sdapi.py --jobs config/asset_generation/sd_jobs_minigames.json
```

## Ejecutar solo un job

```powershell
python tools/generate_assets_sdapi.py --jobs config/asset_generation/sd_jobs_minigames.json --only bg_minigames_menu_pirate_port
```

## Ejecutar solo un tipo de asset

```powershell
python tools/generate_assets_sdapi.py --jobs config/asset_generation/sd_jobs_minigames.json --type background
```

Tipos iniciales:

- `background`
- `icon`
- `button`
- `panel`

## Dry run

Imprime payloads sin llamar a Stable Diffusion:

```powershell
python tools/generate_assets_sdapi.py --jobs config/asset_generation/sd_jobs_minigames.json --dry-run
```

Dry run de un solo job:

```powershell
python tools/generate_assets_sdapi.py --jobs config/asset_generation/sd_jobs_minigames.json --only icon_minigame_memory --dry-run
```

## Metadata

Por cada imagen generada se crea un JSON en:

```text
assets/generated/metadata
```

La metadata incluye:

- fecha de generacion
- job id
- asset type
- template usado
- ruta de salida
- prompt positivo final
- prompt negativo final
- payload enviado
- `info` devuelto por Automatic1111

## Agregar un nuevo fondo

1. Abrir `sd_jobs_minigames.json`.
2. Duplicar un job de `asset_type: "background"`.
3. Cambiar:
   - `id`
   - `output_path`
   - `file_name`
   - `title`
   - `description`
   - `positive_detail`
   - `negative_extra`
   - `tags`
4. Mantener:
   - `template: "background_pirate_kids"`
   - resolucion recomendada `1920x1080`
5. Ejecutar:

```powershell
python tools/generate_assets_sdapi.py --jobs config/asset_generation/sd_jobs_minigames.json --only nuevo_job_id
```

## Agregar un nuevo icono

1. Duplicar un job de `asset_type: "icon"`.
2. Usar:
   - `template: "icon_pirate_kids"`
   - `output_path: "assets/ui/icons/minigames"`
   - `width: 512`
   - `height: 512`
3. Ajustar `positive_detail` para describir el objeto principal.

## Agregar assets para un nuevo minijuego

Ejemplo: minijuego `Trazado`.

### Crear icono

```json
{
  "id": "icon_minigame_tracing",
  "enabled": true,
  "asset_type": "icon",
  "template": "icon_pirate_kids",
  "output_path": "assets/ui/icons/minigames",
  "file_name": "icon_minigame_tracing.png",
  "title": "Icono Trazado",
  "description": "Icono para minijuego Trazado.",
  "positive_detail": "tracing game icon, dotted line path, cute pencil, pirate map shape, cheerful kids mobile game style",
  "negative_extra": "",
  "width": 512,
  "height": 512,
  "steps": 28,
  "cfg_scale": 7,
  "sampler_name": "DPM++ 2M Karras",
  "seed": -1,
  "batch_size": 1,
  "n_iter": 1,
  "tags": ["icon", "minigames", "tracing"]
}
```

### Crear fondo

```json
{
  "id": "bg_tracing_game_pirate_school",
  "enabled": true,
  "asset_type": "background",
  "template": "background_pirate_kids",
  "output_path": "assets/backgrounds/tracing_game",
  "file_name": "bg_tracing_game_pirate_school.png",
  "title": "Fondo Trazado",
  "description": "Fondo para minijuego Trazado.",
  "positive_detail": "friendly pirate school desk on a tropical beach, clean center area for gameplay, pencils and scrolls on the sides, bright cheerful lighting",
  "negative_extra": "",
  "width": 1920,
  "height": 1080,
  "steps": 30,
  "cfg_scale": 7,
  "sampler_name": "DPM++ 2M Karras",
  "seed": -1,
  "batch_size": 1,
  "n_iter": 1,
  "tags": ["background", "tracing", "pirate"]
}
```

Ejecutar:

```powershell
python tools/generate_assets_sdapi.py --jobs config/asset_generation/sd_jobs_minigames.json --only icon_minigame_tracing
```

## Recomendaciones de resolucion

- Fondos Android landscape: `1920x1080`.
- Fondos livianos o pruebas: `1536x864`.
- Iconos y thumbnails: `512x512`.
- Flechas y puntos: `256x256` o `512x512`.
- Paneles de tarjeta: `768x512`.

## Si falta VRAM

- Reducir fondos a `1536x864`.
- Reducir `steps` a `20` o `24`.
- Mantener `batch_size: 1`.
- Mantener `n_iter: 1`.
- Generar un job a la vez con `--only`.
- Cerrar Godot, navegador u otras apps pesadas mientras genera.

## Flujo recomendado

1. Crear o editar jobs JSON.
2. Revisar payload con `--dry-run`.
3. Generar un solo asset con `--only`.
4. Revisar PNG y metadata.
5. Ajustar `positive_detail` o `negative_extra`.
6. Generar el grupo completo con `--type`.
