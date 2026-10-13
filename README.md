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

Left click a frame to target it, right click for its menu. Alt-drag either frame to move the whole row.

## Install

1. Download this repository (Code, then Download ZIP) and unzip it.
2. Copy the `SurvivorPlates` and `SurvivorUI` folders into the game's addon folder, `benilla-config\AddOns\`.
3. Restart the game.

To remove an addon, delete its folder.

## Limits

These come from the 1.12 client and cannot be worked around by an addon:

- Nameplates only exist within 20 yards of the hero.
- Debuffs can only be read from the current target, so only the target's plate shows them.
- A debuff's time left is only known for the hero's own buffs and debuffs.
- The game's own panels (the clock, kills, gold, the damage window) are drawn by the game, not by its addon interface, and cannot be moved from here.

If OmniCC is installed, Survivor UI leaves the cooldown numbers to it.

## License

MIT. See [LICENSE](LICENSE).
