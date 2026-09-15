# Cubu Dash — project rules

Keep these rules when adding or changing code. All source, comments, UI strings, docs, and commits are **English**.

## Code

- Small functions with one job. Readable flow over clever tricks.
- Comments explain **why**, not the next line.
- Match existing style. Do not refactor unrelated files in the same change.
- Prefer clear names over abbreviations.

## Architecture (constructor + adapter)

Anything that may swap backends (input, save, audio, platform APIs) follows this shape:

1. **Port** — the contract the game needs.
2. **Adapter** — one thin implementation (file, keyboard, gamepad, …).
3. **Factory** — picks and wires the adapter.

Gameplay and UI depend on the port, never on a concrete service scattered around the tree.

```
# yes
SaveFactory.make_default() -> SavePort
InputFactory.make(scheme) -> InputPort

# no
FileAccess.open(...) inside a menu
InputMap.add_event(...) inside the player
```

New backend = new adapter + factory choice. Business rules stay outside adapters.

## Input

- Use `InputActions` names (`left`, `btn_a`, …), not raw keys.
- Schemes are exclusive: keyboard, mix, gamepad, touch. One scheme at a time.
- Rapid left/right on the select ring must feel like holding, not like stuck taps.

## Level select (clock ring)

World → Phase. North is the selected slot.

| Gesture | Behavior |
| --- | --- |
| Short tap | Move exactly 1 / 2 / 3 slots (tap count), with acceleration |
| Hold | Continuous chase; look-ahead ramps 1 → 2 → 3 (0 / 0.8s / 1.8s) |
| Reverse while spinning | Short reverse bounce, then one step the other way |
| Release after hold | Brief coast, then settle |

Settle **always** parks with a bounce: overshoot past the slot, then snap back. Keep the unwrapped angle (no TAU wrap snap).

## Circle transitions

Named animations, **800 ms**, cubic **ease-in** for the travel:

| Name | Meaning |
| --- | --- |
| `zoom_in` | Arrive from far away into selection framing |
| `zoom_out` | Leave the current circle (pull back) |
| `dive_in` | Plunge into the north item |
| `dive_out` | Come from inside the camera out to selection framing |

Flow:

- Menu → World: `zoom_in`
- Confirm World → Phase: `dive_in`, then Phase with `zoom_in`
- Confirm Phase → Game: `dive_in`
- Phase back → World: `zoom_out`, then World with `dive_out`
- World back → Menu: `zoom_out`

### Bounce (dock only)

Bounce is the same idea as spin settle: **advance a little past the rest pose, then return**.

- Bounce **only** when the camera is about to park on the **stationary selection framing**.
- Bounce **never** plays at the start of a transition.
- **Do** bounce at the end of `zoom_in` and `dive_out` (they land on selection).
- **Do not** bounce on `zoom_out` or `dive_in` (they leave selection).

Implementation: finish the travel tween first, then start a **new** tween for the dock bounce. Do not `chain()` bounce tweens onto a `set_parallel(true)` travel tween — Godot will often run them from t=0.

Tune with `transition_bounce_zoom`, `transition_bounce_pixels`, `transition_bounce_duration` on Level Select.

## Run feel

- Player X is locked. The world scrolls; dash speeds that scroll up for a short burst.
- Jump squash/stretch and land squash use a short overshoot, then rest — same bounce language as UI dock.
