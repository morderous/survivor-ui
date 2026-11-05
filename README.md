# Survivor UI and Survivor Plates

English | [简体中文](README.zh-CN.md)

[![Latest release](https://img.shields.io/github/v/release/morderous/survivor-ui?label=download&color=2ea44f)](https://github.com/morderous/survivor-ui/releases/latest) [![Support on Ko-fi](https://img.shields.io/badge/Ko--fi-buy%20me%20a%20coffee-FF5E5B?logo=ko-fi&logoColor=white)](https://ko-fi.com/morderous)

![Survivor UI in a run: the run tracker, the build list with its jewelry and the damage meter on the right, This Run and Biggest Crits on the left, the loot list at the top, boss bars, the action bar with the unit frames, and the damage numbers beside the hero with their spells' icons](docs/screenshot.jpg)

![The Jewelry Collection beside the character pane: the class's legendary amulets by spell, the amulets, rings and trinkets found and still to find, with what is worn now; the character pane in the class's color, and the run tracker, build list and damage meter on the right](docs/screenshot-collection.jpg)

Two interface addons for Azeroth Survivors, the Vampire Survivors-style game that runs on [benilla](https://github.com/samwhosung/benilla), a World of Warcraft 1.12.1 client. They are independent: use either one or both.

These are fan-made and not affiliated with the game or its author.

> **The launcher (.exe) is optional.** The addons are plain Lua files: download `SurvivorUI-vX.Y.zip` from the [latest release](https://github.com/morderous/survivor-ui/releases/latest), unzip it and move the `SurvivorUI` and `SurvivorPlates` folders into the game's `benilla-config\AddOns` folder yourself ([how](#by-hand)). The launcher only saves those steps, and more ([with the launcher](#with-the-launcher-easiest)); its source code is in [`installer/`](installer) for anyone to read.

Both are flat and dark, in the manner of EllesmereUI and Plater. They are written from scratch for the 1.12 addon API and share no code with those addons.

## Commands at a glance

**Click the S button** by the minimap (or type `/sui opt`) for the options: every piece and every look on or off, the panels' size, and **Move UI**, a grid to line every piece up (right click the S button to go straight to it). While a tab is open its own pieces can be dragged, so you can play while setting them. **Hold Alt** any time to see everything that can be moved, outlined with its name, and drag it (another key, or none, in the Layout tab). Every piece keeps its place.

| Command | What it does |
|---|---|
| `/sui opt` | The options panel (a right click on the minimap button moves the whole UI) |
| `/sui` | Lists every command in the chat |
| `/sui layout` | Puts every piece back in its first place |
| `/sui hover` | The white outline around what the mouse is on: on or off |
| `/sui loot` | Loot list, or the Default loot notices: on or off |
| `/sui build` | Build list, or the Default row of spells and jewelry: on or off |
| `/sui crits` | Biggest Crits box: on or off (on by default) |
| `/sui scale 0.85` | Size of the whole interface, 0.6 to 1.4. Each part has its own size in `/sui opt`, Size |
| `/sui center` | Puts the middle block (frames and buttons) back under the hero |
| `/sui tracker` | Run tracker under the minimap: on or off |
| `/sui run` | Run panel: on or off |
| `/sui run reset` | Clears the crits |
| `/sui meter` | SurvivorUI's damage meter, or Default |
| `/sui meter now` | Meter now: on or off |
| `/sui bosses` | Boss bars: on or off |
| `/sui bosses elites` | Adds every elite to the boss bars |
| `/sui guide` | The Guide: how Luck, Damage, Crit, Haste and Speed really work, and what marks and sets give |
| `/sui tally` | Kills and gold line under the minimap, or the Default box |
| `/sui pace` | Kill pace, the orb by the run tracker's clock: on or off |
| `/sui pace class` | Kill pace against this class's runs only, or every class's (the default) |
| `/sui pace reset` | Forgets the runs the kill pace holds against, on this zone and modifiers |
| `/sui damage` | SurvivorUI's combat text, or Default (the rest is in `/sui opt`, Combat text) |
| `/sui damage none` | No combat text at all, or back |
| `/sui damage side` | The numbers beside the hero, or over the enemies |
| `/sui damage icons` | Source icons and damage meter colors on the numbers, or not |
| `/sui collection` | The Jewelry Collection (also its button on the character pane) |
| `/sui collection reset` | Forgets every piece in the Jewelry Collection (type it twice) |
| `/sui dots` | The counters over the action bar (DoTs, fears, totems): all on or off; one by one in `/sui opt`, Counters |
| `/sui record` | Shows how a new best crit looks in the combat numbers |
| `/sui sample` | Plays a sample of every combat number as set |
| `/sui guardians` | The guardians' list: on or off |
| `/sui guardians north` | Its arrows north up, or turning with the way you face |
| `/sui guardians bar` | The guardians as a bar in the run tracker, or a list beside it |
| `/sui pins` | Prints what the minimap's cache and lair pins read, to check them |
| `/sui chat 10` | Chat text size, 8 to 18 |
| `/splates normal` | Plates on the rank and file too, or not (the default); also `elites`, `guardians`, `bosses` |
| `/splates names` | A name on every plate (the default), or on elites, guardians, bosses and friends only |
| `/splates target` | Your target's plate whatever its kind, or only when its kind is on (the default) |
| `/splates click` | Clicks go through the plates (the default), or a click on one targets it |
| `/splates none` | No nameplates, or back (on by default) |
| `/splates party` | Plates on your co-op friends, in their class color (also `pets`, `totems`) |
| `/splates suggested` | Friendly plates only: every enemy's off |
| `/splates scale 1.3` | Plate size, 0.5 to 2 |

## Survivor Plates

Nameplates.

> **Out of the box the plates are on for elites, lair guardians and bosses**, with a name on every plate, and off for the rank and file (`/splates normal` puts them on). Each kind is on or off on its own in `/sui opt`, Nameplates, and every choice is remembered.

- A thin bar with a black line round it, the name over it and the health's share small inside, on the right.
- Each kind in its own color, each a little larger: the rank and file red, elites green, lair guardians blue, bosses purple, the final boss orange. From the game's 0.139.2 the game tells each one's kind, so a guardian and an elite of the same name each wear their own.
- A skull over the name: a bone skull on an elite, the minimap's horned lair skull on a guardian, a horned infernal skull on a boss and the final boss.
- In a crowd a boss's plate is in front, then a guardian's, then an elite's; the rank and file behind, a little faded (never your target).
- The target's plate has a gold line and shows its debuffs and their stacks.
- The plate under the mouse glows, comes to the front and takes the click, so you can pick one out of a crowd. A Survivor UI boss bar under the mouse lines its enemy's plate in white.
- Friendly plates, thinner, in a gold rim, each kind on its own and on by default: your pets, summons and totems in mint, and in a co-op run your friends in their class's color.

Commands:

| Command | What it does |
|---|---|
| `/splates none` | Switches between no nameplates and nameplates (the default from v3.0.53) |
| `/splates normal`, `/splates elites`, `/splates guardians`, `/splates bosses` | Each enemy kind on or off: the rank and file (off by default), elites, guardians, bosses |
| `/splates names` | Switches between a name on every plate (the default) and names on elites, guardians, bosses and friends only |
| `/splates target` | Switches between your target's plate only when its kind is on (the default) and your target's plate whatever its kind |
| `/splates click` | Switches between clicks going through the plates, the camera turning from over them (the default), and plates you click to target |
| `/splates totems`, `/splates pets`, `/splates party` | Each friendly kind on or off: your totems, your pets and summons, your co-op friends (all on by default) |
| `/splates suggested` | Friendly plates only: your totems, pets and summons and co-op friends' plates on, every enemy's off (the boss bars follow bosses, elites and guardians) |
| `/splates scale 1.3` | Plate size, 0.5 to 2 |

## Survivor UI

Unit frames and the action bar, in one centered row under the hero:

```
[portrait][ player ]  [1][2][3][4][5][6][=]  [ target ][portrait]
```

- Player and target frames: a health bar in the class color (red for an enemy), the name, the health, a slim power bar and a portrait.
- The hero's buffs and debuffs above the player frame, with time left and stacks. Right click a buff to cancel it.
- Action buttons 1 to 6 and the last button of the bar (the `=` key), with cooldown numbers. The rest of the bar and its art are put away.
- The experience bar as a thin strip under the row, with the run tracker and the XP bar both off.
- A square minimap, zoomed with the mouse wheel.
- The micro buttons in the bottom left corner, hidden until the mouse reaches them.
- A flat, dark chat panel without the scroll buttons, in 10 point text. The mouse wheel scrolls; Shift with the wheel jumps to the top or the bottom.
- A flat character pane in the hero's class color: the hero and the item slots on the left, the run's numbers in titled sections on the right. The numbers beside the hero can be switched off; the same numbers as a panel of their own on the screen all the time, the Stats panel, moved and resized like the other panels; each class picks which of them show and in what order.
- A flat, dark tooltip with smaller type. An ability's tooltip is laid out again: its name in its school's color, the school, the cooldown, the range and the crit at a glance, the description's numbers standing out, then its upgrades, bonuses and talents, a line each.
- Friz Quadrata on every piece of interface text, chat and nameplates included, or a face of your own (see Font below).
- Combat text in place of Default: beside the hero, each hit with its source's icon (a weapon for melee and shots) in its damage meter color, the crits on the right, the heals rising over the hero and the hits taken falling under the action bar; each column moves where you want it, and one source's hits close together add up (`1.2k x3`). Where, how far, the look and what shows are all yours to set; or Default, or none at all.
- A run tracker under the minimap, in the manner of a Mythic+ timer: the zone, the lives left, the time gone against the zone's full length (the time gone alone in endless mode), a timeline with a tick for every boss, every boss with the second it comes, colored by where it stands (grey to come, white next, orange alive, green slain), and the level's progress. It stands in for the Default clock.
- A run panel on the left, under the loot list: the run so far, the same numbers as the game's victory screen (time survived, level, kills, elites, guardians and bosses slain, damage dealt and taken, damage per second, gold earned, caches opened). Hover a row for more: the damage meter, damage taken by source, gold and rerolls.
- A damage meter under the build list, in place of Default, as many lines as fit the screen or as you set, a scroll bar for the rest: one bar per source of damage, with its damage and its share. Hover a line for its card: damage per second, and its critical strikes (biggest, last, average, smallest) and normal hits. The buttons under its title switch pages: each source's damage a second, the last 30 seconds, the run's healing, or in a co-op run each hero's damage. The + at its corner opens more windows, each on a page of its own, and the last button opens the meter now: the last 30 seconds, since its own Reset, or the boss fight.
- Boss bars at the top of the screen: every boss alive and every awake lair guardian, with its health and its debuffs (icons that drain to grey as they run out), at any distance. Click one to target it. Off for a new install from v3.0.53, the plates showing the bosses: `/sui bosses` brings them.
- A DoT and fear counter over the action bar: over each damage over time spell's button, how many of it are out on the enemies, counted by their ticks; over a fear's (Psychic Scream, Intimidating Shout...), how many enemies it holds now. In the spell's damage meter color.
- A guardians' list against the run tracker's left side, small and with no background: a line a lair, with a little arrow toward it, the guardian's name, how far it is, and asleep, awake with its health, or slain at its second and back in so many seconds. The arrows turn with the way you face (or point north up). Over it, the achievement "Slay four guardians before 8:00": how many fell before 8:00.
- Caches and lairs on the minimap, on every map, instances too: a golden chest for each cache, a horned skull for each guardian's lair (grey once empty); one out of range waits on the minimap's edge, pointing the way.
- With the game's Store Level-Ups, a Level Up! button over the action bar for the levels waiting, in place of the game's; the levels waiting by your level too.
- Kills, gold and the next cache's price on a line under the minimap (or the action bar), a red skull and a coin that shines when the cache can be paid, in place of the Default box; what it shows and in what order is yours to set (Kills & gold tab).
- A kill pace on the run tracker, a glowing orb right of its clock: how fast the enemies die (kills a minute over the last 20 seconds), held against your own runs on the zone and modifiers at the same minute of the run, every class's (to see how your shaman does against your paladin) or this class's only. Red as slow as your slowest, yellow in between, blue near your fastest, green as fast or faster, its sparks livelier the better it goes; white until three of your runs reach that minute. Hover it for the numbers: kills a minute, the share of your fastest, your fastest, average and slowest (with their class), the enemies alive, the stretch going on, and the run's modifiers (a run is held only against runs of the very same ones). As each boss comes, a banner left of the tracker tells the stretch just ended: its kills since the boss before (or the start), their share of your best on that stretch and the place they take among your runs (`2nd of 6`), in the color of how it went.
- A build list in the right column, between the run tracker and the damage meter: every spell slot with the spell's icon, rank and share of the damage, from the highest rank down, each filled with its damage meter color; the free slots; and the jewelry, the gear a run drops: a row a slot (neck, rings, trinkets), filled with the piece's quality color, with its rank and what it gives in short. A legendary amulet names the spell it boosts in place of "Neck". Hover a spell for its tooltip, as on its action button.
- A loot list in the top left corner: what the run has dropped, as bars in the item's quality color, with the second it came.
- A Biggest Crits box, on by default (`/sui crits`): every ability's biggest critical strike, in the build list's look.
- A thin white outline around whatever the mouse is on: a button, a bar, a buff. The nameplates, the chat, the minimap and the run tracker go without.
- An options panel (`/sui opt`, or the S button by the minimap), in tabs of their own color: every panel on or off, the combat numbers, the nameplates, every look, a size for the whole interface and one for each part, and Move UI, at the top of every tab, that unlocks every piece over a grid they snap to; while a tab is open its own pieces can be dragged, and the window minimizes to a bar of three buttons to set them with the screen free.
- In the game's co-op runs: a frame for each friend in your party (health in the class's color, down and being brought back), a Party Damage page in the meter, the party named in Run History, and, if you want it, a bar while you are down or bring a friend back.
- A Jewelry Collection (its button on the character pane, or `/sui collection`): every amulet, ring and trinket of the game's codex, found or still to find, with the range seen of each bonus and what each gives by rarity; your class's own amulets by spell, in your class's color. One collection for the whole game folder, shared by every character and account on it. Compact, to read at a glance in a fight.

Left click a frame to target it, right click for its menu. Hold Alt (or the move key chosen in Layout) to outline every movable piece: the action bar, the player and target frames, the buffs, the kills and gold line, the panels. Drag any of them; each keeps its place. `/sui center` puts the action bar back; the option "Player and target frames move with the action bar" (Frames & bar) joins the two frames to it.

Commands:

| Command | What it does |
|---|---|
| `/sui damage` | Switches between SurvivorUI's combat text and Default; every other choice is in `/sui opt`, Combat text |
| `/sui damage none` | No combat text at all; again to bring it back |
| `/sui damage side` | The numbers beside the hero (the default), or over the enemies |
| `/sui damage icons` | Source icons and damage meter colors on the numbers (the default), or not |
| `/sui collection` | The Jewelry Collection: every amulet, ring and trinket found on this game, and what is left to find |
| `/sui dots` | The counters over the action bar (DoTs, fears, totems): all on or off; one by one in `/sui opt`, Counters |
| `/sui record` | Shows how a new best crit looks in the combat numbers |
| `/sui sample` | Plays a sample of every combat number as set |
| `/sui guardians` | The guardians' list: on or off |
| `/sui guardians north` | Its arrows north up, or turning with the way you face |
| `/sui guardians bar` | The guardians as a bar in the run tracker, or a list beside it |
| `/sui pins` | Prints what the minimap's cache and lair pins read, to check them |
| `/sui chat 10` | Chat text size, 8 to 18 (default 10) |
| `/sui run` | Shows or hides the run panel |
| `/sui tracker` | Shows or hides the run tracker under the minimap |
| `/sui meter` | Switches between SurvivorUI's damage meter (the default) and Default |
| `/sui meter now` | Opens or closes the meter now: the last 30 seconds, since its Reset, or the boss fight |
| `/sui center` | Puts the middle block back under the hero |
| `/sui layout` | Puts every piece back in its first place |
| `/sui hover` | The white outline around what the mouse is on: on or off |
| `/sui loot` | Loot list, or the Default loot notices: on or off |
| `/sui build` | Build list, or the Default row of spells and jewelry: on or off |
| `/sui crits` | Biggest Crits box: on or off (on by default) |
| `/sui scale 0.85` | Size of the whole interface, 0.6 to 1.4. Each part has its own size in `/sui opt`, Size |
| `/sui run reset` | Clears the crits in the damage meter's cards; the run's numbers stay |
| `/sui bosses` | Switches the boss bars on or off (off for a new install from v3.0.53) |
| `/sui bosses elites` | Lists every elite in the boss bars too |
| `/sui guide` | Opens the Guide: how Luck, Damage, Crit, Haste and Speed really work, and what marks and sets give |
| `/sui tally` | Switches between the kills and gold line (the default) and the Default box |

### Healing and boss damage

The buttons under the meter's title: **DMG** (the run's damage, with each ability's crits on mouseover), **DPS** (each source's damage a second), **PARTY** in a co-op run (each hero's damage and damage a second, in the class's color), **30s** (the last 30 seconds) and **Healing** (the run's healing, overhealing left out). The meter keeps the page you chose. For the damage to a boss, the meter now's **This boss**.

### Font

The interface uses the game's **Friz Quadrata**. Prefer **Expressway**, the face of many retail UIs? It cannot be shipped with the addon, but if you have it (it comes with EllesmereUI and ElvUI, for one), copy it as `SurvivorUI\Fonts\Expressway.ttf` and restart the game: the addon picks it up on its own.

Each piece can wear a font of its own, on its card in move mode: the game's (Friz Quadrata, Arial Narrow, Morpheus) or one of eight free faces that come with the addon in `SurvivorUI\Fonts`: **Fira Sans**, **Noto Sans**, **Exo**, **Russo One**, **Cinzel Decorative**, **Barlow Semi Condensed**, **Barlow Condensed** and **Noto Sans SC**. Exo, Cinzel Decorative and the two Barlows have no Cyrillic, Russo One no Romanian ț, Noto Sans SC no Czech, Polish, Romanian, Turkish, Ukrainian or Korean letters, so the card offers each only where it can write the game's language. The **global font** (`/sui opt`, Global) puts one of them on every text of the addon's at once; a piece's own font stays its own.

With the game in **Chinese or Japanese**, the addon writes in Noto Sans SC, a font that has those letters. A font without them would take them from the game's font as it draws, and the game then mixes them up with its letters (an English letter drawn as a Chinese character, or the other way round). The font you chose is kept for a game in another language.

### The game's addon API

Azeroth Survivors shares its run with addons: its clock, phase, kills, bosses, guardians, damage meter and more. Survivor UI reads them where the game offers them, and falls back to its own count on a version of the game that does not.

The run tracker, the damage meter, the boss bars and the kills and gold line put the Default clock, meter, boss bars and box away while they are on. That is a game setting, saved by the game: `/sui tracker`, `/sui meter`, `/sui bosses` and `/sui tally` bring them back, and so do the "Show ..." checkboxes in the game's Options, Interface. From v3.0.12 the addon also puts every one it hid back on as the game closes (each goes away again as it starts), so removing the addon with the game closed leaves the game's own showing; removed before that version, the "Show ..." checkboxes bring them back, and for the minimap's flag, the Level Up! button and the damage numbers, which have none, `/script SetCVar("hudFlag", "1")`, `/script SetCVar("hudLevels", "1")` and `/script SetCVar("CombatDamage", "1")` in the chat.

## Install

Two ways, the same result: the launcher, or the zip by hand. The launcher is optional.

### With the launcher (easiest)

1. Download `SurvivorUI-Installer.zip` from the [latest release](https://github.com/morderous/survivor-ui/releases/latest) and unzip it.
2. Open `SurvivorInstaller.exe`. Windows may say it protected your PC, since the program is new and not signed: click **More info**, then **Run anyway**.
3. No game yet? Click **Get the game**. Have it already? The launcher finds it by itself, or click **Find game...** and pick the game itself, `AzerothSurvivors.exe`. A common place is:
   ```
   C:\Git\wenilla\benilla-config\AzerothSurvivors.exe
   ```
4. On a PC with no launcher before it, the launcher installs Survivor UI and SurvivorUI Classic by itself once the game is there, and the game asks which of the two to use as it first starts. If you already have a launcher, in the **Addons** tab Survivor UI is first (recommended): click **Install**. Then **Play** in the Play tab. Restart the game if it was open.

The **Azeroth SurvivorUI Launcher** plays the game, keeps it current, and installs and updates Survivor UI and Survivor Plates, in English, Chinese or Russian: the language button on the Play tab switches it, and until you pick one it follows the game's language. **Play** starts the game, and the launcher steps into the tray. **Get the game** downloads Azeroth Survivors, Aethus' game, from his own servers (wow.aethus.pl, with his ok) or from mirrors, each timed first: our own is picked while it isn't slow, otherwise the fastest, every package checked by the size and sha256 Aethus gave; it puts the game in its usual place and installs Survivor UI with it, then offers to move itself into the game's folder with a shortcut on your Desktop, or to add only the shortcut. Leave it running: minimized or closed, it waits in the tray and asks GitHub for a new release every half hour; when one is out, a **green arrow** shows on its tray icon and a green pill at the right of its tabs. Survivor UI and SurvivorUI Classic update by themselves when a release is out and the game is closed, unless you untick **Auto update** on their rows in the Addons tab; tick it on any other addon installed from the list to have it do the same, or the tick in the column's header for all of them. As its window opens, a box says what else waits. It updates itself too (untick "Update the launcher by itself" to only be told).

Six tabs: **Play** (the game, your playtime and runs, the game's news, its AddOns folder), **Savegame** (your save backed up to the Desktop, a USB drive or a folder, by hand or after each game session, and put back), **Statistics** (your playtime and the save's numbers), **Run History** (Survivor UI's runs, the victories and endless runs kept for good) and **Addons**: Survivor UI and Survivor Plates first, with the release, the beta and each on or off; then more addons from a list morderous checked, each from its author's own latest release (only the addon's own folder and its kinds of files, never a program, never over Survivor UI's folders), with **Update all** and **Uninstall** to the Recycle Bin; then the ones you add yourself with **Add from GitHub...** (a repository's link, kept on your PC only), installed and updated the same way; then the ones you put in by hand. And **Time Machine**: older versions of the game, each in its own folder with a save where everything is open.

The lists it reads live beside its source, so an entry is added or changed without a new launcher: [`installer/addons.json`](installer/addons.json), the addons the Addons tab offers, and [`installer/mirrors.json`](installer/mirrors.json), the mirrors Get the game offers beside Aethus' servers. Its source is in [`installer/`](installer), built with the C# compiler that comes with Windows (`installer\build.bat`). It touches only the addons' folders it installs or you uninstall, the game's list of addons when you switch one off or on, the game's own files when it gets or updates the game for you, and your save and settings when you ask it to back them up or restore one.

### By hand

1. Download `SurvivorUI-vX.Y.zip` from the [latest release](https://github.com/morderous/survivor-ui/releases/latest).
2. Unzip it into the game's addon folder, `benilla-config\AddOns\`. You should end up with `AddOns\SurvivorPlates` and `AddOns\SurvivorUI`. Keep only the one you want, or both.
3. Restart the game.

To remove an addon, delete its folder.

## Limits

These come from the 1.12 client and cannot be worked around by an addon:

- Nameplates only exist within 20 yards of the hero.
- Inside an instance (the dungeon and raid maps) the client gives no place for the hero on the map, and the game's addon API does not send it either: there the minimap shows no caches or lairs, and the guardians no arrow or yards.
- Debuffs can only be read from the current target, so only the target's plate shows them.
- A debuff's time left is only known for the hero's own buffs and debuffs.
- The game's spells and jewelry rows are drawn by the game and cannot be moved from here: the game shares no jewelry data to draw them again.
- A lair guardian is the same creature as its elite. From the game's 0.139.2 the game tells the plates which is which; before it, only your target could be told apart as one, and its plate was an elite's otherwise.
- On a version of the game without its addon API, the run panel keeps its own count: its own clock (hover it for the rules), elites and guardians together, and no gold, caches or bosses to come.

If OmniCC is installed, Survivor UI leaves the cooldown numbers to it.

## Changes

Newest first. The version is also in each addon's `.toc`, so it shows in the game's addon list.

### v3.0.58, 2026-11-05

One experience bar, boss bars whose debuffs leave the name alone, a Stats panel and a run tracker with room to spare, and counters in your own size, color and format.

**Action bar**
- **No second experience bar:** from v3.0.56, turning the XP bar off brought the game's own experience strip back under the action bar, with no way to put it away, and it showed over the Level Up! screen too. It now stays away: the XP bar is the one, and with it off there is none. With the addon's action bar off, the game's bar keeps its experience bar as before.

**Boss bars**
- **Debuffs off the name:** in co-op the debuffs piled up inside a boss's bar and covered its name. They now sit **under** each bar by default, or **over** it, **left** or **right** of it, or **inside** it as before (Boss bars tab, Debuffs). Outside the bar they have their own size (Advanced) and, under or over it, line up from the bar's left, middle or right (Advanced); **Right to left** runs them from the right end, the first (yours, with Yours first) rightmost. Left of the bar they run outward to the left, right of it outward to the right, inside it from the health leftward; a line by the Debuffs title says which way, as chosen. The column keeps room for them, so they never sit on the next bar.
- **How many, and whose:** **Most per bar** sets how many debuffs a bar shows (6 at first). In a group, **Friends' debuffs** shows your party's too, and **Yours first** puts yours ahead when a bar has more than it shows. The game does not say whose a debuff is: one of your build's spells counts as yours (a spell you both have too), so one your talents or jewelry lay may count as a friend's.
- **Each kind on its own:** **Bosses**, **Guardians** and **Elites** each on or off, each with its own health look (or **Off**, the name alone) and, under Advanced, its own size. **Size** still sets the whole column. Advanced also sets the most bars at once (8 at first).
- **Elites' debuffs:** the game sends none for elites, so an elite's bar shows them while it is your target or under the mouse.
- **The tab's preview** draws the column as it will be: a boss, a guardian and an elite, each at its size and look, sample debuffs where chosen.

**Stats panel**
- **Its tab in the new style, in Run:** a live preview of the panel beside its settings, with your run's numbers or a sample run's, and every number of your class under them, ticked to show, in the pane and on the panel alike. The tab moved from Character to Run, under the run tracker.
- **Title on or off:** without it the numbers start at the top and the panel is shorter, with No backgrounds too. To move it then, a strip shows over it (under it at the top of the screen) in move mode, with Alt held or while its tab is open.
- **Group titles on or off:** without them the numbers follow one another, the groups in the same order; they come back, faint, in move mode or with Alt held, to drag a group.
- **Each number's color:** its group's (as before), your class's or one of nine more, for every class; click a number in the preview or the dot after it in the list, then a color. The group's color is the tile of six colors, the class's is your class's icon. **All in this color** sets every number at once. The character pane's own numbers keep their look.
- **Changing the order, said plainly:** the tab now says, in its color, to hold your move key (Alt, or the one chosen in Layout) and drag a number or a group on the panel to its place.

**Run tracker**
- **The title:** the zone's name has a switch of its own, and **Left**, **Center** and **Right** beside it. Center is as before: the name in the middle, the difficulty at the left and the affixes at the right. Left puts the name and all the tags at the left, Right all flush right. With the title off, the clock and all under it move up.
- **The tags on or off:** **Difficulty and affixes** has a switch for the whole row of tags; while it is off, Difficulty, Affixes and Centered keep their choices, greyed out.
- **Compact** (off at first): the zone's name and the tags on one line, as in "Gates of Ahn'Qiraj [Heroic V] [Bolstering] [Sanguine]", each tag short or in words as chosen. When the line is too long the name gives way ("Gates..."), in full when you hover the tracker. Victory, Fallen, Paused or the lives left go beside it when they fit, else on the line under. In Compact the tracker keeps no empty lines for bosses to come, so the guardians' bar sits right under the last boss.
- **Apart** (with Compact): the zone's name at one end of the line and the tags at the other, as in "Elwynn Forest ........ [V] [Bolstering] [Sanguine]"; with the title's Right, the other way round.
- **Fixed:** a run's affix tags could show in the addon's font instead of the tracker's.

**Counters**
- **Their own size, color and format:** Frames & bar has a new Advanced box for the **Totem counter** and the **Debuff counter** (every other count: DoTs, fears, Faerie Fire, Demoralizing Shout, Battle Shout's seconds), each on its own: its **size**, its **color** (the spell's damage meter color, as before, your class's or one of nine more) and its **format** (totems: 12/30, 12, or 12/30 with the seconds until the soonest one ends beside it; the rest: 12 or x12). The preview draws them over the first two buttons. A counter stays within its button's width: when the number (with a totem's seconds) would spill past it, it shrinks to fit.
- **Size moved:** the Counters tab's Size bar gave way to a link to Frames & bar. A size set there before stays as the first of both counters.

### Azeroth SurvivorUI Launcher 1.11.1, 2026-11-05

The Time Machine tells what plays differently in each old version, a line each, under its warning in red.

- **What is different, a line each:** each old version now lists what plays differently from the game of today, one line per change with the version that changed it. A version's line grows to hold them, and the list scrolls on our own scroll bar when they no longer fit.
  - **0.100.1:** Shaman totems have no cap per kind; Shadow Weaving strikes for 1% of the target's maximum health; the old Demonology talents, with Summon Imp and Summon Felguard; bosses have none of their raid mechanics yet; Ice Barrier and Power Word: Shield have no absorb cap.
  - **0.123.0:** Divine Shield can stay up forever, and stuns, roots, fears and polymorph never wear off when used over and over; Ice Barrier and Power Word: Shield have no absorb cap; Shaman totems cap at 40 per kind (30 today).
- **Just for fun, in red:** the warning at the top of the Time Machine tab is now red, so nobody misses it.

### Azeroth SurvivorUI Launcher 1.11.0, 2026-11-04

The Time Machine, auto update for every addon, and a language button in the launcher's own look.

- **Time Machine** (new tab): play the game as it was. Each old version has a line with its day, what is different in it, and **Get it**, then **Play**.
  - **A place of its own:** each version lives in the launcher's own folder (`%LOCALAPPDATA%\SurvivorUIInstaller\Time Machine`), with its own settings, logs and addons, never in your game's folder.
  - **Its own data:** the game files that version knew, by their checksums. The ones your game still has are linked in, taking no room; one Aethus later changes or drops comes from our mirror. Newer patches never reach it.
  - **Everything unlocked, or your own way:** the tick on each version picks its save. On, a save where everything is open (every talent point, every zone and Heroic, the whole collection, every achievement, perk and tabard), to just play. Off, your own save from scratch, to unlock it all yourself. Each keeps its own progress.
  - **Never updates, never online:** it starts with its update check off and no co-op, so it never touches the game of today.
  - **Just for fun, and nothing of yours touched:** nothing done in this tab touches, manages or changes your game, its settings, your addons or your saves; the tab says so at its top. Survivor UI and SurvivorUI Classic come along as you have them.
  - **Fresh save** starts the picked save over; **Remove** sends the version's folder to the Recycle Bin.
  - Old versions get no fixes or support.
- **Auto update on any addon:** in the Addons tab, every addon installed from the list (or added from GitHub) now has an **Auto update** tick: ticked, it updates by itself when a new release is out and the game is closed. Survivor UI, Survivor Plates and SurvivorUI Classic stay ticked unless you untick them; the others start unticked, so nothing changes until you tick one. Addons you put in by hand have no tick: the launcher never updates those.
- **All at once:** the tick in the column's header ticks or unticks every row; it is half filled while only some are on.
- **Language button:** the language on the Play tab is now one of our stone buttons, EN, 中文 or RU with an arrow, opening a menu in the launcher's own look instead of a Windows drop-down.

### v3.0.57, 2026-11-04

A second damage meter for how you are doing right now, buttons for the meter's pages, each pet on a line of its own, kills a minute on the kills line, and totems counted against their cap.

**Meter now** (new)
- **A meter for now:** a window of its own, so the damage meter can keep the whole run. The buttons under its title pick what it counts: **30s**, the last 30 seconds of the run (the default); **Since reset**, from its own Reset (the damage meter's stays as it is); or **This boss**, only the damage to the boss, from the moment it comes until it falls, kept until the next one comes.
- **The meter's look:** the same bars, colors, icons and cards, each card's numbers, crits and hits those of the stretch shown. At its foot, the damage a second, the time it covers and the total.
- **Open it** with the last button of the meter's row, in the options (Damage meter, **Meter now window**) or with `/sui meter now`. Hold Alt and drag to move it, or move it in move mode (**Meter now**), where its card sets its width and lines.

**Damage meter**
- **Page buttons:** the menu on the title gave way to a row of buttons under it, each in its own color, the page shown lit: **DMG**, **DPS**, **PARTY** (greyed out of a party), **30s** (new: the last 30 seconds) and **Healing**, then the meter now's. Hover one for what it shows. The windows the + opens have them too.
- **No more Boss Damage pages:** the meter now's This boss tells a boss fight. A window that was on one goes back to DMG.
- **The numbers at the foot:** the NOW, DPS and TOTAL strip moved under the bars.
- **Each pet on its own line:** a hunter's beasts or a mage's summons were one Pets line; now each pet has its own, with its name and icon, and every total still adds up to the game's. Talents and amulets keep their own lines. The same in the meter now, This Run and Run History, and each pet's crits go to its own card. The White Devilsaur shows its talent's icon, in every game language.

**Kills and gold line**
- **Kills a minute:** hover the kills, under the minimap, for your kills a minute over the last 20 seconds (the kill pace's) and over the whole run, as This Run's Kills / min row has them.

**Counters**
- **Totems against their cap:** a totem's counter now reads 12/30, how many stand out of the most the game lets stand, all in one size and in the spell's damage meter color, in place of the seconds until the next one ends.

### Azeroth SurvivorUI Launcher 1.10.0, 2026-11-04

The launcher in Russian, and in your Windows' language.

- **Russian:** **Language**, on the Play tab, now has English, 中文 and Русский. Tabs, buttons, tips, messages and boxes are translated, and Russian counts its numbers right (1 забег, 2 забега, 5 забегов). Months and units (Oct 29, 12h 30m, MB) stay as they are.
- **Follows Windows:** until you pick a language, the launcher follows the game's; with no game language yet, a Chinese or Russian Windows opens it in Chinese or Russian. The box on the Play tab still wins.
- **Versions that fit:** with a newer launcher or Survivor UI out, the version lines at the top right no longer lose the new version: the launcher's takes a smaller font, Survivor UI's shows "Survivor UI → 3.0.56" (the one installed is in the Addons tab).
- **Game line:** "new game data is out" no longer runs into **Graphics** on the Play tab; the **Update game** button under it says the rest.

### v3.0.56, 2026-11-04

Seven tabs of the options made anew, each with a live preview of what it sets: your range indicator (a tab of its own, each ring in its own look, and the spell each class shows in Spell per class), the minimap, the nameplates, the run tracker, your frames and bar, the tooltips and the build list.

**Range indicator**
- **A tab of its own:** the options' new **Range indicator** tab, after World markers, draws both rings as the game will: round your hero with enemies about it, and on the minimap at its zoom, with the spell that sets the reach. Each ring's switch left World markers for it, and the ring's key is there too.
- **Each its own look:** dots, dashes or a line; light blue (as before), your class's color or one of eight others; the dots' size, the opacity and the gap. Round you, the line and the dashes stay whole even when the ring is wider than the screen; on the minimap the line keeps its thickness at any zoom.
- **Its yards** (new, off): how far the ring reaches, over it on the ground.
- **Shade inside** (new, off): a faint fill inside the minimap's ring, what is in reach.
- **One ring at a time:** the tab picks **Character**, **Minimap**, **Guardian aggro** or **Guardian reset**. A dot on each is lit in its color while it shows. Under it you get that ring's switch, its extras and its look, faded while it is off. The gap and the key are in Advanced.
- **Spell per class** (new, beside Range indicator): pick, once for each class, which spell's reach your range ring shows (a Warrior can pick Execute). Every hero of that class follows it. Until that spell is in your build the ring shows your longest reach, as before; Longest is the default. Each spell shows its yards at its first rank, and in your hero's row a dot marks the spells in your build now.
- **Which spell:** a line under the Range indicator's preview says which spell sets your ring's reach and why, with a link to Spell per class.

**Guardians' rings** (new, in the Range indicator tab: Guardian aggro and Guardian reset, each with its own look: dots, dashes or a line, color, size, opacity and gap; World markers links to them)
- **Where it wakes:** orange dots 20 yards round the nearest guardian asleep at its lair. Walk in, or hit it from anywhere, and it wakes.
- **Where it gives up:** once it is awake, an arc 97.5 yards from its lair. It is your distance to the lair that counts, not the guardian's: past it the guardian heals to full and walks home, and from outside it can't be worn down, as the first hit wakes it and it resets at once. In your last 10 yards the arc turns red and pulses, with the yards left beside it.
- **On the minimap too:** the reset ring as dots round the awake guardian's lair, red in the last yards, and the wake ring at a close zoom. The game's rule, read in its 0.139.2.

**Minimap**
- **A live preview:** the minimap, square or round, with a sample of every pin as your settings stand: the lairs' skulls, empty lairs dimmed or hidden with their timers, the flagged lair's glow or the game's flag, caches, bosses, the final boss's glow, elites, pins on the edge, and the clock and FPS line.
- **Fewer rows:** the pin kinds are chips, the choices sit side by side, and the sizes have S, M and L. The clock's Off sits beside 24 and 12 hours. The lair size, which also sizes the boss and elite skulls, is now called **Lair and boss pins**.
- **What needs what:** a setting fades and stays still while what it needs is off, the reason on hover: the lair settings without the lairs' pins, every pin setting and both pin sizes without Pins on the minimap, Out of reach with no kind of pin on, Clock and FPS on the round minimap, the marker's color and size with the game's arrow. The preview keeps the game's red flag where the game still shows it.
- **No more lair marks:** each lair is the horned skull on the minimap again, dimmed while empty, the one the game's flag points at in its gold glow; its tooltip says Lair. The guardians' bar, count and list in the run tracker, the boss bars and Run History show no marks either, and Lair marks left the Minimap and Run tracker tabs.
- **You on the minimap** (new; an idea of ProTecz's): keep the game's arrow, or put a dot, a dot with a small arrow, a sharp arrow or a cross in its place, in your class's color or one of the range ring's, at S, M or L. The game's arrow shows where the camera looks and never turns as you walk; ours points the way you walk. The preview is now the minimap's real size with your marker in its middle, and the Range indicator tab links to it.

**Nameplates** (Survivor Plates)
- **A live preview** of one plate of each kind as Survivor Plates draws it, in its size, color, rounded bar and skull: the rank and file, an elite as your target, a guardian, a boss, the final boss, a co-op friend, a pet and a totem. It follows every choice: a kind left out fades, the names, the debuffs inside or over your target, the size.
- **The kinds as chips in their plates' colors**, then the look, the size as S, M and L, and the plates' key beside Ignore V and Shift+V. **Suggested setup** (as `/splates suggested`) is the page's own button.
- **A guardian's skull:** the minimap's horned lair skull, a little larger, in place of the white one with red eyes.

**Run tracker**
- **A live preview** beside the settings: the run's tags, the clock and the coin, the timeline and its pips, a boss in its health look, the guardians as chosen, the elites and your level; your run while one is on, a sample otherwise.
- **Every setting kept, in fewer rows:** the guardians' six ways and the four health looks (1.2M / 3.4M too) side by side, the elite bars a step at a time, and the list's size, text size and place under Advanced. The coin's shine is here too, shared with Kills & gold.
- **The guardians' list hangs under the tracker:** right under its last line, whatever it shows, at its width and size, inside its shade, moving with it; the build list under it moves down to make room. **Free list** (Advanced) stands it on its own again, at its own size and place.
- **Tracker Ring** (a new look of the run tracker, Experimental: Tracker Ring, with its switch, preview and settings; the Classic lines stay the default, and the Run tracker tab keeps theirs with a link): the outer ring is the whole run, drawn smooth at any size, filling clockwise from the top, each boss a mark at its time: slain ones dimmed with a tick, the next glowing orange with its time beside it, the final boss a horned skull. A thin inner ring empties until the next boss. In the middle the difficulty and affixes, the clock, "of 16:00" and the next boss with its countdown.
- **A boss alive:** the Dial stays the run's clock and spawn timer. The boss's mark pulses on the ring, its name and its health take the next boss's line ("Ragnaros 63%"), and the thin ring keeps counting down to the next one. No health ring or debuffs on the Dial: the nameplates and the boss bars show them. A long name gets smaller, then short ("Ossirian U. 63%"), to stay inside the ring; the % stays whole.
- **Its own tags:** the difficulty and the affixes are always short (there's no room for words in the circle), and each can be shown or turned off in the Tracker Ring tab. The Run tracker tab's choices are for the Classic lines only.
- **The guardians' compass** under the dial: a tile per lair with an arrow toward it and the yards, green while the guardian is up, orange in a fight with its health in % in place of the arrow, grey with a red clock emptying while slain; hover one for the guardian, click a living one to target it. Each tile is only as big as what it holds, the row centered. **Distance** (on) shows the yards; off, the tiles are shorter and a slain lair shows its wait in place of the clock. No lair marks on the tiles. In the corners the cache coin and its price, the elites alive, the lives left and the kill pace orb. The Dial keeps the tracker's place, Size, Text size and move mode, and the Build list still moves under it. Its own settings: the ring's color (green or your class's), the compass with Distance and North up, the difficulty and the affixes.
- **Removed: the level and XP line** at the tracker's foot, with Level and XP and Time to next level: the XP bar already shows your level, its experience and the time to the next, so the tracker stays shorter. With the tracker on and the XP bar off, the game's own XP bar shows again.
- **New default for a new install:** the guardians as the bar, with an arrow in the middle of each stretch pointing to its lair. Reset this page puts the bar's default back; your settings stay as they are.
- **Difficulty and affixes:** the tags under the zone's name have their own rows: the difficulty short, in words or off, the affixes as icons, in words or off, and Centered. The preview shows a Heroic V with two affixes when your run has none. **Coin shines** now goes with the Cache coin alone and fades while it is off; the Kills & gold line's coin has a shine of its own, in that tab (who had the one shine off keeps both off).

**Frames & bar and Tooltips**
- **Frames & bar:** a live preview of the bottom row as it will look: your frame and your target's in each health look, the shield in light blue, your buffs and the target's debuffs, the action bar with its keys and a cooldown.
- **Tooltips:** the tooltip's place and size moved here from Frames & bar, beside Spell ranks and the Flat tooltips and Ability tooltips switches, with a preview of a spell's tooltip as laid out (or as the game writes it) and a unit's where it opens.

**Build list and Jewelry worn**
- **Build list:** a live preview of the list at its size and text size, your run's build or a sample with each of Info's symbols, and a key of the symbols beside it. **Keep the game's row of spells too** is under Advanced.
- **Every part of a row its own switch:** Info, Info's symbol, the cooldown and the rank, each on or off; what is off leaves the spell's name more room. **Info shows** (all on): a range or a cone's length, an area's radius, a buff's length and its timer, a heal, an absorb, each on or off; a kind off shows the spell's range instead, when it has one.
- **Info in every language:** a heal's cross, a shield's and a buff's hourglass with their numbers now show in every language the game speaks, read in the game's own words (before, only the reach did outside English), and the cooldown is written in the language's seconds ("2.1 с", "2.1秒", "2.1 Sek."), the column a step smaller when it must.
- **Long names fit:** a long spell name (in Russian, or at a bigger text size) is a point smaller, or cut with "..." with the whole name on its card. When a racial's name and its "(racial)" don't both fit, the name stands alone.
- **The preview too:** the Build list tab's preview writes the cooldowns and fits the names the list's way, the sample's as well, so it shows what the list shows.
- **Roman ranks here too:** the list's ranks follow Rank 63 or LXIII, the same choice as Spell ranks in Tooltips, now on this tab as well; the rank column widens to the longest numeral.
- **Jewelry worn:** a live preview of the panel at its size and text size: what you wear in a run, else a sample with a legendary, an epic, a rare and an uncommon piece from the codex. Its stats or its name as two small pictures, then (new) the slot and the rank each on or off, the empty slots shown or hidden, and the rarity color in the row, in the words or none. Until you give it a size of its own, it takes the build list's. At a larger text size, what a piece gives no longer runs into its slot.

**Experimental** (a new group of tabs: everything there is for testing and may change; feedback welcome on Discord)
- **No backgrounds:** one switch takes the dark ground away from the windows, leaving their words, icons and bars on the world: the build list, the jewelry worn, the damage meter and its extra windows, Biggest Crits, the loot list, This Run, the Stats panel and the chat's panel. Off by default. Each window has its own chip: untick one to keep its background. Rows keep their own fills (the meter's bars, the build list's spell colors, the loot and jewelry quality colors). It applies at once, with no reload, and Move UI moves and sizes the windows as before.
- **The chat:** with the Panel look, its ground, edges and the line under the tabs go, and the tabs, copy button, grip and typing box stay. Text on the world keeps its own Background.

**Languages**
- **The options window in Chinese:** with the game in Chinese, the whole options window is in Simplified Chinese: every tab, its help and tooltips, the previews, the confirm boxes and the search, in the game's own words for its spells, stats and terms. The search finds a setting by its Chinese words, or its English ones. In English the window stays as it was.
- **Chinese words for their place:** the Minimap buttons' Left and Right read as the way the row grows (向左, 向右), apart from the party buffs' side (左侧, 右侧); Run History's time zone line names China's zone first, then Brazil's and Portugal's.
- **Russian** (a first version; feedback from Russian players welcome on Discord): with the game in Russian, the run panels, Biggest Crits, the meter, the build list, the character pane, the Jewelry Collection, Run History, Career, the Guide, Change UI, the minimap buttons and the chat help speak Russian, in the game's own words (забег, босс, страж, логово, тайник), in your global font when it has the whole Cyrillic (Friz Quadrata, Arial Narrow, Fira Sans, Noto Sans, Russo One), else in Noto Sans SC; the font lists in Russian offer only the fonts that write it. The options window stays in English in Russian for now.
- **The Guide fits in Russian:** the Sets page's class buttons share the row by their names; the Reduction page's talent chips and the Damage page's buffs take a long name on two lines; the Luck page's formulas start past the longest rarity name; "How often:", "How hard:" and "Best pick:" have their space back.
- **The game's language from the game:** it now comes from the game itself as the interface loads, so Russian is told from Ukrainian for every race and the language's font is worn from the start; older games are still told by the hero's race. The meter's Melee row and Career's maps now show in your language too.
- **The launcher in Russian:** pick Русский in Language on the Play tab. With no choice made it follows the game's language, and on a Chinese or Russian Windows with no game language yet it opens in Chinese or Russian. Russian counts its numbers right (1 забег, 2 забега, 5 забегов) in Statistics, Run History and the alerts.

**Everywhere**
- **Reset this page** on each of these tabs, asked first: the looks go back to their first; where things stand stays.
- **Biggest Crits:** its header now points to Records for the new best crit.
- **Tabs in their place:** Range indicator moved to Combat, after Combat text; Jewelry worn to Character, after Build list.
- **A setting that depends on another** fades and stays still while that one is off, and says why on hover.
- **Nameplates tab:** it no longer says Survivor Plates is missing when another addon makes Survivor UI load first.
- **Your hero as you picked it:** with another class picked in the menu before the run, the game kept telling addons the hero it opened with. Your frame, the addon's color and the cursor wore the first class's color, the character pane read the first race ("Troll Warrior" for a Tauren Warrior), and your racial's lines were kept under that race. The addon now takes the hero's class, race and name from the run itself. Run History mends the runs it saved that way: their class is the one you played again (the race and the name stay as saved).
- **Combat text fits again in Advanced:** its fine settings ran under the page's foot. The game's numbers' size now goes a step at a time beside their title, and the fine settings sit three to a row.
- **Jewelry Collection, long names:** a name too long for its row (in Russian, or at a bigger text size) is a point smaller, or cut with "..." with the whole name in its tooltip. The group titles and the window's title fit too.
- **Jewelry Collection counts:** 16 amulets and 14 trinkets to find, as the game's codex has them since the Star of Mystaria became a trinket. It said 17 and 13 ("14 / 13", and "1 more to find" with every amulet found).
- **Jewelry worn by name:** a name that takes the whole row no longer has " · ...+" drawn over its end.
- **Jewelry worn, long names:** by names, a long name is a point smaller (never under 7) or cut with "...", its rank kept ("Безупречная зачарованная водоросль... II"), the whole name on hover; a text size changed after a cut no longer runs it out of the panel.
- **Damage meter under the right column:** a meter moved right under the column no longer ends up over Jewelry worn when the run tracker grows a row. It stands right under the column, with fewer lines if the screen's bottom is near, and goes back to its place as the column shrinks.
- **Damage meter lines:** lines set in the options or on its card no longer reach past the screen's bottom and over the right column; the rest roll by the wheel.
- **Damage meter Reset:** as wide as its word (Russian's is longer), with the fold button left of it.
- **Guide:** a paragraph or tip that takes more lines than planned pushes what follows down; the DoTs page's facts and the Marks page's cards grow to their words, and a set's bonus too long for its column takes a smaller size.
- **No more "cast":** the Guide's Haste and Not DoTs pages say a spell goes off, as it does in this game, in English, Chinese and Russian, and the Haste page's "This spell" line has room for two lines. The character pane's Damage tip too.

**Game 0.140 (Scholomance)**
- **Kill Command:** the Hunter's Jewelry Collection now counts Kill Command's legendary amulet, Heart of the Packlord, in place of Explosive Trap's, which the game no longer offers.
- **Giantstalker's in the Guide:** the 8-piece bonus now reads as the game's: Kill Command's cooldown 20% shorter and 30% more damage.
- **Tier 0.5 in the Guide:** the Sets page has each class's seventh set, from Scholomance: Heroism, Soulforge, Beastmaster, Darkmantle, Virtuous, Five Thunders, Sorcerer's, Deathmist and Feralheart. Each has a 4-piece bonus of its class's own and its 8-piece bonus at 3/5; at 5/5 it takes the numbers the game gives it instead of growing by half. The Marks page's table has its star costs: 5.5, 11, 16.5, 22 and 27.5 marks at no discount. The Guide's window is a little taller to hold the seventh set.
- **Dread Lord:** the warlock's Pit Lord is a Dread Lord from this version; the damage meter gives it its icon again, the game's own for it (Pact of the Nathrezim's), in every language, and its Searing Pain shows as the Dread Lord's Felseeker in Biggest Crits and the combat numbers. The Summons show up to 2 Dread Lords again, with Pact of the Nathrezim's clock on them. The Pit Lord's name still works.
- **Other languages:** Kill Command, the Devilsaur Matriarch and the game's changed bonus lines are read back in English again.

### v3.0.55, 2026-11-03

A tab of their own for the minimap buttons, with your order, your colors and a live preview, and your friends' buffs on any side of the party frames.

**Minimap buttons**
- **A tab of their own:** the options' new **Minimap buttons** tab, after Minimap, holds the squares beside the minimap: a live preview of them by a corner of the minimap, then a row for each with its switch, two arrows to move it in the order and, for the spell effects, sound effects and range ring, its key. The switches and keys left the Minimap tab for it.
- **Your order:** any of them can come first, the [S] too, and each one shown or hidden. Hide the [S] and `/sui` still opens the options.
- **Your colors:** each one in the class's color (as before) or one of nine others: gold, white, red, orange, green, teal, blue, purple or pink. The Guide's square starts gold as before. **All in this color** paints every button the same.
- **Line up, size and gap:** a column up (as before) or down, or a row to the left or the right; the squares from 12 to 28 (16 as before) and the gap between them from 0 to 12.
- **They move as one:** in move mode they are now one piece, **Minimap buttons**, so the whole line moves together; a place you set before stays.

**Party frames**
- **Buffs on any side:** your friends' buffs can go left of their frames (as before), right of them, over them or under them. Over or under, the frames stand a line of buffs further apart; on the right, until you move them, the frames stand further left of yours so the buffs fit. The Party tab: **Buffs**.
- **Layout preview:** the Party tab draws a full party beside your frame as it will look: the order, the buffs' side, a friend down and one far away. The samples you see while placing the frames show some buffs too.

### v3.0.54, 2026-11-03

Bosses and awake guardians that move on the minimap, your shield in your health numbers, your friends' buffs and distance on the party frames, debuffs inside the nameplates and a button for your range ring.

**Minimap**
- **On the move** (asked by ZA5TEESH): an awake guardian's lair pin follows the guardian while it fights, and goes back to its lair once it is slain. Each boss gets a horned skull that goes where it goes, the final boss in an orange glow. Elites can get a bone skull too (off). The options' Minimap tab: **Lairs follow their guardian**, **Bosses** and **Elites**.
- **Range ring button** (asked by Silveryxd and sh1Neee): a ring over the sound button hides your range ring, on the minimap and round you, in a click; the next click brings back the rings you had on. A key of its own too, none by default. The options' Minimap tab: **Range ring button** and **Range ring key**.

**Nameplates** (Survivor Plates)
- **Debuffs inside:** on elites, guardians and bosses, our debuffs in small icons inside the bar, from left to right. Your target among the rank and file keeps them over its plate. Off with **Debuffs inside the plates** (Nameplates, Look).

**Unit frames**
- **Your shield in the numbers:** while a shield is on you, your health numbers count it too, in light blue, the share going past 100%: `878 | 155%`. Off with **Shield in the health text** (Unit frames).

**Party frames** (asked by Jocke and ebgl_menios)
- **Buffs:** each friend's buffs in small icons beside their frame; hover one for what it is.
- **Distance:** past 30 yards a friend's frame fades and says how far (`33 yd | 73%`); hover it for the yards. Heals and shields in this game are only your own, so this is to keep the party together. The Party tab: **Party buffs** and **Party distance**.

**Cards**
- **Stats panel over the cards:** the Stats panel can stay in sight while you choose a level's cards (the options' **While choosing cards**).

### v3.0.53, 2026-11-02

New nameplates in SurvivorUI Classic's look, each elite, guardian and boss told apart by the game itself. Light beams over the caches, a ring for your range, the mouse cursor over the game's screens and the marks in Run History.

**Nameplates** (Survivor Plates)
- **A new look:** a thin bar with a black line round it and slightly rounded corners, the name over it and the health's share small inside, on the right.
- **Each kind its own:** the rank and file red, elites green, lair guardians blue, bosses purple, the final boss orange, each a little larger. The game tells each one's kind (its 0.139.2), so a guardian and an elite of the same name each wear their own color.
- **Skulls over the name:** a bone skull on an elite, its lair's mark on a guardian, a horned infernal skull on a boss and the final boss.
- **In front:** in a crowd a boss's plate is over every other, then a guardian's, then an elite's; the rank and file behind and a little faded (never your target).
- **Your target:** a gold line round its plate, its debuffs over it.
- **The mouse:** the plate under it glows softly and comes to the front; with clicks going through the plates, it is the only one that takes the click. A boss bar under the mouse lines its enemy's plate in white.
- **Friends:** thinner plates in a gold rim: a co-op friend in their class's color, your pets, summons and totems in mint.
- **On for everyone, once:** the plates come on (even if you had them off), with the rank and file off; elites, guardians, bosses, pets, totems and co-op friends on; a name on every plate. The options' Nameplates tab and `/splates` change any of it after.
- **Your target, whatever its kind** (new, off): on, your target gets a plate even when its kind is off.
- **With the world markers:** a lair's big mark steps aside while its guardian's plate shows, and with **Draw the enemies' marks** the mark sits left of the plate's bar.

**World markers**
- **Light beams over caches:** a column of golden light over each cache, a pool of light under it and the chest floating near the top, bobbing slowly, with how far. Thinner and shorter far away, faint where your hero stands in front. Off (**Light beams over caches**), the chest near the ground as before.
- **Your range** (an idea of ProTecz's): a light blue ring as far as your build's longest damaging spell reaches, heals, shields, buffs and racials left out: on the minimap, and in dots on the ground round your hero. Both on, each on its own in **Your range**. It follows your build as it changes.

**Mouse cursor**
- **Over the game's screens** (reported by Nomad): the colored gauntlet stays over the level-up and treasure cards, where the game's cursor used to come back. The game's Esc menu covers whatever an addon draws, so where Esc does not pause (a co-op run, the town, "Move to begin") the Gauntlet shape is the game's own gauntlet, with the effects round it.

**Run History**
- **The run's marks** (asked for by jiminee): the Loot box says the marks the run earned at its title, and hovering them shows each boss's marks and your class's total, as the loot list's card does. Runs saved before keep their box as it was.

**New defaults** (for a new install)
- **Boss bars off:** the plates show the bosses now. `/sui bosses` brings them back; whoever has them keeps them.
- **Raid marks:** bosses, guardians and elites marked, drawn over them.
- **Run tracker:** the guardians as a count ("Guardians 4 / 4 alive") in place of the bar, and no level and experience line.

### v3.0.52, 2026-11-02

Marks on the world itself with the game's 0.139.2: friends down, caches, lairs and your enemies' marks, right where they are. Two new Guide pages, Haste and Speed.

**World markers** (a new tab in the options, Interface)
- **Friends down:** in a co-op run, a gold cross over a friend who is down, with their name and how far. Their party frame says how far too: DOWN 23 yd.
- **Caches:** a chest over each cache still there, and how far.
- **Lairs:** the guardian's name over its lair while it sleeps. Awake, the name follows the guardian out of its lair; slain, it goes back over the lair with the time until the guardian comes back.
- **Arrows:** for friends down, caches and lairs out of sight, an arrow on a ring round you toward the nearest few, with how far.
- **Explosive orbs:** in a run with the Explosive affix, a pulsing mark over each orb.
- **Bars over elites, guardians and bosses** (off at first, a test): their name and health over them, with no nameplate.

**Raid marks**
- **Drawn marks:** with **Draw the enemies' marks** on, as it comes, every boss, guardian and elite of a kind ticked in the Raid marks tab wears its mark at once, drawn over it, and your target is never taken. Only you see them. Off, the game's raid marks as before. The co-op heroes keep the game's.

**Combat text**
- **Far numbers fade** (Shows): with the numbers over the enemies, hits on enemies more than 20 yards away grow fainter.

**The Guide**
- **Haste:** every cooldown bonus is added into one number, and every wait is divided by 1 plus it. The game shows Haste as how much sooner, so its 50% already means twice as many spells, and 75% four times as many. There is no cap, but no spell comes back faster than 0.25 sec. **Echo** has no cap either: past 100% every spell strikes twice and the rest is the chance of a third, and each strike is a whole cast, aiming again and rolling its own Crit. Sliders for both, a spell's casts a minute in marbles, and the strikes of one cast.
- **Speed:** Speed stops at +120%, 15.4 yards a second. Pickup bonuses multiply each other, so two give more than their sum. Area widens every radius and reach: +100% doubles the radius and covers four times the ground.
- **In Chinese:** both pages read in Chinese with the game in Chinese.

### v3.0.51, 2026-11-02

A fix for v3.0.50. Thanks to N3x and Amarolk for the report.

**Fixed**
- **The options button on the minimap:** after the first level's cards it stayed invisible until the next reload, though a click and the tooltip still found it. It now comes back with the rest of the minimap.

### v3.0.50, 2026-11-02

Two new Guide pages on your gear, Marks and Sets, and the level's cards come clean: nothing of ours over them unless you ask for it.

**The Guide**
- **Marks:** what each star of a piece costs, rarity by rarity, and what all 8 pieces cost to 3 and to 5 stars. **Other classes done** sets how many of your other classes have that set done: each takes 5% off, up to 40%, as the game counts it. The three stars that open something on a set are there too, and hovering Empowered shows what it does for your class.
- **Sets:** every class's six sets, their 4-piece and 8-piece bonuses with the numbers, and the zones each one drops in. Pick a class, opened on yours, and the stars: 4 pieces, 8 pieces or Empowered. The part of each set those stars give lights up, and at Empowered the numbers that grow turn gold. Each set's name wears its color, as an item's does in a tooltip.
- **In Chinese:** both pages read in Chinese with the game in Chinese, in the game's own words for the sets, the zones and the bonuses.

**The level's cards**
- **Hidden while you choose a card:** on a small screen the game's cards are large, and Survivor UI's pieces stood on them. Every piece now hides while you choose a card or a new piece of jewelry, and comes back after.
- **Your pick of what stays:** in the options' Layout tab, **While choosing cards** has **Hide everything while choosing cards**, and under it a box for each piece: the run tracker, the build list, the jewelry worn, the damage meter, This Run, Biggest Crits, the XP bar, the minimap, the chat, the boss bars, the party frames and everything else. Untick the first for everything as before, or tick only the meter, say.
- **A note, once:** the first time you wait in town or at **Move to begin**, a box says so, with **Keep it hidden**, **Show as before** and **Choose pieces**.

**Fixed**
- **The level-up line in the chat** (the game's 0.139): "You have gained +3% damage..." came back with every level, as the game no longer sends its level-up event in a run. With **Level-ups** on in the options' Chat tab, it is kept away again, in every language.

### Azeroth SurvivorUI Launcher 1.9.0, 2026-11-01

Our own high-speed mirror for the game, and the launcher in Chinese.

- **Our own mirror:** Get the game now has a mirror made for this launcher alone, about 11 MB/s in our tests. It comes first in the list while it gives over 256 KB/s, marked **our mirror**, with the other sources behind it, and a far quicker source still takes over during the download. The package is checked by the same size and sha256 as ever.
- **English or Chinese:** one launcher, both languages. **Language**, on the Play tab, starts the launcher again in the other in a second or two. Until you pick one it follows the game's language, so a game in Chinese opens a launcher in Chinese. Tabs, buttons, tips, messages and boxes are translated; the game's news and what comes from your save, such as zone and spell names, stay as they are.
- **Ad free, as always:** a small note, shown once, tells of the mirror and points at **Donate**. One click closes it.

### v3.0.49, 2026-11-01

The Guide comes to Survivor UI, in English and in Chinese. Crits now follow the game's own meter lines, the loot list counts your marks, your jewelry becomes a panel of its own, and the game's clock and the new Enhancement Shaman are in.

**The Guide**
- **The Guide:** six pages on how the game's numbers really work, Luck, Damage, Crit, DoTs, Not DoTs and Damage Reduction, with sliders to try and your own hero's numbers. The gold square on the minimap's stack opens it, with a ! while a page is unread, and so does `/sui guide`. The options' Minimap tab hides the button. Its words are in English for now.
- **A word from the Guide:** the first time you play with this version, a small card beside the Guide's button says it is there. It shows once, and never again.
- **The Guide in Chinese:** with the game in Chinese, all six pages, their tooltips and the names on them read in Chinese, in the game's own words. Talents such as Frostbrand Weapon now show their Chinese names across the addon too.

**Crits and combat numbers**
- **The Shaman's free casts in the crits, for real** (the game's 0.139): the game now says which meter line each hit belongs to, so Biggest Crits and the numbers name each hit exactly: a Fire Nova from Flametongue Weapon is the talent's even with Fire Nova in your build, and so is a Frost Shock from Frostbrand Weapon. The same goes for any proc that borrows a spell, like a Shadow Weaving strike or a Chastise from Holy Nova.
- **Biggest Crits in the meter's own lines:** a Warlock's demons, a Hunter's traps and every summon read as they do on the meter: a Felguard's crits under Felguard, an Imp's Fireball under Imp, and no more Unknown line.
- **Over the enemies, for real** (the game's 0.138): with Combat text's **Over the enemies**, each number stands over the very enemy it hit, with no nameplate needed. It stays over the spot where that enemy fell as you turn or move, and hides when that spot leaves your view.
- **Talent icons in every language:** with the game in another language, a talent's line on the meter now shows its icon and color, in place of the addon's square.

**Loot list**
- **Your marks in the loot list:** its title shows the marks of this run, a boss's and those of pieces you already had. Hover them for a card with each boss's marks, one under the other, with the second they came.
- **Repeats in the loot list:** the same piece again in a run is one bar, x2, x3, also in Run History.

**Build list and jewelry**
- **Jewelry worn, a panel of its own:** the jewelry leaves the build list. It has its own switch in Modules, its own tab under Run, and moves and sizes on its own. Left where it is, it sits under the build list as before, or in its place with the list off.
- **Jewelry by its name:** in the Jewelry worn tab, **Each piece shows** can now be **Its name**: the piece's name alone, cut when long, with its stats on hover.
- **The crits' card and the build list's tooltips open towards the screen's middle:** with Biggest Crits, the build list or the meter moved to either side, they no longer land on their own window.

**Damage meter**
- **The damage meter's height:** **Height** in the options' Damage meter tab, 3 to 20 lines. With more to show than lines, a scroll bar comes up at its right: drag it, click it or use the wheel. The other meter windows have it too.
- **A friend's build on the meter:** in a co-op run, hover a hero on the Party Damage page for their damage by spell, their jewelry and their talent points. It comes from the game's own feed, so it needs nothing from their addons.

**Minimap and clock**
- **One clock on the minimap** (the game's 0.136): the game's new clock under the minimap is put away, and ours now reads your computer's time, with no time zone to set, and so do Run History's dates. Hover it to see what a click does: its box has **Your computer's time** to tick, or untick for a slider to any time zone you want, and **24-hour clock** to tick for 24 hours or untick for 12. Untick **Clock and FPS** in the options' Minimap tab and the game's clock comes back, the kills and gold line and the run tracker stepping down under it.
- **Lair timers on the minimap:** tick **Lair timers** in the options' Minimap tab to see, under an empty lair's pin, how long till its guardian is back.
- **The minimap's pins and the guardians' arrows follow you live** (the game's 0.132), in dungeons and raids too. They used to jump about once a second.

**Run History**
- **Your talents in Run History:** each run now keeps the talents you really had, from the game's own numbers, drawn as the class's three real trees: every talent in its place, the ones you learned lit with their rank, the rest dim, with the points in each tree over them. Hover one for its name and rank.

**Frames and pieces**
- **The target's debuffs move on their own:** a new **Target debuffs** piece in Move UI, so a target frame near the top of the screen no longer pushes them off it. Left where it is, the row follows the frame.
- **The class bar stays out of the level's cards:** soul shards, combo points, the Lightwell and Bloodrage came through the cards when they sat behind them. They now go while you pick, as every other piece does.
- **The XP bar's card stays on the screen:** with the bar at the foot of the screen it opens over the bar. Every tooltip and the crits' card are kept on the screen too, and dragging the bar stops with its odds still on the screen.

**The new Enhancement Shaman**
- **The new Enhancement Shaman** (the game's 0.134 to 0.137): Rockbiter Weapon goes by its full name in the build list, the meter and Biggest Crits, and its tooltip and Stormstrike's wear Nature's color. The new talents have their icons, and the game's new words are read in every language.
- **Stormguard on the stats panel** (Earthen Bulwark until the game's 0.137): the Armor tooltip says whether it is active, in the game's own words.
- **Call of Flame is out:** the Shaman no longer has that spell, so nothing is named after its blast.

**Fixed**
- The first click on the minimap's time did nothing: its box now opens at once.
- With that box open, the FPS beside the time dropped to 1.

### v3.0.48, 2026-10-31

The plate under your mouse lights up, plates can overlap, and a hunter's pets go by one name.

**Survivor UI**
- **A hunter's pets, one name everywhere:** the game's meter adds the Wolf and the Raptor up as Pets, while Biggest Crits and the combat numbers had them apart. They all say Pets now, in one color, with Call Pet's icon, the meter's line too, which had none.

**Survivor Plates**
- **Overlapping plates:** the game's new Nameplate Layout (its 0.131) is set to Overlapping once for everyone, as each plate then stays right over its enemy. **Overlapping plates**, in the options' Nameplates tab, turns it back to Stacking; the game's own option stays in step.
- **The plate under the mouse:** a white line round its bar and the letters of its name, in front of the others. With clicks going through the plates, it is the only one that takes a click, so a click on it targets its enemy and the camera still turns from over the rest.
- **The execute line is out:** the mark at 30% on every plate. The bar still turns yellow there.

### Azeroth SurvivorUI Launcher 1.8.0, 2026-10-30

- **Out of beta:** the version line and the window's title no longer say so.
- **Both addons on a new PC:** a launcher opened on a PC with no launcher before it installs Survivor UI and SurvivorUI Classic by itself, once the game is there (right away, or after Get the game), and says so in one box. If either addon is there already, it leaves them as they are. A launcher that was already on the PC changes nothing.
- **Auto Update when ready:** a tick on the rows of our addons in the Addons tab, on unless you untick it. A newer release is taken by itself as soon as the game is closed, with no box. Survivor UI and Survivor Plates share one tick, as they come in one zip; SurvivorUI Classic has its own.
- **(recommended)** by SurvivorUI Classic too.
- **Uninstall gives the game back what our addons put away:** uninstalling Survivor UI or SurvivorUI Classic brings the game's own screens back, the red flag on the minimap among them, and its damage numbers, as those stay off in the game's `config.toml` otherwise. Survivor UI and Survivor Plates now have an Uninstall button of their own and go together, as they come together. The game must be closed.
- **A progress bar for the game:** Get the game and Update game show a bar over the status line, on every tab, with the same words on it.
- **What waits, as the window opens:** a box lists a newer game and each addon you installed from the list with a newer release, with **Update now** or **Later**. Anything that updates by itself stays out of it, and the same list isn't shown twice while the launcher runs. Addons put in by hand aren't in it.
- **A safer place for the launcher:** when Get the game ends, it offers to move itself into the game's folder with a shortcut on your Desktop, or to add only the shortcut, so that it isn't left in Downloads to be deleted by accident.
- **Update game no longer brings Survivor UI back:** before, it installed Survivor UI after an update if the folder wasn't there.

### v3.0.47, 2026-10-30

Three fixes: the experience strip under the action bar, two buttons left showing in the corner, and the chat's scroll buttons.

**Survivor UI**
- **Two experience bars** (reported on Discord by .slak): with the run tracker off, the game's experience bar came back as a thin strip under the action bar, even with the XP bar showing at the top. It can't be moved or sized, so it looked like it came from somewhere else. It now stays away while the tracker or the XP bar is on, and returns only with both off.
- **Two buttons in the bottom left corner:** since v3.0.46, the game's Character and Talents buttons stayed on show after the first level's cards, where they should wait unseen until the mouse reaches the corner. Fading the whole game bar under the cards brought them back. Only the action buttons fade now.
- **The chat's scroll buttons:** clicking another chat tab, such as Combat Log, brought the game's three scroll buttons back beside the chat, and they stayed. With Flat chat on, they stay away now.

### v3.0.46, 2026-10-30

Change UI: a button that picks Survivor UI or SurvivorUI Classic, and with the launcher the game restarts by itself. And no more icon on top of the level's cards.

**Survivor UI**
- **Change UI:** a button at the foot of the options' sidebar, with SurvivorUI Classic installed, opens a box with a card for each interface, the one in use marked. Pick the other one and the box offers Quit game or Later: the other one runs from the next time the game starts, as the game loads its addons only at its start. SurvivorUI Classic turned off in the game's Options, AddOns tab can't be picked; the box says where to turn it on.
- **The same box, in the addon's look**, in place of SurvivorUI Classic's panel while Survivor UI is the one running: the first question with both installed, and `/suic`.
- **Restart game:** with the launcher open, Quit game in that box becomes Restart game: the game closes and the launcher opens it again by itself. Without the launcher (the game opened some other way, in a browser, on a Mac) it stays Quit game, and you open the game again yourself.
- **An icon through the level's cards** (reported on Discord by Zaynor): the first action button's spell icon could show on top of a card. The bar's buttons stayed lit under the cards while the rest of the row faded. They fade with it now.

### Azeroth SurvivorUI Launcher 1.7.1 (beta), 2026-10-30

- **Restarts the game when Change UI asks:** while the launcher runs, a small addon of its own, only a `.toc`, stands in the AddOns folder, so Survivor UI and SurvivorUI Classic know it is there. The game closed by Restart game, the launcher opens it again. Exit takes that addon away, and it isn't listed in the Addons tab.

### v3.0.45, 2026-10-29

The addon's pictures in the game played in a browser and on the Mac, and each hero's DPS on the Party Damage page.

**Survivor UI**
- **The addon's pictures in the browser** (reported on Discord by kemot, Fulger and Floowi; kemot found the way): the minimap's cache and lair pins, the guardians' arrows, the minimap buttons and every other picture of the addon's were missing in the game played in a browser (Chrome, Brave) and in the macOS port, which read no TGA. Each now comes as a BLP too, the game's own format, which every version of the game reads first. In the Windows game nothing changes: the same pixels.
- **Each hero's DPS on the Party Damage page**: in a co-op run, the damage meter's Party Damage page shows each hero's damage a second beside their damage, in gold, as the DPS over the bars. Before, it showed only on hover.

### v3.0.44, 2026-10-29

SurvivorUI Classic is out: a branch of Survivor UI in the game's own look. Survivor UI and Survivor Plates step aside when it is chosen. And where the tooltip opens, yours to choose.

**Survivor UI**
- **Steps aside for SurvivorUI Classic** (new: [SurvivorUI Classic](https://github.com/morderous/survivorui-classic), a branch of Survivor UI in the game's own look, also in the launcher's Addons tab): each works on its own, and neither needs the other. With both installed, SurvivorUI Classic's panel asks which of the two to use, as they change the same frames. Pick SurvivorUI Classic and, from the game's next start, Survivor UI loads nothing at all: no frames, no options, nothing of the game's put away. Pick Survivor UI and nothing changes. Without SurvivorUI Classic installed, nothing changes either.
- **Where the tooltip opens** (asked on Discord by ProTecz): `/sui opt`, Frames & bar, Tooltip. At its anchor (beside the damage meter, or where you moved it, as before), at the mouse, or left to the game: never moved, for another addon that places the tooltips. Before, Survivor UI moved it even with every module off.

**Survivor Plates**
- **Steps aside for SurvivorUI Classic too**: with SurvivorUI Classic chosen, the plates load nothing from the game's next start, as Survivor UI; the game's own nameplates show.

### v3.0.43, 2026-10-29

The game's own damage numbers in a font and size of yours; a DPS page, Others and each window its own size in the damage meter, the windows linked; damage and crits over Biggest Crits; elites in green; and launcher 1.7.0, with addons added from GitHub.

**Survivor UI**
- **A DPS page in the damage meter** (its title's menu): each spell's damage a second instead of its damage, with its share. It counts on the same clock as the DPS above the bars, so the column adds up to it, and Reset starts it over too. Hover a line for its card, as on Damage Done. Its strip shows **NOW** and **AVG** (a second on average, since the run began or Reset); the total is Damage Done's.
- **Each damage meter window its own size, and linked windows**: in move mode, a meter window's card has its own **Width** (180 to 400) and **Height** (3 to 20 lines), the main one's and each other one's apart. Let a window go against another, side by side or one under the other, and it is linked to it: move the first and the others come along; drag one away to unlink it. The main window is linked to none: let it go against another and that one is linked to it. Its card says what a window is linked to; Reset puts back its first place and size.
- **Fold the small lines**: a small button in each meter window's title, left of Reset, folds the lines under 10% of the total into one grey line at the bottom, **Others (5 spells)**, with what they add up to, their share and a few of their icons. Hover it for each of them. Gold while on; every meter window follows it. The share goes from 1 to 20% in the options' Damage meter tab. The party's page keeps each hero on their own.
- **Biggest Crits: your Damage, Crit and Crit Dmg under its title**, in a strip as the damage meter's, as the Stats panel reads them (+200%, 22.0%, 232%), the damage first and set apart, bigger and in the bright gold, on a gold wash: every other number grows from it. When it changes, a card or a level, the number flashes green (red for a loss) and eases back to gold. Hover it for what each is, and your average hit: x2.48 its base, what the three make together. The options' Biggest Crits tab switches it off.
- **Biggest Crits from the run's start**: the box shows as the run begins, its strip of damage and crits with it, and "No crits yet." until the first one; then it fills as they come.
- **The XP bar for everyone, as it looks best**: on, with the time to the next level, your luck and the cards' odds beside it as numbers (the spells' and jewelry's on its left, the amulets' on its right), without the experience a minute and the odds' ribbon. Set once for everyone with this version; the XP bar tab changes it after that, and keeps what you choose.
- **Elites in green**: bosses in the epic's purple, guardians in the rare's blue, and elites now in the uncommon's green, in place of the legendary's orange, so the colors climb as the item qualities do. The boss bars, This Run, the run tracker, Run History and Survivor Plates alike; a lime green, apart from your pets' mint on the plates.
- **The game's own damage numbers, in a face and size of yours** (Combat text, The game's numbers): the game draws its numbers over the very enemy hit, where ours, told only the enemy's name by the combat log, have to guess among enemies of one name. Pick one of four faces (Barlow, Exo, Fira, Noto) and a size, from 100% down to 40%; picking one switches the numbers to the game's. It shows from your next run: the game reads the face as it enters the world. The game's own face keeps its own size. Thanks to Free for the report.
- **Over the game's cards, the bottom middle clear**: while you pick a card, every piece at the bottom middle of the screen fades out too (the action bar, the player and target frames, the buffs), where the game puts its row of spells, Skip and Reroll; and the cards' part of the screen is wider, for a larger HUD scale. The pieces at the sides stay lit as before; the Layout tab's **Over the game's cards** switches it all off. Thanks to winter for the report.
- **The zone's name centered over the minimap**: it hung where the round minimap sat, off the square's middle.
- **A legendary amulet's bonuses no longer run over its name** in the build list's Jewelry: when they do not fit, the first ones show and "...+" ends the line; hover the row for all of them, in the piece's own tooltip.
- **A crit card as wide as its title**: a talent's or an amulet's long name (Amulet of the Inferno: Consecration) no longer runs past its edge. Such a copy of a spell says that the combat log counts its hits under the spell's own name, on the spell's card, in place of two empty lists.
- **The Stats panel's bonus damage numbers show when you ask for them**: Execute, Vs Controlled, Vs Afflicted, Shielded, Melee and Pet Damage showed only once your hero had some, even with **Hide the numbers at 0 or below** off. They now follow that option as the other numbers do. Thanks to GilgaMocha for the report.
- **A Stats panel you sized grows to hold its numbers**: with more numbers on than its size holds at their smallest, the last ones were cut off at its bottom. It now grows to show them all.
- **The odds beside the XP bar sit centered under their titles** (Spells & Jewelry, Amulets), in the numbers look.

### Azeroth SurvivorUI Launcher 1.7.0 (beta), 2026-10-29

- **Add from GitHub** (Addons tab): paste an addon repository's link, or just its owner/name, and the launcher looks it up: its newest release, a beta when it has only betas, or its source as it stands when it has no release. It reads the zip for the addon's folders and its `.toc` (name, author, notes), then shows what it found: **Add to my list** or **Cancel**. Installing is a step of its own, from the list, when you choose. When a release carries several zips, you pick the one that is the addon.
- **Yours, as if listed**: it joins the list marked "(added by you)", under the checked ones, with Install, Update all, Uninstall, on or off, and the update pill, under the same rules: only its own folders and an addon's kinds of files, never a program, never over Survivor UI's folders. It is not one morderous checked, so the launcher says so before its first install. **Remove from my list** takes it off again; its folder, if installed, stays as one put in by hand.
- **On your PC only**: your list is `my-addons.json` beside the launcher's settings (`%APPDATA%\SurvivorUIInstaller`). The launcher sends it nowhere; it only asks GitHub for each repository's releases. If morderous later checks the same addon, the checked one takes its place.
- **GitHub's limit, and a spare way**: without a login, GitHub's API answers 60 asks an hour from one address, and each addon is one ask a check. Once they are used up, or the API does not answer, the launcher asks GitHub's own pages instead, which count none of them: the latest release, the betas, a release's files, a branch's newest commit, whether a repository is there. The addons you add and the checked ones alike, so the list and Update all keep working. The pages give no zip's size; the author's sha256, where there is one, still holds.

### v3.0.42, 2026-10-28

Spell effects and sound effects on or off from the minimap or a key, Run History's photo filling the screen, and the party frames top to bottom from the top of the party's place.

**Survivor UI**
- **Two switches by the minimap** (from tomlrd's pull request; new art, restart the game once): over Run History's hourglass, the game's **No Spell Effects** (no explosions, missiles, glows or beams) and its **sound effects**, muted and back to their volume, each in a click. The game keeps no sound of the spells apart, so the hits and the clicks go with them; the music and the ambience stay. Each is struck through and dimmed while off, follows the game's own pages, and has its option and **a key of its own** (Minimap tab, **Spell effects key** and **Sound effects key**, none by default; Key Bindings in the game's menu lists them too).
- **Run History's photo fills the screen** (from tomlrd's pull request): the game's screenshot takes the whole screen, so the page now does too, as large as it goes whole, in front of all, its backing and edge drawn out to the screen's edges.
- **Party frames top to bottom start at the top**: the first friend stands where the fourth stands bottom to top, and the others come down under it, so a full party takes the same place in either order.
- The pull request also brought a friend's build from their own Survivor UI, behind an icon by their party frame. It is not in: in a co-op run the game passes no addon's message from one player to another (tried with two games on its 0.126), so one Survivor UI cannot reach a friend's yet.

### v3.0.41, 2026-10-28

Survivor UI over the game's cards (its 0.126), the party frames top to bottom, and the launcher back in this repository.

**Survivor UI**
- **Over the game's cards**: while a level's cards or a new piece of jewelry are up, the game veils the screen, and the interface went dark under it. The pieces around the cards now stay lit over the veil, with their tooltips, and take their clicks there: the build list, This Run, the Stats, the Biggest Crits, the XP bar's chances, the damage meter, the run tracker, the minimap and the chat. The pieces in the cards' part of the screen (the action bar, the player frame, the totems, the buffs) fade out while the cards are up, so nothing covers a card, and come back as one is picked; a piece you moved there does the same. Layout tab, **Over the game's cards**, on by default.
- **No tooltip by chance while you pick a card**: the center bar (the action buttons, the player and target frames, the buffs) shows none while the cards are up, nor does an enemy left under the mouse as they open.
- **Party frames top to bottom** (Party tab, **Order**): each friend who joins goes under the last one instead of over it. The first friend stays level with your frame either way.

### Azeroth SurvivorUI Launcher 1.6.1 (beta), 2026-10-28

- **Back in Survivor UI's repository**: the launcher's source is in [`installer/`](installer) again, and it updates itself from this repository's releases, as it did up to 1.5.6. Launchers 1.5.7 to 1.6.0 take 1.6.1 from [survivor-ui-launcher](https://github.com/morderous/survivor-ui-launcher), where they looked, and follow this repository from then on. The Addons tab's list and Get the game's mirrors are read from `installer/addons.json` and `installer/mirrors.json` here.

### Azeroth SurvivorUI Launcher 1.6.0 (beta), 2026-10-28

- **The Addons tab**: Survivor UI and Survivor Plates first, recommended (the release, the beta, What's new, each on or off), the Survivor UI tab folded into it; then the addons from `addons.json` (ASBuilder, Azerloot, AZSSpellMeter, KeijinUI, SurvivorsDragonUi, thanks to their authors), each from its author's latest release, checked by its size and its author's sha256 where there is one; then the ones put in by hand.
- **Install, Update all, Uninstall, On or off**: only an addon's own folder and kinds of files come in, never a program (such as an auto-updater a release may carry beside the addon), never over Survivor UI's folders; Uninstall sends it to the Recycle Bin, its settings kept. Installed, Not installed or Outdated in the list; an addon off greyed.
- **The game's AddOns folder** and Check folder and move if necessary on the Play tab.
- **Credits and feedback** under every tab: Azeroth Survivors by Aethus, the launcher by morderous, and Feedback on Discord.

### Azeroth SurvivorUI Launcher 1.5.8 (beta), 2026-10-28

- **Get the game from the mirrors too**: the game's package also comes from the mirrors the game's Discord gave (thanks to Meexa and Leo), beside Aethus' own servers. Each is timed first and offered in a list with its speed, the fastest picked; or a package you downloaded already (.rar).
- **Checked before it is used**: a mirror's package only with the size and sha256 Aethus gave.
- **A broken download goes on where it stopped**, on a source that allows it, up to five breaks.
- **Try another source**: while it downloads, the Play button goes on with the next source; and a source that would finish three times later than another, for ten seconds in a row, is left for it by itself.

### Azeroth SurvivorUI Launcher 1.5.7 (beta), 2026-10-28

- Updated itself from a repository of its own, [survivor-ui-launcher](https://github.com/morderous/survivor-ui-launcher), for a while; Survivor UI's updates still came from here. Nothing else changed from 1.5.6.

### v3.0.40, 2026-10-28

New best crits that rise over the newest instead of making way, and No effect for the records, the new default.

**Survivor UI**
- **The last best crits rise over the newest** (from tomlrd's pull request): a newer best crit no longer wipes the one showing. That one steps up over the newest, smaller, and rises slowly as it fades in its own time, five at most. Early in a run nearly every crit is a new best, so they came and went before they could be read.
- **No effect** (`/sui opt`, Records): the last of each record's effects, the crit record's and the jump record's, and their default now: the gold number alone, without the sparks and shine behind it. An effect picked for a class before stays; picking one shows it, as before.

### v3.0.39, 2026-10-28

The run tracker's affixes and the totem counter as the game tells them, with its 0.124.

**Survivor UI**
- **The affixes as the game names them**: from its 0.124 the game tells addons a Heroic run's affixes, so the run tracker and Run History take them from it. Until now they were worked out from the week and the zone by the rule read in the game's exe, and checked against its chat line and the Explosive Orb's banner; an older game is still read that way. An affix newer than Survivor UI shows by its name.
- **The totem counter as the game tells it**: from its 0.124 the game tells addons how many totems of each kind stand and when the soonest goes, so the number over each totem's button and its seconds are the game's own. Until now each cast counted a totem for its tooltip's time, and Call of the Elements and Totemic Wrath were guessed from the spells a run starts with; an older game is still counted that way.

### v3.0.38, 2026-10-27

A hotfix: Run History and the launcher say a Heroic run's affixes.

**Survivor UI**
- **Run History says a run's affixes**: each run now keeps its affixes with it, and its head shows them as red chips beside its **Difficulty** (Heroic V, Sanguine, Explosive), each with what it does under the mouse. A run kept with v3.0.37 shows the ones its tracker had.

### Azeroth SurvivorUI Launcher 1.5.6 (beta), 2026-10-27

- **A Heroic run's affixes in Run History**: its head line says them after its level, "Heroic V (Sanguine, Explosive)".

### v3.0.37, 2026-10-27

Heroic difficulty and the week's affixes in the run tracker, its head and timeline drawn again, endless mode's bosses kept apart, the guardians' respawn timers, the XP bar's odds as bars, every talent's icon and tag in the meter, and fixes.

**Survivor UI**
- **The game's Heroic difficulty** (its 0.121, Heroic I to V in place of the Run Options): the kill pace now holds a run against runs of the same zone and Heroic level, a normal run keeping the normal runs from before; with 0.121 it had put normal and Heroic runs together. Its tooltip, the run tracker's and Run History's **Difficulty** say the level (Heroic III, or Normal), and the run tracker shows it in a tag (below).
- **The run tracker's head, laid out again**: the zone's name centered, in green; under it a row of tags, each in a thin border of its color: at the left the difficulty (Normal in grey, a Heroic level in orange) and endless mode (purple), at the right the week's affixes (red, below). Short by default (N or the Heroic level's numeral, an infinity sign for endless, a symbol for each affix: two chevrons up for Bolstering, a drop for Sanguine, a flame for Explosive), the full name under the mouse; Run tracker tab, **Tags**: **Difficulty in words**, **Affixes in words**, and **Centered** to gather them all in the middle. Victory, Fallen, Paused and the lives left follow the left tags. Run History's copy of the tracker the same.
- **The game's other languages, for its 0.121**: the new lines (the sets' bonuses, Heroic's numbers) read back in English as the rest; a line with two numbers in it now reads right.
- **Endless mode in the run tracker**: the game brings the zone's bosses back on the same lines of its list, so each endless boss used to take the place of one slain for the victory. The list now stays as it stood at the victory, every boss slain at the second it fell; under it, **Next boss** and its timer (the game does not say which), and **Endless bosses slain** with the count since endless mode began. Run History's copy of the tracker shows the same, and a boss's countdown there now reads in the game's language.
- **The run tracker's timeline, drawn again**: a thinner bar, still green (purple in endless mode), a white cap where now is, and a diamond for every boss where it comes in place of the white ticks: green slain, white the next, orange alive, grey and hollow still to come, the final boss's a little bigger in a gold ring. Only the next boss's countdown over it, no longer every boss's (the list under it has them all). Run History's copy of the tracker the same, the cap where a fallen run stopped.
- **The week's affixes in the run tracker** (Heroic III and up), as tags at the right of the row under the zone; hover one for what it does and from which Heroic level it counts this week. The game says them in the chat as a run begins ("Heroic V · Sanguine: ... · Explosive: ...", in its language), and Survivor UI takes them from there; before that line, or after a reload, it works them out the way the game picks them (the zone, the week, turning on Thursdays at 00:00 UTC, and the Heroic level: one from Heroic III, a second at Heroic V). An Explosive Orb's banner marks Explosive as seen. Told or seen otherwise than worked out means the game picks them another way now: Survivor UI says so once in the chat, and until it is updated shows only what the game told or showed. Run History's copy of the tracker keeps them.
- **The guardians' respawn timers in the run tracker**: Run tracker tab, Guardians, **Show as** is now a list with three counts. **A count and the next** (the count as it was, now with the next lair to fill: 0 / 4 alive · next 0:47); **Each lair's timer**, on the count's line in place of the count: each lair's mark, the time until it fills again in red, its health in orange while awake, a green pip while its guardian is there; **A count, timers under**: the count, and under it a cell a lair (its time, its health, or alive), the two in a box that holds the line together. Hover any of them for each lair by name. Run History's copy of the tracker shows the same.
- **The guardians' bar, your way** (Run tracker tab, Guardians): **Arrows: On the bar** takes the arrows off the bar (a stretch still flashes as you near its guardian), beside **North up** on the same row (Arrows north up before); **Lair marks**, as before, the marks; and **Bar thickness** makes it 4 to 16 pixels thick (9 as before).
- **The stats at 0 or less are hidden by default**, in the character pane and the Stats panel (Stats panel tab, **Hide the numbers at 0 or below**), and the option is on again for everyone once with this version; switch it off to see them.
- **The Stats panel as tall as its rows**: sized (as a new install has it, or dragged by its corner), its rows are as tall as the size makes them for every stat it can show, and hiding the stats at 0 or less now takes their room off the panel instead of leaving it empty.
- **The XP bar's side titles** (SPELLS & JEWELRY, AMULETS) stand a little apart from the legendary's odds.
- **Every talent's own damage with its talent's icon** in the damage meter and Biggest Crits (Nightfall, Daybreak, Rampage, Soul Devourer...): the icons come from the game itself, every class's talents, where before only the talents the 1.12 client also has showed theirs. And the tag after a proc's name says what it is: **(talent)** for a talent's own damage, **(neck)** for an amulet's (a class amulet's too, "Amulet of the Inferno: Consecration"), **(proc)** for the rest (a ring's, a trinket's); in Run History's copy of the meter too.
- **The odds beside the XP bar as small bars** (XP bar tab, **The odds as**): Numbers as before, **Bars filled** (each chance a bar of one size, centered under its title, filled in its rarity's color as far as the chance goes, full at 40%, the number inside), or **Tags** (the run tracker's tag look: a thin border and a dark wash of the color, the number in it). Their titles (SPELLS & JEWELRY, AMULETS) now in the luck's green.
- **A new install's XP bar**: the odds beside it as filled bars, the time to the next level under it and not the experience a minute (an install from before keeps its own). "Next lv. in" now in the level's light purple.
- **The XP bar's lines under it, each on its own** (XP bar tab): **Time to the next level** and **Experience a minute** show or hide apart (one choice before; whoever had it off keeps both away).
- **The XP bar says only how far into the level**, as a share (35%): the experience itself (766 / 2.22k), in the thousands late in a run, ran into the luck over the bar.
- **Item tooltips: the game's own for everyone**, in the flat look; the choice (Modules, and the Tooltips tab) is gone. The spells' tooltips are still laid out by Survivor UI.

### Azeroth SurvivorUI Launcher 1.5.5 (beta), 2026-10-27

- **Heroic in Run History**: a Heroic run (the game's 0.121) says its level after its zone in the list ("· H III") and in its head line.

### Azeroth SurvivorUI Launcher 1.5.4 (beta), 2026-10-27

- **Your victories and endless runs, kept for good**: Survivor UI's Run History keeps 100 runs at most. Each victory and endless run the Run History tab reads is now copied into the launcher's own archive (`run-archive.lua` in `%APPDATA%\SurvivorUIInstaller`, without the tooltips' photos: some 8 kB a run), never trimmed; an endless run gone on is copied again. The tab shows the archive's runs with the game's, newest first: a date in gold is a run gone from the game's Run History, kept here. The tick beside the list is now **Only victories and endless**, a filter.
- **Close to the tray** (new, on by default, Play tab and the tray's menu): on, the window's close button puts the launcher in the tray, as before, where it keeps looking for updates and backs up your save as the game closes; off, the close button quits it.
- **Total playtime on the Play tab**: a **Total** card beside **Today**, all the playtime the launcher has seen (the Statistics tab's Playtime).

### v3.0.36, 2026-10-27

Survivor UI in Chinese; the options window's new sidebar with a search, and its first reworked tabs; two Barlow fonts; a card for each side of the XP bar; clicks through the nameplates; and fixes.

**Survivor UI**
- **The options window, reworked (its first part): a new sidebar**: a search box on top (crit, size, sound...) that finds any setting of any tab by its name or its note and opens its tab with the setting lit; Enter opens the first one found, Escape empties it. Under it the five groups, one open at a time with its tabs, each with how many it holds. Move UI and Donate at the sidebar's foot.
- **The pages made of one kit**, the same on every reworked tab: a head with the part's switch (On, Off), The game's beside it where the game has its own, and Back to its place; a **live preview** where there is something to see, drawn as you change things; choices as segments and as pictures; things on or off as chips (hover one for what it does); a size as S, M, L and a bar for any size between; a number a step at a time with - and +; a "?" for help; the fine settings in an **Advanced** box (Simple or Advanced at the window's top right, kept for every tab); **Reset this page** and the page's own button at its foot, beside Save & Close.
- **The first tabs reworked**: Combat text (its preview: the hero and the numbers about it in their sizes, colors and icons, beside the hero or over the enemies), Boss bars (its preview: a boss's, a guardian's and an elite's bar at their size and text size) and Chat (its two looks as pictures, its filter as chips). The other tabs keep their pieces for now, and the search finds theirs too.
- The options window is a little wider, to give the pages room.
- **Always keep Victory & Endless** in the Run History (on by default, at the window's foot beside Delete, and in the Run History tab): once the runs kept are full, a new run makes the oldest Fallen or Left one go; a Victory or an Endless run goes only when no other can. Pinned runs, and the 10 longest when kept, never go.
- **The game's buff notices hidden**: the "<Power Word: Shield>" floating over the fight as a buff or debuff comes, and its notice as it fades, now stay away. Combat text tab, **Buffs gaining and fading**, to have them back.
- **Survivor UI in Chinese** (new, asked on Discord by Jormungandrr): with the game set to Simplified Chinese, the addon speaks it too: This Run and Biggest Crits, the damage meter and its windows, the build list and its jewelry, the run tracker and the guardians, the XP bar and its luck card, the Level Up! button, the stats, the Jewelry Collection, the kill pace, Run History and Career, move mode, the boss bars, the loot, the party and revive bars, the summons, the map pins, the minimap button, the chat's tabs and `/sui`'s help. The game's terms are the game's own words (暴击, 急速, 传说...), every spell, pet and piece of jewelry is named as the game names it, and the rest is translated for the addon; anything not translated yet stays English, and so does the options window for now. Chinese players: tell us on Discord what reads wrong.
- **Names kept from a game in another language** (a pet's best crit, a run played in Chinese) now show in the language of the moment; they showed as empty space.
- **Chinese and Japanese drawn right** (Chinese asked about on Discord by Jormungandrr): with the game in one of them, any font without those letters took them from the game's own font, and the game then mixed letters up: a Chinese character in place of an English letter or the other way round ("e克pty slot", "拉m佐", "エTウィン"), on any text, numbers included. The addon now switches by itself to **Noto Sans SC**, new with the addon, which has them (Japanese's kanji drawn the Chinese way). The font you chose is kept for a game in another language, and the Global tab says so in red. Noto Sans SC can be picked in English, German, Spanish, French, Portuguese and Russian too. Korean has the same trouble and no such font yet.
- **Two new free fonts**: **Barlow Semi Condensed** and **Barlow Condensed**, both SemiBold, condensed faces close to the look of many retail UIs, to pick as the global font (`/sui opt`, Global) or a piece's own (its card in move mode). Barlow reads a little smaller than other faces at the same size: a step up on a piece's card evens it.
- **A card for each side of the XP bar**: with The odds beside the bar on, hovering the spells' and jewelry's odds shows their card alone (their column, a legendary among a level-up's 3 cards), and the amulets' odds theirs (their column, and that an amulet rolls with +50% luck of its own); the bar keeps the whole card.
- **The odds' ribbon under the XP bar is off by default**; XP bar tab, **The odds' ribbon under the bar**, to have it back.
- **Move mode's size slider no longer runs away** (reported on Discord by Mistrick): dragging a piece's size on its card made the piece grow, the card beside it move, and the slider with it out from under the cursor, so one push went from 50% to 200%. The card now stays where it is while the slider is dragged, and goes back beside the piece when let go.
- **Armor is now called Dmg Reduction** in the stats (the character pane, the Stats panel, its options and the Run History), as that is what it is: the damage you take is reduced by that much, 60% at most. The game's own pane still calls it Armor, and the tooltip says so. Its place and whether it shows are kept.

**Survivor Plates**
- **Clicks go through the plates** (new, on by default; reported on Discord by Chunn): with the mouse over a plate, holding a button turned no camera, as the plate took the click. The plates no longer take the mouse: the camera turns from over them, and a click lands in the world, where clicking an enemy still targets it. A click on a plate no longer targets; `/splates click`, or Click through the plates in the options' Nameplates tab, makes them clickable again. The game lets no addon pass one mouse button through and not the other.

### v3.0.35, 2026-10-26

Luck and the cards' odds on the XP bar; a new chat panel; the mouse cursor in a color of yours; a coin for every cache your gold pays for, with a new sound; how Damage and Crit Dmg work together.

**Survivor UI**
- **How Damage and Crit Dmg work together**, in the stats' tooltips (Damage, Crit and Crit Dmg, in the character pane and the Stats panel): a hit is the spell's damage times your Damage, and a critical hit times your Crit Dmg as well; each one's own sources add up, then the two multiply (read in the game's 0.120). With your numbers of now: what a spell of 100 deals, critical or not, and on average with your Crit.
- **The odds beside the XP bar**, to read without the mouse (XP bar tab, **The odds beside the bar**, off by default): a legendary's, an epic's and a rare's chance, one under the other in their colors, the spells' and jewelry's on the bar's left and the amulets' on its right.
- **A coin drops for every cache your gold pays for**: before, once as the gold reached the next cache's price; now each time it pays for one cache more, bought or not: the next at its price, the one after at the price that follows (the game raises it by 1.3 times plus 5 for each cache bought, read in its 0.119), and so on. The coins' rain comes with it. Kills & gold tab, **A coin drops when you can pay**.
- **Survivor's Hoard**, a new sound of ours and now the default in the Kills & gold tab's **Sound** list: about two seconds of a shower of gold coins poured onto a pile (Survivor's Coin, the one coin, is still there).
- **The mouse cursor in a color of yours**: Global tab, **Mouse cursor**: **Cursor in a color of yours** (off by default), a **Shape**, a **Color** (White, Gold, Green, Blue, Red, Purple or your class color) and a **Size** (Small, Medium, Large). Gauntlet: the game's own cursors, read from its own files and tinted (its gauntlet, its sword over an enemy, its glowing gauntlet while a spell waits for its target), in any size; while the game shows a screen of its own (paused, the cards, a run's end) its cursor comes back as it is, since an addon draws under those. Arrow: an arrow of ours, 32 pixels at most (Large fills them), over everything. **Its touches**, in its color: a glow breathing round it, motes trailing off as it moves, a ring and sparks where it clicks the world. It changes as you pick, so the cursor over the window is the preview; the game's own cursor shows while you hold something.
- **A new chat panel**: one dark panel holds the chat, its windows as tabs along its top (the one shown in your class color with a line under it, the others dimmed, lit under the mouse and marked with a dot when a line comes to them unseen; right-click a tab for the game's menu of that window), a copy button at its top right, a grip at its bottom right to size it (the size is kept), and the typing box joined under it, or over it when the chat sits so low the box would leave the screen. The copy button opens the shown tab's last lines in a box, selected, so Ctrl+C copies them as plain text (the chat itself can't be selected). The Combat Log tab shows only while the chat filter lets lines into it. Chat tab, **Look**: Panel (the default) or Text on the world, the chat as before; **Background** sets how dark the panel is; **Lock the chat** leaves the panel alone, no tabs, copy button, grip or edges.
- **Luck on the XP bar**: your luck over the bar's middle (yours and your level's summed, as the cards roll with it; the card under the mouse tells the two apart), and under the bar a thin ribbon of the next level-up card's odds, each rarity's color (Common, Uncommon, Rare, Epic, Legendary) as wide as its chance, so the rarer colors grow as your luck and level do (XP bar tab, **Luck and the cards' odds**, on by default). Hover the bar for a card of the odds: on top your luck and your level's (Luck: 25% + 7% (from Lv. 7)), and in red that luck has no cap (the more luck, the better your odds of a legendary); a row for each rarity, in its color, and a column for the spells, rings and trinkets (they roll alike) and one for the amulets, each chance a bar on a dim track with its number in a column after it, in the rarity's color; a legendary among a level-up's 3 cards; where luck comes from, each with its luck (Gnome racial +20%, the rogue's Initiative +6% to +30%, the trinket Mark of the Chosen +22% to +72%, the amulet Pristine Enchanted South Seas Kelp +30%, gear with +luck), jewelry giving more the better its quality and the higher its rank; and in red, the hoards' own luck (guardian hoards and bosses: +25% native luck on their jewelry). As the game rolls them (read in its 0.119): with m = 1 + your luck + your level's 1% (30% at most), the weights are Common 60, Uncommon 25m, Rare 10m², Epic 4m³ and Legendary m⁴, each pick rolled on its own; rings and trinkets roll as the cards, amulets with m + 0.5, and the jewelry of a guardian's hoard or a boss with 0.25 more than a bought cache's.

### v3.0.34, 2026-10-26

Friendly plates only, suggested with a button; the target's plate with every enemy kind off; plates there as the game opens; the Vaniron fix test removed.

**Survivor UI**
- **A suggestion in the Nameplates tab**, boxed in amber: friendly plates only. The engine is old, enemy plates stack badly and a run brings a great many enemies, so for a smoother game every Enemy kind off and the Friendly ones on; bosses, elites and guardians keep the boss bars for their health and debuffs. Only a suggestion: nothing changes by itself, and its **Use suggested** button sets it at once (or /splates suggested).

**Survivor Plates**
- **Vaniron fix (test) removed**: the switch that laid vaniron's optimizations into the plates (his pull request #4, off by default since v3.0.33) is gone, with /splates vaniron; the plates are drawn as they were in v3.0.32.
- **/splates suggested**: the friends' plates (totems, pets and summons, co-op members) on, the enemies' off, the plates back on if they were all off.
- **Your target always, with every enemy kind off**: the target's plate did not show, the game's enemy plates being off as a whole. They now come on while an enemy is your target (its plate alone shows, the other enemies' kinds being off) and go off again as the target goes.
- **Plates missing as the game opens**: with plates chosen, a game just opened could show none until a setting was switched off and on. The game has no way to tell an addon whether its plates are on, and it clears them itself as the world is entered, after the addon had put them on; the plates are now put as chosen every half second (with V and Shift+V ignored, the default).

### Azeroth SurvivorUI Launcher 1.5.3 (beta), 2026-10-26

- **The game's log, kept**: Play starts the game with its output, its log, going to `game-log.txt` in the launcher's folder (`%APPDATA%\SurvivorUIInstaller`; the one before is kept as `game-log-before.txt`). When the game closes as it starts without a crash report, the launcher shows the log's last lines, how far the game got, with a button to the file to share in the game's Discord.
- **Set to run as an administrator**: a game whose exe is set to run as an administrator (its Properties, Compatibility) could not be started with graphics picked ("The requested operation requires elevation"). It now starts through Windows, which asks its leave as before; the graphics and the log need that tick off, and the launcher says so if the game then closes.

### Azeroth SurvivorUI Launcher 1.5.2 (beta), 2026-10-26

- **The game's graphics, and a second try by itself**: the Play tab has a **Graphics** choice: **Auto** (the game's own choice), **DirectX 12** or **Vulkan**. On some PCs the game closes as it starts, the graphics driver failing the renderer the game picks (an access violation, 0xC0000005); the game's own FAQ answers with a .bat that starts it with DirectX 12. The launcher does it by itself now: on Auto, when the game closes as it starts, it starts it again at once with DirectX 12, and when the game then stays up, it keeps DirectX 12 for that PC (and says so). If it closes with both, or with the graphics picked by hand, the launcher says so and what to try.
- **Donate**: the coffee cup in the header is now a light blue **Donate** button, "if you like my work" under it, a glint crossing it now and then; it still opens the [Ko-fi](https://ko-fi.com/morderous).

### Azeroth SurvivorUI Launcher 1.5.1 (beta), 2026-10-26

- **When the game closes as it starts, the launcher says why**: after Play it watches the game for a minute. If the game closes in that time, the launcher comes back from the tray and says what it can tell: Windows lacks Microsoft's Visual C++ runtime, a part the game needs to load (with a button to Microsoft's download, vc_redist.x64.exe); or the game left a crash report (its reason, and a button to the report, to share in the game's Discord); or else the game's exit code. Before, it said "Starting the game..." while nothing opened.

### Azeroth SurvivorUI Launcher 1.5.0 (beta), 2026-10-26

- **A new name, a beta**: the launcher is now the **Azeroth SurvivorUI Launcher**, a beta for now, as its version line and window title say.
- **Updates told in the window**: when a new launcher, Survivor UI or game is out, a green pill breathes at the right of the tabs (such as "Game 0.120.0 is out", or how many wait); a click takes you to it (the launcher updates itself; Survivor UI's tab; Play for the game), and a green dot marks the tab. The launcher looks as it opens, every half hour while it runs (in the tray too) and at Check for updates. Its versions at the top right are a brighter yellow, green while an update waits.

- **Five tabs**: **Play** (the game, Play, your numbers and the game's news), **Survivor UI** (the addons), **Savegame**, **Statistics** and **Run History**. The launcher opens on the tab you left it on.
- **Larger, in a look of its own**: the window is up to 40% larger, as much as your screen allows, and dressed as a fantasy RPG's panel, in Wenrexa's "UI RPG Game Interface" art (CC0): its frame round the window, which no longer wears Windows' border (drag it by its header; minimize and close at its top right), red and stone buttons, tabs as stone plates (the open one red), switches for the ticks, the title on its plaque in Cinzel Decorative, its dark cards for the numbers, its inner frames round the lists and charts, drop-downs in its stone field, its own scroll bars, and its frame for the tooltips and every message the launcher shows. The stone of the header and the coffee cup are drawn by the launcher.
- **Buy me a coffee**: a steaming cup in the header opens the [Ko-fi](https://ko-fi.com/morderous), for whoever likes what Survivor UI does. Hover it and it says how long you have played with it so far.
- **Play**: beside the Play button, today's playtime, the last time you played, and your runs and wins. Under it, the game's own news: Aethus' notes for the newest Azeroth Survivors, and a button to the game's Discord.
- **Each addon on or off**: Survivor UI and Survivor Plates each have a tick in the Survivor UI tab. Off, the game skips it from its next start (the game's own list of addons, `AddOns\account.txt`); nothing is deleted, and a tick brings it back. So the launcher also serves a player who wants the game without our addons: with Survivor UI off, it no longer tells of its updates.
- **Your save, kept**: **Back up now** zips your heroes, their gear, talents and unlocks (the game keeps them in `%APPDATA%\wenilla-rogue`, sealed the same on every PC), with the game's settings and the addons' (key bindings, chat windows, camera, layout, options, Run History), as `AzerothSurvivors-save-<date>.zip`, to the place you pick: the Desktop, a USB drive (each one plugged in is listed, with its free space) or a folder of your own. To keep, or to take to another PC. **Restore save...** puts one in the game: the zip checked first (the game's own sealed save inside, nothing that climbs out of its folder), your save as it is then kept on the Desktop (`AzerothSurvivors-save-before-restore-<date>.zip`), and its settings only if you say so. Both only with the game closed. The AddOns, the game's data, logs and caches stay out of the zip.
- **Backed up by itself**: tick **Back up after each game session** and each time the game closes, a backup goes to `Documents\Azeroth Survivors saves` (and to a USB drive when one is plugged in, if you tick that too), the last 5, 10, 20 or 50 kept. Only the oldest automatic ones are removed, never the ones you make yourself. The launcher must be running, open or in the tray, as the game closes. **Your backups** lists them all, newest first: double click one, or **Restore this one**.
- **Statistics**: your playtime (the time the game ran while the launcher was open or in the tray; on its first start, 1.5 counts in the game time of the runs already in your Run History) with a bar a day for the last 14 days; your runs, wins, kills, gold, bosses, guardians and caches; your achievements with their dates, newest first; a row for each class with the zones whose final boss fell to it and the talent points it has spent; and your collection (gear, jewels seen in the codex, pets, tabards). Read from the game's save, which the launcher never writes.
- **Run History**: Survivor UI's runs in the launcher, newest first, by class and by result: when, hero, class (these three on a bar of the class's colour), zone, result (on a bar of its own colour), time, kills, DPS and level. A run won and gone on in endless mode shows as Endless, with its end's time. Pick one to see it whole: its numbers, its damage by spell, its jewelry, its bosses and when each fell (in green), and how it ended (the blows before a death, the party's damage in co-op, its biggest hits); the damage, the jewelry, the build and the biggest hits in their own colours, as the game's Run History paints them. For an endless run, **Victory** and **Endless** show each moment on its own: the run as it stood at the victory, or the whole run as it ended, with what the endless part added beside its numbers. Every column scrolls with the mouse wheel when it holds more than fits, and so do the achievements in Statistics, all of them now, newest first. Its **Stats** tab shows the run's numbers as the game's Stats panel groups them (offense, defense, reach, utility, damage over time, bonus damage), each with what the gear gave, only the ones above 0. Its **Build** tab shows the run's build as the build list had it: each spell with its rank, cooldown and range, the racial marked, the talent experience the run gave, and its jewelry. Read from Survivor UI's saved settings, which the game writes as it goes back to the character screen or closes. **Keep only victories and endless** is the launcher's own: its list then holds only your victories and the runs gone on in endless mode. The game's Run History keeps what its own options say (Survivor UI's Options, Run History); the two are separate.

### v3.0.33, 2026-10-26

Coins that drop and rain as your gold pays for a cache, the jump record at checkpoints, record effects for each class, the Stats panel without its zeros, and Donate.

**Survivor UI**
- **Hide the numbers at 0 or below** (the options, Stats panel, off by default): a number that reads 0 or less (Lives 0, Execute +0%, a Speed of -10%) leaves the Stats panel and the character pane alike, its group with it once none is left, and comes back as soon as it grows past 0. While arranging they all show, to keep their order.
- **A coin drops when you can pay** (the options, Kills & gold, on by default): the sound of a coin falling on a table, our own (Sounds\CoinDrop.wav), once as the gold you carry comes to pay for the next cache, with the kills and gold line on or off; again only after the next cache's price has gone past your gold. **Sound**, a list: ours, Survivor's Coin, or one of the game's own coin and auction house sounds (Auctioneer's Farewell, Auctioneer's Welcome, Pile of Coins, Handful of Coins, Purse Opens, Purse Snaps Shut), played from the game's files; picking one plays it.
- **Coins rain on the gold** (the options, Kills & gold, on by default): with the sound, a shower of gold coins over the line's coin and number, in the new best crit's Radiant look (a golden halo, pillars of light, twinkling stars): the coins fall turning on themselves and bounce twice on your gold, each with a flare. With the line off, over the run tracker's coin, else over your hero. **Try it** shows both.
- **Jump record at checkpoints**: NEW JUMP RECORD now comes at every 50 jumps in a run (50, 100, 150...), each the first time you ever reach it, instead of once a run as you passed your record by a jump. With a record of 434, the next is at 450.
- **Record effects for each class**: the crit record's and the jump record's effects are kept for each class. In the Records tab, each record has a **Class** list (your hero's first): pick a class, then its effect. A class you have not picked for yet wears what you had picked before for all of them.
- **Donate**: the options window's "Buy me a coffee :)" is now **Donate**, a light blue box alive as the Run History's Left one (its glow breathing, its sparks drifting out to the right), brighter under the mouse; a click still shows the Ko-fi link to copy.

**Survivor Plates**
- **Vaniron fix (test)**: vaniron's pull request #4 (his optimizations of the plates, written on v3.0.18) laid into the current file behind a switch, off by default: the Nameplates tab, **Vaniron fix (test)**, or /splates vaniron. On, a plate's bar, number and color are drawn again only when they change, the target's border and debuffs only as the game says they changed (its PLAYER_TARGET_CHANGED and UNIT_AURA), and a plate handed to another enemy stays hidden two frames while the client fills it in. The settings are checked once and handed back after that, on or off.

### v3.0.32, 2026-10-25

Text sizes steady again on the game's 0.116, the spell-to-button map reverted and the bar locked, raid marks in a tab of their own with a mark for each hero.

**Survivor UI**
- **The spell-to-button map is gone**: since v3.0.23 the addon read every action button's tooltip every few seconds to follow a spell dragged to another button, and the reading confused a spell's icon now and then (reported on Discord by Amarolk). The spells are taken where the game lays them again, button 1 to 6 and the racial on =, and **the bar is locked** against moving them (Frames & bar, **Spells locked on the bar**, on): a drag or a shift-click off a button does nothing, and the chat says why once. Unlocked, a spell dragged elsewhere wears the icon of the one that was there until the game lays the bar out again.
- **Raid marks in a tab of their own** (Interface, Raid marks), out of the Nameplates tab, with an **Uncheck all** button: every row off and without a mark, and the marks taken off the heroes and your target.
- **A mark for each hero of a co-op party** (asked for on Discord by Towneh, who marked his friends to find them in the horde): Raid marks, **Each hero a mark**, off by default, and a mark picked for each of Hero 1 to 5. The heroes take them by their names in alphabetical order, so every Survivor UI in the party gives the same, and a hero already marked keeps that mark. Every mark belongs to one row: picked for a hero or a kind of enemy, it leaves the other rows, and the last box of a row, a dash, leaves it with no mark (a row on with no mark marks nothing).
- **Run History survives a missing art file**: with Art\DropArrow.tga gone from an install, Run History failed at load ("RunHistory.lua:1024: attempt to index a nil value", reported on Discord by Fedda) and nothing of it was made; the arrow goes untinted instead. The pins on the minimap are art files too (Art\PinCache and PinLair): with the folder short of them the minimap shows none, so an install missing them wants the launcher's update again.
- **Text no longer grows or shrinks on its own** (reported on Discord by Zitten, Squezy, Setoz, Klopp and 문핼이 after the game's 0.116): a piece with a text size step of its own (its card's A- or A+) had its step added again every second and a half, bigger and bigger with a + step, smaller with a -, since the game's new engine answers a font's size a hair off whole and the addon no longer recognised the size it had set. Sizes are read rounded now. A step of 0 was never affected.
- **The extra damage meter windows in the main one's font and text size**: a face or a text size chosen on the main meter's card (move mode) is theirs too, at once, and a change on any of them changes all. They were drawn in the default font and size (reported by Lucas).

### v3.0.31, 2026-10-25

Raid marks put on their own, more damage meter windows, your talents' clocks and a move key of your own.

**Survivor UI**
- **More damage meter windows**: a **+** at the main meter's corner opens another window on a page the main one does not show (Party Damage in a co-op run, else Healing Done, Boss Damage or Damage Done), up to three more. Each wears the main meter's bars, colors, icons and cards; its title switches its page, its **-** closes it. Hold Alt (the move key) and drag to move one, or move mode (Damage meter 2 to 4); the wheel rolls its list. Which are open, their pages and places are kept, and they show while the main meter does. Each is as big as the main one, with as many lines.
- **The revive bar on by default** (the game's 0.115 lets an addon put its own away): while you are down, or bring a friend back, Survivor UI's bar shows and the game's slim one and its "you are down" line go, put back as the game closes or when ours is switched off (the Party tab, or Modules with **The game's** beside it). With a game before 0.115, ours stays off unless chosen, as before: the game's could not be put away.
- **Your talents' clocks in the Summons** (the game's 0.115, `AZS_GetTimers`): the next Felguard (Butcher), Pit Lord (Pact of the Annihilan) or Legion Gate wave as a slim bar under the demons' icon, filling to the next one, its seconds in the tooltip; with none out yet, the talent's icon dimmed and counting down, "0/2". A talent's or a piece of jewelry's cooldown from 5 sec long gets an icon of its own (a second life: Cheat Death, Reincarnation, Last Stand, Divine Intervention; Rapture's shield, Swiftmend's Regrowth; a proc's limit of a few seconds is left out), dimmed and counting while it waits, bright when ready (the Summons tab, **Talent cooldowns**, on). The Legion Gate's icon is now the talent's own. "Keep the game's row of spells too" is no longer needed for the Butcher and Pact countdown.
- **Raid marks put on their own** (asked for on Discord by Farsigt; the game's 0.115 lets everyone mark): the Nameplates tab, **Raid marks**: bosses, lair guardians and elites, each on or off (all off by default) and with the mark you pick (a skull, a cross and a star unless picked). A mark goes on once the enemy is in the fight, a guardian once awake (one asleep in its lair takes no mark). When the game has it in your target, it is marked there; else the hero targets it by name for a moment. One enemy per mark at a time: the next waits for the one marked to fall. An enemy already marked, by a friend in a co-op run too, is left as it is. The marks go to your whole party.
- **Raid marks seen**: on the boss bars, before the name, and over the target's portrait.
- **A move key of your own** (asked for on Discord by Szanyi, whose push to talk is Alt): the Layout tab, **Move key**: Alt as before, Ctrl, Shift, or None (Move UI only). It is the key held to see the grid and drag the pieces while you play; the tooltips name it.

**Survivor Plates**
- **A raid mark by the bar**: the game hangs a plate's mark off its own wider plate, far left of the bar; it now sits right by it, as tall as the bar.
- **Your target's plate, or not** (asked for on Discord by Klopp): the Nameplates tab, **Your target always**, on as before. Off, a kind left out shows no plate on your target either: with the rank and file left out, no plate jumps from one enemy to the next as the game moves your target. /splates target.
- **A key for the plates**: Key Bindings in the game's menu, Survivor Plates, **Nameplates on or off**, or the Nameplates tab, **Plates on or off key** (click, then press the key; a right click clears it). It turns all the plates off and back, as /splates none. None by default.

### v3.0.30, 2026-10-24

Areas read right in the build list, and the game's own item tooltips back by default.

**Survivor UI**
- **Item tooltips: the game's own by default again**, in Survivor UI's flat look: the bind line, the green "Equip:" lines, as the game writes them. The layout Survivor UI gives them since v3.0.14 (no bind line, the health in green, each effect a line of its own, its numbers in colors) is now a choice: the Tooltips tab, **Item tooltips laid out again**, or Modules, Item tooltips. It takes hold at once. Whoever had switched it on themselves keeps it.
- **The area of a spell that lands on a spot, in the build list** (reported on Discord for Flamestrike): Flamestrike, Rain of Fire, Volley, Blizzard and Hurricane showed in Info the range they are cast from (30 yd), which never changes. They now show their area's radius ("every enemy within 21 yd of that spot"), what their Area upgrades widen, under a ring with a dot in place of the measuring arrow. Every class's spells were read over for the like: no other showed a wrong number.
- **Every area under the ring**: the build list's Info now tells an area from a range at a glance. A ring for an area's radius: around you (Frost Nova, Thunder Clap, Blast Wave, Swipe), where you stand (Consecration, Frost Trap), where a spell lands, a totem's (Magma Totem), a burst's (Call of Flame, Polymorph, Bloodrage). The measuring arrow for a range, and a cone's length. Run History's Range column keeps the range.

### v3.0.29, 2026-10-24

Records with effects of your own, a jump counter, and your co-op friends' plates in their class colors.

**Survivor UI**
- **Jumps**, a fun stat (asked for on Discord): This Run counts your jumps in a row of its own; hover it for your record in one run and all your jumps ever. Run History keeps each run's. A press while still in the air does not count.
- **New jump record**: once a run, as you pass your record (from 10 jumps), the number stands still right under the new best crit, over an effect. It moves on its own in move mode (New jump record); `/sui record` shows both notices.
- **Records tab** (Combat): the new best crit and the new jump record, each on or off (both on by default) and each with an effect of its own, chosen apart: **Fire** (a bed of flames, embers rising and swaying, sparks crackling, the number glowing like a coal), **Lightning** (bolts lashing out and striking down, flashing blue-white), **Radiant** (a golden halo, pillars of light, motes and stars), **Frost** (ice shards flung out, a crown of frost crystals, snow drifting down), **Void** (orbs circling in two rings, motes spiralling in), **Physical** (a blow: three red claw slashes torn across the number, a shockwave, sparks and drops flung out, the number shaken, another blow every so often) and **Nature** (sprouts growing up behind the number and swaying, leaves spiralling out and drifting, pollen rising). Picking one shows it. The jump record has its own Stays and Size too, and a winged boot left of its number (the game's Sprint icon), as the crit record wears its spell's icon. The crit record wears Radiant and the jump record Fire unless chosen. The crit record's settings (which crits, how long, its size) moved here from Combat text; its old glow is the Radiant effect's now.
- The game guards its jump as it guards every move: an addon that calls it is blocked, and the hero does not jump. Survivor UI only notices the key's own call, so your jump is never touched. A gamepad's jump may not be counted.

**Survivor Plates**
- **Co-op members' plates** (asked for on Discord): a friendly kind of its own for your friends in a co-op run, a little larger than a pet's, in the friend's class color with the class's icon beside the name and the health left on it. A friend who is down has no plate (the game gives a fallen hero none); the party frames show DOWN. Until now a friend's plate showed in the pets' style, small and green, and only with Pets and summons on. Off by default: `/sui opt`, Nameplates, Friendly (Totems, Pets and summons, Co-op members), or `/splates party`. Like every plate in 1.12, a friend has one only within 20 yards of you; farther away, the party frames still show them.

### v3.0.28, 2026-10-23

Ready for the game's co-op runs (its 0.113): your party in Survivor UI's look.

**Survivor UI**
- **Party frames**: in a co-op run, a frame for each friend, left of your own, the first at the bottom and each next one over it: their class icon, their health in the class's color with what is left of it, the host's crown. A friend down shows DOWN in red; while you bring them back, a gold fill and "Reviving 45%"; the friend bringing you back says "Reviving you". Hover one for their damage this run, their damage per second and their top spell; click to target. The game's party frames at the top left are put away while these are on. Moved on their own (move mode, Party frames), sized in the new Party tab.
- **Revive bar**, off by default: while you are down, how far a friend has brought you back and who ("Bleedin is bringing you back 45%"); while you bring a friend back, how far. Under the hero, over the game's own. Moved on its own (move mode, Revive bar). The game shows a slim revive bar of its own, and an addon can neither hide nor move it: the game's addon API has no setting for it yet, as it has for its clock or its meter. Until an update of the API brings one, two bars would show, so ours waits in the Party tab for whoever wants it; once the game's can be put away, ours takes its place.
- **Party Damage in the damage meter**: the title's menu has a page for the party's damage, a bar a hero in the class's color with the class's icon; hover one for their damage per second and top spell. Greyed out of a party; chosen once, it comes back by itself in the next co-op run.
- **Run History names the party**: a co-op run keeps its party, "Party of 2: Bleedin" after the hero's line; hover it for each hero's damage and top spell as the run ended. The list of runs marks them "Party 2".
- **Down is not the end**: while you are down in a party the game says the run is lost every fraction of a second, though a friend can still bring you back. Run History waits for the real end now, and keeps the run once. The run tracker and your frame say Down, not Fallen or Dead.
- A new **Party** tab in the options (Combat), and Party frames and Revive bar in Modules, each on or off.

### v3.0.27, 2026-10-23

**Survivor UI**
- **The racial's icon on a spell in the damage meter**: since v3.0.23 a spell learned in the run could take the racial's icon in the meter for the whole run (Eviscerate with Perception's, Searing Pain with a gnome's, Chain Lightning with an orc's). The buttons' reading was kept by place in the game's spell list, and a new spell moves the racial, always last, one place down: for an instant the new spell got the racial's button, and the meter kept the icon it read then. The reading is kept by spell now, and the meter reads a spell's icon off its button every time.

### Survivor UI Launcher 1.4.4, 2026-10-23

- **Ready for the game's 0.112.5**: from it the game keeps your AddOns, settings and options in a `benilla-config` folder beside its exe (for the usual install, `C:\Git\wenilla\benilla-config\benilla-config`), and the first time it starts it brings everything along from the older folders. The launcher installs there from 0.112.5 on (read in the game itself, as before), keeps the build's folder for 0.112.0 to 0.112.4, and the old one before them.
- **The game's own move left to it**: the game copies the older folders only while its new folder is not there yet, so until the game has started once, the launcher makes nothing there: Install, Update game and "Check folder and move if necessary" say to click Play once first, and nothing is lost.
- The AddOns folder follows the game when it updates itself while the launcher is open, and the folders' button also looks in the older folders the game knows.

### v3.0.26, 2026-10-23

**Survivor UI**
- **The options window readable at any UI Scale, and sized with Whole interface**: it had one size of its own, so at a small game UI Scale (0.64, the lowest) it stood a third smaller and hard to read, and the Whole interface slider left it as it was. It now takes the same share of the screen whatever the game's UI Scale, grows and shrinks with Whole interface (resized once the slider is let go), and never runs past the screen; its minimized bar too. The game has two sizes of its own: its UI Scale (in its Options) sizes every addon; its HUD Scale sizes the game's own HUD only.
- The window's "Buy me a coffee" button covered the last tab of the list (Nameplates) since the Summons tab came; it sits at the foot of the page now, level with Save & Close.

### v3.0.25, 2026-10-23

The game's 0.112 moved its folder: the launcher follows it and moves your things there. And the combat numbers back in the middle at any UI scale.

**Survivor UI**
- **The combat numbers in the middle at any UI scale**: their columns (Damage numbers, Crit numbers, Healing, Damage taken) took the screen's middle from `UIParent:GetWidth()`, which leaves the UI scale out, so at a scale other than 1 they stood off center, down and to the left (the game's default is 0.9: a fresh game folder, as 0.112's, has it). The screen's size is now read with the scale in, everywhere: the columns, the numbers around the hero, the new best crit's side, Move UI's grid (it reaches the edges now), the piece cards and the options window's check that it is on screen. Columns you moved keep their place.

**Survivor UI Launcher 1.4.3**

- **The game's own folder, wherever it moved**: the game keeps its AddOns, saved settings and options in the folder its exe was built from, a path the exe carries, and the game's 0.112 build was made from another folder on Aethus' PC, so it moved them for every player to `C:\Git\wenilla\.claude\worktrees\release-gaze\benilla-config` (the launcher kept installing in the old one, and the settings looked gone). The launcher now reads that folder in the game's exe, as the game does, and installs the addons there, whatever folder the next build names.
- **Check folder and move if necessary**: a button of its own under the AddOns folder, steel blue; green while your things are still in an older folder of the game, the status line saying so. Its tooltip tells why: the game keeps your things in a folder its exe names, and if Aethus' build changes it, the launcher makes a backup and moves your data to the new place. A click shows both folders and when each last saved settings, and moves your AddOns, saved settings (the account's and each hero's), key bindings and options into the game's folder: what the game had made there under the same names is kept in `before-move-<time>` there, and the originals in `moved-<time>` where they were. Nothing is deleted; the game itself, its data, logs and pictures stay where they are, and your progress (`%APPDATA%\wenilla-rogue`) is never touched. The game must be closed.
- **In any order**: an addon the game's folder has already (Survivor UI installed there before the move) is kept as it is, and only the addons it lacks come over. The button turns green while the old folder holds an addon, or an addon's settings, that the game's folder lacks; folders already copied by hand are not flagged again, and a click still checks.
- "Up to date; so is Survivor UI" no longer said with Survivor UI missing from the game's folder.
- The game is remembered on its own, apart from the AddOns folder, which no longer sits beside it: Play, the game's version and Update game go by it.

### v3.0.24, 2026-10-22

**Survivor UI**
- **The Level Up! button alive, and in a color**: the sparks rising, the stars and the shine of Run History's Victory box, over the button, with its breathing glow; a tick in the Level Up! tab (Look) turns them off. The button wears the class's color, or one chosen there: gold, white, red, orange, green, teal, blue, purple or pink; the fill, the glow, the edge, the key cap and the sparks take it.
- **The grid with Alt**: holding Alt lays the Move UI grid over the screen along with the outlines, so pieces can be lined up without opening the options; a piece dragged with Alt held snaps to the grid or to a neighbour's edge as in Move UI (let go of Alt before the mouse to put it down free).
- **A spell's icon read off the wrong button, once in a while**: the build list's new reading of the buttons (v3.0.23) could take a tooltip the game had left empty for an earlier button's, and give a spell the racial's icon until the next reading (Curse of Agony with Escape Artist's, seen 2026-10-22). Now an empty tooltip says nothing, and a spell leaves its own button only when that button's tooltip names another spell and some other button names it.

### v3.0.23, 2026-10-22

**Survivor UI**
- **A counter for Faerie Fire** (Counters tab, Marks), asked for by a druid: over its button, how many enemies carry the mark right now, bosses too. The game writes each enemy it hits but not the mark's end, so each one counts for the mark's time (read off the tooltip); one hit again before its mark fades counts twice until it does.
- **The build list follows a spell dragged to another button**: the game lays the spells on the bar in its own order and the addon took that order for the buttons, so a spell dragged onto another button (as in 1.12) wore the icon, the range and the tooltip of the one that was there, and one dragged off the row lost them. Now each button is read for the spell it holds, and the DoT and fear counters, the totems and the soul shards follow the spell too. The game lays the bar out again at each new spell, which puts the moved ones back where they were.
- **The Star of Mystaria is a trinket** (the game's 0.111): the Jewelry Collection lists it among the trinkets now, not the amulets.
- **"Soulfire", one name.** The game spells it "Soulfire" since its 0.110 (its meter, its cards and its tooltips) while the combat log still writes "Soul Fire", and the addon took them for two spells: the meter gave Soulfire a placeholder icon and a color of its own, and the soul shards never read its tooltip, so the seconds between shards and how many it takes stayed at their first values. Both are one spell now, and the build list calls it Soulfire too.
- **Keep the game's row of spells too** (Build list tab): the game's own row stays under the list. Since the game's 0.111 it is the only place that counts down to the next Felguard or Pit Lord of Butcher and Pact of the Annihilan, on the talent's icon (it was a buff before, which the buffs row showed).
- The game's words for its 0.111 and 0.112 (Trauma, Bloodlust, the Star as a trinket) in every language.

### v3.0.22, 2026-10-22

**Your summons, at a glance.** The game's 0.110 tells addons about every summon out, and Survivor UI now shows them over your frame: how many of each kind against the game's limit, and how long the longest-lived one has left.

**Survivor UI**
- **Summons** (new, Modules → Combat): your summons over your frame, from the game's 0.110, a buff-sized icon each. One that stays the whole run (the Imp, your companion demon, a hunter's beast, Treants, Spirit Wolves, a Water Elemental) shows its icon alone, and only with "Track permanent pets" on. A kind that comes and goes shows how many are out against the game's limit in the corner (an Infernal or a Doomguard 1/1, a Felguard or a Pit Lord 2/2) and the longest time one of them has left in the middle. The Legion Gate's lesser demons are one icon, the talent's own, "out/12"; hover it for each kind, and any icon for each one's time left. It sits over the buffs by default and goes with the player frame; move mode places it on its own ("Summons"). Its tab (Options → Summons) has "Track permanent pets", off by default: on, the ones that stay the whole run show too.
- The game's words for its 0.110 (the demons, the moved talents, the new achievements and looks) in every language.

### v3.0.21, 2026-10-21

**What matters about each spell, at a glance.** The Build list's third column, once Range, is now **Info**: for each spell the one number that matters most besides its cooldown, and a symbol of its own beside it, in a column of its own, so you can tell at a glance what the number is. Tuned by hand, one class at a time: every class played and every spell's tooltip read, to give each spell its row. New art of our own: **restart the game once** after updating.

**Survivor UI**
- **The Build list's Info column** (new):
  - **An hourglass, gold: how long a buff lasts.** While it is up, its row drains as a timer and the cell counts the seconds down ("5.2"). Divine Shield, Holy Shield, Battle Shout, Slice and Dice, Adrenaline Rush, Lightning Shield, Thorns, and your demons' Demonic Empowerment (its length only: the game lists your own buffs, not your demons'). The length is the game's own, as the buff last went up, so an upgrade that lengthens it shows, and it is kept for your next runs.
  - **A cross, green: how much a heal gives back**, as a share of your health: Holy Light, Renew, Healing Wave, Rejuvenation, Regrowth.
  - **A shield, blue: how much a shield holds back**, as a share of your health: Power Word: Shield, Ice Barrier. They last until they break, so no hourglass.
  - **A measuring arrow, gray: how far a spell reaches**, or its radius around you, for everything else: the number alone, "22", no "yd".
  - **The right reach**: the distance a spell is cast from ("Cast once enemies are within 30 yd", a totem's "once enemies are within 25 yd", Blizzard's "once enemies come within 30 yd") is no longer taken for its reach. Magma Totem shows its 16 yd of fire, not 25; Holy Shield, Battle Shout and their like show their time.
  - A heal, a shield or a buff whose tooltip tells no number shows its reach instead, never an empty cell under a symbol. The column's name over the symbols and the numbers together; the numbers centered, as CD's and Rank's are.
- **Your shield on your frame** (new): what the shields on you still hold, from the game's own count (Power Word: Shield, Ice Barrier, Stoneform and the rest), drawn on your unit frame's health bar: pale blue with white stripes from where your health ends, a bright edge at its end. With your health whole, it lies over the bar's right end instead; over a light bar (a priest's white, a rogue's yellow) it goes deep blue with dark stripes, so it still shows. Your name and numbers stay over it.
- **The damage meter's ranks, now your choice**: off by default, the meter shows each spell's name alone. On (Options, Damage meter: **Spell ranks after the names**), the rank follows the name as a bare number, "Holy Shock  2", in the run's meter and the Run History's; with **Roman spell ranks** on (Options, Tooltips), as II. The tooltips keep "Rank 2".
- **The game's empty bar no longer outlined**: since the game's 0.108 its main bar is small enough for the mouse-over outline to frame it where it stands empty under Survivor UI's own row. With the row on, that bar no longer takes the mouse; its buttons in the row still do.

### v3.0.20, 2026-10-21

**Survivor UI**
- **Ready for the game's 0.108 action bar**: the game's new bar between the gryphons left three of its pieces showing through Survivor UI's own row (Modules, Interface, Action bar): a slice of its art at the bottom of the screen, the racial's gold rim around the = button, and its experience numbers, now always up, over the thin experience strip. All three are kept away with the row on; with it off, the game's bar is as the game made it.

### v3.0.19, 2026-10-20

**A meter for each class the game tells us about.** Until now an addon could only guess at a class's own resource: the soul shards were worked out from your kills and Soul Fire's tooltip, and for every other class there was nothing to show at all. The game's 0.105 (Aethus, 2026-10-20) changed that: it now tells addons, live, how full four classes' own proc is, a number from empty to full (`AZS_RUN.proc`, `pv` and `pm`). Those four are the warrior's **Bloodrage**, the rogue's **Seal Fate**, the warlock's **Soul Fire** and the priest's **Lightwell**, and so these are the four that get a meter: each drawn its own way under your frame, with art of our own, and nothing on it guessed. When the game tells us about another class's proc, that class gets its meter too: the module is built so that one more is a line and its art.

**Survivor UI**
- **Bloodrage for warriors** (new): five iron chevrons pointing ahead, like a Charge. Each one is a fifth of your rage, and the next one fills from its back as you hit and are hit, a flare at its front. Near the top the full ones beat; as Bloodrage is set off they all blaze white for a moment, speed lines streaking back behind them. While it is on, your unit frame shows no rage bar of its own, the health bar taking its room.
- **Combo points for rogues** (new): five red orbs in a dark iron ring, filled as the game counts your combo points (Seal Fate), each new one with a pulse of light, all of them flashing as a finisher spends them; empty, a dark socket.
- **Soul shards as the game counts them**: the five violet gems now follow the game's own count, no longer worked out from your kills, so they are never off, and the shard on its way lights up as far as it has come (the Felguard's swings now give a fifth of one at a time). With a game older than 0.105 they count as before.
- **Lightwell for priests** (new): three fonts of light, one for each Lightwell that can stand. Each is a stone basin whose pool glows while its well stands, a beam of light rising from it as high as the well's time left, a star at its top and motes of light climbing it; it fades through the well's last seconds and goes dark when the well is out. The newest well is always the one at the left: a new one comes with a flash, and the others move one place right. Where the cooldown outlasts the well, the first font's pool glows dim, filling, while the next one comes. How many stand at once is the well's duration over its cooldown, at most three, so the second and third fonts light up as your upgrades and cooldown bonuses grow (the tooltip's "up to 2 stand at once", then "up to 3").
- **The four together**: each is a module of its own (Modules, Combat), on, and only your class's shows. They share one place under your frame, moved in move mode as **Class gems** (the Soul shards card, renamed). With new art: **restart the game once** after updating.
- **The Pit Lord's crits under the Pit Lord**: since the game's 0.105 the meter puts the Pit Lord's damage on a bar of its own, Felseeker in its tooltip; Biggest Crits names its Searing Pain "Pit Lord's Felseeker", in that bar's color.
- **The loot lists in one look, and "new" no longer cut off** (Faya): each row is now always filled with its quality's color in a black edge, the words white over it (the look up to v2.10). The faint wash look and the "(epic)" beside the name are gone, with their options (Loot list). A long item name used to be cut to fit its row and take the green "new" with it: the count and "new" now come after the name on their own, and only the name is cut. Hover an item you have worn in a run for its tooltip. In the loot list during a run and in the Run History's Loot.
- **Spell ranks as "Rank 63" again**: your spells' tooltips, the Biggest Crits' cards and the damage meter (the run's and the Run History's) show a spell's rank as the game writes it, Rank 63, no longer as a Roman numeral. The Roman one, LXIII, is an option on a new tab, **Tooltips** (Interface): **Roman spell ranks (also applied to the meter)**, off.
- **Run tracker tab fixed**: the guardians list's **Back to its place** button sat over the **Show as** choices (A count, Off); it now has a row of its own, **List place**, above the list's size.

### v3.0.18, 2026-10-20

**Survivor Plates**
- **Each kind of plate on its own** (Options, Nameplates, a box each, or /splates and the kind):
  - **Friendly** (new; asked by Sedz and Amarolk, with so many warlock demons about): **pets and summons** (a warlock's demons, the Water Elemental, spirit wolves, treants, a hunter's pets) in green, **totems** in blue (the game names each one just "Totem": the icon of your one totem spell, or a totem's when you have both). Small, with the name and its icon (Survivor UI's), and none by default. They are the game's friendly plates, told from an enemy's by the color the game gives them, so an Infernal of yours is never drawn as the enemy elite of that name; they show even with the enemies' plates off.
  - **Enemy**: **normal**, **elites**, **guardians** and **bosses**, each on or off (all on by default; whoever had chosen "elites, guardians and bosses only" keeps the rank and file off). A kind left out still shows as your target. A zone's guardians are named as its elites, so a guardian the game lists is told apart by its health, and your target always by what the game says it is.
- **The plates hold steady**: the game hands a plate to another unit over a frame or two (its name, then its color and health), and a plate read too soon kept the last unit's kind: a totem drawn as a hidden enemy, a guardian as a pet, one coming as the other went. A plate's kind is now read again whenever its name, color or health changes.
- **V and Shift+V ignored** (on by default; Options, Nameplates, or /splates keys): the game's own keys for its plates turned them on and off behind these choices. What they change now goes back within half a second.

**Survivor UI**
- **The Nameplates tab redone**: **Friendly** (Pets and summons, Totems) and **Enemy** (Normal, Elites, Guardians, Bosses), a box each, in place of the choice between every enemy and only the dangerous ones; "Ignore V and Shift+V" under Look. The totems' plain "Totem" is read in every language the game has.

### v3.0.17, 2026-10-20

**Survivor UI**

A warlock's update: the soul shards on screen, and the demons named and drawn as what they are.

- **Soul shards** (new, with new art: restart the game once; asked by Simops): five gems under your frame, lit violet as they fill, a pulse of light for each new one, a flash as Soul Fire goes. The game tells addons no shard count, so it is worked out from Soul Fire's own rule: each kill gathers one, at most one every few seconds, and the free Soul Fire at five empties them, which also sets the count right each time. The seconds and the five are read off Soul Fire's tooltip, in any of the game's languages, so a talent or a patch that changes them changes the gems too; should the tooltip stop reading as expected, or another of your spells speak of shards (a new talent or spell; this one with the game in English), the gems dim and the chat says once why. They go with your frame until you move them on their own in move mode ("Soul shards"; its card's reset puts them back). Only while you have Soul Fire. A module of its own: **Soul shards** (Modules, Combat), on.
- **Your demons with their own icons**: Imp, Succubus, Voidwalker, Felhunter, Felguard, Infernal, Doomguard, the Pit Lord and its Felseeker, each with its summoning icon in the meter, Biggest Crits and Run History, instead of the Survivor UI one; in every language the game has. The other classes' summons too: the Water Elemental, spirit wolves, treants, the hunter's wolf and raptor.
- **Your demons' crits as theirs**: the combat log writes a demon's spells as if they were yours, so Biggest Crits had a "Fireball" you never learned. Now each goes to its demon, named and colored as the meter counts it: "Imp's Fireball", "Infernal's Inferno" for the Infernal's fall (a meteor's icon, no longer two rows that looked the same), "Infernal's Hellfire" for its burning aura, the Pit Lord's Searing Pain as its "Felseeker", the Doomguard's Shadow Bolt as its own. With the same spell in your build, your cooldown tells the two apart: your cast starts it over in the game's spell list, so a Hellfire crit is yours only when it came as you cast it (such a crit comes into the box a couple of seconds late; for a spell cooling faster than the game sends that list, they stay together as yours).
- **The damage meter scrolls with the mouse wheel**: in the right column it shows as many lines as fit, so a seventh source (a Doomguard, say) could be out of sight. Roll down over it and the first line goes up while the next comes in at the bottom; roll up to come back. Changing view (damage, healing, boss damage) starts at the top again.
- **Run History's damage is the meter's**: "Damage dealt" and "Damage / sec" now show what reached the enemies, the same number as This Run during the run and the Damage Done total. The game's end of the run counts the blows' whole damage, overkill included, and with many weak enemies under big blows that came to nearly four times as much (960k against 252k), which made a run look far stronger than it was. That count is still kept, at the top of the row's tooltip in red ("Damage with overkill", with how much of it is overkill). The personal bests and the Career's totals go by the meter's too, older runs included where they kept it.
- **The game's menu buttons in the bottom left corner**, under the chat, still hidden until the mouse reaches them: in the bottom right they came up over the damage meter.
- **The addon's version at the foot of Run History**: its footer ends with "Survivor UI v3.0.17", read off the addon's own .toc, so a picture of the window tells which version took it.

### v3.0.16, 2026-10-20

**Survivor UI**
- **A note when a run worth a look was kept**: as the next run begins, if the last run in Run History was won or went on in endless mode, a small note by Run History's minimap button says "Last run summary is available!", with the zone (green), its time (white) and the result (its color): "Elwynn Forest 20:50 - ENDLESS"; the whole note is the result's box as Run History has it, alive (Victory green, its sparks rising and a shine; Endless purple, sparks circling), level with the button, growing up from its foot. A click opens Run History on it; it has an x, and goes by itself after 25 seconds. Once for each run kept.

### v3.0.15, 2026-10-20

**Survivor UI**
- **No frozen bosses from the run before** (reported by Faya): the guardians or bosses fought in one run showed on the boss bars of the next, their health frozen, until new ones spawned. The game sends its special enemies when the list changes, not as a run begins, so its last list stayed. Now a list from before the run's clock went back, or one left while no run is on, is emptied until the game sends the next: the boss bars, the run tracker's boss health and elites, and the guardians' health all start the new run clean.
- **Lighter combat log reading** (by Vaniron, pull request #3): each line of the combat log is first checked for the word its patterns need ("hit", "crit") before they run on it, so a line that has neither costs almost nothing. Most noticeable with area builds in big pulls, where the lines come by the thousand.

### v3.0.14, 2026-10-19

**Survivor UI**
- **A clock and the FPS on the minimap**, along its bottom, inside the square: your time on the left, the frames a second on the right (green from 60, gold from 30, red under it). The game's own clock runs in UTC, so the time takes the time zone set in This Run ("Your time zone"), with a small "UTC" beside it until one is set. The game has no frame rate for addons, so the addon counts the frames it draws. **Click the time to set it** (a gold edge goes round it under the mouse): a box by the minimap shows the time large, with a slider of the time zone (UTC-12 to UTC+14, in half hours, with - and + beside it) and 24 or 12 hours; slide until the time is yours. It is This Run's time zone, so Run History's dates follow. In the Minimap tab: **Clock and FPS**, on unless you untick it, and 24 or 12 hours. With the square minimap only.
- **The totem counter reads the shaman's talents** off the spells a run starts with, as the game tells addons no talents: Searing Totem there from the first second is **Call of the Elements**, and each cast now counts the two totems it sets down; Magma Totem is **Totemic Wrath**, and the Searing Totem it drops on its own every 14 sec counts too (by the run's clock, as the game writes nothing of it). Both were the counter's blind spots: a cast counted one, the free Searing Totem none.
- **Shouts in the counters** (Counters tab, **Shouts**, on): over Demoralizing Shout's button, how many enemies its last cast weakened, for as long as it holds (its tooltip's time; bosses count, it takes them); over Battle Shout's, the seconds its buff has left. `/sui dots` switches them with the rest.
- **The tooltips, spring cleaned**:
  - **The build list shows the spell's own tooltip**, the one its action button has, beside the list and level with the row; it showed the damage meter's card (damage, crits, hits), which the meter and Biggest Crits still have. The racial's tells the race's traits at its foot, on the action bar too.
  - **What it does, under its name**, in its color: "Physical damage · Automatic", "Arcane damage", "Nature heal", "Frost shield", "Nature thorns" (Lightning Shield), or **Buff** in amber (Slice and Dice, Adrenaline Rush, Battle Shout: a buff deals no damage, so it is not "Physical"), "Immunity", "Control". The name wears the same color: physical damage red (it was tan), a heal or a shield its spell's school (Regrowth Nature, Ice Barrier Frost), where it went to physical.
  - **One color for each kind of number**, the same under the name and in the description, so it reads at a glance: time **blue** (seconds, cooldowns), distance **mint** (yards), a share **gold** (percentages, the crit), damage its **school's** color (thorns' too), a heal or a shield's amount **green**, a count white.
  - **The game's own rules in a dim shade** of their kind's color, so the eye goes to what your build changes: "cast once enemies are within 30 yd", "when you fall below 85% health", "8% weaker with each jump".
  - **A whole cast's damage in its school's color** too: Consecration's "181 in all".
  - **The crit read at a glance**: "7% crit · 204% dmg" (it said "7% crit · 204%").
  - **Upgrades in gold**, as the level-up cards they come from (white before); bonuses stay green, talents blue.
  - **Item tooltips laid out the same way** (the character pane, the jewelry, the loot): the "Binds when picked up" line goes (nothing is traded in a run), the health a piece gives in green, and each "Equip:" effect a line of its own under a green rule, without the word, its numbers in their colors (a share gold, a heal green). A module of its own, **Item tooltips** (Modules, Character), on; Ability tooltips stays its own.
  - **Ranks as Roman numerals** in every tooltip, as the damage meter has them: "II" where it said "Rank 2" (the ability's, and the damage meter's and Biggest Crits' cards, the kept ones in Run History too).
- **What your gear gives to each stat**: hover a number in the Stats panel or the character pane for its parts, **Worn gear** (green, as the game tells it) and **Everything else** (level, talents, cards, buffs, race): Damage +85% is gear +46% and the rest +39%. For the 13 numbers gear can give (health, regen, damage, haste, crit, crit damage, armor, area, targets, echo, speed, pickup, gold); in Run History's Stats panel too, as the run stood.
- **The hover outline leaves the character pane's background alone**: over the pane it framed a large box around it all; now only what answers the mouse there (a slot, a stat) gets it.

### v3.0.13, 2026-10-19

**Survivor UI**
- **The game's red flag in Modules**: the minimap's flag on the lair to head for (the game's, from its 0.102) gets its **The game's** tick beside **Minimap pins**, as every part with a game's own of it has. With the pins on, as before: the lair glows gold in place of the flag (the Minimap tab still chooses Our glow, The game's or Off). With the pins off, the game's flag is back, at once; untick its The game's for neither. Before, the pins off left the flag put away with no glow in its place, and its one switch was deep in the Minimap tab.

### v3.0.12, 2026-10-19

**Survivor UI**
- **Run History: the hero's numbers, a Stats panel of their own** in a fourth column, right of Biggest Crits and the loot: the Stats panel's numbers as they stood when the run ended (each moment of an endless run its own), in its groups and colors (Offense, Defense, Reach, Utility, Damage over time, Bonus damage). Only the ones that count: a number at nothing (+0%, 0) is left out, so a run shows what its build and jewelry gave. Hover one for what it means. Kept from this version on; a run kept before says so. The window is a column wider, its height the same; the tooltips of the first two columns show on its left, the other two on its right.
- **Cooldown numbers on short cooldowns too** (asked by Nathan): the numbers left out every cooldown of 1.5 s or less, the global cooldown's length in WoW; with much haste a spell's own cooldown falls under it, and its number went. Now those count down too, in tenths, never red (the last two seconds of a longer one still are). A new tick under "Cooldown numbers on the buttons" (Frames & bar), **Short cooldowns too (1.5 s or less)**, on unless you untick it: off, it is as before (the global cooldown of a spell cast by hand shows no number either). A setting, so an update keeps it.
- **Removing the addon leaves the game as it was** (reported by Emotong): to put its own in their place, the addon switches some of the game's own screens off (the clock, the boss bars, the kill tally, the build row, the loot, the meter, the minimap's flag towards the nearest guardian, the Level Up! button, the damage numbers), and those are the game's settings, which it saves; the addon gone, they stayed off, the flag and the Level Up! button with no switch in the game's options to bring them back. Now, as the game closes or reloads, every one the addon switched off goes back on, and at the next start each part switches its own off again (the game's may show for a blink as the game starts). The addon removed before this version, these lines in the chat bring them back (no addon needed): `/script SetCVar("hudFlag", "1")` for the flag, `/script SetCVar("hudLevels", "1")` for the Level Up! button, `/script SetCVar("CombatDamage", "1")` for the damage numbers; the others are on the game's Interface page.
- **A new install starts with the author's look**: the Stats panel on (beside This Run), the XP bar on, SurvivorUI's Level Up! button on (switch it off on a touch screen, where only the game's takes a tap), the boss bars on, the bosses' health on the boss bars and not in the run tracker, no elite bars in the run tracker and its coin on, the cooldown column in the build list, the kills and gold line under the action bar, the loot list filled in its quality's color, with no background and no quality beside the names, the character pane's stats 2 steps larger, the map's cache and lair pins at 12 and 11, the damage meter's text a step smaller and the Jewelry Collection's two; the combat text's columns 140 from the hero, hits added up within half a second, a new best crit held 2.3 seconds. The Stats panel's groups go Offense, Defense, Reach, Utility, the crit first. An install from before keeps how it looks; only the stats' order changes, for a class whose order was never set by hand.

### v3.0.11, 2026-10-19

**Survivor UI**
- **The core as modules: Unit frames, Action bar and Buffs**, each on or off as a whole (Modules, Interface; and at the top of the Frames & bar tab), after a reload. Off, the game's own comes back and SurvivorUI's neither shows nor runs: the game's player and target frames, its whole action bar with the bags and the experience bar, its buffs at the top right. Keeping the bags shut (B opening none) now goes with the action bar; with it off, the row's seven dark slots go too, and its Size no longer touches the game's own buttons and experience bar. With every module off, what is left is the [S] button with the options, Run History, and the switches of other tabs (the chat filter, the cooldown numbers, one font everywhere).
- **Checked against the game's 0.103.0**: its addon API is the same as 0.102's.
- **The run's modifiers, all four, in the kill pace orb's tooltip**: Enemy density, health, damage and speed, a line each with its share, harder than normal in orange, easier in green, the normal ones grey, under "Modifiers (held against runs with the same)". It listed only the ones off 100%, on one line.
- **Run History: an endless run's two badges are its switch**: the purple one says **ENDLESS** (it said FALLEN, as the red one), and each badge holds its time ("VICTORY 20:04", "ENDLESS 44:56"). A click on a badge shows that moment: its badge lit with a line of its color under it, the other dimmed until the mouse is over it. The two tabs under them are gone.
- **Run History: the modifiers as chips**, under the badges in the middle: Density, Health, Damage and Speed, each with its share, harder than normal in orange, easier in green, normal in grey (a run with all four normal shows "Modifiers normal"). They were a grey line of text under the date.
- **Run History: Delete reworked** (new art, a trash can and our own dropdown arrow: restart the game once): a red button of the addon's own kind, with a list over it. **Delete this run** asks once, in a box over the window that names the run; **Clear all runs** asks for the word `clear` to be typed first (Enter works too), and takes every run kept, the pinned ones too. It was a red word asking again at a second click.
- **Run History: our own arrow on the run list**, in gold, in place of the chat's scroll arrow.
- **Run History: the footer reworded**: "RUN HISTORY · 43 of 100 runs kept · 2 pinned", the name in soft gold, the numbers white.
- **The options, spring cleaned** (a new file: restart the game once):
  - **Text size in every tab** with a piece: the same step as its card's A- and A+ in move mode (the two always agree), under its Size. The Jewelry Collection, Run History and Career, which have no card, get theirs too: Jewelry in its tab, the Run History window and Career together in the Run History tab, with a **Size** (they had none) and a **Back to its place**.
  - **One box asks before anything goes**, in the middle of the screen: everything of a kind asks for a word typed first (**Clear all runs**: `clear`, in the window and the Run History tab alike; **Forget the collection**: `forget`, and `/sui collection reset` too), the rest once (Forget this zone's runs in Kill pace, which asked nothing; Every piece back in place, Every size and Every font back to default, Combat text back to default, Stats back to default). Each says how much goes: the runs and the pinned, the pieces, the zone's runs. Before: a second click within 3 seconds, or 10 with a line in the chat, or nothing.
  - **Back to its place always at the right of a tab's first row**: Level Up! now has the head every part has (On, The game's, Back to its place, Size, Text size) in place of its own button choice; the minimap and the guardians list have theirs there too. Frames & bar gains **Frames back in place** (your frame, the target's, the buffs).
  - **The same words everywhere**: the game's own parts are **The game's** (they were "Default" in most tabs), a thing shown or not is **Off** (Combat numbers and the red flag said "None"); Modules names its parts as the tabs do (Kills & gold, Level Up!, Jewelry), in the tabs' order.
  - **Sizes**: the Tooltip's and the nameplates' now 0.5 to 2 as every part's; "Plate size" and "The list's size" are "Size" and "List size"; Combat text's "Text size" is its "Size"; the chat's text size reads in points.
  - **Counters get a Size** for their numbers; the Jewelry tab's note sits beside its button, as the others do; the guardians' note is shorter.
- **The character pane's stats get a text size** (Character pane tab, "Stats text size", -4 to +8 over what their rows give); the Stats panel keeps its own, in its tab.

**Survivor Plates**
- **Plate size from 0.5** (it started at 0.6), as every size in Survivor UI's options; `/splates scale 0.5-2`.

### v3.0.10, 2026-10-19

**Survivor UI**
- **Run History on the minimap** (new art, the hourglass and the push pin: restart the game once): over the [S], a square of its own in the same look, an hourglass in the class's color; a click opens Run History. The game's battleground button now sits over it. Off with "Run History button" (the options, Minimap tab).
- **Every run in a list**: a small arrow beside the run's number opens them all, a line each, "Fallen, Paladin 28 - EF": how it ended in its badge's color (Victory green, Fallen red, Endless purple, Left steel blue), the class and level in the class's color, the map short in green (EF, DW, SM, WSG...), and how long ago. A click goes to it; the wheel scrolls; it opens on the run shown, lit gold.
- **Pin, Career and Runs, one kind of button**: at the foot of Run History, Pin (a push pin, lit gold while the run is pinned) and Career beside it (a crown), and Career's way back, Runs (Run History's hourglass): each a small gold button with its icon, lit under the mouse with a soft glow.
- **This Run without its History button**: Run History opens from the hourglass by the minimap (or /sui history).
- The photo's tooltip says it shorter: a screenshot of this page alone, to share, saved in the game's Screenshots folder.

### v3.0.9, 2026-10-19

**Survivor UI**
- **The game's red flag, our way** (the game's 0.102): the flag the game puts on the minimap, on the lair to head for (the nearest with its guardian, else the one back soonest), is put away, and that lair's mark glows gold instead, on the minimap and in the run tracker's guardians (the bar and the list), and in Run History's tracker. The Minimap tab, "The game's flag": our glow, the game's red flag, or none. Hover the pin: "The game's flag points here."
- **A photo of the page** (Run History, the camera at the top): the rest of the interface put away for a moment, the world dimmed behind the window, and a screenshot taken, in the game's Screenshots folder, ready to share; then all as it was.
- **Fallen to** (Run History, a fall kept from now on): what struck last, large in red (its name and what with, how much, a crit or not; a ground effect when the ground's damage grew after the last hit the combat log wrote), the hits of its last 10 seconds with how long before the fall, and the damage taken by kind as the game counts it (boss melee, mob spell, area...), each in a bar of its share.
- **Personal bests** (Run History, The Run): each number against every earlier run of the same class on the same map, **NEW BEST** in gold where it beat them all (the time, the level, the kills and kills a minute, elites, guardians, bosses, the damage and DPS, gold, caches; the rates only between runs of 2 minutes or more). Worked out as a run is shown, so the runs already kept have theirs too.
- **Career** (new file: restart the game once; Run History's Career button): every run kept added up, by class (its icon and color) and by map (its icon, its name in green): the runs, won, fallen and left, the longest, the most kills, the best DPS, the kills in all; and under them all of it together, with the time played, the damage, the gold and the talent experience. Runs, at its top, goes back.
- **Run History writes the level as the run tracker does**: "Lv. 18" before the race and class, all in the class's color (it was "Level 18").
- **The map's own icon in Run History** (new art: restart the game once): by the map's name, now in green as the game writes a zone's name over the minimap, a parchment map folded in three, green land, a river and a dotted red trail to an X.
- **Run History holds still by its top**: going from run to run, a taller or shorter one grows or shrinks the window downward, its title bar with < and > staying where it is (it was held by its middle, so the arrows moved under the mouse); dragged, it holds by its top where it is let go.
- **Run History with the game's own end** (the game's 0.102): as a run ends, the game now tells addons its end screen's numbers (the result, time, level, kills, elites, guardians, bosses, damage dealt and taken, gold, caches), and Run History keeps those, the same as the end screen. A run **left from the menu** is kept too, as **Left**, in steel blue, its sparks drifting out to the right (an endless run left from the menu too), and **the magnets taken**, a number the end screen does not show, are a row of The Run.
- **The Level Up! button shows its key**: the game's 0.102 gave opening the level-ups a key, Y unless changed in its Key Bindings; the button shows it as a key cap on its right, a glow breathing behind it and a tap now and then as if pressed, and its tooltip says so.
- **A Minimap tab**: the minimap's settings in one place, in the options under Interface. **Square minimap** and the minimap's **size** (from Frames & bar, with Back to its place; drag the minimap or its button while the tab is open), and **the pins**: lairs and caches each on or off with **a size of their own, 10 to 28** (16 as before), the lair marks or the skull, **an empty lair dimmed or hidden**, and **a pin out of reach on the minimap's edge or hidden**. A preview under them draws the pins as set. "Caches on the minimap" in Modules is now **Minimap pins**, the same tick.

### v3.0.8, 2026-10-19

**Survivor UI**
- **Run History loads again on the game's 0.101.0** (fix): the game now runs addons on Lua 5.0, where a function may reach at most 32 of its file's locals. Run History's drawing reached 54, so on 0.101.0 its file did not load at all ("RunHistory.lua: too many upvalues (limit=32)") and Run History was gone. It now draws in four parts. Every file of both addons was checked the same way, and for what Lua 5.0 lacks only as the code runs (string methods such as `s:lower()`, later library functions): nothing else.
- **Lair marks** (new art: restart the game once): each lair wears its own heraldic mark, crossed swords, a shield, a crown, a chalice, a fleur-de-lis, a war hammer, a tower or a helm, each its own shape and color, and the same mark wherever the lair shows: at the left of its stretch of the guardians' bar, before its name in the list, in the count's line, as its pin on the minimap, in place of the skull (its tooltip names it, "Crown lair"), before the guardian's name on its boss bar while you fight it, and in Run History's tracker. Dimmed while the lair is empty. So the stretch counting down 1:06 is the tower on your minimap. Off with "Lair marks" (Run tracker tab, Guardians). An idea from 0xpr1nceh8.
- **Run History says how many it keeps**: its footer reads "11 runs kept (up to 100)", the limit set in the Run History tab; the "1 / 11" by the arrows counts the runs kept, growing to it as new ones come.

### v3.0.7, 2026-10-18

**Survivor UI**
- **Your last runs** (new; a new file, restart the game once): as a run ends, fallen or won, the addon's panels are kept as they stand, up to 100 runs for the account. **Its own tab, Run History**, says which: every run, victories only, or none; 10, 25, 50 or 100; the 10 longest kept however old or not; and how many keep their tooltips (every run, the newest 50 or 25, or none: the tooltips are most of a run's room in the saved file), with what is kept now and its room, and Delete all. In the window, **Pin** keeps a run however many come after it. **History** at This Run's title (or `/sui history`) opens them, one run at a time with < and >: over them the map, the result and when, the hero, race, class and level, and the modifiers; then each panel in a frame of its own and in its own look, in three columns. **The run tracker as it was the moment the run ended** (the clock against the zone's length, the timeline, each boss and the second it fell, the guardians (alive, their health awake, or the time to their return), the elites alive, the level) and **the run's numbers** in This Run's rows, with the talent experience the run gave; **the build** as the build list shows it (every slot, the ranks, the range or cooldown as you had them, the racial) **with its jewelry** and what each piece gives, and **the damage by source** in the meter's bars with DPS and TOTAL; **Biggest Crits** and **the loot** in their own rows, the run second each piece came. **Hover anything for its tooltip as it was when the run ended**, kept with the run: a spell's, a source's or a crit's card, each of the run's numbers, the run tracker, each jewel and piece of loot. The window wears the hero's class color, the class's icon by the map, the result as its title, at the top in the middle, in a box of its color, alive as Move UI's button and the kill pace's orb (Victory green, its sparks rising and a shine crossing it; Fallen red, embers falling; an endless run's end purple, sparks circling it; hover it for the run's time), the date and time in your time zone with how long ago (the game's own clock is in UTC and does not tell the computer's zone: set yours in the options, This Run, "Your time zone"; untouched, the times say UTC). < and > go round (1 is the newest), a click on "3 / 10" takes a run's number, and **Delete** takes the run shown away for good, at a second click. **A run won and gone on in endless mode is one run with two moments**, a tab each by the title: **Victory** as it stood at the victory, and **Endless**, the whole run as it ended, with what the endless part added small beside each number (+7:40, +3120 kills, +180M damage); kept every 10 seconds while it lasts, so a run left from the menu keeps its endless end too. The game's end screen covers the addon's panels and says none of the damage, the shares or the crits.
- **The Level Up! button: SurvivorUI's, the game's, or off**, one choice in its tab ("Button"), and its **Default** tick in Modules as for the other parts the game has its own of. **The game's by default again** (reported by Iceshots): on a touch screen SurvivorUI's took no tap, and the addon cannot tell a touch screen from a mouse, while the game's takes both. Off shows no button at all, for those who keep Store Level-Ups off. SurvivorUI's chosen before stays only if you chose it yourself; left as it came, the game's returns.
- **The meter's bars as the build list's rows**: a little taller, the icon inside the bar with the source's color round it, the filled part never shorter than the icon (a source of 1% too wears its color), as Build and Biggest Crits have them.
- **Call of Flame's crits under its own name** (the "Fire Nova" with no Fire Nova taken): the game writes Call of Flame's blast, the totems exploding as they expire, as a "Fire Nova" in the combat log, while its meter calls it Call of Flame. So Biggest Crits and the combat numbers showed a Fire Nova with the addon's own icon, and Call of Flame's card had no crits. With Call of Flame and no Fire Nova Totem, a Fire Nova is now Call of Flame's: its color, its icon, its crits.
- **The build list names its spells as the meter does**: "Call of Flame", not "Call Of Flame". The colors go by the name, so the two spellings gave the same spell a color in the build list and another in the meter.
- **The run tracker's boss line without "enraged"**: a boss alive shows its health share and the second it came, nothing more.
- **Big numbers written right, and the same everywhere**: thousands k, millions M, billions **B**, trillions **T**, three figures where they fit (4.9k, 282.7k, 1.11M, 9.27B, 10.3B). A late run's billions read as thousands of millions before (9272.7m).

### v3.0.6, 2026-10-18

**Survivor UI**
- **SurvivorUI's, the game's, or neither**: the six parts the game has its own of (the run tracker's clock, the boss bars, the kills and gold line, the build list, the loot list and the damage meter) brought the game's back whenever switched off. Each now has a **Default** tick beside its own, in Modules and at the head of its tab: SurvivorUI's ticked puts the Default away; the Default ticked switches SurvivorUI's off (the boss bars', the run tracker's boss health too) and shows the game's; both unticked, neither shows. The boss bars' tab tells how to keep only the run tracker's own bosses.
- **The meter in the build list's look**: each source's bar on a dark base, its color as strong as the build list's, an edge of it around the filled part, white words, the amount and the share in columns between dividers, and no numbers before the names (the order and the bars say it). Biggest Crits' value in a column of its own too.
- **The meter's numbers in a strip of their own**, under its title: **NOW**, green while above the average, orange while below, **DPS** in gold and **TOTAL**; hover them for what each is.
- **One name, one color for each spell**: the combat log names some spells at more length than the game's build list and meter (Fire Nova Totem for their Fire Nova), so Biggest Crits gave it a color of its own, and its crits stayed away from its card on the meter and the build list. A name that begins with one of the build's spells or the meter's lines now goes by that one: the same color, icon and crits everywhere, the combat numbers too.
- **Biggest Crits' colors as the build list's**: their rows' colors were see-through, so over a bright ground they read lighter than the build list's; both lists' rows now sit on a dark base, the same over any ground.
- **The loot list's own settings** (Loot list tab): rows in a faint wash of the item's quality or **filled** with it, strong, in a black edge, as the list was up to v2.10; the **quality** small beside the name, `(rare)`, `(epic)`, `(legendary)`; how many lines show, 3 to 15; and its background, or the rows on the world itself. Hover a piece for its tooltip once you have worn it in a run, on any hero (the game's loot line names it without its details); until then it says so.
- **Chat filter** (Chat tab; a new file, restart the game once): a run's chat was six lines in ten level-ups, and most of the rest repeated the game's banners. Kept away now, each its own tick, by the game's own events so in every language: the **level-ups** and their gains (the XP bar shows the level), **what the banners show** (the horde's moves, a boss or guardian coming or slain), the **boss yells**, the **loot** while the loot list is on (it reads the line first), and the **Combat Log window**, fed thirteen lines a second whether ever opened or not (SurvivorUI reads the fight from the game's events, never from it: less work for the game). What stays: a new spell, an upgrade's news, the run's end.
- **The chat on the world itself**: the flat chat's dark panel is gone by default; a **Background** slider in the Chat tab brings it back, 0 to 100%, with the addon's color down its left edge.
- **The race's traits on the racial's card**: hover the racial in the build list for what your race gives, as the game tells it in the chat as a run begins (Berserking's cooldowns, Regeneration's health a second, Throwing Specialization's crit...), kept for each race.
- **New first places**, as the layout settled: the boss bars left of the run tracker a little under its top, the Stats panel at the top of the screen right of This Run, the chat low in the bottom left corner, and the new best crit right beside Biggest Crits near its top. A piece already moved stays where it is; Reset on its card, or Back to its place, takes it to the new one.
- Fixed: a long name with `(proc)` on the meter ran its tag past the numbers and out of the meter; the name now ends in "..." first. The build list's **Rank** header broke in two lines. The run tracker's level sat right against the guardians' bar over it.

### Survivor UI Launcher 1.4.2, 2026-10-19

- **The game kept current**: under the AddOns folder, the game's version (read in its exe) and whether a newer one is out, asked of wow.aethus.pl as the launcher opens and with each look at GitHub: "Azeroth Survivors 0.101.0 · 0.102.0 is out: click Update game". Then Play turns to **Update game**: it asks first, with the size, then takes the newest exe and data patches the way Get the game does, each checked by its sha256; the tray says so once too. The game would also update itself as it starts: this is to know, and to have it ready.
- **The game's own notes**: while a newer game is out, What's new opens on Aethus' notes for it, from the game's server, then Survivor UI's.
- **Check version**, a small button under the AddOns folder: asks wow.aethus.pl again at once, the line beside it and the status line saying whether a newer game is out.
- **The game's version on the green button**, small under its words: "Ver. 0.102.0" to play, "Ver. 0.101.0 → 0.102.0" to update.
- **The versions together at the top right**: "Launcher ver. 1.4.2" and "Survivor UI ver. 3.0.9" (a newer one out: "→ 3.0.10", in green), Check for updates under them; the Installed and Latest line is gone, the install button saying the latest.
- The install button in a deeper gold with white words, the beta button in lavender (both readable while they wait, no longer the system's dark grey), and the two ticks (Start with Windows, Update the launcher by itself) told at a glance: on, a box filled gold with a dark check and gold words; off, an empty dark box and grey words.
- At the bottom, whose game it is on the left and his site, wow.aethus.pl, in the other corner.
- **No game found, the way to it**: the status line opens on "No game found: click Get the game, or Find game... if yours is somewhere else", or, with the game's exe and no data, "The game's data is missing: click Get the game to fill it in". It sent a new player to Find game... before, with Get the game right beside it.

### Survivor UI Launcher 1.4.1, 2026-10-18

- **Get the game gets all of it**: the game's base data (`Data\patch.MPQ`, 1.28 GB) is in none of the indexes the game updates itself by, so 1.4.0 left a new player with the game's exe alone, and a game with no text nor world. Now it takes, each only when missing: the full package Aethus' site offers, for the base data (unpacked by Windows' own tar), the newest game, and its newest updates, each checked; about 800 MB in all, asked first with the sizes, and the room on the disk checked before.
- **An install from 1.4.0 mended**: a game with its exe but no base data counts as missing, so Get the game shows again and fills in what is not there.

### Survivor UI Launcher 1.4.0, 2026-10-18

- **Get the game**: with no Azeroth Survivors found, the Play button turns to **Get the game**. It asks first (the version, the size, where it goes), then downloads the game from Aethus' own servers, the same way the game updates itself, checks it against the game's own sha256, puts it in its usual place (`C:\Git\wenilla\benilla-config`) and installs Survivor UI with it. With Aethus' ok; nothing is hosted anywhere else.
- **The game found in its usual place by itself**, on a first start, with no "Find game..." needed.
- **Whose game it is**, at the bottom of the window: Azeroth Survivors is a game by Aethus, with a link to wow.aethus.pl.

### Survivor UI Launcher 1.3.1, 2026-10-18

The installer is now the **Survivor UI Launcher**: it plays the game and keeps Survivor UI current. Its file stays `SurvivorInstaller.exe` (in `SurvivorUI-Installer.zip`), so the launchers out there find and take it.
- **A new emblem**: the golden S on a shield, on the exe, the window, the taskbar and the tray (the green arrow on it while an update waits).
- **The release and the beta as two buttons**, each with its version: the release large and gold (`Install v3.0.5`, `Update to v3.0.5`, `Back to stable v3.0.5`, or `Up to date · v3.0.5`), the beta under it, smaller and orange (`Install beta v3.0.6-beta.1`), when one newer than the release is out, with its warning first. The Beta builds tick goes: a beta installed follows the betas, and the gold button takes you back.
- **Its own version at the top right**, with **Check for updates**; a newer launcher out lights a green arrow there, and the button turns to it, green.
- Fixed: the "Open folder" link over the hint's last word; "Installed" left as it was once Survivor UI changed while the launcher stayed open.

### v3.0.5, 2026-10-18

**Survivor UI**
- **A tab for each panel**, the tabs in five groups down the sidebar: **General** (Global, Modules, Layout), **Run** (Run tracker, Kill pace, Boss bars, Kills & gold, XP bar, Level Up!, Loot list), **Combat** (Combat text, Damage meter, This Run, Biggest Crits, Counters), **Character** (Build list, Character pane, Stats panel, Jewelry) and **Interface** (Frames & bar, Chat, Nameplates). Each panel's tab opens with the same head: its **switch** (the same as its tick in Modules), **Back to its place**, and its **size**; then its own settings, the panel draggable while the tab is open. The Panels and Size tabs go: their settings live with each panel now, the whole interface's size stays in Global.
- **What the tabs hold now**: the Boss bars' elites and health; the Kills & gold line's place and layout; the XP bar's time to the next level; the Build list's range and cooldown; the Character pane's stats beside the hero (the pane opens with the tab, and closes again after); the Stats panel's place, size and this class's stats; the Jewelry's place beside the pane and its forgetting; Frames & bar's health numbers, the action bar's looks, its joined frames and centering, and the sizes of the center bar, the minimap and the tooltip; the Chat's text size (only `/sui chat` before); the guardians' look and their list's size in Run tracker; in Layout, every size back to default beside every piece back in place. The kills and gold line, under the minimap now, has a size of its own, out of the center bar's (as large as it was).
- **Each setting once**: the coin's shine is set in Kills & gold only, the Jewelry Collection beside the pane in Jewelry only; Biggest Crits' clearing (its own Reset does it) and the Damage meter's view (its title's menu) left the tabs; Counters is one section of three ticks; Combat text opens with one choice, SurvivorUI's numbers, Default's or none.
- **The character pane's stats and the Stats panel, each on its own**: the numbers beside the hero in the pane (on unless switched off: the Character pane tab), and the **Stats panel**, the same numbers as a panel on the screen all the time, now a module of its own (Modules, and the Stats panel tab: its place, its size, its corner), both on at once if you like. The window of its own that opened with the pane is gone: whoever had it keeps the pane's numbers, and "always shown" becomes the Stats panel on. Which numbers show, and their order, are the same in both.
- **The character pane moves like the other pieces**: dragged while its tab is open or in move mode, with a card of its own (its place in numbers, its size, Reset), and **Back to its place** in the Character pane tab. The Jewelry Collection beside it goes with it.
- **Level Up! button** (new, for the game's 0.98): with the game's Store Level-Ups on, a level-up no longer stops the fight and the levels wait; the game's button for them sits over its own action bars, where Survivor UI's compact bar is not, so the addon draws its own in its place: over the action bar, `LEVEL UP!  x3`, breathing a gold glow, a click choosing them one after another. Movable and sized like the other pieces, with its own tab (Run, Level Up!), which also switches the game's Store Level-Ups; off in Modules, the game's button comes back. The levels waiting show by your level too, in the run tracker and on the XP bar: `Lv. 12 +3`.
- **Range and cooldown in the build list** (the range asked by Iceshots): beside each spell its range, read off the spell's own tooltip (its radius for one with no range), and its cooldown as it stands, haste in; each its own tick in the Build list tab, in columns under a header, **Range | CD | Rank**, between dividers. A column switched off goes and the name takes its room. The share of the damage is gone from there: the meter has it.
- **Damage a second right now** (asked by wayn3): the meter's numbers each named, `total 238.8k` over `719 dps   now 2.5k`: the run's damage, that a second on average, and the damage a second over the last five seconds of the run's clock, the two rates together as the game's own meter has them (the healing's too, in its view). Hover them for what each is. Off in the Damage meter tab, "Damage a second right now".
- **The guardians as a count, or off** (Run tracker tab, "Show as"): besides the bar in the tracker and the list beside it, only a count, `Guardians   3 / 5 alive`, one line in the tracker (orange while one is awake), or none at all, the same as their tick in Modules.
- **The game's Czech** (its 0.99): the spells, jewelry and bonus lines read back to English with the game set to Čeština, as in its other languages, so the meter's colors, the build list and the Jewelry Collection work there too. Every free font that comes with the addon writes Czech.
- **The bursts' icons** (the game's 0.98): Seed of Corruption's and Shadowform's bursts now go off as Corpse Explosion, Toxic Bloom's as Noxious Cloud; on the meter, the combat text and Biggest Crits they wear the icon of the spell they come from.
- **One name for each piece**, the same in move mode, its tab and Modules (Build list, Loot list, Kills and gold line, Stats); a font chosen for a piece stays with it.
- **The stats always shown come back with each match** (reported by AkumaMini): on their own and always shown, they stayed away once a match closed and another began, until their place was chosen again; they show again by themselves now.
- **A guardian hurt is a fight** (reported by Iceshots): one feared or held from the first hit never turns on you, and the game still calls it asleep, so its health stayed away from the tracker's guardians and the boss bars; a guardian already hurt shows its health now.

Note: from the game's 0.98, the harder zones' last minutes are tougher (Gurubashi Arena on: the horde gains health as the run goes). Your runs there from before it were faster at the end, so the kill pace orb reads slower late in a run until newer runs replace them: the Kill pace tab's **Forget this zone's runs**, in each of those zones, starts them over.

**Installer 1.3**
- **Play**: a button beside Install, and an item in the tray's menu, that starts the game (the one by the AddOns folder); the installer steps into the tray. It waits while an install runs, and says so when the game is open already.
- **It updates itself**: a newer installer out lights a green **Launcher update** button at the top of its window, breathing so it is seen, and an item in the tray's menu; with **Update the installer by itself** ticked (the default), it takes it at once and starts again, in the tray if it was there. The installer 1.2 and older cannot: download this one by hand once.
- **Closing keeps it in the tray**: the window's close button puts it there, like minimizing, still looking for updates. To quit it, right click its tray icon and choose **Exit**; the first time it says so.
- **Beta builds** (since 1.2): a tick in the window and in the tray's menu for the test builds that come before a release (GitHub's pre-releases), with a warning first: more bugs than usual, updated more often. Ticked, it installs the latest beta and follows the betas from then on; unticked, it offers the release again ("Back to"). A version with `-beta` is read right: the release stands above its betas.

### v3.0.4, 2026-10-18

**Survivor UI**
- **Time to the next level** (asked by Floowi): the pace of your experience over the last 45 seconds of the run (its own clock, which stops while you pause or choose a card), the levels gained counted across, tells when the next level comes, once 10 seconds are in. Beside the level at the run tracker's foot (`Lv. 12  next in 0:42`), and on the new XP bar.
- **XP bar** (new, Panels): your level and experience as a bar of its own, at the top of the screen and movable, with no backing: the experience and its share, the bar marked at every 20%, and under it the time to the next level (`Next lv. in 0:15`) and the experience a minute. Off until chosen; the time to the next level on or off on its own.
- **Modules** (new tab, `/sui opt`): each part of SurvivorUI on or off as a whole, in one place, two columns, hover one for what it does: the run tracker, kill pace, guardians, boss bars, caches on the minimap, kills and gold line, XP bar, loot list, combat text, damage meter, This Run, Biggest Crits, counters, character pane, build list, Jewelry Collection, ability tooltips, flat tooltips, flat chat, square minimap, menu buttons, white outline and nameplates. Off, a part does not run at all, and the Default comes back where there is one; those that restyle the game's own windows take hold after a reload (marked *). The other tabs keep only how each part shows, their sections saying "off in Modules" while it is off. The counters and the Jewelry Collection have a switch of their own now.
- **The tracker's XP bar, as chosen** (Run tracker, XP bar): the level and the bar at its foot on or off, and the time to the next level beside the level on or off. Both can show with the XP bar of its own.

### v3.0.3, 2026-10-18

**Survivor UI**
- **The kills and gold line stays centred once moved:** a line moved by hand was kept by its left edge, so, as wide as its numbers since v3.0.2, it drifted to the right as they grew (reported by Amarolk). It is kept by its middle now; a place saved before is read once as its middle.

**Installer 1.1.1**
- Unzips only the `SurvivorUI` and `SurvivorPlates` folders, as it says: the release zip's license, at its top, was left loose in the `AddOns` folder.

### Installer 1.1, 2026-10-17

- **Waits in the tray and tells of updates**: minimized, the installer goes to the tray by the clock instead of the taskbar, and asks GitHub for a new release every half hour. When one newer than the installed addons is out, a green arrow shows on its tray icon and on its taskbar button's corner, and a note says so once; a click on the note or the icon opens it, ready to update. Right click the tray icon for Open, Check for updates now (which brings it forward and installs a newer release at once), Install and Exit. With the latest installed, a green "Up to date" badge stands where the install button was. Opened again while it runs, the one running comes forward.
- **Start with Windows, in the tray**: a tick in the window, beside the install button, and the same in the tray's menu; on, it starts with Windows straight into the tray and looks for an update. It writes one line in your own startup list (the Run key of your user), and takes it away when unticked.
- **Open folder** is now a link under "Find game...", by the folder it opens, in place of the button beside Install.
- **Read larger**, by "What's new": the latest release's notes in a large window that reads well, the headings in gold, a bullet for each item.
- The window's title is Survivor UI alone.
- **Its own icon**: the addons' gold S, on the exe, the window and the tray.

### v3.0.2, 2026-10-17

**Survivor UI**
- **The kills and gold line, shorter**: `(skull) 220   (coin) 114/20`, a red skull for the kills, the run tracker's gold coin and your gold against the next cache's price, in place of `Kills 220   Gold 114   Cache 20`; its first place is now under the minimap, between it and the run tracker. Its coin shines as the tracker's did while the next cache can be paid; the tracker's own coin is now off until chosen (Run tracker tab, Coin on the tracker), "Shine when you can pay" being both coins'. In Panels the line has a section of its own: its place, under the minimap, under the action bar or off (the Default box); what it shows, the kills then the gold, the gold then the kills, the kills only or the gold only; the gold and the cache apart, the coin with your gold and the minimap's chest with the next cache's price; and its coin's shine.
- **Combat text columns move** (the Combat text tab, or Move UI), as the new best crit does: the damage numbers, the crits, the damage taken and the heals, each a piece with its card; the damage taken and the heals can be put away there too. A column moved stays put whatever the distance chosen.
- **The damage taken in a line**: hits taken together fell side by side, spreading up to 160 to the left, and the last ones over the action bar; they now line up in their column, one behind the other, as the damage does, and a swarm's hits in the same instant add up in one number. The heals too.
- **Heal numbers work**: the game's heals never reach the combat text's feed, so none showed; they are now read from the game's healing meter, each source's with its icon. A trickle (regeneration, a ring's health per second) gathers until it is worth a number, 2% of max health.
- **Reset (Default)** on a piece's card in move mode, said plainly.
- **The combat text's first places, laid out anew**: the damage and the crits 170 out from the hero, level with it; the heals over the hero; the damage taken under the action bar; the new best crit beside the Biggest Crits, where the bests are listed (following them when moved). For a new install and the "back to default" button, which now puts the columns back too.
- **The Combat text tab, tidier and with more to set**: the crits' own size; the smallest heal shown (2% of max health first); "Show a sample" (or `/sui sample`) plays every number as set, a new best crit too.
- **Numbers add up**: the damage, the crits, the heals and the hits taken, each as chosen (Combat text, Add up): one source's hits close together (200 ms first, 50 to 500) show as one number, their sum and how many, `1.2k x3`, so a swarm or an area spell reads instead of piling up.
- **SurvivorUI and Default**: wherever the addon's look and the game's were "the addon's own" and "the game's own", they are now SurvivorUI and Default (Combat text: SurvivorUI, Default, None).
- **Moving, tab by tab**: the options open without move mode, and each tab's own pieces can be dragged (or clicked for their card) while it is open, so you can play while setting them: Panels the panels, Run tracker the tracker and the guardians, Combat text its columns and the new best crit, Unit frames your frame, the target's and the buffs, Interface the chat, the minimap and its S button (now a piece of its own, following the minimap); the other tabs none. **Move UI**, now at the top of every tab beside its title, bright, unlocks them all over the grid as before, and minimizes the window as it does; at the bottom, **Save & Close** takes Reload interface's place (Reload & Close while a look waits for a reload). The - beside the x minimizes the window to a small bar of three buttons, Maximize, Move UI and Save & Close, to set the pieces with the screen free; the open tab's pieces stay movable. The minimap button: a click opens the options, a right click moves the whole UI.
- **Minimap pins and guardian arrows on every map, instances too** (the game's 0.97): the game now sends the hero's place in the world, in the caches' and lairs' own yards, and the way faced, so the pins and the guardians' distances need no map at all: the Scarlet Monastery, Blackrock Mountain, Naxxramas and Ahn'Qiraj have them now. The guardians' arrows turn with the way you face, standing still too. Indoors (most of an instance) the minimap draws closer, at a zoom of its own, and the pins now keep to that scale, so they sit on the cache, not short of it. On an older game, the map's way as before. `/sui pins` shows the hero's place and facing, the nearest cache and lair, and the minimap's scale.
- **The Jewelry Collection's codex, read again for the game's 0.97**: Heavy Dark Iron Ring (+25% to +57% max health), Lifegiving Gem (+20% to +46%) and Archimtiros' Ring of Reckoning (+4.4% to +10% damage reduction, +18% to +40% max health) give their new numbers at each rarity, and Master Dragonslayer's Ring reads "critical strike chance", as the game writes it now.
- **Romanian, Ukrainian and Japanese** (the game's 0.97): the game's words read back in English in them too (the codex, the meter, the build list's bonuses), the loot line read, and the free fonts offered where they write them.
- **Buy me a coffee :)** in the options window's corner, over the credit: a click shows the Ko-fi link to copy (the game opens no link).
- **The run tracker's tab holds all of it** (`/sui opt`, Run tracker), each part on or off on its own and apart from the boss bars: the bosses' health (shown as `73%`, `1.2M | 73%` or `1.2M`), the guardians, the elites (4 to 12 bars, or the row only while one is alive) and the cache coin (and its shine). A guardian or an elite in the tracker is clicked to target whatever else is on.
- **Boss bars apart from the tracker** (`/sui opt`, Panels): the bosses and the awake guardians, with the elites when asked, whatever the tracker shows; with the bosses' health in the tracker they had stayed away whole, elites and all, though "Elites on the boss bars" was on (reported by Faya). Off on a new install, as the tracker shows the bosses already; the Default ones stay away while either shows them.
- **New best crit, set up in Combat text:** on or off, what counts as a best (each ability's own, or the run's biggest), how long it stays, its size and its glow; and it moves like any piece in move mode. The tab's mode and "What shows" now sit in a row each, and a note says that None turns every combat number off, Default's too.
- **Build list, every amulet bonus:** a stun, a root, a shield, an absorb and a weakening had no short name and were left out (Heart of the Earthshaker's "hits stun for 1.5 sec"), and two read wrong: they show now as `STUN 1.5s`, `ROOT 2s`, `STUN 20%` (a chance to stun), `40% SHIELD`, `+30 ABSORB`, `+5 WEAK`, and a stun's added duration as `STUN +0.5s` (was `DUR`), a shield of your max health as `SHIELD` (was `HP`). Games in another language read them too.
- **Crit records** (new), to see a build grow: the crit that beats its ability's best shows in the combat numbers larger and gold over a glow, "NEW BEST CRIT" over it, standing still for about two seconds instead of climbing with the rest (an ability's first crit only sets its best); and each ability's card in Biggest Crits says how long ago its best was set. `/sui record` shows how it looks.
- **This Run's tooltips beside the panel:** with This Run now at the top of the screen, a row's tooltip, opened above it, was pushed down over the rows, under the mouse's white outline. They open beside the panel now, level with the row, on the side of the screen with room.

### v3.0.1, 2026-10-17

**Survivor UI**
- **The cache coin turns red:** short of the next cache's price it stayed grey. The game's engine greys a texture with its colors taken out and ignores any tint put on it after, so the coin was never red; a red coin of its own, drawn as the gold one, now takes its place.

### v3.0, 2026-10-17

**Survivor UI**
- **Guardians** (new): a small list against the run tracker's left side, with no background. A line a lair: a little arrow toward it, the guardian's name and how far it is in yards, and asleep, awake with its health, or slain at its second and back in so many seconds (an empty lair is claimed again 20 seconds on). The client cannot tell which way you face, so the arrows turn with the way you walk, straight up ahead; standing still they keep the last way, or `/sui guardians north` points them north up as the minimap does. Over it, the achievement "Slay four guardians before 8:00": `1/4 by 8:00 · 6:41`, green once done. The nearest living guardian's arrow is larger and breathes, and every arrow has a dark shadow to stand out; walking straight at a guardian turns its arrow gold over a glow, and within 10 yards of a living one its line flashes. On or off in `/sui opt`, on the new Run tracker tab (with the tracker's own switch), or `/sui guardians`; hold Alt to move it, its own size in Size. It stands against the tracker's left side, and the kill pace's boss banner shows under it. Or, as a bar in the run tracker (`/sui guardians bar`, the default), a bar inside the tracker over its level: a stretch a lair, green while its guardian is there with its arrow in the middle (four greens, the nearest lightest), orange while you fight it, its health draining it, red once slain with the time until it is back; over it, a thin line with the 8:00 achievement, and the tracker's level and experience under it.
- **A card for each piece, in move mode** (new): click a piece and its card opens beside it: its name with `<` and `>` for the next piece; its place from the screen's middle, to type or to nudge by one (Shift by ten); centered across or up and down at a click; its own size; shown or hidden, for the pieces that can be put away; back to its first place; and undo. Its font too, picked from a list where each face is written in itself: the game's own (Friz Quadrata, Arial Narrow, Morpheus) and five free ones that now come with the addon (Fira Sans, Noto Sans, Exo, Russo One, Cinzel Decorative); and the text's size a step at a time. The arrow keys move it, Ctrl+Z undoes, Escape closes, Done too. Every font back to default at once: `/sui opt`, Global. Pieces now show bright corner marks, and one let go near a neighbour's edge (or middle) lines up with it.
- **Your class's color** (new): the addon's own color, gold until now, is your class's: the piece cards and their font list, move mode's marks and grid, the options' title and Global page, the chat's edge line and the minimap button's S. Prefer the gold? `/sui opt`, Global.
- **Global tab** (new), first in `/sui opt`: what holds for the whole addon. The **global font**, new: one face for every text of the addon's at once, picked from a list where each face is written in itself (the game's, or the five free ones that now come with the addon); a piece with a font of its own keeps it, and with One font everywhere (moved here from Interface) the game's own text wears it too. Every font back to default (moved here from Layout). The addon's color: your class's, or the gold of before. The whole interface's size (moved here from Size, which keeps each part's).
- **New defaults**, for a new install and for each "default" button: the whole interface at 0.90, the action bar at 0.85 and the whole center bar at 0.90; the boss bars against the run tracker's left side; the guardians as a bar in the run tracker and the bosses' health there too; Biggest Crits on, elites on the boss bars; the target's and the boss bars' health as `1.2M | 73%`; the combat numbers 140 from the hero, rising 170; chat text 8. What you have set yourself stays as it is.
- **The stats a class shows by default:** every number but the damage over time ones (DoT Stacks, DoT Haste) and the bonus damage ones (Vs Elites, Execute, Vs Controlled, Vs Afflicted, Shielded, Melee, Pet Damage), which stay at nothing in most runs. Each can be switched on in `/sui opt`, Character; `Default for this class` gives this back. A class whose stats you have already switched on or off stays as you left it.
- **Options window, tidied:** the tabs in a new order (Kill pace next to the Run tracker) and each in a color of its own; every page in titled sections; notes that wrap instead of running past the window or over the next line; checks that read as on or off in any color (a priest's white too); every text read again (no more "Mythic+ timer", the boss bars where they are now).
- **The game's own build, put away**: while the Build list is on, the game's row of spell and jewelry icons with their cooldowns (Show Build on its Interface page) is hidden, as the game's clock, kills box and meter already were; switch the list off and it comes back.
- **The game's own loot notices, put away**: while the Loot list is on, the cards the game pops up mid-screen for each piece a boss drops (Show Loot Notices on its Interface page) are hidden; switch the list off and they come back.
- **Loot list, in the theme:** the same dark box, gold title and rows as This Run, each item in its quality's color over a faint wash and a thin line of it, in place of the solid bars (asked for by Alexth).
- **The left column, in order:** This Run at the top, Biggest Crits under it, and the Loot list last, under the crits (or under This Run while there are none). The Loot list shows only once something has dropped: no empty box.
- **A coin for the next cache** (new): on the run tracker, left of the clock, a gold coin (a reeded rim, a star in relief): shining when the gold you carry pays for the next cache (a glow that breathes, a spark on its rim, a burst the moment it is enough), red when it does not yet. Hover it for the price and how much is missing. The kill pace's orb moves to the clock's right, and the run's state (Choosing, Victory, lives left) up to the zone's line.
- **Elites in the tracker** (new, on by default; `/sui opt`, Run tracker): under the guardians, a small orange bar for each elite alive, filled with its health; bright once it has taken a hit (the game tells of no fight but the health), dim while whole, the most hurt leftmost, and over them how many are alive and how many fighting. Hover one for its name and health; with the boss health in the tracker, a click targets it.
- **Boss health in the tracker** (an option, in `/sui opt`, Run tracker): in place of the boss bars, a boss alive fills its line in the tracker with its health, in the fight's orange as a guardian awake, and its share, and a click on it targets it; a click on a living guardian's stretch of the guardians' bar targets it too (by name: an elite of the same name may come first). On by default; switched off, the boss bars come back, with their debuffs and elites.
- **Combat text, smoother and shorter:** each number comes in over a tenth of its life, rising a little into place, and fades out softly over its second half; big numbers read short (`1475` as `1.5k`), as the health does. "Short numbers" in `/sui opt`, Combat text.
- **Run tracker:** the level reads `Lv. 32`.
- **Build list, jewelry in plain short words:** the number first with its sign, then the word: `+24% DMG`, `+1 TGT`, `-19% CDR`, `2.2% LEECH`. Bonuses that were wrong or missing now read right: a kill's heal is `+3 HP/KILL` (was `HP 3`), and a legendary amulet's leaps, splashes, bleeds and second strikes show too (`LEAP 2x36%`).
- **Caches and lairs on the minimap in every outdoor zone:** a zone whose run fills only a corner of its map (Feralas) had no pins, and the guardians no distances: the yards a map unit spans are now found from places 0.4% of the map apart, not 5%.
- **Known limit, the new dungeon and raid maps** (Scarlet Monastery, Blackrock Mountain, Naxxramas, Ahn'Qiraj): no caches or lairs on the minimap there, and the guardians show no arrow or yards (their names, state and timers still do). Inside an instance the 1.12 client gives addons no place for the hero on the map, as the original game never drew your arrow on a dungeon's map, and the game's addon API sends where each cache and lair is but not where the hero is: with nothing to measure from, there is no pin to place. Outdoors nothing changes. Should the game come to send the hero's place, they come back.
- **Totem counter** (new): over each totem's button, how many of it are down, and the seconds until the next one ends. The game writes nothing as a totem goes down or ends, so each cast (its cooldown starting over) counts one totem for the time its tooltip gives: two set down at once by a talent count as one, and one that drops on its own is not seen.
- **Counters tab** (new) in `/sui opt`: the DoT, fear and totem counters, each on or off, and what keeps each from being exact. `/sui dots` switches them all.
- **Searing Totem, named right:** its shots come in the combat log as an "Attack" for Fire damage, so Biggest Crits listed them as "Attack" and the combat numbers showed the weapon. With the totem among your spells, a Fire "Attack" is now the Searing Totem's.
- **DoT and fear counter** (new): over each damage over time spell's action button, how many of it are out on the enemies. The game does not say when a DoT ends on an enemy that dies, so they are counted by their ticks: each one out ticks once a second (quicker with DoT Haste), and an enemy that dies drops out on its own. Any spell that ticks counts. A fear is not written at all, only its hits, so over Psychic Scream, Intimidating Shout, Howl of Terror and Fear it is the enemies hit within the time they flee (read off the spell's tooltip, 3 seconds for Psychic Scream), bosses left out. In the spell's damage meter color; on or off in `/sui opt`, Counters, or `/sui dots`.
- **Pickup range, in every language:** a piece giving pickup range (the Gnomish Universal Remote) seen with the game in another language showed its bonus twice in the Jewelry Collection, once in that language's words, and had no short name in the Build list: the game writes "pick up", and the addon looked for "pickup". The collection joins the two on its own.
- **Jewelry Collection, each bonus once:** a bonus with two numbers (the Eye of the Splitting Sky's "hits leap to 2 more enemies for 30%") showed a line for every value seen; now one, `for 30-71%`. "Strikes 1 more target" and "2 more targets" are one line, `1-2 more targets`. A legendary amulet's short codex lines give way to its own once it has been worn.

### v2.11, 2026-10-16

**Survivor UI**
- **Every language the game speaks:** in a game set to German, French, Spanish, Portuguese, Polish, Turkish, Russian, Chinese or Korean, the game names spells, jewelry and bonuses in that language while the combat log stays in English, so several pieces matched nothing. Now each name and bonus goes back to English first, with the game's own translations:
  - **Jewelry Collection:** found pieces match the codex, so the ones still to find tick off, and your class's amulets are known by their spell. Pieces are kept under their English names: one collection whatever language you play in.
  - **Damage meter:** each line gets its icon, rank, color and crit card again, the white damage its weapon, and the combat text the same colors as the meter.
  - **Build list:** jewelry bonuses get their short names again (`CRIT DMG`, `CDR`...).
- **Jewelry Collection, one piece once:** pieces kept twice, once in another language (from before this version, or with the game's language switched), join into one on their own, their bonuses too; a class's amulets join by their spell.
- **`/sui collection reset`:** forgets the whole collection (asked twice, within 10 seconds).
- **Build list:** "your critical strikes deal X% more damage" reads as `CRIT DMG`, not `CRIT`.

### v2.10.2, 2026-10-16

**Survivor UI**
- **Loot list in every language:** it read only the English loot line, so in a game set to German, French or any other language it always said "Nothing yet". It now reads the game's loot line, and its "New in your collection", in all ten of the game's languages.

### v2.10.1, 2026-10-16

**Survivor UI**
- **The options window can't get lost anymore:** dragged past the screen's edge (or left there by a change of size), it opens in the middle again, and `/sui layout` brings it back too.

### v2.10, 2026-10-16

**Survivor UI**
- **Kill pace** (new): a glowing orb on the run tracker, left of its clock, that tells how fast the enemies die against your own runs.
  - Kills a minute over the last 20 seconds of the run's clock, held against your runs on the same zone and modifiers at the same minute of the run, as a run grows thicker as it goes on.
  - Red as slow as your slowest run at that minute (its sparks sinking), yellow in between, blue near your fastest, green as fast or faster (quick sparks and stars). White until three of your runs reach that minute.
  - Every class's runs by default, to see how one hero does against another (the fastest and the slowest name their class); `/sui pace class` holds it against this class's only. Only runs with the very same modifiers count.
  - **Stretches:** as each boss comes, a banner left of the tracker tells the stretch just ended, from the boss before (or the start): its kills, their share of your best on it and its place among your runs (`2nd of 6`), in the color of how it went.
  - Hover the orb for the numbers: kills a minute, the share of your fastest, your fastest, average and slowest, the enemies alive, the stretch going on and the run's modifiers.
  - Each run keeps its kills minute by minute, its stretches and its class: the last 60 of each zone and modifiers, on your own PC. A run of under two minutes, or one joined after a reload, is not kept.
  - **Its own tab** in `/sui opt`: on or off, every class's runs or this class's, the seconds the rate is read over (10 to 60), the runs a minute needs before it is colored (1 to 10), the sparks (full, calm or none), the boss banner and how long it stays, and a button to forget the zone's runs. Also `/sui pace`, `/sui pace class` and `/sui pace reset`. It moves and sizes with the tracker.
- **This Run:** a Kills / min row under Kills: the last 20 seconds' rate, and the whole run's beside it in small type.
- **Health numbers,** on a new Unit frames tab in `/sui opt`: your frame, the target frame and the boss bars each show the health as a percent (`73%`), the health left (`1.2M`), both (`1.2M / 3.4M`) or the health left and the percent (`1.2M | 73%`), always short: 1k, 1.1k, 2M, 2.2M. Your frame keeps its `1.2k | 100%` and the others their percent until you pick another.
- **Jewelry Collection:** what you wear now comes first in its group, to see at a glance, and your class's amulets come in order, the one worn first. A class amulet with no icon of its own (one not yet worn on this game) shows its spell's. The Common Quick Strike Ring's bonus is filled in (-14% cooldowns).

### v2.9, 2026-10-16

**Survivor UI**
- **Jewelry Collection** (was the jewelry book): every one of the codex's 39 shared amulets, rings and trinkets, the ones still to find by name, each with what it gives at every rarity; and your class's legendary amulets by spell, in your class's color and icon. Group titles are progress bars with what you wear now (`Rings - 2/2`), a green `E` marks what is worn, and it opens from its own button on the character pane, beside it. One collection for the whole game folder, every class and account filling it.
- **Combat text, rebuilt from scratch:** three modes (Survivor, the game's own, none at all) and Survivor's own settings: beside the hero or over the enemies, the distance and how far the numbers rise, crits in their own column, source icons, damage meter colors, the text size, and whether damage over time, heals and damage taken show. A `Survivor defaults` button sets it back. The default now: beside the hero, with icons and the meter's colors, the type 15% smaller.
- **Weapon icons:** melee shows the weapon in hand, shots the ranged weapon, in the damage meter and the combat text.
- **Character pane:** the hero's class color on the name line and the border; always in front of the panels; the Skills, Honor and other tabs put away; 15% smaller by default (its own size in Size). The numbers on their own take the panels' look when always shown and resize by their corner; a new Character tab picks, per class, which numbers show.
- **Size:** the minimap and a whole center bar slider join the parts.
- **Smaller:** the options window, tooltips and right click menus (20%), the minimap buttons, the chat text (10 by default).
- Bags no longer open (B); the old experience bar stays away while the run tracker is on.

**Both**
- Every file names its author and license.

### v2.8, 2026-10-16

**Survivor UI**
- **New options panel:** tabs down the left, each in its own color (Panels, Combat, Nameplates, Interface, Size, Layout), a short note on every choice, and **Move mode** always at the bottom, next to Reload, lit while it is on.
- **A size for each part:** the action bar, the player and target frames, the buffs, the kills and gold line and every panel each have their own slider, on top of the whole interface's (`/sui scale`). Moved pieces keep their place. Whoever had changed `/sui scale` keeps the bar and the frames at the size they had.
- **Jewelry book:** a new ring button by the minimap (or `/sui jewelry`) opens every neck, ring and trinket your class has worn, each with the range of every bonus seen (`CRIT DMG 29-86%`). One book per class for the whole game folder: every character and account on it fills the same books. A slim list, quick to read in a fight; hover a piece for its bonuses written out.
- **Damage numbers beside the hero are now the default:** hits on the left, crits on the right, heals rising and damage taken falling below. Over the enemies and the game's own are still in Combat.
- **No combat text at all:** a new choice in Combat (`/sui damage none`): no numbers and no floating combat text.
- **Loot list** is out of beta.

**Survivor Plates**
- **No nameplates by default:** the boss bars show every boss, guardian and elite already. Turn them back on in `/sui opt`, Nameplates, or `/splates none`.
- A plate size slider in the options.

### v2.7.1, 2026-10-15

**Installer**
- Recommends where the game should be: `AzerothSurvivors.exe` inside the game's `benilla-config` folder, usually `C:\Git\wenilla\benilla-config`. The hint sits under the folder box, "Find game..." opens there, and picking the game anywhere else asks first, showing where the addons would go.

### v2.7, 2026-10-15

Built on the game's new addon API: healing and boss meters, debuffs, caches and lairs.

**Survivor UI**
- **Healing and boss damage in the damage meter:** click the meter's title for a menu: Damage Done, Healing Done (the run's healing, overhealing left out) or Boss Damage (the last boss fight). No need to switch to the game's own meter anymore.
- **Debuffs on the boss bars:** every boss, guardian and elite shows its debuffs as small icons inside its bar. Each drains to grey as it runs out, with the time left in the middle, the stacks in the corner and its dispel type's color on the edge.
- **Caches and lairs on the minimap:** a golden chest for each cache, a horned skull for each guardian's lair (grey once empty). One out of range sits on the minimap's edge, pointing the way. Hover a pin for what it is and how far. Off in the options; `/sui pins` prints what the addon reads.
- **Jewelry bonuses with their values:** `CRIT DMG 86%`, `CDR 31%`... The text gets smaller on its own when a piece has many (legendary amulets), and a legendary amulet's spell is shortened (`Consec.`, `HoJ`) to leave room.
- A piece past rank X shows `X+`, as its name does.
- **Damage numbers beside the hero** (test, off by default): `/sui damage side` or the option. Hits rise on the left, crits on the right, heals rise from under the hero and damage taken falls below it. Type it again to go back.
- The grey bar the client shows at the top level (99) is gone.
- The meter's title lights up in gold under the mouse, without the white outline.
- The options panel names the author and the repository.

**Both**
- **License: GPL-3.0** from this version on (v2.6 and earlier stay MIT). Copies and changes stay open source and keep the credit; see Credits.

### v2.6, 2026-10-15

**Survivor UI**
- **Jewelry in the build list:** the gear section shows only the jewelry, the gear a run drops: one row for the neck, each ring and each trinket, filled with the piece's quality color. Each row has the slot, the piece's rank in Roman numerals (read off its name, "Blackhand's Breadth IV") and what it gives in short (`CRIT DMG`, `CDR`, `LUCK`...). An empty slot is faint. Hover a piece for its tooltip.
- **Legendary amulets:** the row names the spell the amulet boosts in place of "Neck" (`Consecration IV`), with what it adds to it: `AREA`, `DUR` (duration), `DMG`, `BOOM` (kills explode).
- "Increases the damage of your critical strikes" now reads as `CRIT DMG`, not `CRIT`.
- **Biggest Crits** in the build list's look: each ability's icon and its damage meter color.

### v2.5.1, 2026-10-15

**Survivor UI**
- **Icons in the damage meter:** every line starts with its source's icon. A spell's comes from its action button; a talent's or an item's own damage is looked up in the spellbook, the talents and the worn items, by name. With none found, the addon's own icon stands in.

### v2.5, 2026-10-15

**Survivor UI**
- **Options panel** (`/sui opt`): every panel on or off (run tracker, build list, damage meter, This Run, Biggest Crits, boss bars, kills and gold, loot), the quick damage numbers, every look the addon gives the game (cooldown numbers, key labels, ability tooltip, character pane, square minimap, flat chat and tooltips, the font, the menu buttons), and Survivor Plates' two choices. Panels switch at once; a look waits for a reload, and the Reload button lights up.
- **Move mode with a grid:** from the panel, every piece unlocks without Alt over a grid (the screen's middle lines in gold), and a piece let go snaps to it.
- **Minimap button** with the addon's own icon, outside the minimap's bottom left corner: click for the options in move mode, right click for the options alone.
- **More pieces to move:** the player frame, the target frame, the action bar, the buffs and the kills and gold line, each on its own. The option `Unit frames move with the action bar` keeps the two frames at its sides, moving as one.
- The game's battleground button on the minimap gets the same square look.

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

## Credits

Survivor UI and Survivor Plates are made by **morderous** ([github.com/morderous/survivor-ui](https://github.com/morderous/survivor-ui)).

If you use, adapt or build on this code, please credit Survivor UI and link the repository. Suggestions and bug reports are welcome on the [issues page](https://github.com/morderous/survivor-ui/issues).

## License

Copyright (C) 2026 morderous.

GNU General Public License v3.0 (GPL-3.0), from v2.7 on: you may use, change and share the addons, as long as what you share stays under the same license, with its source and this credit. See [LICENSE](LICENSE). Versions up to v2.6 were released under the MIT license.

The launcher's art (`installer/art`) is from "Assets: UI RPG Game Interface" by Wenrexa ([wenrexa.itch.io/werdanta03](https://wenrexa.itch.io/werdanta03)), under Creative Commons Zero v1.0 (public domain), with thanks; `installer/art/CREDITS.txt` says which pieces and how two were made from them. The launcher's title font is Cinzel Decorative, as below.

The fonts in `SurvivorUI/Fonts` are not the addon's: Fira Sans (The Mozilla Foundation and Telefonica S.A.), Noto Sans (The Noto Project Authors), Exo (The Exo Project Authors), Russo One (Jovanny Lemonad) and Cinzel Decorative (Natanael Gama) are each under the SIL Open Font License 1.1, its text beside each one (`OFL-*.txt`), shipped unchanged. Barlow Semi Condensed and Barlow Condensed (The Barlow Project Authors), at their SemiBold weight, are under it too (`OFL-Barlow.txt`), shipped unchanged. Noto Sans SC (Adobe, with Reserved Font Name 'Source') is under the same license (`OFL-NotoSansSC.txt`), cut at its Medium weight (500) from the variable font Google Fonts publishes, otherwise unchanged. `SurvivorUI/Fonts/Numbers` holds changed copies of Barlow Condensed, Exo, Fira Sans and Noto Sans, for the game's damage numbers: their letters drawn at 90% down to 40%, subset to Latin letters, their hinting and kerning left out, renamed "SUI Numbers"; each under the same license as its original.
