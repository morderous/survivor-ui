# Survivor UI and Survivor Plates

[![Latest release](https://img.shields.io/github/v/release/morderous/survivor-ui?label=download&color=2ea44f)](https://github.com/morderous/survivor-ui/releases/latest) [![Support on Ko-fi](https://img.shields.io/badge/Ko--fi-buy%20me%20a%20coffee-FF5E5B?logo=ko-fi&logoColor=white)](https://ko-fi.com/morderous)

Two interface addons for Azeroth Survivors, the Vampire Survivors-style game that runs on [benilla](https://github.com/samwhosung/benilla), a World of Warcraft 1.12.1 client. They are independent: use either one or both.

These are fan-made and not affiliated with the game or its author.

Both are flat and dark, in the manner of EllesmereUI and Plater. They are written from scratch for the 1.12 addon API and share no code with those addons.

## Survivor Plates

Nameplates.

> **Too many plates?** Type `/splates all` in chat to keep them only on elites, guardians and bosses. Type it again to bring them all back.
>
> Out of the box every enemy carries a plate, and only elites, guardians and bosses carry a name on it. `/splates names` puts a name on every plate. Both choices are remembered.

- A flat health bar with a thin border, the name above it and the unit's health on it.
- A marker at 30% health, where execute effects start. Below it the bar turns yellow.
- Elites, guardians and bosses get larger plates in their own colors.
- The target's plate shows its debuffs and their stacks.

Commands:

| Command | What it does |
|---|---|
| `/splates all` | Switches between plates on every enemy (the default) and plates only on elites, guardians and bosses |
| `/splates names` | Switches between names only on elites, guardians and bosses (the default) and names on every plate |
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
- A flat, dark chat panel without the scroll buttons, in 12 point text. The mouse wheel scrolls; Shift with the wheel jumps to the top or the bottom.
- A flat character pane: the hero and the item slots on the left, the run's numbers in titled sections on the right.
- A flat, dark tooltip with smaller type. An ability's tooltip is laid out again.
- Friz Quadrata on every piece of interface text.
- Quick damage numbers over the enemies, and the hits the hero takes in red over the hero, in place of the game's own.
- A run panel above the chat: the run so far (time survived, level, kills, elites, guardians and bosses slain, damage dealt, damage per second, damage taken) and the biggest critical strike of each ability, live.

Left click a frame to target it, right click for its menu. Alt-drag either frame to move the whole row.

Commands:

| Command | What it does |
|---|---|
| `/sui damage` | Switches between the quick damage numbers (the default) and the game's own |
| `/sui chat 12` | Chat text size, 8 to 18 (default 12) |
| `/sui run` | Shows or hides the run panel |
| `/sui run reset` | Clears the biggest crits; the run's numbers stay |

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
- The game does not share its clock or its pauses with addons. The run panel's time is the addon's own count and can drift from the game's; hover it for the rules it follows.

If OmniCC is installed, Survivor UI leaves the cooldown numbers to it.

## Changes

Newest first. The version is also in each addon's `.toc`, so it shows in the game's addon list.

### v1.7, 2026-10-14

**Survivor UI**
- The ability tooltip is laid out again. The name wears the color of its school (Holy, Fire, Frost, Nature, Shadow, Arcane, or physical), as do the rule under the summary and the school's damage in the description. Under the name: how it casts, its cooldown, its reach and its crit, each number in a color of its own. The description's numbers stand out in white. Each upgrade, bonus and talent gets a line of its own, with a thin rule between the sections. A tooltip the addon cannot read is left as the game wrote it.
- The hits the hero takes float over the hero in the same quick style as the damage dealt, in red, in place of the slow floating combat text. Heals and the rest of the floating combat text are unchanged. `/sui damage` switches both back.
- Lair guardians are counted as guardians in the run panel, not as elites. A guardian dies under its elite's name, so the panel watches the guardians' plates and the game's lair announcement to tell them apart.

### v1.6, 2026-10-13

**Survivor UI**
- Reset on the run panel clears only the biggest crits, and sits on that section's title. The run's numbers stay until the next run starts.

### v1.5, 2026-10-13

**Survivor UI**
- A run panel above the chat, in two sections. This Run: time survived, level, kills, elites, guardians and bosses slain, damage dealt, damage per second and damage taken, each in its own color. Biggest Crits: every ability that has crit, in its own color, with its biggest critical strike.
- Hover an ability for its last, average and smallest crit, and its average and last normal hit.
- The time starts at the hero's first step, as the game's does, and pauses when the game does (Escape, the level-up cards). The addon is not told about a pause, so it reads one from 1.5 seconds with no movement and no combat; hover the time for the details.
- Hold Alt and drag a section title to move the panel. Reset clears it; a new run clears it too.
- `/sui run` shows or hides the panel, `/sui run reset` clears it.

### v1.4, 2026-10-13

**Survivor UI**
- A new character pane: one flat dark panel with the hero and the item slots on the left and the run's numbers on the right, in titled sections (Offense, Reach, Defense, Utility, Damage over time, Bonus damage). It replaces the stock stat rows and the separate Run Stats box, and shows the same 29 numbers.
- Item slots are square, with a border in the item's quality color.
- Drag the hero to turn it; the rotate buttons are gone.
- The list sizes itself to fit without scrolling.

### v1.3, 2026-10-13

**Survivor UI**
- Friz Quadrata on every piece of interface text, chat and numbers included.
- A flat tooltip: dark box, hairline border, smaller type, a slim health bar along the bottom edge.
- Quick damage numbers: small, over the enemy, up and gone in half a second. A critical strike lands oversized in gold with a heavy outline, then settles. They replace the game's own; `/sui damage` switches back.
- Chat text is 12 point. `/sui chat N` changes it.
- Slightly smaller text on the unit frames.

**Survivor Plates**
- New defaults: a plate on every enemy, and a name only on elites, guardians and bosses. `/splates all` and `/splates names` change either. Settings saved under the old defaults are reset once.
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

## Support

The addons are free and open source, and will stay that way. If they made your runs nicer and you want to say thanks, you can [buy me a coffee on Ko-fi](https://ko-fi.com/morderous). Bug reports and ideas help just as much: open an [issue](https://github.com/morderous/survivor-ui/issues).

## License

MIT. See [LICENSE](LICENSE).
