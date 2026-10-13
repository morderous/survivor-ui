# Survivor UI and Survivor Plates

Two interface addons for Azeroth Survivors, the Vampire Survivors-style game that runs on [benilla](https://github.com/samwhosung/benilla), a World of Warcraft 1.12.1 client. They are independent: use either one or both.

These are fan-made and not affiliated with the game or its author.

Both are flat and dark, in the manner of EllesmereUI and Plater. They are written from scratch for the 1.12 addon API and share no code with those addons.

## Survivor Plates

Nameplates.

> **Want a plate on every enemy?** Type `/splates all` in chat.
>
> Out of the box only elites, guardians and bosses carry a plate, because a run puts over a hundred enemies on screen. `/splates all` shows them on everything; type it again to go back. The choice is remembered.

- A flat health bar with a thin border, the name above it and the unit's health on it.
- A marker at 30% health, where execute effects start. Below it the bar turns yellow.
- Elites, guardians and bosses get larger plates in their own colors.
- The target's plate shows its debuffs and their stacks.

Commands:

| Command | What it does |
|---|---|
| `/splates all` | Switches between plates on every enemy and plates only on elites, guardians and bosses (the default) |
| `/splates names` | Names on every plate, or only on elites, guardians and bosses |
| `/splates scale 1.3` | Plate size, 0.6 to 2 |

## Survivor UI

Unit frames and the action bar, in one centered row under the hero:

```
[portrait][ player ]  [1][2][3][4][5][6][=]  [ target ][portrait]
```

- Player and target frames: a health bar in the class color (red for an enemy), the name, the health, a slim power bar and a portrait.
- The hero's buffs and debuffs above the player frame, with time left and stacks. Right click a buff to cancel it.
- Action buttons 1 to 6 and the last button of the bar (the `=` key), with cooldown numbers. The rest of the bar and its art are put away.
- The experience bar as a thin strip under the row.
- A square minimap, zoomed with the mouse wheel.
- The micro buttons in the bottom right corner, hidden until the mouse reaches them.
- A flat, dark chat panel without the scroll buttons. The mouse wheel scrolls; Shift with the wheel jumps to the top or the bottom.
- A flat, dark tooltip with smaller type.
- Friz Quadrata on every piece of interface text.
- Quick damage numbers over the enemies, in place of the game's own. `/sui damage` switches between the two.

Left click a frame to target it, right click for its menu. Alt-drag either frame to move the whole row.

## Install

1. Download `SurvivorUI-vX.Y.zip` from the [latest release](https://github.com/morderous/survivor-ui/releases/latest).
2. Unzip it into the game's addon folder, `benilla-config\AddOns\`. You should end up with `AddOns\SurvivorPlates` and `AddOns\SurvivorUI`. Keep only the one you want, or both.
3. Restart the game.

To remove an addon, delete its folder.

## Limits

These come from the 1.12 client and cannot be worked around by an addon:

- Nameplates only exist within 20 yards of the hero.
- Debuffs can only be read from the current target, so only the target's plate shows them.
- A debuff's time left is only known for the hero's own buffs and debuffs.
- The game's own panels (the clock, kills, gold, the damage window) are drawn by the game, not by its addon interface, and cannot be moved from here.

If OmniCC is installed, Survivor UI leaves the cooldown numbers to it.

## Changes

Newest first. The version is also in each addon's `.toc`, so it shows in the game's addon list.

### v1.3, 2026-10-13

**Survivor UI**
- Friz Quadrata on every piece of interface text, chat and numbers included.
- A flat tooltip: dark box, hairline border, smaller type, a slim health bar along the bottom edge.
- Quick damage numbers: small, over the enemy, up and gone in half a second, with critical strikes larger and gold. They replace the game's own; `/sui damage` switches back.
- Slightly smaller text on the unit frames.

**Survivor Plates**
- Shares its list of plates with Survivor UI, which places the damage numbers by it.

### v1.2, 2026-10-13

**Survivor UI**
- The chat is a flat, dark panel: no scroll buttons, no tab art, plain text with a soft shadow. The mouse wheel scrolls; Shift with the wheel jumps to the top or the bottom.
- The micro buttons stay hidden until the mouse reaches the bottom right corner.
- Shamans wear their modern blue. The 1.12 client paints them in the paladin's pink.

### v1.1, 2026-10-12

**Survivor Plates**
- Only elites, guardians and bosses carry a plate. `/splates all` puts one on every enemy.
- The elite list now comes from the game's own tables: three per zone, 27 in all.
- Plates sit where the client puts them again. The addon's own stacking and smoothing made a crowd of plates drift and bounce, so it was removed along with the `stack`, `smooth` and `spread` commands.

**Survivor UI**
- An enemy's unit frame shows its health as a percentage only. The numbers are on its nameplate.

### v1.0, 2026-10-12

First release.

**Survivor Plates**
- Flat health bars with the name above and the unit's health on the bar.
- An execute marker at 30% health.
- Larger plates in their own colors for elites, guardians and bosses.
- Debuffs and their stacks on the target's plate.

**Survivor UI**
- Player and target frames, action buttons 1 to 6 and the `=` button, in one centered row under the hero.
- The hero's buffs and debuffs above the player frame, with time left and stacks.
- Cooldown numbers on the action buttons.
- A square minimap, zoomed with the mouse wheel.
- The experience bar as a thin strip under the row.

## License

MIT. See [LICENSE](LICENSE).
