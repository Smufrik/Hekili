Statuspage for Mop Specs:

💯  = "100%" complete
✅  = should work, needs optimization
⚠️  = work in progress
❌  = no progress

DK: ⁠⁠DeathKnight - Mop Discussion
Blood⚠️
Frost ⚠️
Unholy⚠️


Druid: ⁠⁠Druid - Mop Discussion
Balance⚠️
Feral ✅
Guardian ⚠️

Hunter: ⁠Hunter - Mop Discussion
BM ✅
MM ✅ 
Survival ✅ 

Mage: ⁠Mage - Mop Discussion
Arcane ⚠️
Fire ⚠️
Frost⚠️

Paladin:(⁠Paladin - Mop Discussion
Retribution ✅
Protection ✅ 

Priest: ⁠Priest - Mop Discussion
Shadow ✅ 

Rogue: ⁠Rogue - Mop Discussion
Assassination ⚠️ 
Combat ⚠️
Subtlety ⚠️

Shaman: ⁠Shaman - Mop Discussion
Elemental  ✅
Enhanceme⚠️

Monk: ⁠Monk - Mop Discussion
Windwalker ✅ 
Brewmaster✅ 

Warlock:
⁠Warlock - Mop Discussion
Affliction ✅
Demonology ⚠️
Destruction ⚠️

Warrior: ⁠Warrior - Mop Discussion
Arms⚠️
Fury ❌
Protection ⚠️

## Project-Wide Editing Workflow

- Rotation and priority order are edited in .simc files.
- Core spell behavior and engine logic are implemented in .lua files.
- Exception: spec-specific spell edge cases may require targeted .lua logic.
- State calls needed by APL/rotation conditions must be exposed from Lua (state expressions/functions) so .simc files can reference runtime state without moving rotation logic into Lua.
