# Hekili

## [v5.5.1-1.0.0m](https://github.com/Smufrik/Hekili/tree/v5.5.1-1.0.0m) (2025-10-27)
[Full Changelog](https://github.com/Smufrik/Hekili/compare/e227c6d0...v5.5.1-1.0.0m)

- MoP DK (Frost/Blood): Stricter Empower Rune Weapon gating to avoid early usage.
- MoP DK: Live death-rune counting fixes for accurate runes.death.count in APLs.
- MoP Blood APL: Use Rune Strike as RP spender; improved Plague Leech conditions.
- Enhancement Shaman: swing-weave hardcasting improvements.
- Core (MoP tanks): Implemented functional Vengeance tracking for priority conditions (issue #105).
	- Incoming damage now feeds Vengeance runtime state in combat.
	- `vengeance_stacks`, `vengeance_value`, `vengeance_attack_power`, and `high_vengeance` now resolve with live aura/state data.


