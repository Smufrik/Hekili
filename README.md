# Hekili

**Hekili** is a powerful, highly configurable **rotation/priority helper** for **World of Warcraft**. It supports **all DPS and Tank specializations**. Healer specialiazations are supported with a focus on **DPS abilities**, great for solo content or downtime during PvE.

[➡️ Latest Release](https://github.com/Hekili/hekili/releases/latest)

---

## ✨ What Does It Do?

Hekili displays a **sequential queue of icons** showing which abilities to use next — helping you make fast, informed decisions in combat. It supports **1 to 10 icons** at a time (default is 3), each one representing the **next best action**.

The logic behind these decisions comes from **SimulationCraft Action Priority Lists (APLs)**, known to many as the tool [RaidBots](https://www.raidbots.com/simbot). These are translated into addon logic as closely as possible and are **regularly updated** to reflect class balance changes and theorycrafting.

It’s a helpful tool for:

- Increasing your **damage output**
- Learning unfamiliar specializations
- Gaining new insights into specs you already play

---

## 🔧 How Does It Work?

Hekili uses your current character state (cooldowns, resources, buffs/debuffs, enemies nearby, etc.) to **simulate several spells into the future**, assuming you follow its recommendations.

As soon as you press a spell — even one that wasn’t the current recommendation — the addon will **instantly re-evaluate** and show updated suggestions.

This makes Hekili incredibly responsive and helpful for both casual and competitive players.

Other features include:
- Optional Separate Displays for:
  - AoE-specific rotation
  - Cooldowns
  - Defensive abilities
  - Interrupts
    - The addon can recommend interrupts on your primary target, guiding you to interrupt as late into the cast as possible
    - A season mythic+ filter can be enabled to only recommend interrupting important spells
- Toggle controls for cooldowns, defensives, and more:
  - These keybindable and macroable toggles allow you to enable or disable the use of major abilities like **2-minute cooldowns**, giving you direct control over when they are used.
  - This is a powerful feature of the addon: pairing your cooldown usage with encounter knowledge can lead to **significant DPS gains**.
  - Instead of toggling on and off, these abilities can also be shown in a separate, dedicated**Cooldowns display**, letting you manually choose when to cast them.
- Compatible with **ElvUI**, **Bartender**, and other UI mods
- Highly customizable:
  - Enable or disable different displays (Automatic, AOE, Single Target, Dual-Display, Dual-Reactive Display)
  - Change icon layout, spacing, fonts, and sizing
  - Adjust visibility settings by content (PvE, PvP, mounted, etc.)
  - Even the rotation is customizble if you desire, using (mostly) SimulationCraft syntax and expressions

---

## 🚀 Getting Started

### 1. Install the Addon

- Recommended: Use [CurseForge](https://www.curseforge.com/wow/addons/hekili), or [Wago App](https://addons.wago.io/addons/hekili)
- Manual: Download the `.zip` from [Releases](https://github.com/Hekili/hekili/releases/latest) and extract it into your `Interface/AddOns` folder

### 2. Configure In-Game

Use the command:

```
/hekili
```

In the options panel, you can:

- Enable or disable different displays (Primary, AOE, etc.)
- Change icon layout, spacing, fonts, and sizing
- Set hotkeys to toggle cooldowns, defensives, interrupts, etc.
- Adjust visibility settings by content (PvE, PvP, mounted, etc.)

---

## 🛠 Need Help?

### 🐛 Bug Reports

If something isn’t working:

1. Install [BugSack](https://www.curseforge.com/wow/addons/bugsack) and [BugGrabber](https://www.curseforge.com/wow/addons/bug-grabber)
2. Reproduce the issue, generate a [snapshot](https://github.com/Hekili/hekili/wiki/Report-An-Issue#how-do-i-get-a-snapshot), then open BugSack to check for LUA errors
3. Submit a report on the [Issues page](https://github.com/Hekili/hekili/issues/new/choose), be sure to include your newly acquired snapshot and LUA errors (if applicable)

### ❓ Other Support

- Review the [Wiki](https://github.com/Hekili/hekili/wiki)
- Ask questions in the [Hekili Discord](https://discord.gg/3vRJx5g)

---

## 🙏 Credits

- Based on logic from [SimulationCraft](https://www.simulationcraft.org/), which is maintained by many wonderful developers and theorycrafters
- Uses libraries like [Ace3](https://www.wowace.com/projects/ace3), [LibRangeCheck](https://www.wowace.com/projects/librangecheck-2-0), and others
- Maintained by [Hekili](https://github.com/Hekili), [Syrif](https://github.com/syrifgit), [Nerien](https://github.com/johnnylam88) and lots of help from our community contributors

---

## 🧪 Developer Notes

If you're working on class modules or want to contribute:

- See the [Developer Stuff](https://github.com/Hekili/hekili/wiki/Developer-Stuff) page
- Use `/hekili` and the Snapshots tab to inspect live decision-making
- Review existing and past [Pull Requsts](https://github.com/Hekili/hekili/pulls)
- Review existing and past [Issues](https://github.com/Hekili/hekili/issues)

