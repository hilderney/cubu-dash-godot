# Cubu Dash

Retro auto-runner in **Godot 4.7**. The player stays fixed on X; the world scrolls toward them. Jump and dash are the only run controls.

## Play

Open the project in Godot 4.7+ and run it. The main scene is the title screen.

| Screen | What it does |
| --- | --- |
| Main Menu | Start, Sound, Graphic, Controls, Debugger (dev builds) |
| Level Select | Clock ring: pick a **World**, then a **Phase** |
| Game | Auto-run: A = jump (double), B = dash, Start = pause |
| Controls | Exclusive input scheme: keyboard, keyboard+mouse, gamepad, touch |

Sound, Graphic, and Debugger still open a placeholder screen.

## Controls

Gameplay and UI share the same actions: `left`, `right`, `up`, `down`, `btn_a`, `btn_b`, `btn_start`. Bindings come from the selected input scheme, not from hardcoded keys in gameplay code.

## Layout

```
autoload/   GameManager, InputManager, SaveLoad, EventBus, Audio, stats
input/      InputPort + adapters + factory
save/       SavePort + file adapter + factory
audio/      Placeholder for future AudioPort stack
stages/     Placeholder for future world/phase content
scenes/
  app/      MainMenu, ControlSettings, UnderConstruction
  select/   LevelSelect, CarouselItem
  run/      Game, Player, PauseMenu
  hud/      TouchControls
assets/     Fonts (and future art/audio assets)
```

Project conventions (language, architecture, animation bounce, select-ring feel) live in [RULES.md](RULES.md).
