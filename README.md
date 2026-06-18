<p align="center">
  <img src="docs/brand/banner.svg" alt="BUGOPOLY" width="100%">
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Godot-4.6-478CBF?logo=godotengine&logoColor=white" alt="Godot 4.6">
  <img src="https://img.shields.io/badge/lenguaje-GDScript-14110E" alt="GDScript">
  <img src="https://img.shields.io/badge/estado-en%20desarrollo-F0C419" alt="En desarrollo">
  <img src="https://img.shields.io/badge/assets-CC0-1F7A3D" alt="Assets CC0">
  <img src="https://img.shields.io/badge/marca-propia-B3322F" alt="Marca propia">
</p>

# Bugopoly

Juego de mesa digital en 3D con temática de **QA de software y programación**. NO es Monopoly: es marca propia. Comprás módulos de software, construís **cobertura de tests hacia CI/CD**, cazás bugs, esquivás la deuda técnica y corrés para **shipear el release**.

Hecho con **Godot Engine 4.6**. Jugable en multijugador local (hot-seat con bots) y en modo autoplay.

## Características

- **Tablero 3D** estilo juego de mesa premium, 40 casillas, con fichas-monstruo animadas (**21 para elegir**) y centro oscuro con logo + ciudad de software.
- **Propiedades = módulos de software** por subsistema: al **comprar**, un tractor aplana el lote y queda el cimiento con el color del dueño; al **desarrollar**, crecen edificios (cobertura de tests → CI/CD) con polvo y sube la renta.
- **Deuda Técnica**: se acumula y cobra interés cada turno; se refactoriza/paga en el Coffee Break.
- **Retos QA** reales (severidad vs prioridad, valores límite, TDD, idempotencia…) que otorgan **cartas de habilidad**:
  - **Hotfix** — limpia tu deuda técnica.
  - **Rollback** — recuperás tu último gasto.
  - **Feature Flag** — tu próxima renta es gratis.
- **Cartas Bug / Retro** con cara del Art Kit: salen del mazo y se agrandan hacia la pantalla, con el icono del kit en el centro.
- **Billetes "QA Credits"** texturizados con denominación (10/50/100/500/1000, color por valor) que vuelan hacia la pantalla al cobrar/pagar.
- **Casillas especiales** con iconos del kit (Salida, Bug Report, Reto QA, Deuda Técnica, Bloqueado, On-Call, Coffee Break, Incidente en Prod, Retro); las propiedades muestran icono de subsistema y descripción QA al comprar.
- **Vida en el tablero**: multitud de monstruos bailando + espectadores animados (saludan, pelean) alrededor; cámara con órbita lenta; anillo en la ficha del turno.
- **Pantalla de fin de partida** con stats y logros.
- **Menú**: título con extrude 3D, mini-tablero con monstruos bailando, baraja Bug/Retro y billete QA Credits de marca, música, y secciones de Ayuda y Créditos.
- **Opciones** de audio (música / sonidos / voces por separado) y de gráficos (antialiasing, escala de render, sombras, glow, fullscreen, vsync).
- **App icon propio** (cíclope de marca) y **optimizado para GPU integrada** (renderer Mobile, carga lazy, caché de materiales y texturas).
- **Data-driven y moddeable**: tablero, cartas, retos, fichas y subsistemas viven en JSON bajo `data/` y `mods/`.

## Cómo correr

Necesitás **Godot 4.6**.

```bash
godot --path .
```

Modo autoplay (los bots juegan solos):

```bash
BUGOPOLY_AUTOPLAY=1 godot --path .
```

> En la primera corrida Godot importa los assets. Algunos modelos `.gltf` y sonidos se cargan en runtime, así que pueden tardar un toque al abrir el menú o entrar a la partida.

## Identidad de marca

Sistema de marca completo (logo, app icon, cartas, billetes "QA Credits", tablero, tipografías) en [`docs/brand/BUGOPOLY-Art-Kit.dc.html`](docs/brand/BUGOPOLY-Art-Kit.dc.html).

**Paleta base**

![Rojo](https://img.shields.io/badge/Rojo-B3322F-B3322F)
![Negro](https://img.shields.io/badge/Negro_cálido-14110E-14110E)
![Crema](https://img.shields.io/badge/Crema-E6D9BD-E6D9BD)
![Dorado](https://img.shields.io/badge/Dorado-F0C419-F0C419)

**Colores de subsistema**

![Frontend](https://img.shields.io/badge/Frontend-E08A1E-E08A1E)
![Backend](https://img.shields.io/badge/Backend-1F7A3D-1F7A3D)
![Datos](https://img.shields.io/badge/Datos-2E6FB0-2E6FB0)
![Auth](https://img.shields.io/badge/Auth-7B3AA0-7B3AA0)
![Pagos](https://img.shields.io/badge/Pagos-C0271F-C0271F)
![Infra](https://img.shields.io/badge/Infra-16A0A0-16A0A0)

**Tipografías:** Bungee (display) + Archivo Black (UI).
**Iconografía:** set de 21 line-icons recolorables en `assets/bugopoly/icons/` (bug, search, rocket, wrench, shield, bell, server, database, git-branch, terminal, coins, credit-card, trophy, dice, lock, gear, refresh, coffee, alert, cage, circle-check).

## Estructura

```
data/            contenido data-driven (tablero, cartas, retos, fichas, subsistemas)
mods/            mods de ejemplo (qa_extras)
docs/brand/      Art Kit de marca (Claude Design) + banner
src/
  core/          autoloads: registry, game_state, audio, gfx_settings, event_bus
  presentation/  board_view, decor, dice, camera_rig (render 3D)
  simulation/    player
  ui/            hud, palette (sistema de marca)
  world/         start_screen (menú), main (partida)
assets/bugopoly/ modelos, sonidos, música, texturas, iconos, fuentes
```

## Roadmap

- [x] Título del menú con extrude 3D + app icon de marca.
- [x] Cartas (Bug/Retro/propiedad) y billetes "QA Credits" in-game con el Art Kit.
- [x] Tractor de construcción, multitud de monstruos y espectadores animados.
- [ ] Capturas de pantalla y GIF de gameplay.
- [ ] Más retos QA y cartas.
- [ ] Comercio entre jugadores (ofrecer/intercambiar propiedades).
- [ ] Guardar opciones (audio/gráficos) en disco.

## Créditos / licencias de assets

Todos libres para uso comercial:

- **Monstruos y personajes** — Quaternius (CC0)
- **Edificios y props** — Kenney (CC0)
- **Texturas de madera** — Poly Haven (CC0)
- **Música de menú** — "Chill Main Menu music" vía OpenGameArt (CC0)
- **Sonidos y voces** — Kenney (CC0)
- **Fuentes** — Bungee y Archivo Black (Google Fonts, OFL)
- **Sistema de marca / iconos** — generados con Claude Design
- **Motor** — Godot Engine (MIT)

---

<p align="center"><sub>BUGOPOLY · marca propia — no es Monopoly</sub></p>
