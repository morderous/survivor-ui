# Survivor UI and Survivor Plates

[![Latest release](https://img.shields.io/github/v/release/morderous/survivor-ui?label=download&color=2ea44f)](https://github.com/morderous/survivor-ui/releases/latest) [![Support on Ko-fi](https://img.shields.io/badge/Ko--fi-buy%20me%20a%20coffee-FF5E5B?logo=ko-fi&logoColor=white)](https://ko-fi.com/morderous)

Two interface addons for Azeroth Survivors, the Vampire Survivors-style game that runs on [benilla](https://github.com/samwhosung/benilla), a World of Warcraft 1.12.1 client. They are independent: use either one or both.

These are fan-made and not affiliated with the game or its author.

Both are flat and dark, in the manner of EllesmereUI and Plater. They are written from scratch for the 1.12 addon API and share no code with those addons.

## Commands at a glance

**Hold Alt** to see everything that can be moved, outlined with its name, and drag it. Every piece keeps its place.

| Command | What it does |
|---|---|
| `/sui` | Lists every command in the chat |
| `/sui layout` | Puts every piece back in its first place |
| `/sui hover` | The white outline around what the mouse is on: on or off |
| `/sui loot` | Loot list: on or off |
| `/sui build` | Build list: on or off |
| `/sui crits` | Biggest Crits box: on or off (off by default) |
| `/sui scale 0.85` | Size of the panels (tracker, run panel, meter, boss bars), 0.6 to 1.4. For smaller screens |
| `/sui center` | Puts the middle block (frames and buttons) back under the hero |
| `/sui tracker` | Run tracker under the minimap: on or off |
| `/sui run` | Run panel: on or off |
| `/sui run reset` | Clears the crits |
| `/sui meter` | The addon's damage meter, or the game's own (for healing and boss damage) |
| `/sui bosses` | Boss bars: on or off |
| `/sui bosses elites` | Adds every elite to the boss bars |
| `/sui tally` | Kills and gold line under the bar, or the game's own box |
| `/sui damage` | Quick damage numbers, or the game's own |
| `/sui chat 12` | Chat text size, 8 to 18 |
| `/splates all` | Plates on every enemy, or only on elites, guardians and bosses |
| `/splates names` | Names only on elites, guardians and bosses, or on every plate |
| `/splates scale 1.3` | Plate size, 0.6 to 2 |

## Survivor Plates

Nameplates.

> **Too many plates?** Type `/splates all` in chat to keep them only on elites, guardians and bosses. Type it again to bring them all back.
>
> Out of the box every enemy carries a plate, and only elites, guardians and bosses carry a name on it. `/splates names` puts a name on every plate. Both choices are remembered.

- A flat health bar with a thin border, the name above it and the unit's health on it.
- A marker at 30% health, where execute effects start. Below it the bar turns yellow.
- Elites and bosses get larger plates in their own colors. A lair guardian wears its elite's plate, except as your target: then it turns blue.
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
- Friz Quadrata on every piece of interface text, chat and nameplates included, or a face of your own (see Font below).
- Quick damage numbers over the enemies, and the hits the hero takes in red, falling over the hero, in place of the game's own.
- A run tracker under the minimap, in the manner of a Mythic+ timer: the zone, the lives left, the time gone against the zone's full length (the time gone alone in endless mode), a timeline with a tick for every boss, every boss with the second it comes, colored by where it stands (grey to come, white next, orange alive, green slain), and the level's progress. It stands in for the game's own clock.
- A run panel on the left, under the loot list: the run so far, the same numbers as the game's victory screen (time survived, level, kills, elites, guardians and bosses slain, damage dealt and taken, damage per second, gold earned, caches opened). Hover a row for more: the damage meter, damage taken by source, gold and rerolls.
- A damage meter under the build list, in place of the game's own, as many lines as fit the screen: one bar per source of damage, with its damage and its share. Hover a line for its card: damage per second, and its critical strikes (biggest, last, average, smallest) and normal hits.
- Boss bars at the top of the screen: every boss alive and every awake lair guardian, with its health, at any distance. Click one to target it.
- Kills, gold and the next cache's price on a line under the experience bar, in place of the game's own box.
- A build list in the right column, between the run tracker and the damage meter: every spell slot with the spell's icon, rank and share of the damage, from the highest rank down, each filled with its damage meter color; the free slots; and the gear, each piece of jewelry with what it gives (or what all the gear adds, with its sources on hover).
- A loot list in the top left corner: what the run has dropped, as bars in the item's quality color, with the second it came.
- A Biggest Crits box, off by default (`/sui crits`): every ability's biggest critical strike.
- A thin white outline around whatever the mouse is on: a button, a bar, a buff. The nameplates, the chat, the minimap and the run tracker go without.

Left click a frame to target it, right click for its menu. Hold Alt to outline the whole middle block (frames, buttons, experience bar, kills and gold, buffs) and drag it anywhere; the place is kept. `/sui center` puts it back.

Commands:

| Command | What it does |
|---|---|
| `/sui damage` | Switches between the quick damage numbers (the default) and the game's own |
| `/sui chat 12` | Chat text size, 8 to 18 (default 12) |
| `/sui run` | Shows or hides the run panel |
| `/sui tracker` | Shows or hides the run tracker under the minimap |
| `/sui meter` | Switches between the addon's damage meter (the default) and the game's own |
| `/sui center` | Puts the middle block back under the hero |
| `/sui layout` | Puts every piece back in its first place |
| `/sui hover` | The white outline around what the mouse is on: on or off |
| `/sui loot` | Loot list: on or off |
| `/sui build` | Build list: on or off |
| `/sui crits` | Biggest Crits box: on or off (off by default) |
| `/sui scale 0.85` | Size of the panels (tracker, run panel, meter, boss bars), 0.6 to 1.4. For smaller screens |
| `/sui run reset` | Clears the crits in the damage meter's cards; the run's numbers stay |
| `/sui bosses` | Switches the boss bars on (the default) or off |
| `/sui bosses elites` | Lists every elite in the boss bars too |
| `/sui tally` | Switches between the kills and gold line (the default) and the game's own box |

### Healing and boss damage

The addon's damage meter shows the run's damage by source, the same numbers as the game's meter, with each ability's crits on mouseover. The game's own meter also has views for **healing** and **damage to bosses**, which the game does not share with addons yet.

To see them, type `/sui meter`: the addon's meter steps aside and the game's comes back, with its buttons. Type `/sui meter` again to return. Hovering the meter's title says the same.

### Font

The interface uses the game's own **Friz Quadrata**. Prefer **Expressway**, the face of many retail UIs? It cannot be shipped with the addon, but if you have it (it comes with EllesmereUI and ElvUI, for one), copy it as `SurvivorUI\Fonts\Expressway.ttf` and restart the game: the addon picks it up on its own.

### The game's addon API

Azeroth Survivors shares its run with addons: its clock, phase, kills, bosses, guardians, damage meter and more. Survivor UI reads them where the game offers them, and falls back to its own count on a version of the game that does not.

The run tracker, the damage meter, the boss bars and the kills and gold line put the game's own clock, meter, boss bars and box away while they are on. That is a game setting, saved by the game: `/sui tracker`, `/sui meter`, `/sui bosses` and `/sui tally` bring them back, and so do the "Show ..." checkboxes in the game's Options, Interface. Do that before removing the addon, or the game's own will stay hidden.

## Install

### With the installer (easiest)

1. Download `SurvivorUI-Installer.zip` from the [latest release](https://github.com/morderous/survivor-ui/releases/latest) and unzip it.
2. Open `SurvivorInstaller.exe`. Windows may say it protected your PC, since the program is new and not signed: click **More info**, then **Run anyway**.
3. Click **Find game...** and pick `AzerothSurvivors.exe` (or put the installer in the game's folder and it finds it by itself).
4. Click **Install / Update**, and restart the game if it was open.

Open it again any time to update: it always offers the latest release, with its notes. It only touches the `SurvivorUI` and `SurvivorPlates` folders in the game's `AddOns` folder. Its source is in [`installer/`](installer), built with the C# compiler that comes with Windows (`installer\build.bat`).

### By hand

1. Download `SurvivorUI-vX.Y.zip` from the [latest release](https://github.com/morderous/survivor-ui/releases/latest).
2. Unzip it into the game's addon folder, `benilla-config\AddOns\`. You should end up with `AddOns\SurvivorPlates` and `AddOns\SurvivorUI`. Keep only the one you want, or both.
3. Restart the game.

To remove an addon, delete its folder.

## Limits

These come from the 1.12 client and cannot be worked around by an addon:

- Nameplates only exist within 20 yards of the hero.
- Debuffs can only be read from the current target, so only the target's plate shows them.
- A debuff's time left is only known for the hero's own buffs and debuffs.
- The game's spells and jewelry rows are drawn by the game and cannot be moved from here: the game shares no jewelry data to draw them again.
- A lair guardian is the same creature as its elite, so only your target can be told apart as one. Its plate is an elite's otherwise; the run panel and the boss bars know them all from the game.
- On a version of the game without its addon API, the run panel keeps its own count: its own clock (hover it for the rules), elites and guardians together, and no gold, caches or bosses to come.

If OmniCC is installed, Survivor UI leaves the cooldown numbers to it.

## Changes

Newest first. The version is also in each addon's `.toc`, so it shows in the game's addon list.

### v2.4, 2026-10-15

**Survivor UI**
- **Build list** (new): every spell slot with the spell's icon, rank and share of the damage, from the highest rank down, each row filled with its damage meter color; the free slots (the count turns red when they are full); the racial apart. Under it, the gear: each piece of jewelry with what it gives in short (`CDR · DMG`, colored as in the character pane), or, with none worn, what all the gear adds, with the pieces it comes from on hover. `/sui build`
- **New layout:** the build list joins the right column, between the run tracker and the damage meter; the run panel moves to the left, under the loot list, with the Biggest Crits box right under it. Every piece goes back to its first place once.
- **Damage meter:** each spell's rank after its name, in Roman numerals (`Holy Wrath XII`). Its card also shows the spell's rank and cooldown, and for a buff how long it lasts and how long it has left.
- **Run tracker:** in endless mode, when the next boss comes. Over each boss's tick, the time until it comes (the next one in orange); a tick turns green once its boss is slain. Smaller and tighter, the level without the numbers.
- **One experience bar:** the one under the action bar hides while the run tracker shows its own.
- **Action bar:** no key labels; a spell cooling down is dimmed, and its last two seconds count down in red.
- **Biggest Crits box:** the damage meter's colors, and the run panel's style.

### v2.3, 2026-10-15

**Survivor UI**
- **Fixed stuttering since v2.1:** the interface is back on the game's own Friz Quadrata, and the damage numbers no longer set their font again on every hit. Want Expressway? Drop your own in `SurvivorUI\Fonts` (see Font).
- **Loot list** in the top left corner: what the run has dropped, as bars in the item's quality color, with the second it came. `/sui loot`
- **Biggest Crits box** is back as an option, off by default: `/sui crits`.
- The damage meter's card shows the spell's rank, its cooldown and when it is ready again, handy while the cards are up and the action bar is not.
- An enemy's name in the target frame has more room, and goes by its first word when it still does not fit, instead of being cut short.
- No hover outline on the hero in the character pane, nor around whole panels (only their lines).

### v2.2.2, 2026-10-15

**Survivor UI**
- The tooltip for enemies and the world can be moved: hold Alt and drag the "Tooltip" box. Left alone, it opens beside the damage meter as before. `/sui layout` puts it back.

### v2.2.1, 2026-10-15

**Survivor UI**
- `/sui scale` no longer sends a moved panel off the screen: each panel keeps its place at any scale, and none can leave the screen. `/sui layout` brings back one that went missing in v2.2.
- The damage meter's proc tag reads "(proc)", smaller.
- No hover outline on the nameplates, the chat, the minimap and the run tracker.

### v2.2, 2026-10-15

**Survivor UI**
- The damage meter's Reset works: the meter starts over from that moment (damage, damage per second and shares) and the crits are cleared. The run panel keeps the whole run.
- More colors in the damage meter: twelve distinct ones, procs included, so neighbours never look alike. Procs keep their "proc" tag.
- The run tracker shows when each boss fell, beside when it came: `4:00 / 5:32`.
- A thin white outline around whatever the mouse is on: a button, a bar, a buff. `/sui hover` switches it off.

### v2.1, 2026-10-15

**Survivor UI**
- New font: Barlow Condensed, everywhere, one point larger than before. Your own Expressway is used instead if you put it in `SurvivorUI\Fonts` (see Font).
- Smaller screens: the damage meter sits right under the run panel and shows as many lines as fit, three at least, instead of running over it. `/sui scale 0.85` sizes the panels (0.6 to 1.4).
- The run panel's old Biggest Crits list is gone for good: the crits live in the damage meter's cards. `/sui meter` now only swaps the meter.
- The damage meter marks a talent's or amulet's own damage as "proc" again.

**Survivor Plates**
- The same font as Survivor UI when it is installed.

### v2.0, 2026-10-14

Built on the game's new addon API. On a version of the game without it, Survivor UI works as before.

**Survivor UI: new**
- **Run tracker** under the minimap, after a Mythic+ timer: the zone, the time gone against the zone's full length from the game's own clock (it stops when you pause or choose a card; the time gone alone in endless mode), a timeline with a tick for every boss, every boss with the second it comes, colored by where it stands (grey to come, white next, orange alive with its health, green slain), lives left and the level's progress. One size all run. It stands in for the game's own clock. Hover it for the time to the final boss and the run's settings. `/sui tracker`
- **Damage meter** in place of the game's: one bar per source with its damage and share, a talent's or amulet's own damage in blue. Hover a line for its card: damage per second from the game, and critical strikes (biggest, last, average, smallest) and normal hits from the combat log. One size all run; its cards open on its left. For healing and boss damage, `/sui meter` switches to the game's own meter and back.
- **Boss bars** at the top of the screen: every boss alive, the final boss on top, and every awake lair guardian, at any distance, with the name and the health left. An enraged boss's name turns red. Click a bar to target it. `/sui bosses`, `/sui bosses elites`
- **Kills, gold and cache** on a line under the experience bar, in place of the game's own box, so they move with the middle block. `/sui tally`
- **Hold Alt** and every piece that can move shows outlined with its name: the middle block, the chat, the minimap, the run tracker, the run panel, the damage meter, the boss bars and the tooltip. Drag any of them; each keeps its place. `/sui layout` puts everything back, `/sui center` only the middle block.

**Survivor UI: changed**
- The run panel reads the game's own numbers, the same as its victory screen: time, level, kills, elites, guardians on a row of their own again, bosses, damage dealt and taken, damage per second, gold earned and caches opened. Hover a row for more: enemies alive, the damage meter by source, damage taken by source, gold, rerolls and lives.
- The right column stacks the run tracker, the run panel and the damage meter, all the same width and in one lighter shade. The crits live in the meter's cards now; the run panel's old Biggest Crits list is gone.
- The game's tooltip for enemies opens beside the damage meter instead of on top of it.
- No more "Health Low" in big letters over the fight.
- Updating puts every piece back in its first place once, since the layout changed.

**Survivor Plates**
- Your target's plate turns blue when it is a lair guardian.
- Elites and bosses are also recognized by the names the game sends.
### v1.8.1, 2026-10-14

**Survivor Plates**
- The separate guardian plate is gone: it never showed, since a guardian reaches the client under its elite's name. Guardians wear the elite's plate, as they already did.

**Survivor UI**
- Elites and guardians are counted together in the run panel, as "Elites & guardians slain". The game tells addons nothing that sets a guardian apart from its elite, and the chat line v1.8 relied on did not reach the addon. They can be split again once the game marks its guardians.

### v1.8, 2026-10-14

**Survivor UI**
- Lair guardians really are counted as guardians now. A guardian is an elite to the client and dies under its elite's name, so v1.7 still counted it as an elite. The run panel now counts it from the game's own chat line, "is slain! Its lair yields treasure", and takes back the elite its death counted.

### v1.7, 2026-10-14

**Survivor UI**
- The ability tooltip is laid out again. The name wears the color of its school (Holy, Fire, Frost, Nature, Shadow, Arcane, or physical), as do the rule under the summary and the school's damage in the description. Under the name: how it casts, its cooldown, its reach and its crit, each number in a color of its own. The description's numbers stand out in white. Each upgrade, bonus and talent gets a line of its own, with a thin rule between the sections. A tooltip the addon cannot read is left as the game wrote it.
- The hits the hero takes fall over the hero in the same quick style as the damage dealt, in red, in place of the slow floating combat text. Heals and the rest of the floating combat text are unchanged. `/sui damage` switches both back.
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
