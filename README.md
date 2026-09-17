# Graybox Platformer

A minimal but real 3D platformer built with **Godot 4.7.2**, scaffolded as a
starting point in the style of the Knotris / Psychic Blade repos: the game lives
in Git, and GitHub Actions builds it and ships it to the web on every push.

Gray capsules and boxes are the entire art direction. This is a feature, not a bug.

## Play it

- **In the editor / locally:** open the project in Godot 4.7.x and press F5, or
  run headless from the project root:
  ```
  godot --path .
  ```
- **Controls:** `WASD` / arrow keys to move, `Space` to jump.

## The game

- `scenes/main.tscn` — level root: sky, sun, follow camera, UI layer. The level
  geometry itself is built from code in `scripts/game.gd` so the level layout is
  one readable list of platforms.
- `scripts/player.gd` — `CharacterBody3D` with run / jump / gravity, turns to
  face its movement direction.
- `scripts/coin.gd` — spinning `Area3D` collectible; emits `collected`.
- `scripts/goal.gd` — finish flag `Area3D`; emits `reached` once.
- `scripts/follow_camera.gd` — smooth fixed-offset follow camera (no mouse look).
- `scripts/game.gd` — builds the ground + 4 floating platforms, places 6 coins
  and the goal flag, spawns the player, counts coins in the HUD, shows
  "YOU WIN!" at the flag, and respawns the player if they fall below y = -12.

## The pipeline (`.github/workflows/deploy.yml`)

No itch.io, no Discord — just build and publish, per current scope.

1. **build** (ubuntu-latest): checks out the repo, downloads the Godot 4.7.2
   headless binary and the matching export templates, then runs
   `--headless --export-release "Web"` to produce `./exports/web/`.
   The `Web` preset (`export_presets.cfg`) targets `./exports/web/index.html`
   with thread support **off**, so the game runs on any static host with no
   special `Cross-Origin-Opener-Policy` headers needed.
2. **deploy**: uploads `exports/web` with `actions/upload-pages-artifact` and
   deploys it with `actions/deploy-pages` (the official Pages workflow build).

Every push to `main` (or a manual `workflow_dispatch`) redeploys the site.

### Repo settings you still need to click once

In the GitHub repo: **Settings → Pages → Build and deployment → Source →
GitHub Actions.** After that, pushes to `main` go live on their own.

## Credits

- [**Ultimate Platformer Pack**](https://quaternius.itch.io/ultimate-platformer-pack)
  (character, coins, platforms, flag) by [Quaternius](https://quaternius.com)
  — CC0 1.0 Universal

As licensed assets are added, each artist, asset, and license will be
credited here, in the in-game credits menu (Credits button on the title
screen), and on the website.

## Decisions baked in (easy to change)

- **Godot 4.7.2** (latest stable as of 2026-09-16), GL Compatibility renderer —
  required for web exports.
- Single-threaded web build: simpler hosting, slightly less physics throughput.
  Flip `variant/thread_support` in `export_presets.cfg` if you ever need threads
  (then the host must send COOP/COEP headers).
- World-aligned movement + fixed follow camera. Camera-relative controls are the
  usual next upgrade.
- Level is code-built in `game.gd::_build_level()`. If the level grows, move it
  to hand-placed scenes.
- License: not chosen yet — add one before publishing (Psychic Blade used GPLv3,
  Knotris used MIT).
