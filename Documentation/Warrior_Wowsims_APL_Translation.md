# Warrior APL Updates - Wowsims ToT BiS Translation

## Overview
Updated both Fury and Arms Warrior SimC priority lists based on Wowsims ToT Preliminary BiS APL exports (JSON format). These rotations are optimized for Throne of Thunder BiS gear with specific trinket interactions.

## Key Wowsims Concepts Translated

### Variables (valueVariables)
Wowsims uses calculated variables that update dynamically. Translated to SimC `variable` actions:

**Fury:**
- `CS: Last HS GCDussy` → `cs_last_used` - tracks time since CS was applied
- `Feather: Last GCDussy` → `feather_stacks` - tracks Jin'ya's Arcane Proxies stacks

**Arms:**
- `CS: Last HS GCDussy` → `cs_last_used` - tracks time since CS was applied  
- `Feather: Last GCDussy` → `feather_stacks` - tracks Jin'ya's Arcane Proxies stacks
- `ending rage` → `ending_rage` - tracks if rage.deficit<25

### Cooldown Windows (Groups)
Wowsims "On UsUwU and BloodbUwU" group = Use cooldowns on fresh CS application
- Translated to: `if=debuff.colossus_smash.up&variable.cs_last_used<1`
- Ensures Recklessness, Avatar, Bloodbath, trinkets, and racials align with CS

### Bladestorm Logic
**Fury (AoE BladestUwU):**
- Use with Feather stacks: `feather_stacks>=3&rage>=20`
- Or on rage cap: `rage>=20&!buff.jinas_arcane_proxies.up`

**Arms:**
- **AoE BladestUwU:** Same as Fury, for 3+ targets
- **ST BladestUwU:** During execute with Bloodbath+Skull Banner active

## Fury Warrior Changes

### Prepull
- Added prepull potion at -1.5s
- Added prepull Bloodthirst at -1.5s  
- Added prepull Colossus Smash at -1s

### Single Target Priority
1. **Variables:** Track cs_last_used and feather_stacks
2. **CS Priority:** Refresh when <1.5s remaining
3. **Cooldown Timing:** All major CDs sync with fresh CS (<1s old)
4. **Enrage Maintenance:** Bloodthirst when missing or <1.5s remaining
5. **CS Window:** Prioritize Bloodthirst, 2-stack Raging Blow, Storm Bolt, Dragon Roar
6. **Proc Management:** Execute (Sudden Death <3s), Wild Strike (Bloodsurge <3s)
7. **Raging Blow:** Use at 2 stacks or during CS
8. **Rage Dumps:** Wild Strike at 70+, Heroic Strike at 90+

### AOE Changes
- Bladestorm gated by Feather stacks (>=3) or rage>=20
- Whirlwind maintains Meat Cleaver buff
- Enrage maintenance via Bloodthirst
- Raging Blow with Meat Cleaver active
- Heroic Strike only with Meat Cleaver for cleave

## Arms Warrior Changes

### Prepull
- Added prepull potion at -1.5s
- Added prepull Mortal Strike at -1s

### Single Target Priority
1. **Variables:** Track cs_last_used, feather_stacks, ending_rage
2. **CS Priority:** Refresh when <1.5s remaining
3. **Cooldown Timing:** Recklessness, Avatar, Bloodbath, Skull Banner sync with fresh CS
4. **Mortal Wounds:** Maintain debuff (refresh if <4s)
5. **CS Window Priority:** Overpower (TfB 3→2 stacks), Storm Bolt, Dragon Roar
6. **Slam Usage:** During CS at 25+ rage, or outside CS at 60+ rage
7. **Overpower Management:** TfB 3 stacks > TfB 2 stacks > filler when rage<70
8. **Rage Dumps:** Heroic Strike at 85+ or during Deadly Calm

### Execute Phase (<20%)
- CS refresh priority
- Cooldowns synced with fresh CS
- Maintain Mortal Wounds (<3s during execute)
- Execute priority: During CS at 30+ rage, Sudden Death proc, rage cap (100+)
- Slam during CS for rage control
- Overpower for TfB stacks or rage<80

### AOE (>=2 targets)
- Sweeping Strikes uptime
- **Bladestorm Logic:**
  - AOE (3+): Feather stacks>=3 or rage>=20
  - ST Execute (<=2): During Bloodbath+Skull Banner
- Thunder Clap for Blood and Thunder (3+ targets, no Deep Wounds)
- CS on <=6 targets
- Cooldowns synced with CS
- Mortal Strike with Sweeping (<=4 targets)
- Cleave and Slam with Sweeping
- Whirlwind on 5+ targets at 30+ rage
- Battle Shout during Bladestorm

## Testing Notes

### Important Buffs to Track
- `buff.jinas_arcane_proxies` - Feather trinket stacks (key for Bladestorm timing)
- `debuff.colossus_smash.applied_at` - For cs_last_used calculation
- `buff.taste_for_blood` - Arms Overpower priority (track stacks)
- `buff.sudden_death` - Execute proc window
- `buff.bloodsurge` - Fury Wild Strike proc window
- `buff.meat_cleaver` - Fury AOE cleave window

### Potential Issues
1. **Jin'ya's Arcane Proxies:** Trinket may not be in game data - Bladestorm conditions may need fallback
2. **Variable Calculations:** `debuff.colossus_smash.applied_at` may not exist - might need alternative tracking
3. **Stance Names:** Verify `berserker_stance` and `battle_stance` are correct identifiers
4. **Prepull Timing:** Negative time conditions (`time<-1.5`) may need adjustment

### Recommended Testing Order
1. Test single target rotation on target dummy
2. Verify CS/cooldown synchronization
3. Test Bladestorm conditions (with and without Feather trinket)
4. Validate Overpower/TfB tracking (Arms)
5. Test execute phase transitions
6. Test AOE rotations on multiple targets

## Backup Files
Old rotations saved as:
- `WarriorFury.simc.backup`
- `WarriorArms.simc.backup`

Restore with: `Copy-Item "WarriorFury.simc.backup" "WarriorFury.simc" -Force`
