# Contributing Guidelines

## Rotation vs Spell Logic

- Edit rotations and action priority lists in `.simc` files.
- Implement core spell behavior and engine/state logic in `.lua` files.
- Keep rotation decisions in `.simc` whenever possible.
- Use `.lua` for spec-specific spell edge logic only when required.

## State Calls for APL

- If a rotation condition needs runtime game state, expose it from Lua as a state expression or state function.
- Reference those exposed state calls from `.simc` conditions.
- Do not move full rotation logic into Lua just to support one APL condition.
