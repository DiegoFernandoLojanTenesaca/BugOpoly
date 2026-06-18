# Bugopoly

Juego de mesa digital en 3D con temática de QA de software y programación. NO es Monopoly: comprás módulos de software (Frontend, Backend, Base de Datos, Auth, Pagos, Infra…), construís cobertura de tests hacia CI/CD, cazás bugs y corrés para shipear el release.

Hecho con Godot Engine 4.6. Estado: en desarrollo (jugable en autoplay y multijugador local con bots).

## Características

- Tablero 3D con fichas-monstruo animadas (21 para elegir).
- Mecánica de Deuda Técnica: se acumula y cobra interés cada turno; se refactoriza en el Coffee Break.
- Retos QA reales que dan cartas de habilidad (Hotfix, Rollback, Feature Flag).
- Cobertura hacia CI/CD: las propiedades se desarrollan con edificios que crecen.
- Cartas Bug/Retro con humor dev.
- Pantalla de fin de partida con stats y logros.
- Menú con escena 3D de fondo, música y opciones de audio (música/sonidos/voces) y gráficos (antialiasing, escala de render, sombras).
- Data-driven y moddeable: tablero, cartas, retos, fichas y subsistemas en JSON bajo data/ y mods/.

## Cómo correr

Necesitás Godot 4.6.

```bash
godot --path .
```

Modo autoplay (los bots juegan solos):

```bash
BUGOPOLY_AUTOPLAY=1 godot --path .
```

En la primera corrida Godot importa los assets. Algunos modelos .gltf se cargan en runtime, así que pueden tardar un toque al abrir el menú o entrar a la partida.

## Estructura

```
data/            contenido data-driven (tablero, cartas, retos, fichas, subsistemas)
mods/            mods de ejemplo (qa_extras)
src/
  core/          autoloads: registry, game_state, audio, gfx_settings, event_bus
  presentation/  board_view, decor, dice, camera_rig (render 3D)
  simulation/    player
  ui/            hud, palette (sistema de marca)
  world/         start_screen (menú), main (partida)
assets/bugopoly/ modelos, sonidos, música, texturas, iconos, fuentes
```

## Créditos / licencias de assets

Todos libres para uso comercial:

- Monstruos y personajes — Quaternius (CC0)
- Edificios y props — Kenney (CC0)
- Texturas de madera — Poly Haven (CC0)
- Música de menú — "Chill Main Menu music" vía OpenGameArt (CC0)
- Sonidos y voces — Kenney (CC0)
- Fuentes — Bungee y Archivo Black (Google Fonts, OFL)
- Motor — Godot Engine (MIT)
