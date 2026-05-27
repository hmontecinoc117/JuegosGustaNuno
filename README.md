# JuegoInfantilAndroid

Base profesional para un juego infantil casual Android creado con Godot 4.x y GDScript.

## Arquitectura

El proyecto separa responsabilidades por carpeta:

- `scenes/main`: escena de entrada y contenedor principal.
- `scenes/ui`: pantallas de interfaz como menu principal, opciones, seleccion de personajes o recompensas.
- `scenes/game`: escenas jugables, niveles y minijuegos.
- `scenes/characters`: futuras escenas de personajes.
- `scripts/managers`: servicios globales cargados como autoload.
- `scripts/core`: constantes y utilidades compartidas.
- `scripts/ui`: clases base para pantallas.
- `scripts/game`: clases base para modos de juego.
- `assets`: sprites, audio, fuentes y animaciones.
- `resources`: recursos `.tres` o `.res` reutilizables.
- `config`: configuraciones de datos del juego.
- `autoload`: espacio reservado para futuras escenas o recursos usados por autoloads.

## Escenas iniciales

- `Main.tscn`: punto de entrada del proyecto.
- `MainMenu.tscn`: pantalla inicial con botones Jugar, Opciones y Salir.
- `GameScene.tscn`: nivel de prueba con boton para volver al menu.
- `MemoryGame.tscn`: primer minijuego funcional tipo memorice infantil.
- `MemoryCard.tscn`: carta reutilizable para el memorice.

El cambio de escenas se hace desde `SceneManager`, evitando que las pantallas conozcan detalles internos de otras escenas.

## Managers

- `GameManager`: estado global, nivel actual y control de flujo.
- `AudioManager`: musica y efectos de sonido.
- `SceneManager`: navegacion entre escenas.
- `SaveManager`: guardado y carga de datos en `user://save_data.json`.

Todos estan configurados como autoloads en `project.godot`.

## Como abrir el proyecto en Godot

1. Abrir Godot 4.x.
2. Seleccionar `Importar`.
3. Elegir `D:\Proyectos\JuegoInfantilAndroid\project.godot`.
4. Abrir el proyecto.
5. Ejecutar con F5.

## Como usar Visual Studio Code

1. Abrir la carpeta `D:\Proyectos\JuegoInfantilAndroid` en Visual Studio Code.
2. Instalar la extension recomendada `geequlim.godot-tools`.
3. En Godot, abrir `Editor > Editor Settings > Text Editor > External`.
4. Activar `Use External Editor`.
5. Configurar Visual Studio Code como editor externo.

Configuracion sugerida:

```text
Exec Path: ruta a Code.exe
Exec Flags: {project} --goto {file}:{line}:{col}
```

## Como ejecutar en Android

1. Instalar Android Build Template desde Godot si el proyecto lo requiere.
2. Configurar Android SDK, JDK y debug keystore en `Editor Settings > Export > Android`.
3. Conectar un dispositivo Android con depuracion USB activa.
4. Abrir `Project > Export`.
5. Seleccionar el preset `Android`.
6. Exportar APK o ejecutar en el dispositivo.

El proyecto ya queda preparado con orientacion horizontal, escalado adaptable y renderer mobile.

## Como agregar nuevos niveles

1. Crear una escena nueva en `scenes/game`, por ejemplo `Level01.tscn`.
2. Crear su script en `scripts/game`, por ejemplo `Level01.gd`.
3. Agregar la ruta en `AppConstants.gd` o en un futuro archivo de configuracion de niveles.
4. Cambiar de escena usando `SceneManager.change_scene("res://scenes/game/Level01.tscn")`.

## Como agregar nuevos personajes

1. Guardar sprites en `assets/sprites/characters`.
2. Crear una escena de personaje en `scenes/characters`.
3. Crear su script en `scripts/game` o `scripts/characters` si se agrega esa carpeta en el futuro.
4. Usar recursos `.tres` en `resources` para datos como nombre, rareza, velocidad o animaciones.

## Como agregar nuevos sonidos

1. Guardar musica en `assets/audio/music`.
2. Guardar efectos en `assets/audio/sfx`.
3. Precargar o cargar los audios desde `AudioManager`.
4. Usar `AudioManager.play_music(stream)` o `AudioManager.play_sfx(stream)`.

## Fases futuras recomendadas

- Sistema de perfiles infantiles.
- Selector de personajes.
- Sistema de recompensas.
- Mapa de niveles.
- Minijuegos independientes.
- Configuracion de volumen y accesibilidad.
- Guardado de progreso por nivel.

## Minijuego Memorice

El boton Jugar abre `MemoryGame.tscn`. La escena crea una grilla 4x3 con seis pares de animales, cuenta intentos, valida pares, muestra feedback visual y guarda progreso con `SaveManager`.

La carta reutilizable `MemoryCard.tscn` ya tiene espacio para un `TextureRect`, por lo que puede reemplazar los textos placeholder por sprites reales sin cambiar la logica principal.

La fase visual premium agrega:

- Menu principal con mascota leon, logo grande y botones tactiles.
- Tablero de memorice con fondo cartoon, panel lateral de estrellas y contadores grandes.
- Panel de victoria con leon celebrando, estrellas, intentos, mejor resultado y botones de flujo.
- Theme global en `resources/themes/PremiumKidsTheme.tres`.

Audio opcional esperado:

- `assets/audio/sfx/card_flip.ogg`
- `assets/audio/sfx/match_ok.ogg`
- `assets/audio/sfx/match_error.ogg`
- `assets/audio/sfx/victory.ogg`
- `assets/audio/music/memory_theme.ogg`

Si esos archivos aun no existen, `AudioManager` los ignora sin romper la partida.


