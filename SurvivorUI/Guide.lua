-- Survivor UI - Copyright (C) 2026 morderous - GPL-3.0 - github.com/morderous/survivor-ui
-- Survivor UI: the guide, pages that explain the game's numbers so a child
-- could follow them, each with numbers to play with: SurvivorUI Classic's, in
-- this addon's flat look. Its button is the gold square on the stack by the
-- minimap (MinimapButton.lua). Opened from there or with /sui guide. In a run
-- the game's Paused screen takes Escape first. Its words go through
-- SurvivorUI_T, the game's names through SurvivorUI_Native (Locale.lua).
--
-- The rules, read in the game's 0.131 exe (game\mod.rs, game\upgrades.rs):
--   Luck: as in XpBar.lua. At m = 1 the weights add up to 100.
--   A hit = the spell's own number x Damage x Crit Dmg if it crits x the
--     enemy's bonuses. Inside each, added; from one to the next, multiplied.
--   Damage adds level, gear, jewelry, talents and the buffs that last a while
--     (Battle Shout 0.4, Slice and Dice 0.32, Arcane Power 0.35, Blood Fury
--     0.35, Perception 0.15, at their first rank), each buff x (1 + Buff
--     Power). The same buff twice counts once: the stronger stays.
--   Past Crit 100% the rest adds to Crit Dmg, one for one.
--   A DoT: spell x Damage counted once as it lands, x (its time / its base
--     time) x (1 + DoT Haste), cut into ticks of one size. It rolls no crit.
--     Ticks: its base ticks stretched by its time, x (1 + DoT Haste), to the
--     nearest. Each tick goes through the enemy's bonuses as it lands. Copies on
--     one enemy: 1, and 1 more every 15 levels, 4 at most; a new one takes
--     the place of the copy with the fewest ticks left.
--   A ground spell (game\mod.rs): a list of its own on the hero, each with its
--     clock, none knowing of the others; the tick's size set as it lands; at
--     every tick every enemy inside rolls Crit. Measured in the test game on
--     2026-10-31: Consecration 23.6% of 1725 hits at Crit 23.7%, Blizzard 20.3%
--     at 21.1%, and two Consecrations striking the same enemies 0.13 sec apart;
--     Corruption and Curse of Agony none of 897 ticks.
--   Marks are kept per class. A star on a piece costs star x its rarity's base
--     (1, 2, 3, 4, Legendary 6, PvP 5; below Legendary the 5th star's base is 6,
--     so 30, and PvP's 25), the same on every slot, 5% less for each other class
--     that owns all 8 pieces of that rarity with each at the star being bought
--     or more, 40% at most (0.139: 0x145e5c2b0, the count 0x145e5c6f0), and
--     rounded up to a tenth: ceil(cost x 10 - 0.001) / 10.
--   Sets (sets.rs): six a class, 8 armor pieces each. The 4-piece bonus is one
--     to a set whatever the class, the 8-piece bonus the class's own, and
--     Empowered works it out at 1.5 strength, roundf for the whole numbers.
--   Damage reduction: every source added, then min(sum, 0.6 + the cap's raises);
--     Titan is the only raise. A hit x (1 - reduction) x (1 - the gear's "while
--     5 or more enemies are within 8 yards"), which stands outside the cap, and
--     only then shields. Past the cap, lost but for Unbreakable; Defiance reads
--     the reduction after the cap.
--   Haste (0.139: the sum 0x145ed1410, the wait 0x145f2f3a0): every cooldown
--     bonus added, a cooldown x 1 / (1 + them), no cap; the game shows 1 - 1 /
--     (1 + them). No wait under 0.25 sec (Hellfire 0.5, Divine Shield its own).
--   Echo (0x145f6b260): under 100%, one roll, rolled again while it lands for
--     the Mage capstone, 3 more at most; from 100%, all of those land, one more
--     for each 100% past it, the rest one more roll. Each strike is a whole
--     cast, its targets and Crit its own.
--   Speed: 7 yd a second x (1 + bonuses), 2.2 at most. Pickup: 9 yd x (1 + each
--     bonus), one after another. Area: every radius and reach x (1 + bonuses);
--     past 70 yd, 70 + 10 x ln(1 + (yd - 70) / 10).

if SurvivorUI_Standby then return end

-- Tall enough for the Sets page's seven sets (the game's 0.140); a 768 high
-- screen, the game's at UI scale 1, still holds it.
local WIDTH, HEIGHT = 770, 670
local LEFT = 130                -- the pages' left edge, past the tabs
local PAGE_WIDTH = WIDTH - LEFT - 26
local PAGE_TOP = -36
local TEXT = 13                 -- the words' size
local SMALL = 11
local LINE = 16                 -- a line of the words
local FLAT = "Interface\\ChatFrame\\ChatFrameBackground"
local MARBLE = "Interface\\AddOns\\SurvivorUI\\Art\\Marble"
local NEW_MARK = "Interface\\AddOns\\SurvivorUI\\Art\\GuideNew"
local MAP_ICON = "Interface\\AddOns\\SurvivorUI\\Art\\MapIcon"
local STAR = "Interface\\AddOns\\SurvivorUI\\Art\\Star"
local DISC = "Interface\\AddOns\\SurvivorUI\\Art\\Disc"
local GOLD = "|cffffd100"
local GREEN = { 0.35, 0.95, 0.45 }  -- as on the character page
local ZONE_GREEN = { 0.40, 1.00, 0.42 }  -- a zone's name, as Survivor UI's Run History writes it
local PEACH = { 1, 0.67, 0.38 }
local RED = { 1, 0.45, 0.4 }
local BLUE = { 0.45, 0.75, 1 }
local PURPLE = { 0.75, 0.5, 1 }
local YELLOW = { 1, 0.85, 0.3 }
local TEAL = { 0.3, 0.9, 0.85 }
local ORANGE = { 1, 0.5, 0.15 }
local GREY = { 0.55, 0.55, 0.55 }
-- Common to Legendary, as CardOdds gives them.
local RARITIES = {
	{ "Common", { 0.62, 0.62, 0.62 } },
	{ "Uncommon", { 0.12, 1, 0 } },
	{ "Rare", { 0.2, 0.55, 1 } },
	{ "Epic", { 0.64, 0.21, 0.93 } },
	{ "Legendary", { 1, 0.5, 0 } },
}
-- The Luck page's ladder: a bar of 100 cards for each step of Luck, at level 30
-- and up, and the hero's own row among them. The first bar's y (lower when the
-- right column's title takes more lines), a bar's room, the Luck's column on the
-- left and, past a line, a legendary among 3 cards.
local LADDER = { top = 62, row = 32, label = 80, pick = 60, steps = { 0, 0.3, 0.6, 1, 2, 3 } }
LADDER.bar = PAGE_WIDTH - 8 - (16 + LADDER.label) - 20 - LADDER.pick - 6
LADDER.split = 4 + 16 + LADDER.label + LADDER.bar + 10   -- the line, from the ladder's left
-- Each with who has it, and its first rank's numbers in the exe: %, seconds, cooldown.
local BUFFS = {
	{ "Battle Shout", "Interface\\Icons\\Ability_Warrior_BattleShout", "Warrior spell", 40, 8, 16 },
	{ "Slice and Dice", "Interface\\Icons\\Ability_Rogue_SliceDice", "Rogue spell", 32, 9, 15 },
	{ "Arcane Power", "Interface\\Icons\\Spell_Nature_Lightning", "Mage spell", 35, 12, 30 },
	{ "Blood Fury", "Interface\\Icons\\Racial_Orc_BerserkerStrength", "Orc racial", 35, 12, 40 },
	{ "Perception", "Interface\\Icons\\Spell_Nature_Sleep", "Human racial", 15, 10, 30 },
}
-- The boxes of a hit: its title, its color, its icon, what goes in it, each thing in a color.
local STEPS = {
	{ "The spell", BLUE, "Spell_Fire_FlameBolt", { { "Its base hit", BLUE }, { "Its rank", TEAL }, { "Talents that name it", PURPLE } } },
	{ "Damage", GREEN, "INV_Sword_27", { { "3% a level", YELLOW }, { "Gear and jewelry", TEAL }, { "Talents", PURPLE }, { "Damage buffs", GREEN } } },
	{ "Crit", PEACH, "Ability_CriticalStrike", { { "", YELLOW }, { "", ORANGE } } },
	{ "The enemy", RED, "INV_Misc_Bone_HumanSkull_01", { { "Elite or boss", PURPLE }, { "Under 30% health", RED }, { "Stunned or slowed", BLUE }, { "Burning or bleeding", ORANGE } } },
}
local BOX_GAP = 20
local BOX_HEIGHT = 154
local CARD_GAP = 10
local CARD_HEIGHT = 90
local FACT_HEIGHT = 80
local WARNING = { 1, 0.28, 0.18 }
local WARNING_HEIGHT = 52
local TICK = 12                 -- a tick's marble on the DoTs page
local SAMPLE_TICKS = 6          -- the sample DoT's ticks
local MOST_COPIES, MOST_TICKS = 4, 24
local COPY_COLORS = { PURPLE, BLUE, TEAL, GREEN }
local SPELL_ROW = 46            -- a ground spell's card, and the step to the next
local FEET = "Marks the ground where you stand once enemies come within %d yd."
local GROUP = "Lands on the thickest group of enemies within %d yd."
-- The ground spells: name, icon, class, its name, where it lands (the words and
-- the yards), the yards it reaches, each tick, its time, its cooldown, what else
-- it does. Each spell's first rank, as its tooltip says with no bonuses.
local GROUND = {
	{ "Consecration", "Spell_Holy_InnerFire", "PALADIN", "Paladin spell", FEET, 8, 8, "1", "11", 8 },
	{ "Flamestrike", "Spell_Fire_SelfDestruct", "MAGE", "Mage spell", GROUP, 30, 8, "2.1", "8.4", 7 },
	{ "Blizzard", "Spell_Frost_IceStorm", "MAGE", "Mage spell", GROUP, 30, 9, "1", "9.8", 8, "Slows them by 40% for 1.5 sec." },
	{ "Rain of Fire", "Spell_Shadow_RainOfFire", "WARLOCK", "Warlock spell", GROUP, 30, 8, "1.9", "11", 8 },
	{ "Hurricane", "Spell_Nature_Cyclone", "DRUID", "Druid spell", GROUP, 28, 10, "1", "11", 9, "Slows them by 40% for 1.5 sec." },
	{ "Volley", "Ability_Marksmanship", "HUNTER", "Hunter spell", GROUP, 28, 8, "1", "8.4", 8 },
	{ "Immolation Trap", "Spell_Fire_FlameShock", "HUNTER", "Hunter spell", FEET, 7, 7, "1.9", "11", 9 },
	{ "Frost Trap", "Spell_Frost_FreezingBreath", "HUNTER", "Hunter spell", FEET, 10, 10, "2.1", "8.4", 10, "Roots them for 1.5 sec; bosses for a quarter as long." },
}
-- What touches the cap.
local CAP_TALENTS = {
	{ "Titan", "Ability_Warrior_DefensiveStance", "WARRIOR", "Warrior capstone" },
	{ "Unbreakable", "Ability_Warrior_Sunder", "WARRIOR", "Warrior talent, 3 ranks" },
	{ "Defiance", "Ability_Warrior_InnerRage", "WARRIOR", "Warrior talent, 3 ranks" },
	{ "Soul Link", "Spell_Shadow_GatherShadows", "WARLOCK", "Warlock talent, 3 ranks" },
}
-- The other classes' talents, which only add to the number: name, icon, class,
-- what it is, "talent", what it does.
local OTHER_TALENTS = {
	{ "Deflection", "Ability_Parry", "WARRIOR", "Warrior talent, 5 ranks", "talent", "Reduces all damage taken by 1% a rank: 5% at 5 ranks." },
	{ "Shield Specialization", "INV_Shield_06", "WARRIOR", "Warrior talent, 5 ranks", "talent", "Reduces all damage taken by 1.5% a rank: 7.5% at 5 ranks." },
	{ "Unyielding Faith", "Spell_Holy_UnyieldingFaith", "PALADIN", "Paladin talent, 3 ranks", "talent", "Reduces all damage taken by 1.2% a rank: 3.6% at 3 ranks." },
	{ "Unbreakable Will", "Spell_Magic_MageArmor", "PRIEST", "Priest talent, 5 ranks", "talent", "Reduces all damage taken by 0.8% a rank: 4% at 5 ranks." },
	{ "Elemental Warding", "Spell_Nature_StoneClawTotem", "SHAMAN", "Shaman talent, 3 ranks", "talent", "Reduces all damage taken by 2% a rank: 6% at 3 ranks." },
	{ "Stormguard", "Spell_Nature_LightningShield", "SHAMAN", "Shaman talent, 5 ranks", "talent", "While Lightning Shield is active, reduces all damage taken by 3% a rank: 15% at 5 ranks." },
	{ "Arcane Fortitude", "Spell_Arcane_ArcaneResilience", "MAGE", "Mage talent, 3 ranks", "talent", "Reduces all damage taken by 2.5% a rank: 7.5% at 3 ranks." },
	{ "Rake", "Ability_Druid_Disembowel", "DRUID", "Druid milestone", "talent", "Your hide thickens: 8% less damage taken and 20% more maximum health." },
	{ "Dire Bear Form", "Ability_Racial_BearForm", "DRUID", "Druid capstone", "talent", "You fight in Dire Bear Form: 10% less damage taken and 25% more maximum health." },
}
local CHIP_HEIGHT = 22
local CHIP_GAP = 5
local CHIP_REST, CHIP_LIT = 0.5, 0.66   -- how much of the class's color fills a chip
local WALL_WIDTH = PAGE_WIDTH   -- the wall's bar
local WALL_HEIGHT = 16
local FLOOR = 0.25              -- the shortest wait, in seconds
local CASCADE = 3               -- the Mage capstone's rolls again
local ROW_LABEL = 104           -- where a row's marbles start, past its name
local CASTS, CAST_MARBLE = 38, 12
local STRIKES, STRIKE, STRIKE_STEP = 9, 18, 22
local RUN, MOST_SPEED = 7, 2.2  -- yards a second, and the cap
local PICKUP = 9                -- yards
local SOFT_REACH = 70           -- yards
local REACH_BOX = 196
local DISC_MOST = 48            -- the widest circle's radius
-- Hellfire looks the same and works another way: nothing stays on the ground.
local HELLFIRE = { "Hellfire", "Spell_Fire_Incinerate", "WARLOCK", "Warlock spell" }
local ROW_STEP = 14
-- The seven sets in the Collection Log's order: the rarity, its color, its
-- zones (Tier 0.5 has one), the set's place in a class's list below, its
-- 4-piece bonus (Tier 0.5's is each class's own), each star's marks on one
-- piece at no discount, and the color an item tooltip gives that quality's
-- name. Read in the game's 0.140.
local TIER = 7
local SET_KINDS = {
	{ "Common", { 1, 1, 1 }, "Elwynn Forest", "Duskwood", 1, "+25% gold, +30% pickup range", { 1, 2, 3, 4, 30 }, { 1, 1, 1 } },
	{ "Uncommon", { 0.12, 1, 0 }, "Warsong Gulch", "Un'Goro Crater", 2, "1.5% max health per second after 3 seconds unhurt", { 2, 4, 6, 8, 30 }, { 0.12, 1, 0 } },
	{ "Rare", { 0.31, 0.64, 1 }, "Arathi Basin", "Feralas", 3, "+1 target to every ability", { 3, 6, 9, 12, 30 }, { 0, 0.44, 0.87 } },
	{ "Epic", { 0.73, 0.54, 0.95 }, "Gurubashi Arena", "Scarlet Monastery", 4, "6% chance for an ability to strike twice", { 4, 8, 12, 16, 30 }, { 0.64, 0.21, 0.93 } },
	{ "PvP", { 0.73, 0.54, 0.95 }, "Alterac Valley", "Blackrock Mountain", 6, "+12% damage reduction with 5 or more enemies close", { 5, 10, 15, 20, 25 }, { 0.64, 0.21, 0.93 } },
	{ "Tier 0.5", { 0.73, 0.54, 0.95 }, "Scholomance", false, TIER, false, { 5.5, 11, 16.5, 22, 27.5 }, { 0.64, 0.21, 0.93 } },
	{ "Legendary", { 1, 0.6, 0.18 }, "Gates of Ahn'Qiraj", "Naxxramas", 5, "+30% critical damage", { 6, 12, 18, 24, 30 }, { 1, 0.5, 0 } },
}
local PVP_SET = "Field Marshal's / Warlord's"
-- Each class: its key, its name, its sets' names (the PvP one is PVP_SET),
-- its seven 8-piece bonuses, each with its numbers and, after them, the same
-- Empowered, and its Tier 0.5 4-piece bonus. Tier 0.5's 8-piece bonus does
-- not grow by half at 5/5: it takes the numbers the game gives it, and its
-- words there when they say more, with a third number if it has one.
local SETS = {
	{ "WARRIOR", "Warrior", { "Recruit's", "Valor", "Might", "Wrath", "Dreadnaught", [TIER] = "Heroism" }, {
		{ "Cleave strikes {v} more enemies in a {v2}% wider arc.", 2, 30, 3, 45 },
		{ "Thunder Clap claps again for {v}% of its damage.", 50, 0, 75, 0 },
		{ "Whirlwind is {v}% wider and deals {v2}% more damage.", 50, 30, 75, 45 },
		{ "Each Bloodthirst hit gives {v}% damage for 8 sec, stacking 5 times.", 5, 0, 7.5, 0 },
		{ "Execute strikes {v} more of the most wounded enemies, and each of its kills takes {v2} sec off your other spells' cooldowns.", 2, 0.5, 3, 0.75 },
		{ "Enemies hit by Mortal Strike take {v}% more damage from everything for 4 sec.", 20, 0, 30, 0 },
		{ "Shield Slam deals {v}% more damage, plus Physical damage equal to {v2}% of your max health.", 20, 4.5, 30, 6 },
	}, "Fortified shields up to 50% of your max health (62% with Shield Mastery), and Shield Slam deals 10% more damage while it holds." },
	{ "PALADIN", "Paladin", { "Squire's", "Lightforge", "Lawbringer", "Judgement", "Redemption", [TIER] = "Soulforge" }, {
		{ "Hammer of Wrath comes back, striking again for {v}%.", 60, 0, 90, 0 },
		{ "Consecration moves with you and deals {v}% more damage.", 20, 0, 30, 0 },
		{ "A Holy Shock kill fires another Holy Shock, once every {v} sec.", 1.5, 0, 1, 0 },
		{ "Enemies killed by Judgement explode for {v}% of their max health on everything within 8 yards.", 15, 0, 22.5, 0 },
		{ "Exorcism leaps to {v} more enemies for 75% of its damage.", 3, 0, 5, 0 },
		{ "Hammer of Justice strikes {v} more enemies, deals 300% more damage and comes back 40% sooner, and you deal {v2}% more damage to enemies you stun, root, slow or fear.", 5, 100, 8, 150 },
		{ "Hammer of Justice deals {v}% of its target's max health, up from 1.5%, and bursts within 10 yards of it for {v2}% of the shield you have left.", 1.75, 40, 1.9, 65 },
	}, "Hammer of the Righteous's shields explode for 75% of what they absorbed, up from 50%." },
	{ "HUNTER", "Hunter", { "Tracker's", "Beaststalker's", "Giantstalker's", "Dragonstalker's", "Cryptstalker", [TIER] = "Beastmaster" }, {
		{ "Every {v} Auto Shots fire a free Multi-Shot.", 5, 0, 4, 0 },
		{ "When its victim dies, Serpent Sting leaps to {v} enemies near it.", 2, 0, 3, 0 },
		{ "Kill Command's cooldown is {v}% shorter and it deals {v2}% more damage.", 20, 30, 30, 45 },
		{ "Volley moves with you and lasts {v}% longer.", 50, 0, 75, 0 },
		{ "Aimed Shot pierces to {v} more enemies for 60% of its damage.", 4, 0, 6, 0 },
		{ "Concussive Shot strikes {v} more enemies, deals 150% more damage and comes back 40% sooner, and you deal {v2}% more damage to enemies you stun, root, slow or fear.", 5, 100, 8, 150 },
		{ "A Devilsaur Matriarch joins you for good. Her bites deal 150% of the Wolf's, and {v}% more to Hunter's Mark targets.", 50, 0, 100, 0 },
	}, "Bestial Wrath makes your pets' bites strike 5 more enemies for 150% damage each." },
	{ "ROGUE", "Rogue", { "Footpad's", "Shadowcraft", "Nightslayer", "Bloodfang", "Bonescythe", [TIER] = "Darkmantle" }, {
		{ "Every {v} Sinister Strikes strike twice.", 3, 0, 2, 0 },
		{ "Enemies dying with your Rupture burst for {v}% of their max health on everything within 8 yards.", 15, 0, 22.5, 0 },
		{ "Blade Flurry spins again for {v}% of its damage.", 60, 0, 90, 0 },
		{ "An Eviscerate kill readies it again, once every {v} sec.", 1, 0, 0.67, 0 },
		{ "Sinister Strike and Backstab have a {v}% chance to strike twice, and Adrenaline Rush lasts {v2}% longer.", 35, 50, 52.5, 75 },
		{ "Kidney Shot strikes {v} more enemies, deals 200% more damage and comes back 40% sooner, and you deal {v2}% more damage to enemies you stun, root, slow or fear.", 5, 100, 8, 150 },
		{ "Backstab and Eviscerate mark a boss or elite for death: it takes {v2}% more damage from you. One at a time.", 1, 35, 2, 40,
			"Backstab and Eviscerate mark {v} bosses or elites for death: they take {v2}% more damage from you. Double damage starts below {v3}% health.", false, 45 },
	}, "Backstab and Eviscerate deal double damage to enemies below 40% health, up from 30%." },
	{ "PRIEST", "Priest", { "Acolyte's", "Devout", "Prophecy", "Transcendence", "Faith", [TIER] = "Virtuous" }, {
		{ "Smite leaps to a second enemy for {v}% of its damage.", 50, 0, 75, 0 },
		{ "When Power Word: Shield breaks it explodes for {v}% of what it absorbed on everything within 8 yards.", 200, 0, 300, 0 },
		{ "Shadow Word: Pain strikes {v} more enemies and deals {v2}% more damage.", 2, 20, 3, 30 },
		{ "Holy Nova rings twice, the second for {v}%, and is {v2}% wider.", 60, 30, 90, 45 },
		{ "A Mind Flay kill fires a free Mind Blast, once every {v} sec.", 1, 0, 0.67, 0 },
		{ "Psychic Scream deals 900% more damage and comes back 40% sooner, and you deal {v2}% more damage to enemies you stun, root, slow or fear.", 0, 100, 0, 150 },
		{ "Shadowform's death explosions deal {v}% of the enemy's max health, up from 4%, and Shadow Word: Pain jumps to {v2} enemies.", 8, 2, 10, 3,
			"Shadowform's death explosions deal {v}% of the enemy's max health, Shadow Word: Pain jumps to {v2} enemies, and Shadowy Apparitions' chance rises to {v3}%.", false, 12 },
	}, "Shadowy Apparitions has an 8% chance per Shadow Word: Pain tick to fire a free Mind Blast, up from 4%." },
	{ "SHAMAN", "Shaman", { "Primal", "Elements", "Earthfury", "Ten Storms", "Earthshatter", [TIER] = "Five Thunders" }, {
		{ "Lightning Bolt forks to a second enemy for {v}% of its damage.", 50, 0, 75, 0 },
		{ "Enemies dying with your Flame Shock explode for {v}% of their max health on everything within 8 yards.", 15, 0, 22.5, 0 },
		{ "Searing Totem deals {v}% more damage and stands {v2}% longer.", 50, 50, 75, 75 },
		{ "Chain Lightning jumps {v} more times and deals {v2}% more damage.", 3, 20, 5, 30 },
		{ "Fire Nova is {v}% wider and deals {v2}% more damage.", 50, 30, 75, 45 },
		{ "Earth Shock strikes 2 more enemies, and they take {v}% more damage for 5 sec.", 20, 0, 30, 0 },
		{ "Every Stormstrike sets off Thunderburst: Nature damage equal to {v}% of its damage on enemies within {v2} yards.", 25, 6, 50, 8 },
	}, "Stormstrike deals 15% more damage and comes back 35% sooner." },
	{ "MAGE", "Mage", { "Apprentice's", "Magister's", "Arcanist", "Netherwind", "Frostfire", [TIER] = "Sorcerer's" }, {
		{ "Arcane Missiles fires {v} more missiles.", 2, 0, 3, 0 },
		{ "Every {v} Arcane Explosions, one goes off twice.", 3, 0, 2, 0 },
		{ "Flamestrike's flames strike twice, the second for {v}%.", 50, 0, 75, 0 },
		{ "Blizzard moves with you and deals {v}% more damage.", 20, 0, 30, 0 },
		{ "Fireball splits, striking {v} more enemies for 60% of its damage.", 2, 0, 3, 0 },
		{ "Frost Nova is {v}% wider, deals 400% more damage and comes back 40% sooner, and you deal {v2}% more damage to enemies you stun, root, slow or fear.", 50, 100, 75, 150 },
		{ "Your Water Elemental's Frostbolts set off Splitting Ice too, and deal {v}% more damage to bosses and elites.", 100, 0, 150, 150,
			"Your Water Elemental's Frostbolts set off Splitting Ice and deal {v}% more to bosses and elites. Splitting Ice deals {v2}%, your Frostbolt {v3}% more to them.", false, 50 },
	}, "Splitting Ice reaches 7 yards, up from 5, and deals 125% damage, up from 100%." },
	{ "WARLOCK", "Warlock", { "Novice's", "Dreadmist", "Felheart", "Nemesis", "Plagueheart", [TIER] = "Deathmist" }, {
		{ "Shadow Bolt pierces to {v} more enemies for 50% of its damage.", 2, 0, 3, 0 },
		{ "When its victim dies, Curse of Agony leaps to {v} enemies near it.", 2, 0, 3, 0 },
		{ "Drain Life drains {v} more enemies at once.", 2, 0, 3, 0 },
		{ "Rain of Fire sets enemies burning for {v}% of its hit over 3 sec.", 30, 0, 45, 0 },
		{ "Corruption strikes {v} more enemies and deals {v2}% more damage.", 2, 25, 3, 37.5 },
		{ "Death Coil strikes {v} more enemies, deals 50% more damage, horrifies them for 3 sec and comes back 40% sooner, and you deal {v2}% more damage to enemies you stun, root, slow or fear.", 5, 60, 8, 90 },
		{ "Conflagrate brands its main target for 10 sec: your direct spells deal {v}% more damage to branded bosses and elites.", 35, 0, 55, 40,
			"Conflagrate brands its main target for 10 sec: your direct spells deal {v}% more damage to branded bosses and elites, and the brand burns for {v2}% of its hit over 4 sec." },
	}, "Conflagrate explodes on everything within 8 yards for 35% of the direct hit that set it off." },
	{ "DRUID", "Druid", { "Thicket", "Wildheart", "Cenarion", "Stormrage", "Dreamwalker", [TIER] = "Feralheart" }, {
		{ "Every {v} Wraths, one strikes twice.", 4, 0, 3, 0 },
		{ "Swipe is 50% wider and makes enemies bleed for {v}% of its hit over 6 sec.", 40, 0, 60, 0 },
		{ "Entangling Roots strikes {v} more enemies.", 3, 0, 5, 0 },
		{ "Starfire bursts on every enemy within 6 yards of its target for {v}% of its damage.", 35, 0, 52.5, 0 },
		{ "Hurricane is {v}% wider and lasts {v2}% longer.", 40, 40, 60, 60 },
		{ "Shred strikes {v} more enemies, has a 33% chance to stun them for 1 sec and comes back 40% sooner, and you deal {v2}% more damage to enemies you stun, root, slow or fear.", 2, 100, 3, 150 },
		{ "Each healing Tranquility plants Seed of Life on an enemy: 1.5 sec later it deals {v}% of Tranquility's hit to it and {v2} enemies within {v3} yards.", 60, 5, 100, 7,
			"Each healing Tranquility plants Seed of Life on an enemy: 1.5 sec later it deals {v}% of Tranquility's hit to it and {v2} enemies within {v3} yards, bosses and elites twice.", 6, 8 },
	}, "Regrowth and Rejuvenation heal 20% more, and Tranquility reaches 15 yards, up from 12." },
}
-- Each a button: its label, the stars it asks of every piece, its rule.
local SET_STEPS = {
	{ "4 pieces", 1, "Wear 4 armor pieces of one set at 1/5 or more. Only Tier 0.5's bonus is the class's own." },
	{ "8 pieces", 3, "Wear all 8 armor pieces of one set at 3/5 or more." },
	{ "8 pieces, Empowered", 5, "All 8 pieces at 5/5: the 8-piece bonus is 50% stronger (Tier 0.5: numbers of its own)." },
}
local STAR_SIZE = 11
local MARK_CARD = 86
local OPEN_CARD = 72
local COST_ROW = 16
local SET_ROW, SET_TALL = 48, 61    -- a set's panel, and the PvP and Tier 0.5 ones' three lines
local SET_CAPTION = 17              -- its name and zones, over the panel
-- Jewels: written by bot\ferramentas\make_jewels_lua.py, not by hand.
-- Read in the game's 0.142.0 (make_jewels_data.py). Rings and trinkets: name, icon, the game's line,
-- whether it stops being offered near a most, and by rarity each pick's numbers, taken again and again
-- at that rarity until the game stops offering it (10 shown where it never stops), then by rarity the
-- average pick of Jewel.GROUPS for one that divides, its soft cap for one that slows, or false. Amulets: name, icon,
-- rarity, who its {hits} are, every number's size by rank in hundredths (rank 1 = 100), and its lines
-- with their numbers by rank and at the cap (3 times rank 1 where they grow). The class legendary amulets are left out.
local JEWELS = {
	ring = {
		{ "Band of Accuria", "INV_Jewelry_Ring_15", "+{v}% damage", false, {
			{ { g = "25.5", v = "25.5" }, { g = "15.7", v = "41.2" }, { g = "14.7", v = "55.9" }, { g = "13.7", v = "69.6" }, { g = "12.9", v = "82.5" }, { g = "12.1", v = "94.6" }, { g = "11.5", v = "106.1" }, { g = "10.9", v = "117" }, { g = "10.4", v = "127.4" }, { g = "9.9", v = "137.3" } },
			{ { g = "35.7", v = "35.7" }, { g = "22", v = "57.7" }, { g = "20.5", v = "78.3" }, { g = "19.2", v = "97.4" }, { g = "18", v = "115.5" }, { g = "17", v = "132.5" }, { g = "16.1", v = "148.6" }, { g = "15.3", v = "163.8" }, { g = "14.5", v = "178.3" }, { g = "13.8", v = "192.2" } },
			{ { g = "45.9", v = "45.9" }, { g = "28.3", v = "74.2" }, { g = "26.4", v = "100.6" }, { g = "24.7", v = "125.3" }, { g = "23.2", v = "148.5" }, { g = "21.9", v = "170.3" }, { g = "20.7", v = "191" }, { g = "19.6", v = "210.6" }, { g = "18.7", v = "229.3" }, { g = "17.8", v = "247.1" } },
			{ { g = "61.2", v = "61.2" }, { g = "37.8", v = "99" }, { g = "35.2", v = "134.2" }, { g = "32.9", v = "167.1" }, { g = "30.9", v = "198" }, { g = "29.1", v = "227.1" }, { g = "27.6", v = "254.7" }, { g = "26.2", v = "280.8" }, { g = "24.9", v = "305.7" }, { g = "23.7", v = "329.4" } },
			{ { g = "81.6", v = "81.6" }, { g = "50.4", v = "132" }, { g = "46.9", v = "178.9" }, { g = "43.9", v = "222.7" }, { g = "41.2", v = "264" }, { g = "38.9", v = "302.8" }, { g = "36.8", v = "339.6" }, { g = "34.9", v = "374.4" }, { g = "33.2", v = "407.6" }, { g = "31.6", v = "439.2" } },
		}, { { "14.7", "11.9", "9.3" }, { "20.6", "16.6", "13" }, { "26.5", "21.3", "16.7" }, { "35.3", "28.4", "22.3" }, { "47", "37.9", "29.7" } } },
		{ "Quick Strike Ring", "INV_Jewelry_Ring_07", "-{v}% cooldowns", false, {
			{ { g = "13.5", v = "13.5" }, { g = "8.3", v = "21.8" }, { g = "7.8", v = "29.6" }, { g = "7.3", v = "36.9" }, { g = "6.8", v = "43.7" }, { g = "6.4", v = "50.1" }, { g = "6.1", v = "56.2" }, { g = "5.8", v = "61.9" }, { g = "5.5", v = "67.4" }, { g = "5.2", v = "72.7" } },
			{ { g = "18.9", v = "18.9" }, { g = "11.7", v = "30.6" }, { g = "10.9", v = "41.4" }, { g = "10.2", v = "51.6" }, { g = "9.5", v = "61.1" }, { g = "9", v = "70.1" }, { g = "8.5", v = "78.6" }, { g = "8.1", v = "86.7" }, { g = "7.7", v = "94.4" }, { g = "7.3", v = "101.7" } },
			{ { g = "24.3", v = "24.3" }, { g = "15", v = "39.3" }, { g = "14", v = "53.3" }, { g = "13.1", v = "66.3" }, { g = "12.3", v = "78.6" }, { g = "11.6", v = "90.2" }, { g = "10.9", v = "101.1" }, { g = "10.4", v = "111.5" }, { g = "9.9", v = "121.4" }, { g = "9.4", v = "130.8" } },
			{ { g = "32.4", v = "32.4" }, { g = "20", v = "52.4" }, { g = "18.6", v = "71" }, { g = "17.4", v = "88.4" }, { g = "16.4", v = "104.8" }, { g = "15.4", v = "120.2" }, { g = "14.6", v = "134.8" }, { g = "13.8", v = "148.7" }, { g = "13.2", v = "161.8" }, { g = "12.6", v = "174.4" } },
			{ { g = "43.2", v = "43.2" }, { g = "26.7", v = "69.9" }, { g = "24.8", v = "94.7" }, { g = "23.2", v = "117.9" }, { g = "21.8", v = "139.7" }, { g = "20.6", v = "160.3" }, { g = "19.5", v = "179.8" }, { g = "18.5", v = "198.2" }, { g = "17.6", v = "215.8" }, { g = "16.7", v = "232.5" } },
		}, { { "7.8", "6.3", "4.9" }, { "10.9", "8.8", "6.9" }, { "14", "11.3", "8.9" }, { "18.7", "15.1", "11.8" }, { "24.9", "20.1", "15.7" } } },
		{ "Heavy Dark Iron Ring", "INV_Jewelry_Ring_14", "+{v}% max health", false, {
			{ { g = "25.3", v = "25.3" }, { g = "12.2", v = "37.5" }, { g = "9.5", v = "46.9" }, { g = "7.4", v = "54.3" }, { g = "5.7", v = "60" }, { g = "4.7", v = "64.7" }, { g = "4.1", v = "68.7" }, { g = "3.6", v = "72.4" }, { g = "3.3", v = "75.7" }, { g = "3", v = "78.7" } },
			{ { g = "33.1", v = "33.1" }, { g = "14", v = "47.1" }, { g = "9.8", v = "56.9" }, { g = "7", v = "63.9" }, { g = "5.7", v = "69.6" }, { g = "4.9", v = "74.5" }, { g = "4.3", v = "78.8" }, { g = "3.9", v = "82.7" }, { g = "3.5", v = "86.2" }, { g = "3.3", v = "89.5" } },
			{ { g = "39.9", v = "39.9" }, { g = "14.7", v = "54.6" }, { g = "9.5", v = "64" }, { g = "7.1", v = "71.2" }, { g = "5.9", v = "77.1" }, { g = "5.1", v = "82.2" }, { g = "4.6", v = "86.8" }, { g = "4.1", v = "90.9" }, { g = "3.8", v = "94.7" }, { g = "3.5", v = "98.1" } },
			{ { g = "48.3", v = "48.3" }, { g = "14.6", v = "62.9" }, { g = "9.5", v = "72.4" }, { g = "7.5", v = "79.9" }, { g = "6.3", v = "86.2" }, { g = "5.5", v = "91.7" }, { g = "4.9", v = "96.5" }, { g = "4.4", v = "101" }, { g = "4.1", v = "105.1" }, { g = "3.8", v = "108.9" } },
			{ { g = "57", v = "57" }, { g = "14.2", v = "71.2" }, { g = "10", v = "81.2" }, { g = "8", v = "89.2" }, { g = "6.8", v = "95.9" }, { g = "5.9", v = "101.8" }, { g = "5.3", v = "107.1" }, { g = "4.8", v = "112" }, { g = "4.4", v = "116.4" }, { g = "4.1", v = "120.5" } },
		}, "60" },
		{ "Master Dragonslayer's Ring", "INV_Jewelry_Ring_41", "+{v}% critical strike chance", false, {
			{ { g = "6", v = "6" }, { g = "3.7", v = "9.7" }, { g = "3.4", v = "13.2" }, { g = "3.2", v = "16.4" }, { g = "3", v = "19.4" }, { g = "2.9", v = "22.3" }, { g = "2.7", v = "25" }, { g = "2.6", v = "27.5" }, { g = "2.4", v = "30" }, { g = "2.3", v = "32.3" } },
			{ { g = "8.4", v = "8.4" }, { g = "5.2", v = "13.6" }, { g = "4.8", v = "18.4" }, { g = "4.5", v = "22.9" }, { g = "4.2", v = "27.2" }, { g = "4", v = "31.2" }, { g = "3.8", v = "35" }, { g = "3.6", v = "38.5" }, { g = "3.4", v = "42" }, { g = "3.3", v = "45.2" } },
			{ { g = "10.8", v = "10.8" }, { g = "6.7", v = "17.5" }, { g = "6.2", v = "23.7" }, { g = "5.8", v = "29.5" }, { g = "5.5", v = "34.9" }, { g = "5.1", v = "40.1" }, { g = "4.9", v = "44.9" }, { g = "4.6", v = "49.6" }, { g = "4.4", v = "53.9" }, { g = "4.2", v = "58.1" } },
			{ { g = "14.4", v = "14.4" }, { g = "8.9", v = "23.3" }, { g = "8.3", v = "31.6" }, { g = "7.7", v = "39.3" }, { g = "7.3", v = "46.6" }, { g = "6.9", v = "53.4" }, { g = "6.5", v = "59.9" }, { g = "6.2", v = "66.1" }, { g = "5.9", v = "71.9" }, { g = "5.6", v = "77.5" } },
			{ { g = "19.2", v = "19.2" }, { g = "11.9", v = "31.1" }, { g = "11", v = "42.1" }, { g = "10.3", v = "52.4" }, { g = "9.7", v = "62.1" }, { g = "9.1", v = "71.2" }, { g = "8.6", v = "79.9" }, { g = "8.2", v = "88.1" }, { g = "7.8", v = "95.9" }, { g = "7.4", v = "103.3" } },
		}, { { "3.5", "2.8", "2.2" }, { "4.8", "3.9", "3.1" }, { "6.2", "5", "3.9" }, { "8.3", "6.7", "5.2" }, { "11.1", "8.9", "7" } } },
		{ "Archimtiros' Ring of Reckoning", "INV_Jewelry_Ring_40", "+{v}% damage reduction{max}, +{h}% max health", false, {
			{ { g = "4.4", h = "17.7", max = false, v = "4.4" }, { g = "2.1", h = "26.2", max = false, v = "6.6" }, { g = "1.7", h = "32.9", max = false, v = "8.2" }, { g = "1.3", h = "38", max = false, v = "9.5" }, { g = "1", h = "42", max = true, v = "10.5" }, { g = "0", h = "45.3", max = true, v = "10.5" }, { g = "0", h = "48.1", max = true, v = "10.5" }, { g = "0", h = "50.7", max = true, v = "10.5" }, { g = "0", h = "53", max = true, v = "10.5" }, { g = "0", h = "55.1", max = true, v = "10.5" } },
			{ { g = "5.8", h = "23.2", max = false, v = "5.8" }, { g = "2.4", h = "33", max = false, v = "8.2" }, { g = "1.7", h = "39.8", max = false, v = "10" }, { g = "0.5", h = "44.7", max = true, v = "10.5" }, { g = "0", h = "48.7", max = true, v = "10.5" }, { g = "0", h = "52.1", max = true, v = "10.5" }, { g = "0", h = "55.1", max = true, v = "10.5" }, { g = "0", h = "57.9", max = true, v = "10.5" }, { g = "0", h = "60.3", max = true, v = "10.5" }, { g = "0", h = "62.6", max = true, v = "10.5" } },
			{ { g = "7", h = "27.9", max = false, v = "7" }, { g = "2.6", h = "38.2", max = false, v = "9.5" }, { g = "1", h = "44.8", max = true, v = "10.5" }, { g = "0", h = "49.8", max = true, v = "10.5" }, { g = "0", h = "54", max = true, v = "10.5" }, { g = "0", h = "57.5", max = true, v = "10.5" }, { g = "0", h = "60.7", max = true, v = "10.5" }, { g = "0", h = "63.6", max = true, v = "10.5" }, { g = "0", h = "66.3", max = true, v = "10.5" }, { g = "0", h = "68.7", max = true, v = "10.5" } },
			{ { g = "8.5", h = "33.8", max = false, v = "8.5" }, { g = "2", h = "44", max = true, v = "10.5" }, { g = "0", h = "50.7", max = true, v = "10.5" }, { g = "0", h = "55.9", max = true, v = "10.5" }, { g = "0", h = "60.3", max = true, v = "10.5" }, { g = "0", h = "64.2", max = true, v = "10.5" }, { g = "0", h = "67.6", max = true, v = "10.5" }, { g = "0", h = "70.7", max = true, v = "10.5" }, { g = "0", h = "73.5", max = true, v = "10.5" }, { g = "0", h = "76.2", max = true, v = "10.5" } },
			{ { g = "10", h = "39.9", max = false, v = "10" }, { g = "0.5", h = "49.9", max = true, v = "10.5" }, { g = "0", h = "56.9", max = true, v = "10.5" }, { g = "0", h = "62.4", max = true, v = "10.5" }, { g = "0", h = "67.2", max = true, v = "10.5" }, { g = "0", h = "71.3", max = true, v = "10.5" }, { g = "0", h = "75", max = true, v = "10.5" }, { g = "0", h = "78.4", max = true, v = "10.5" }, { g = "0", h = "81.5", max = true, v = "10.5" }, { g = "0", h = "84.3", max = true, v = "10.5" } },
		}, "10.5" },
		{ "Ring of the Devoured", "INV_Jewelry_Ring_AhnQiraj_05", "+{v} health per second", true, {
			{ { g = "2.3", v = "2.3" }, { g = "0.8", v = "3" }, { g = "0.5", v = "3.5" }, { g = "0.3", v = "3.8" }, { g = "0.2", v = "4.1" } },
			{ { g = "3.2", v = "3.2" }, { g = "0.6", v = "3.8" }, { g = "0.3", v = "4.1" } },
			{ { g = "4.1", v = "4.1" } },
			{ { g = "4.5", v = "4.5" } },
			{ { g = "4.5", v = "4.5" } },
		}, false },
		{ "Ring of Spell Power", "INV_Jewelry_Ring_38", "+{v}% area of effect", false, {
			{ { g = "21", v = "21" }, { g = "13", v = "34" }, { g = "12.1", v = "46" }, { g = "11.3", v = "57.3" }, { g = "10.6", v = "67.9" }, { g = "10", v = "77.9" }, { g = "9.5", v = "87.4" }, { g = "9", v = "96.4" }, { g = "8.5", v = "104.9" }, { g = "8.1", v = "113" } },
			{ { g = "29.4", v = "29.4" }, { g = "18.1", v = "47.5" }, { g = "16.9", v = "64.4" }, { g = "15.8", v = "80.3" }, { g = "14.8", v = "95.1" }, { g = "14", v = "109.1" }, { g = "13.2", v = "122.3" }, { g = "12.6", v = "134.9" }, { g = "12", v = "146.9" }, { g = "11.4", v = "158.3" } },
			{ { g = "37.8", v = "37.8" }, { g = "23.3", v = "61.1" }, { g = "21.7", v = "82.9" }, { g = "20.3", v = "103.2" }, { g = "19.1", v = "122.3" }, { g = "18", v = "140.3" }, { g = "17", v = "157.3" }, { g = "16.2", v = "173.5" }, { g = "15.4", v = "188.8" }, { g = "14.7", v = "203.5" } },
			{ { g = "50.4", v = "50.4" }, { g = "31.1", v = "81.5" }, { g = "29", v = "110.5" }, { g = "27.1", v = "137.6" }, { g = "25.5", v = "163" }, { g = "24", v = "187" }, { g = "22.7", v = "209.7" }, { g = "21.5", v = "231.3" }, { g = "20.5", v = "251.8" }, { g = "19.5", v = "271.3" } },
			{ { g = "67.2", v = "67.2" }, { g = "41.5", v = "108.7" }, { g = "38.6", v = "147.3" }, { g = "36.1", v = "183.4" }, { g = "33.9", v = "217.4" }, { g = "32", v = "249.4" }, { g = "30.3", v = "279.6" }, { g = "28.7", v = "308.4" }, { g = "27.3", v = "335.7" }, { g = "26", v = "361.7" } },
		}, { { "12.1", "9.8", "7.7" }, { "17", "13.7", "10.7" }, { "21.8", "17.6", "13.8" }, { "29.1", "23.4", "18.4" }, { "38.7", "31.2", "24.5" } } },
		{ "Seal of the Damned", "INV_Jewelry_Ring_51Naxxramas", "Your damage over time spells tick {v}% faster", true, {
			{ { g = "15", v = "15" }, { g = "8.5", v = "23.5" }, { g = "7.7", v = "31.2" }, { g = "6.9", v = "38" }, { g = "6.2", v = "44.2" }, { g = "5.6", v = "49.8" }, { g = "5", v = "54.8" }, { g = "4.5", v = "59.3" }, { g = "4.1", v = "63.4" }, { g = "3.7", v = "67.1" }, { g = "3.3", v = "70.4" }, { g = "3", v = "73.3" }, { g = "2.7", v = "76" }, { g = "2.4", v = "78.4" }, { g = "2.2", v = "80.6" }, { g = "1.9", v = "82.5" }, { g = "1.8", v = "84.2" }, { g = "1.6", v = "85.8" }, { g = "1.4", v = "87.2" }, { g = "1.3", v = "88.5" }, { g = "1.1", v = "89.7" }, { g = "1", v = "90.7" } },
			{ { g = "21", v = "21" }, { g = "11.1", v = "32.1" }, { g = "9.5", v = "41.6" }, { g = "8.2", v = "49.8" }, { g = "7", v = "56.8" }, { g = "6", v = "62.8" }, { g = "5.2", v = "68" }, { g = "4.5", v = "72.5" }, { g = "3.8", v = "76.4" }, { g = "3.3", v = "79.7" }, { g = "2.8", v = "82.5" }, { g = "2.4", v = "85" }, { g = "2.1", v = "87.1" }, { g = "1.8", v = "88.9" }, { g = "1.6", v = "90.4" } },
			{ { g = "27", v = "27" }, { g = "13.1", v = "40.1" }, { g = "10.8", v = "50.9" }, { g = "8.8", v = "59.8" }, { g = "7.2", v = "67" }, { g = "5.9", v = "72.9" }, { g = "4.9", v = "77.8" }, { g = "4", v = "81.8" }, { g = "3.3", v = "85.1" }, { g = "2.7", v = "87.8" }, { g = "2.2", v = "90" }, { g = "1.8", v = "91.8" } },
			{ { g = "36", v = "36" }, { g = "15.4", v = "51.4" }, { g = "11.7", v = "63" }, { g = "8.9", v = "71.9" }, { g = "6.7", v = "78.6" }, { g = "5.1", v = "83.8" }, { g = "3.9", v = "87.7" }, { g = "3", v = "90.6" } },
			{ { g = "48", v = "48" }, { g = "16.6", v = "64.6" }, { g = "11.3", v = "76" }, { g = "7.7", v = "83.6" }, { g = "5.2", v = "88.9" }, { g = "3.6", v = "92.4" } },
		}, false },
		{ "Blooddrinker's Band", "INV_Jewelry_Ring_49Naxxramas", "{v}% of all damage dealt heals you", true, {
			{ { g = "1.5", v = "1.5" }, { g = "0.5", v = "2" }, { g = "0.3", v = "2.3" }, { g = "0.2", v = "2.6" }, { g = "0.1", v = "2.7" } },
			{ { g = "2.1", v = "2.1" }, { g = "0.4", v = "2.5" }, { g = "0.2", v = "2.7" } },
			{ { g = "2.7", v = "2.7" } },
			{ { g = "3", v = "3" } },
			{ { g = "3", v = "3" } },
		}, false },
	},
	trinket = {
		{ "Earthstrike", "Spell_Nature_AbolishMagic", "+{v}% damage", false, {
			{ { g = "19.5", v = "19.5" }, { g = "12", v = "31.5" }, { g = "11.2", v = "42.7" }, { g = "10.5", v = "53.2" }, { g = "9.8", v = "63.1" }, { g = "9.3", v = "72.4" }, { g = "8.8", v = "81.1" }, { g = "8.3", v = "89.5" }, { g = "7.9", v = "97.4" }, { g = "7.6", v = "105" } },
			{ { g = "27.3", v = "27.3" }, { g = "16.9", v = "44.2" }, { g = "15.7", v = "59.8" }, { g = "14.7", v = "74.5" }, { g = "13.8", v = "88.3" }, { g = "13", v = "101.3" }, { g = "12.3", v = "113.6" }, { g = "11.7", v = "125.3" }, { g = "11.1", v = "136.4" }, { g = "10.6", v = "146.9" } },
			{ { g = "35.1", v = "35.1" }, { g = "21.7", v = "56.8" }, { g = "20.2", v = "76.9" }, { g = "18.9", v = "95.8" }, { g = "17.7", v = "113.5" }, { g = "16.7", v = "130.3" }, { g = "15.8", v = "146.1" }, { g = "15", v = "161.1" }, { g = "14.3", v = "175.3" }, { g = "13.6", v = "188.9" } },
			{ { g = "46.8", v = "46.8" }, { g = "28.9", v = "75.7" }, { g = "26.9", v = "102.6" }, { g = "25.2", v = "127.7" }, { g = "23.6", v = "151.4" }, { g = "22.3", v = "173.7" }, { g = "21.1", v = "194.7" }, { g = "20", v = "214.7" }, { g = "19", v = "233.8" }, { g = "18.1", v = "251.9" } },
			{ { g = "62.4", v = "62.4" }, { g = "38.5", v = "100.9" }, { g = "35.9", v = "136.8" }, { g = "33.5", v = "170.3" }, { g = "31.5", v = "201.8" }, { g = "29.7", v = "231.6" }, { g = "28.1", v = "259.7" }, { g = "26.7", v = "286.3" }, { g = "25.4", v = "311.7" }, { g = "24.2", v = "335.9" } },
		}, { { "11.2", "9.1", "7.1" }, { "15.7", "12.7", "9.9" }, { "20.2", "16.3", "12.8" }, { "27", "21.8", "17.1" }, { "36", "29", "22.7" } } },
		{ "Talisman of Ephemeral Power", "INV_Misc_StoneTablet_11", "-{v}% cooldowns", false, {
			{ { g = "10.5", v = "10.5" }, { g = "6.5", v = "17" }, { g = "6", v = "23" }, { g = "5.6", v = "28.7" }, { g = "5.3", v = "34" }, { g = "5", v = "39" }, { g = "4.7", v = "43.7" }, { g = "4.5", v = "48.2" }, { g = "4.3", v = "52.4" }, { g = "4.1", v = "56.5" } },
			{ { g = "14.7", v = "14.7" }, { g = "9.1", v = "23.8" }, { g = "8.4", v = "32.2" }, { g = "7.9", v = "40.1" }, { g = "7.4", v = "47.5" }, { g = "7", v = "54.5" }, { g = "6.6", v = "61.2" }, { g = "6.3", v = "67.5" }, { g = "6", v = "73.4" }, { g = "5.7", v = "79.1" } },
			{ { g = "18.9", v = "18.9" }, { g = "11.7", v = "30.6" }, { g = "10.9", v = "41.4" }, { g = "10.2", v = "51.6" }, { g = "9.5", v = "61.1" }, { g = "9", v = "70.1" }, { g = "8.5", v = "78.6" }, { g = "8.1", v = "86.7" }, { g = "7.7", v = "94.4" }, { g = "7.3", v = "101.7" } },
			{ { g = "25.2", v = "25.2" }, { g = "15.6", v = "40.8" }, { g = "14.5", v = "55.2" }, { g = "13.5", v = "68.8" }, { g = "12.7", v = "81.5" }, { g = "12", v = "93.5" }, { g = "11.4", v = "104.9" }, { g = "10.8", v = "115.6" }, { g = "10.2", v = "125.9" }, { g = "9.8", v = "135.6" } },
			{ { g = "33.6", v = "33.6" }, { g = "20.7", v = "54.3" }, { g = "19.3", v = "73.7" }, { g = "18.1", v = "91.7" }, { g = "17", v = "108.7" }, { g = "16", v = "124.7" }, { g = "15.1", v = "139.8" }, { g = "14.4", v = "154.2" }, { g = "13.7", v = "167.8" }, { g = "13", v = "180.9" } },
		}, { { "6.1", "4.9", "3.8" }, { "8.5", "6.8", "5.4" }, { "10.9", "8.8", "6.9" }, { "14.5", "11.7", "9.2" }, { "19.4", "15.6", "12.2" } } },
		{ "Lifegiving Gem", "INV_Misc_Gem_Pearl_05", "+{v}% max health", false, {
			{ { g = "20.2", v = "20.2" }, { g = "9.8", v = "30" }, { g = "7.6", v = "37.5" }, { g = "5.9", v = "43.4" }, { g = "4.6", v = "48" }, { g = "3.7", v = "51.7" }, { g = "3.2", v = "55" }, { g = "2.9", v = "57.9" }, { g = "2.6", v = "60.5" }, { g = "2.4", v = "62.9" } },
			{ { g = "26.5", v = "26.5" }, { g = "11.2", v = "37.7" }, { g = "7.9", v = "45.5" }, { g = "5.6", v = "51.1" }, { g = "4.5", v = "55.7" }, { g = "3.9", v = "59.6" }, { g = "3.4", v = "63" }, { g = "3.1", v = "66.1" }, { g = "2.8", v = "69" }, { g = "2.6", v = "71.6" } },
			{ { g = "31.9", v = "31.9" }, { g = "11.8", v = "43.7" }, { g = "7.6", v = "51.2" }, { g = "5.7", v = "56.9" }, { g = "4.7", v = "61.7" }, { g = "4.1", v = "65.8" }, { g = "3.6", v = "69.4" }, { g = "3.3", v = "72.7" }, { g = "3", v = "75.7" }, { g = "2.8", v = "78.5" } },
			{ { g = "38.7", v = "38.7" }, { g = "11.6", v = "50.3" }, { g = "7.6", v = "57.9" }, { g = "6", v = "63.9" }, { g = "5", v = "68.9" }, { g = "4.4", v = "73.3" }, { g = "3.9", v = "77.2" }, { g = "3.6", v = "80.8" }, { g = "3.3", v = "84.1" }, { g = "3", v = "87.1" } },
			{ { g = "45.6", v = "45.6" }, { g = "11.4", v = "57" }, { g = "8", v = "65" }, { g = "6.4", v = "71.4" }, { g = "5.4", v = "76.8" }, { g = "4.7", v = "81.5" }, { g = "4.2", v = "85.7" }, { g = "3.8", v = "89.6" }, { g = "3.5", v = "93.1" }, { g = "3.3", v = "96.4" } },
		}, "48" },
		{ "Hand of Justice", "INV_Jewelry_Talisman_01", "{v}% chance for a spell to cast twice", true, {
			{ { g = "9", v = "9" }, { g = "5.6", v = "14.6" }, { g = "5.2", v = "19.7" }, { g = "4.8", v = "24.6" }, { g = "4.5", v = "29.1" }, { g = "4.3", v = "33.4" }, { g = "4.1", v = "37.5" }, { g = "3.8", v = "41.3" }, { g = "3.7", v = "45" }, { g = "3.5", v = "48.4" }, { g = "3.3", v = "51.8" }, { g = "3.2", v = "55" } },
			{ { g = "12.6", v = "12.6" }, { g = "7.8", v = "20.4" }, { g = "7.2", v = "27.6" }, { g = "6.8", v = "34.4" }, { g = "6.4", v = "40.8" }, { g = "6", v = "46.8" }, { g = "5.7", v = "52.4" }, { g = "5.4", v = "57.8" } },
			{ { g = "16.2", v = "16.2" }, { g = "10", v = "26.2" }, { g = "9.3", v = "35.5" }, { g = "8.7", v = "44.2" }, { g = "8.2", v = "52.4" }, { g = "7.6", v = "60" } },
			{ { g = "21.6", v = "21.6" }, { g = "13.3", v = "34.9" }, { g = "12.4", v = "47.3" }, { g = "11.6", v = "59" } },
			{ { g = "28.8", v = "28.8" }, { g = "17.8", v = "46.6" }, { g = "13.4", v = "60" } },
		}, false },
		{ "Blackhand's Breadth", "INV_Misc_ArmorKit_09", "+{v}% critical strike damage", false, {
			{ { g = "29.3", v = "29.3" }, { g = "18.1", v = "47.3" }, { g = "16.8", v = "64.1" }, { g = "15.7", v = "79.8" }, { g = "14.8", v = "94.6" }, { g = "13.9", v = "108.5" }, { g = "13.2", v = "121.7" }, { g = "12.5", v = "134.2" }, { g = "11.9", v = "146.1" }, { g = "11.3", v = "157.4" } },
			{ { g = "41", v = "41" }, { g = "25.3", v = "66.2" }, { g = "23.5", v = "89.8" }, { g = "22", v = "111.8" }, { g = "20.7", v = "132.5" }, { g = "19.5", v = "152" }, { g = "18.4", v = "170.4" }, { g = "17.5", v = "187.9" }, { g = "16.6", v = "204.6" }, { g = "15.9", v = "220.4" } },
			{ { g = "52.7", v = "52.7" }, { g = "32.5", v = "85.2" }, { g = "30.3", v = "115.4" }, { g = "28.3", v = "143.7" }, { g = "26.6", v = "170.3" }, { g = "25.1", v = "195.4" }, { g = "23.7", v = "219.1" }, { g = "22.5", v = "241.6" }, { g = "21.4", v = "263" }, { g = "20.4", v = "283.4" } },
			{ { g = "70.2", v = "70.2" }, { g = "43.3", v = "113.5" }, { g = "40.3", v = "153.9" }, { g = "37.7", v = "191.6" }, { g = "35.5", v = "227.1" }, { g = "33.4", v = "260.5" }, { g = "31.6", v = "292.1" }, { g = "30", v = "322.1" }, { g = "28.5", v = "350.7" }, { g = "27.2", v = "377.9" } },
			{ { g = "93.6", v = "93.6" }, { g = "57.8", v = "151.4" }, { g = "53.8", v = "205.2" }, { g = "50.3", v = "255.5" }, { g = "47.3", v = "302.8" }, { g = "44.6", v = "347.3" }, { g = "42.2", v = "389.5" }, { g = "40", v = "429.5" }, { g = "38", v = "467.5" }, { g = "36.3", v = "503.8" } },
		}, { { "16.9", "13.6", "10.7" }, { "23.6", "19", "14.9" }, { "30.4", "24.5", "19.2" }, { "40.5", "32.6", "25.6" }, { "54", "43.5", "34.1" } } },
		{ "Carrot on a Stick", "INV_Misc_Food_54", "+{v}% movement speed", true, {
			{ { g = "12", v = "12" }, { g = "5.6", v = "17.6" }, { g = "4.5", v = "22.1" }, { g = "3.6", v = "25.7" }, { g = "2.9", v = "28.5" }, { g = "2.3", v = "30.8" }, { g = "1.8", v = "32.7" }, { g = "1.5", v = "34.1" }, { g = "1.2", v = "35.3" }, { g = "0.9", v = "36.2" } },
			{ { g = "16.8", v = "16.8" }, { g = "6.5", v = "23.3" }, { g = "4.7", v = "28" }, { g = "3.4", v = "31.3" }, { g = "2.4", v = "33.8" }, { g = "1.7", v = "35.5" }, { g = "1.3", v = "36.8" } },
			{ { g = "21.6", v = "21.6" }, { g = "6.6", v = "28.2" }, { g = "4.2", v = "32.5" }, { g = "2.7", v = "35.2" }, { g = "1.7", v = "36.9" } },
			{ { g = "28.8", v = "28.8" }, { g = "5.4", v = "34.2" }, { g = "2.8", v = "37" } },
			{ { g = "38.4", v = "38.4" } },
		}, false },
		{ "Gnomish Universal Remote", "INV_Misc_PocketWatch_01", "+{v}% pickup range", true, {
			{ { g = "52.5", v = "52.5" }, { g = "24.5", v = "77" }, { g = "19.6", v = "96.6" }, { g = "15.7", v = "112.3" }, { g = "12.5", v = "124.8" }, { g = "10", v = "134.9" }, { g = "8", v = "142.9" }, { g = "6.4", v = "149.3" }, { g = "5.1", v = "154.4" }, { g = "4.1", v = "158.6" } },
			{ { g = "73.5", v = "73.5" }, { g = "28.4", v = "101.9" }, { g = "20.5", v = "122.4" }, { g = "14.7", v = "137.1" }, { g = "10.6", v = "147.7" }, { g = "7.6", v = "155.4" }, { g = "5.5", v = "160.9" } },
			{ { g = "94.5", v = "94.5" }, { g = "29", v = "123.5" }, { g = "18.5", v = "142" }, { g = "11.9", v = "153.9" }, { g = "7.6", v = "161.5" } },
			{ { g = "126", v = "126" }, { g = "23.5", v = "149.5" }, { g = "12.2", v = "161.8" } },
			{ { g = "168", v = "168" } },
		}, false },
		{ "Insignia of the Horde", "INV_Jewelry_TrinketPVP_02", "+{v}% experience", true, {
			{ { g = "18", v = "18" }, { g = "8.4", v = "26.4" }, { g = "6.7", v = "33.1" }, { g = "5.4", v = "38.5" }, { g = "4.3", v = "42.8" }, { g = "3.4", v = "46.2" }, { g = "2.8", v = "49" }, { g = "2.2", v = "51.2" }, { g = "1.8", v = "53" }, { g = "1.4", v = "54.4" } },
			{ { g = "25.2", v = "25.2" }, { g = "9.7", v = "34.9" }, { g = "7", v = "42" }, { g = "5.1", v = "47" }, { g = "3.6", v = "50.6" }, { g = "2.6", v = "53.3" }, { g = "1.9", v = "55.2" } },
			{ { g = "32.4", v = "32.4" }, { g = "9.9", v = "42.3" }, { g = "6.4", v = "48.7" }, { g = "4.1", v = "52.8" }, { g = "2.6", v = "55.4" } },
			{ { g = "43.2", v = "43.2" }, { g = "8.1", v = "51.3" }, { g = "4.2", v = "55.5" } },
			{ { g = "57.6", v = "57.6" } },
		}, false },
		{ "Royal Seal of Eldre'Thalas", "INV_Jewelry_Talisman_10", "+{v}% gold", true, {
			{ { g = "37.5", v = "37.5" }, { g = "17.5", v = "55" }, { g = "14", v = "69" }, { g = "11.2", v = "80.2" }, { g = "9", v = "89.2" }, { g = "7.2", v = "96.3" }, { g = "5.7", v = "102.1" }, { g = "4.6", v = "106.6" }, { g = "3.7", v = "110.3" }, { g = "2.9", v = "113.3" } },
			{ { g = "52.5", v = "52.5" }, { g = "20.3", v = "72.8" }, { g = "14.6", v = "87.4" }, { g = "10.5", v = "97.9" }, { g = "7.6", v = "105.5" }, { g = "5.5", v = "111" }, { g = "3.9", v = "114.9" } },
			{ { g = "67.5", v = "67.5" }, { g = "20.7", v = "88.2" }, { g = "13.2", v = "101.4" }, { g = "8.5", v = "109.9" }, { g = "5.4", v = "115.4" } },
			{ { g = "90", v = "90" }, { g = "16.8", v = "106.8" }, { g = "8.7", v = "115.5" } },
			{ { g = "120", v = "120" } },
		}, false },
		{ "Mark of the Chosen", "INV_Jewelry_Talisman_08", "+{v}% luck", true, {
			{ { g = "22.5", v = "22.5" }, { g = "10.5", v = "33" }, { g = "8.4", v = "41.4" }, { g = "6.7", v = "48.1" }, { g = "5.4", v = "53.5" }, { g = "4.3", v = "57.8" }, { g = "3.4", v = "61.2" }, { g = "2.8", v = "64" }, { g = "2.2", v = "66.2" }, { g = "1.8", v = "68" } },
			{ { g = "31.5", v = "31.5" }, { g = "12.2", v = "43.7" }, { g = "8.8", v = "52.4" }, { g = "6.3", v = "58.8" }, { g = "4.5", v = "63.3" }, { g = "3.3", v = "66.6" }, { g = "2.4", v = "68.9" } },
			{ { g = "40.5", v = "40.5" }, { g = "12.4", v = "52.9" }, { g = "7.9", v = "60.9" }, { g = "5.1", v = "66" }, { g = "3.3", v = "69.2" } },
			{ { g = "54", v = "54" }, { g = "10.1", v = "64.1" }, { g = "5.2", v = "69.3" } },
			{ { g = "72", v = "72" } },
		}, false },
		{ "Onyxia Blood Talisman", "Spell_Shadow_LifeDrain", "Each kill heals {v} health", true, {
			{ { g = "3", v = "3" }, { g = "1", v = "4" }, { g = "0.7", v = "4.7" }, { g = "0.4", v = "5.1" }, { g = "0.3", v = "5.4" } },
			{ { g = "4.2", v = "4.2" }, { g = "0.8", v = "5" }, { g = "0.4", v = "5.5" } },
			{ { g = "5.4", v = "5.4" } },
			{ { g = "6", v = "6" } },
			{ { g = "6", v = "6" } },
		}, false },
		{ "Horn of the Warchief", "INV_Misc_Horn_01", "Your buffs are {v}% stronger", true, {
			{ { g = "22.5", v = "22.5" }, { g = "10.5", v = "33" }, { g = "8.4", v = "41.4" }, { g = "6.7", v = "48.1" }, { g = "5.4", v = "53.5" }, { g = "4.3", v = "57.8" }, { g = "3.4", v = "61.2" }, { g = "2.8", v = "64" }, { g = "2.2", v = "66.2" }, { g = "1.8", v = "68" } },
			{ { g = "31.5", v = "31.5" }, { g = "12.2", v = "43.7" }, { g = "8.8", v = "52.4" }, { g = "6.3", v = "58.8" }, { g = "4.5", v = "63.3" }, { g = "3.3", v = "66.6" }, { g = "2.4", v = "68.9" } },
			{ { g = "40.5", v = "40.5" }, { g = "12.4", v = "52.9" }, { g = "7.9", v = "60.9" }, { g = "5.1", v = "66" }, { g = "3.3", v = "69.2" } },
			{ { g = "54", v = "54" }, { g = "10.1", v = "64.1" }, { g = "5.2", v = "69.3" } },
			{ { g = "72", v = "72" } },
		}, false },
		{ "Major Soulstone", "INV_Misc_Orb_04", "+{v} return to life at half health (2 at most)", true, {
			{ { g = "1", v = "1" } },
			{ { g = "1", v = "1" } },
			{ { g = "1", v = "1" } },
			{ { g = "2", v = "2" } },
			{ { g = "2", v = "2" } },
		}, false },
		{ "Star of Mystaria", "INV_Enchant_EssenceMagicLarge", "+{v}% max health, +{h}% damage reduction{max}", false, {
			{ { g = "21.1", h = "3.4", max = false, v = "21.1" }, { g = "10.2", h = "5", max = false, v = "31.2" }, { g = "7.9", h = "6.3", max = false, v = "39.1" }, { g = "6.1", h = "7.2", max = false, v = "45.2" }, { g = "4.8", h = "8", max = false, v = "50" }, { g = "3.9", h = "8.6", max = false, v = "53.9" }, { g = "3.4", h = "9.2", max = false, v = "57.3" }, { g = "3", h = "9.6", max = false, v = "60.3" }, { g = "2.7", h = "10.1", max = false, v = "63" }, { g = "2.5", h = "10.5", max = false, v = "65.6" } },
			{ { g = "27.6", h = "4.4", max = false, v = "27.6" }, { g = "11.7", h = "6.3", max = false, v = "39.2" }, { g = "8.2", h = "7.6", max = false, v = "47.4" }, { g = "5.9", h = "8.5", max = false, v = "53.3" }, { g = "4.7", h = "9.3", max = false, v = "58" }, { g = "4.1", h = "9.9", max = false, v = "62.1" }, { g = "3.6", h = "10.5", max = false, v = "65.6" }, { g = "3.2", h = "11", max = false, v = "68.9" }, { g = "3", h = "11.5", max = false, v = "71.8" }, { g = "2.7", h = "11.9", max = false, v = "74.6" } },
			{ { g = "33.2", h = "5.3", max = false, v = "33.2" }, { g = "12.3", h = "7.3", max = false, v = "45.5" }, { g = "7.9", h = "8.5", max = false, v = "53.4" }, { g = "5.9", h = "9.5", max = false, v = "59.3" }, { g = "4.9", h = "10.3", max = false, v = "64.2" }, { g = "4.3", h = "11", max = false, v = "68.5" }, { g = "3.8", h = "11.6", max = false, v = "72.3" }, { g = "3.4", h = "12", max = true, v = "75.7" }, { g = "3.1", h = "12", max = true, v = "78.9" }, { g = "2.9", h = "12", max = true, v = "81.8" } },
			{ { g = "40.3", h = "6.4", max = false, v = "40.3" }, { g = "12.1", h = "8.4", max = false, v = "52.4" }, { g = "7.9", h = "9.7", max = false, v = "60.3" }, { g = "6.2", h = "10.7", max = false, v = "66.6" }, { g = "5.2", h = "11.5", max = false, v = "71.8" }, { g = "4.6", h = "12", max = true, v = "76.4" }, { g = "4.1", h = "12", max = true, v = "80.5" }, { g = "3.7", h = "12", max = true, v = "84.2" }, { g = "3.4", h = "12", max = true, v = "87.6" }, { g = "3.2", h = "12", max = true, v = "90.7" } },
			{ { g = "47.5", h = "7.6", max = false, v = "47.5" }, { g = "11.8", h = "9.5", max = false, v = "59.4" }, { g = "8.3", h = "10.8", max = false, v = "67.7" }, { g = "6.6", h = "11.9", max = false, v = "74.3" }, { g = "5.6", h = "12", max = true, v = "80" }, { g = "4.9", h = "12", max = true, v = "84.9" }, { g = "4.4", h = "12", max = true, v = "89.3" }, { g = "4", h = "12", max = true, v = "93.3" }, { g = "3.7", h = "12", max = true, v = "97" }, { g = "3.4", h = "12", max = true, v = "100.4" } },
		}, "50" },
	},
	amulet = {
		{ "Mark of Fordring", "INV_Jewelry_Talisman_07", 1, "", { 100, 160, 202, 231.4, 252, 266.4, 276.5, 283.5, 288.5, 291.9 }, {
			{ "+{p} damage", { { p = "15%" }, { p = "24%" }, { p = "30.3%" }, { p = "34.7%" }, { p = "37.8%" }, { p = "40%" }, { p = "41.5%" }, { p = "42.5%" }, { p = "43.3%" }, { p = "43.8%" } }, { p = "45%" } },
		} },
		{ "Talvash's Enhancing Necklace", "INV_Jewelry_Necklace_02", 1, "", { 100, 160, 202, 231.4, 252, 266.4, 276.5, 283.5, 288.5, 291.9 }, {
			{ "-{p} cooldowns", { { p = "10%" }, { p = "16%" }, { p = "20.2%" }, { p = "23.1%" }, { p = "25.2%" }, { p = "26.6%" }, { p = "27.6%" }, { p = "28.4%" }, { p = "28.8%" }, { p = "29.2%" } }, { p = "30%" } },
		} },
		{ "Pristine Enchanted South Seas Kelp", "INV_Jewelry_Necklace_26", 1, "", { 100, 160, 202, 231.4, 252, 266.4, 276.5, 283.5, 288.5, 291.9 }, {
			{ "+{p} luck", { { p = "30%" }, { p = "48%" }, { p = "60.6%" }, { p = "69.4%" }, { p = "75.6%" }, { p = "79.9%" }, { p = "82.9%" }, { p = "85.1%" }, { p = "86.5%" }, { p = "87.6%" } }, { p = "90%" } },
			{ "+{p} gold", { { p = "25%" }, { p = "40%" }, { p = "50.5%" }, { p = "57.9%" }, { p = "63%" }, { p = "66.6%" }, { p = "69.1%" }, { p = "70.9%" }, { p = "72.1%" }, { p = "73%" } }, { p = "75%" } },
		} },
		{ "Prestor's Talisman of Connivery", "INV_Jewelry_Necklace_17", 2, "", { 100, 150, 187.5, 215.6, 236.7, 252.5, 264.4, 273.3, 280, 285 }, {
			{ "+{p} damage", { { p = "16%" }, { p = "24%" }, { p = "30%" }, { p = "34.5%" }, { p = "37.9%" }, { p = "40.4%" }, { p = "42.3%" }, { p = "43.7%" }, { p = "44.8%" }, { p = "45.6%" } }, { p = "48%" } },
			{ "+{p} critical strike", { { p = "4%" }, { p = "6%" }, { p = "7.5%" }, { p = "8.6%" }, { p = "9.5%" }, { p = "10.1%" }, { p = "10.6%" }, { p = "10.9%" }, { p = "11.2%" }, { p = "11.4%" } }, { p = "12%" } },
		} },
		{ "Animated Chain Necklace", "INV_Jewelry_Necklace_01", 2, "", { 100, 150, 187.5, 215.6, 236.7, 252.5, 264.4, 273.3, 280, 285 }, {
			{ "+{p} max health", { { p = "25%" }, { p = "37.5%" }, { p = "46.9%" }, { p = "53.9%" }, { p = "59.2%" }, { p = "63.1%" }, { p = "66.1%" }, { p = "68.3%" }, { p = "70%" }, { p = "71.2%" } }, { p = "75%" } },
			{ "+{p} damage reduction", { { p = "8%" }, { p = "12%" }, { p = "15%" }, { p = "17.3%" }, { p = "18.9%" }, { p = "20.2%" }, { p = "21.2%" }, { p = "21.9%" }, { p = "22.4%" }, { p = "22.8%" } }, { p = "24%" } },
		} },
		{ "Woven Ivy Necklace", "INV_Misc_Herb_15", 2, "", { 100, 150, 187.5, 215.6, 236.7, 252.5, 264.4, 273.3, 280, 285 }, {
			{ "+{v} health per second", { { v = "6" }, { v = "9" }, { v = "11.3" }, { v = "12.9" }, { v = "14.2" }, { v = "15.2" }, { v = "15.9" }, { v = "16.4" }, { v = "16.8" }, { v = "17.1" } }, { v = "18" } },
			{ "+{p} max health", { { p = "12%" }, { p = "18%" }, { p = "22.5%" }, { p = "25.9%" }, { p = "28.4%" }, { p = "30.3%" }, { p = "31.7%" }, { p = "32.8%" }, { p = "33.6%" }, { p = "34.2%" } }, { p = "36%" } },
			{ "+{p} movement speed", { { p = "12%" }, { p = "18%" }, { p = "22.5%" }, { p = "25.9%" }, { p = "28.4%" }, { p = "30.3%" }, { p = "31.7%" }, { p = "32.8%" }, { p = "33.6%" }, { p = "34.2%" } }, { p = "36%" } },
		} },
		{ "Amulet of the Darkmoon", "INV_Jewelry_Necklace_14", 2, "", { 100, 150, 187.5, 215.6, 236.7, 252.5, 264.4, 273.3, 280, 285 }, {
			{ "-{p} cooldowns", { { p = "12%" }, { p = "18%" }, { p = "22.5%" }, { p = "25.9%" }, { p = "28.4%" }, { p = "30.3%" }, { p = "31.7%" }, { p = "32.8%" }, { p = "33.6%" }, { p = "34.2%" } }, { p = "36%" } },
			{ "+{p} movement speed", { { p = "8%" }, { p = "12%" }, { p = "15%" }, { p = "17.3%" }, { p = "18.9%" }, { p = "20.2%" }, { p = "21.2%" }, { p = "21.9%" }, { p = "22.4%" }, { p = "22.8%" } }, { p = "24%" } },
		} },
		{ "Jeklik's Opaline Talisman", "INV_Jewelry_Necklace_03", 3, "", { 100, 135, 163.9, 187.7, 207.3, 223.6, 236.9, 248, 257.1, 264.6 }, {
			{ "Heals you for {p} of all damage dealt", { { p = "3%" }, { p = "4.1%" }, { p = "4.9%" }, { p = "5.6%" }, { p = "6.2%" }, { p = "6.7%" }, { p = "7.1%" }, { p = "7.4%" }, { p = "7.7%" }, { p = "7.9%" } }, { p = "9%" } },
			{ "Each kill heals {v} health", { { v = "1" }, { v = "1.4" }, { v = "1.6" }, { v = "1.9" }, { v = "2.1" }, { v = "2.2" }, { v = "2.4" }, { v = "2.5" }, { v = "2.6" }, { v = "2.6" } }, { v = "3" } },
		} },
		{ "The Eye of Hakkar", "INV_Jewelry_Necklace_22", 3, "Your critical hits", { 100, 135, 163.9, 187.7, 207.3, 223.6, 236.9, 248, 257.1, 264.6 }, {
			{ "+{p} critical strike", { { p = "4.8%" }, { p = "6.5%" }, { p = "7.9%" }, { p = "9%" }, { p = "10%" }, { p = "10.7%" }, { p = "11.4%" }, { p = "11.9%" }, { p = "12.3%" }, { p = "12.7%" } }, { p = "14.4%" } },
			{ "{hits} burn and bleed for {frac} more over {dur} sec", { { dur = "4", frac = "80%" }, { dur = "4", frac = "108%" }, { dur = "4", frac = "131.1%" }, { dur = "4", frac = "150.2%" }, { dur = "4", frac = "165.9%" }, { dur = "4", frac = "178.9%" }, { dur = "4", frac = "189.6%" }, { dur = "4", frac = "198.4%" }, { dur = "4", frac = "205.7%" }, { dur = "4", frac = "211.7%" } }, { dur = "4", frac = "240%" } },
		} },
		{ "Medallion of Steadfast Might", "INV_Jewelry_Amulet_03", 3, "", { 100, 135, 163.9, 187.7, 207.3, 223.6, 236.9, 248, 257.1, 264.6 }, {
			{ "+{p} damage reduction", { { p = "10%" }, { p = "13.5%" }, { p = "16.4%" }, { p = "18.8%" }, { p = "20.7%" }, { p = "22.4%" }, { p = "23.7%" }, { p = "24.8%" }, { p = "25.7%" }, { p = "26.5%" } }, { p = "30%" } },
			{ "+{p} max health", { { p = "15%" }, { p = "20.3%" }, { p = "24.6%" }, { p = "28.2%" }, { p = "31.1%" }, { p = "33.5%" }, { p = "35.5%" }, { p = "37.2%" }, { p = "38.6%" }, { p = "39.7%" } }, { p = "45%" } },
			{ "Melee attackers take {p} of the damage they deal", { { p = "100%" }, { p = "135%" }, { p = "163.9%" }, { p = "187.7%" }, { p = "207.3%" }, { p = "223.6%" }, { p = "236.9%" }, { p = "248%" }, { p = "257.1%" }, { p = "264.6%" } }, { p = "300%" } },
		} },
		{ "Choker of Enlightenment", "INV_Jewelry_Necklace_10", 4, "Your hits", { 100, 135, 163.9, 187.7, 207.3, 223.6, 236.9, 248, 257.1, 264.6 }, {
			{ "{hits} leap to 1 more enemy for {frac}", { { frac = "30%" }, { frac = "40.5%" }, { frac = "49.2%" }, { frac = "56.3%" }, { frac = "62.2%" }, { frac = "67.1%" }, { frac = "71.1%" }, { frac = "74.4%" }, { frac = "77.1%" }, { frac = "79.4%" } }, { frac = "90%" } },
		} },
		{ "Amulet of Vek'nilash", "INV_Jewelry_Necklace_AhnQiraj_01", 4, "", { 100, 125, 146.9, 166, 182.8, 197.4, 210.2, 221.5, 231.3, 239.9 }, {
			{ "{who}: +{n} target", { { n = "1" }, { n = "1" }, { n = "1" }, { n = "1" }, { n = "1" }, { n = "1" }, { n = "2" }, { n = "2" }, { n = "2" }, { n = "2" } }, { n = "3" } },
			{ "+{p} damage", { { p = "5%" }, { p = "6.3%" }, { p = "7.3%" }, { p = "8.3%" }, { p = "9.1%" }, { p = "9.9%" }, { p = "10.5%" }, { p = "11.1%" }, { p = "11.6%" }, { p = "12%" } }, { p = "15%" } },
		} },
		{ "Pendant of the Fallen Dragon", "INV_Jewelry_Necklace_12", 4, "", { 100, 125, 146.9, 166, 182.8, 197.4, 210.2, 221.5, 231.3, 239.9 }, {
			{ "A killing blow leaves you at {heal} health instead, once every {cd} sec", { { cd = "60", heal = "50%" }, { cd = "60", heal = "50%" }, { cd = "60", heal = "50%" }, { cd = "60", heal = "50%" }, { cd = "60", heal = "50%" }, { cd = "60", heal = "50%" }, { cd = "60", heal = "50%" }, { cd = "60", heal = "50%" }, { cd = "60", heal = "50%" }, { cd = "60", heal = "50%" } }, { cd = "60", heal = "50%" } },
			{ "+{p} max health", { { p = "20%" }, { p = "25%" }, { p = "29.4%" }, { p = "33.2%" }, { p = "36.6%" }, { p = "39.5%" }, { p = "42%" }, { p = "44.3%" }, { p = "46.3%" }, { p = "48%" } }, { p = "60%" } },
			{ "+{v} health per second", { { v = "5" }, { v = "6.3" }, { v = "7.3" }, { v = "8.3" }, { v = "9.1" }, { v = "9.9" }, { v = "10.5" }, { v = "11.1" }, { v = "11.6" }, { v = "12" } }, { v = "15" } },
		} },
		{ "Malice Stone Pendant", "INV_Jewelry_Necklace_29Naxxramas", 4, "", { 100, 125, 146.9, 166, 182.8, 197.4, 210.2, 221.5, 231.3, 239.9 }, {
			{ "{p} chance for a spell to cast twice", { { p = "20%" }, { p = "25%" }, { p = "29.4%" }, { p = "33.2%" }, { p = "36.6%" }, { p = "39.5%" }, { p = "42%" }, { p = "44.3%" }, { p = "46.3%" }, { p = "48%" } }, { p = "60%" } },
			{ "-{p} cooldowns", { { p = "8%" }, { p = "10%" }, { p = "11.8%" }, { p = "13.3%" }, { p = "14.6%" }, { p = "15.8%" }, { p = "16.8%" }, { p = "17.7%" }, { p = "18.5%" }, { p = "19.2%" } }, { p = "24%" } },
		} },
		{ "Onyxia Tooth Pendant", "INV_Jewelry_Necklace_09", 5, "Your critical hits", { 100, 125, 146.9, 166, 182.8, 197.4, 210.2, 221.5, 231.3, 239.9 }, {
			{ "+{p} critical strike", { { p = "4%" }, { p = "5%" }, { p = "5.9%" }, { p = "6.6%" }, { p = "7.3%" }, { p = "7.9%" }, { p = "8.4%" }, { p = "8.9%" }, { p = "9.3%" }, { p = "9.6%" } }, { p = "12%" } },
			{ "+{p} critical strike damage", { { p = "19.5%" }, { p = "24.4%" }, { p = "28.6%" }, { p = "32.4%" }, { p = "35.6%" }, { p = "38.5%" }, { p = "41%" }, { p = "43.2%" }, { p = "45.1%" }, { p = "46.8%" } }, { p = "58.5%" } },
			{ "{hits} splash {frac} on enemies within {radius} yd", { { frac = "30%", radius = "5" }, { frac = "37.5%", radius = "5" }, { frac = "44.1%", radius = "5" }, { frac = "49.8%", radius = "5" }, { frac = "54.8%", radius = "5" }, { frac = "59.2%", radius = "5" }, { frac = "63.1%", radius = "5" }, { frac = "66.4%", radius = "5" }, { frac = "69.4%", radius = "5" }, { frac = "72%", radius = "5" } }, { frac = "90%", radius = "5" } },
		} },
		{ "Choker of the Fire Lord", "INV_Jewelry_Amulet_05", 5, "", { 100, 125, 146.9, 166, 182.8, 197.4, 210.2, 221.5, 231.3, 239.9 }, {
			{ "Enemies you kill explode for {frac} of their max health", { { frac = "15%" }, { frac = "18.8%" }, { frac = "22%" }, { frac = "24.9%" }, { frac = "27.4%" }, { frac = "29.6%" }, { frac = "31.5%" }, { frac = "33.2%" }, { frac = "34.7%" }, { frac = "36%" } }, { frac = "45%" } },
		} },
	},
}
JEWELS.who = "Your spells"  -- the {who} of an amulet's line
-- End of the jewels.

-- A panel tinted in its own color: thin edge, the ground a dark shade of it.
local TINTED = { bgFile = FLAT, edgeFile = FLAT, edgeSize = 1, insets = { left = 1, right = 1, top = 1, bottom = 1 } }
-- The game's font templates, as the pages name them: size, color.
local TEMPLATES = {
	GameFontHighlight = { 12, 1, 1, 1 },
	GameFontNormal = { 12, 1, 0.82, 0 },
	GameFontNormalLarge = { 16, 1, 0.82, 0 },
	GameFontDisableSmall = { 10, 0.5, 0.5, 0.5 },
}

local try = {}                  -- the numbers being played with
local pages, tabs = {}, {}
local current

-- Friz whatever font the options choose, as the pages are laid out by its
-- lines; in a language the addon speaks, that language's face.
local function Text(parent, template, size)
	local look = TEMPLATES[template]
	local text = parent:CreateFontString(nil, "OVERLAY")
	text:SetFont(SurvivorUI_Translated() and SurvivorUI_FONT or "Fonts\\FRIZQT__.TTF", size or look[1])
	text:SetTextColor(look[2], look[3], look[4])
	text:SetShadowColor(0, 0, 0, 1)
	text:SetShadowOffset(1, -1)
	return text
end

-- A panel: the window's ground a little darker, a grey line round it.
local function Framed(frame)
	frame.noHoverOutline = true
	frame:SetBackdrop(TINTED)
	frame:SetBackdropColor(0.02, 0.02, 0.04, 0.6)
	frame:SetBackdropBorderColor(0.3, 0.3, 0.36, 1)
end

-- A gold line fading out at both ends.
local function Rule(parent)
	local rule = parent:CreateTexture(nil, "ARTWORK")
	rule:SetTexture(FLAT)
	rule:SetHeight(1)
	if rule.SetGradientAlpha then
		rule:SetGradientAlpha("HORIZONTAL", 1, 0.82, 0, 0.8, 1, 0.82, 0, 0.15)
	else
		rule:SetVertexColor(1, 0.82, 0, 0.5)
	end
	return rule
end

-- Common to Legendary, 0 to 1, and their weights, for a roll with the given m.
local function CardOdds(m)
	local weights = { 60, 25 * m, 10 * m * m, 4 * m * m * m, m * m * m * m }
	local total = 0
	for index = 1, 5 do
		total = total + weights[index]
	end
	local odds = {}
	for index = 1, 5 do
		odds[index] = weights[index] / total
	end
	return odds, weights
end

local function FlatButton(parent, label, width)
	local button = CreateFrame("Button", nil, parent)
	button:SetWidth(width)
	button:SetHeight(22)
	button.noHoverOutline = true
	button:SetBackdrop(TINTED)
	button:SetBackdropColor(0.11, 0.11, 0.14, 1)
	button:SetBackdropBorderColor(0.3, 0.3, 0.36, 1)
	button.text = Text(button, "GameFontHighlight", SMALL)
	button.text:SetPoint("CENTER", button, "CENTER", 0, 0)
	button.text:SetText(label)
	button:SetScript("OnEnter", function() this:SetBackdropBorderColor(1, 0.82, 0, 1) end)
	button:SetScript("OnLeave", function() this:SetBackdropBorderColor(0.3, 0.3, 0.36, 1) end)
	return button
end

-- A button that can be pressed, or greyed out.
local function Able(button, on)
	if on then
		button:Enable()
		button.text:SetTextColor(1, 1, 1)
	else
		button:Disable()
		button.text:SetTextColor(0.45, 0.45, 0.45)
	end
end

local window = CreateFrame("Frame", "SurvivorUIGuide", UIParent)
window:SetWidth(WIDTH)
window:SetHeight(HEIGHT)
window:SetPoint("CENTER", UIParent, "CENTER", 0, 30)
window:SetFrameStrata("DIALOG")
-- The size it has on SurvivorUI Classic.
window:SetScale(0.8)
-- The ground see-through, the game behind it: the run panel's color, more
-- solid than that panel for the words' sake.
window:SetBackdrop(TINTED)
window:SetBackdropColor(0.04, 0.04, 0.07, 0.7)
window:SetBackdropBorderColor(1, 0.82, 0, 0.6)
window:EnableMouse(true)
window:SetMovable(true)
if window.SetClampedToScreen then
	window:SetClampedToScreen(true)
end
window:RegisterForDrag("LeftButton")
window:SetScript("OnDragStart", function() this:StartMoving() end)
window:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)
window:Hide()
if UISpecialFrames then
	table.insert(UISpecialFrames, "SurvivorUIGuide")
end
local heading = Text(window, "GameFontNormalLarge")
heading:SetPoint("TOP", window, "TOP", 0, -10)
heading:SetText(SurvivorUI_T("Guide"))
window.heading = heading
local close = FlatButton(window, "x", 20)
close:SetPoint("TOPRIGHT", window, "TOPRIGHT", -6, -6)
close:SetScript("OnClick", function() window:Hide() end)

local function Level()
	return tonumber(AZS_RUN and AZS_RUN.lvl) or UnitLevel("player") or 1
end

-- The numbers to play with, from the hero.
local function FromHero()
	local s = AZS_STATS
	try.luck = s and tonumber(s.luck) or 0
	try.level = Level()
	try.damage = s and tonumber(s.dmg) or 1
	try.crit = s and tonumber(s.crit) or 0.05
	try.double = s and tonumber(s.cm) or 2
	try.haste = s and tonumber(s.doth) or 0
	try.longer = 0
	try.armor = s and tonumber(s.arm) or 0
	try.cap = try.armor > 0.6 and 0.7 or 0.6
	try.crowd = 0
	try.cooldowns = s and tonumber(s.cd) and 1 / tonumber(s.cd) - 1 or 0
	try.wait = try.wait or 8
	try.echo = s and tonumber(s.echo) or 0
	try.speed = s and tonumber(s.spd) and tonumber(s.spd) - 1 or 0
	try.pickup = s and tonumber(s.pick) and tonumber(s.pick) / PICKUP - 1 or 0
	try.pickup2 = 0
	try.area = s and tonumber(s.area) and tonumber(s.area) - 1 or 0
end

-- Our tooltips stand over the guide's words, and the game's tooltip art lets
-- them through at any color: a solid floor of our own under them while open.
local tipFloor

local function SolidTip()
	if not tipFloor then
		tipFloor = GameTooltip:CreateTexture(nil, "BACKGROUND")
		tipFloor:SetTexture(FLAT)
		tipFloor:SetVertexColor(0.03, 0.03, 0.05, 1)
		tipFloor:SetPoint("TOPLEFT", GameTooltip, "TOPLEFT", 4, -4)
		tipFloor:SetPoint("BOTTOMRIGHT", GameTooltip, "BOTTOMRIGHT", -4, 4)
	end
	tipFloor:Show()
end

local function CloseTip()
	if tipFloor then
		tipFloor:Hide()
	end
	GameTooltip:Hide()
end

-- An average hit from the three numbers, and the Crit and Crit Dmg it plays with.
local function Worth(damage, crit, double)
	if crit > 1 then
		double = double + crit - 1
		crit = 1
	end
	local average = 1 + crit * (double - 1)
	return damage * average, average, crit, double
end

------------------------------------------------------------------------------
-- What the pages are made of. The words go down the page, each a number of
-- lines tall, more when they take more (a language's longer words: the game
-- knows a wrapped text's height as soon as it is set).

local function Paint(text, color)
	text:SetTextColor(color[1], color[2], color[3])
end

-- Words fitted to their room (Fit.Size, Fit.TwoLines).
local Fit = {}

-- A text in another size, its face kept.
function Fit.Size(text, size)
	local face, _, flags = text:GetFont()
	text:SetFont(face, size, flags)
end

-- A name beside its icon (anchored on the icon's right) in two lines as even
-- as its words go, one over the other about the icon's middle; the wider
-- line's width. A single word stays as it is.
function Fit.TwoLines(text, icon)
	local words = text:GetText()
	local best, first, rest
	local at = 0
	while true do
		local space = string.find(words, " ", at + 1, true)
		if not space then
			break
		end
		text:SetText(string.sub(words, 1, space - 1))
		local wide = text:GetStringWidth()
		text:SetText(string.sub(words, space + 1))
		wide = math.max(wide, text:GetStringWidth())
		if not best or wide < best then
			best, first, rest = wide, string.sub(words, 1, space - 1), string.sub(words, space + 1)
		end
		at = space
	end
	text:SetText(words)
	if not first then
		return text:GetStringWidth()
	end
	text:SetText(first)
	text:ClearAllPoints()
	text:SetPoint("BOTTOMLEFT", icon, "RIGHT", 4, 0)
	local face, size, flags = text:GetFont()
	local more = Text(text:GetParent(), "GameFontHighlight", size)
	more:SetFont(face, size, flags)
	more:SetPoint("TOPLEFT", icon, "RIGHT", 4, 0)
	more:SetText(rest)
	return best
end

local function Words(parent, x, y, width, text, size, color)
	local words = Text(parent, "GameFontHighlight", size or TEXT)
	words:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
	words:SetWidth(width)
	words:SetJustifyH("LEFT")
	words:SetText(text or "")
	if color then
		Paint(words, color)
	end
	return words
end

local function Para(page, text, lines)
	local words = Words(page, 0, page.y, PAGE_WIDTH, text)
	local tall = words:GetHeight()
	if math.floor(tall / TEXT + 0.5) > lines then
		page.y = page.y - tall - 10
	else
		page.y = page.y - lines * LINE - 6
	end
end

local function Title(page, text)
	local title = Text(page, "GameFontNormalLarge")
	title:SetPoint("TOPLEFT", page, "TOPLEFT", 0, page.y)
	title:SetText(text)
	page.y = page.y - 26
	return title
end

local function Tip(page, text, lines)
	local words = Words(page, 0, page.y, PAGE_WIDTH, text, SMALL + 1)
	local tall = words:GetHeight()
	if math.floor(tall / (SMALL + 1) + 0.5) > (lines or 1) then
		page.y = page.y - tall - 5
	else
		page.y = page.y - (lines or 1) * 15 - 3
	end
end

local function Heading(page, text)
	local heading = Text(page, "GameFontNormal", TEXT + 1)
	heading:SetPoint("TOPLEFT", page, "TOPLEFT", 0, page.y)
	heading:SetText(text)
	page.y = page.y - 16
	local rule = Rule(page)
	rule:SetWidth(PAGE_WIDTH)
	rule:SetPoint("TOPLEFT", page, "TOPLEFT", 0, page.y)
	page.y = page.y - 8
end

-- A panel of the same make as the others, its title in the middle.
local function Box(page, title, color, x, y, width, height)
	local box = CreateFrame("Frame", nil, page)
	box:SetWidth(width)
	box:SetHeight(height)
	box:SetPoint("TOPLEFT", page, "TOPLEFT", x, y)
	Framed(box)
	box.title = Text(box, "GameFontNormal", TEXT)
	box.title:SetPoint("TOP", box, "TOP", 0, -8)
	box.title:SetText(title)
	if color then
		Paint(box.title, color)
	end
	return box
end

-- A tinted panel, with a band of its color across its top or foot.
local function Tint(box, color, strength)
	box:SetBackdropColor(color[1] * 0.16 * strength, color[2] * 0.16 * strength, color[3] * 0.16 * strength, 0.95)
	box:SetBackdropBorderColor(color[1], color[2], color[3], 0.35 + 0.6 * strength)
end

local function Tinted(parent, color, x, y, width, height)
	local box = CreateFrame("Frame", nil, parent)
	box.noHoverOutline = true
	box:SetWidth(width)
	box:SetHeight(height)
	box:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
	box:SetBackdrop(TINTED)
	Tint(box, color, 1)
	return box
end

local function Band(box, color, edge, height)
	local band = box:CreateTexture(nil, "BORDER")
	band:SetTexture(FLAT)
	band:SetVertexColor(color[1], color[2], color[3], 0.3)
	band:SetHeight(height)
	local inset = edge == "TOP" and -1 or 1
	band:SetPoint(edge.."LEFT", box, edge.."LEFT", 1, inset)
	band:SetPoint(edge.."RIGHT", box, edge.."RIGHT", -1, inset)
	return band
end

-- A slider to play with, flat as the clock's: label, its range, how a value
-- reads, what it sets.
local function Try(page, x, y, width, label, low, high, step, shown, set)
	local slider = CreateFrame("Slider", nil, page)
	slider.noHoverOutline = true
	slider:SetOrientation("HORIZONTAL")
	slider:SetWidth(width)
	slider:SetHeight(14)
	slider:SetPoint("TOPLEFT", page, "TOPLEFT", x, y)
	slider:SetMinMaxValues(low, high)
	slider:SetValueStep(step)
	slider:EnableMouseWheel(true)
	local track = slider:CreateTexture(nil, "BACKGROUND")
	track:SetTexture(FLAT)
	track:SetVertexColor(0.14, 0.14, 0.18, 1)
	track:SetHeight(4)
	track:SetPoint("LEFT", slider, "LEFT", 0, 0)
	track:SetPoint("RIGHT", slider, "RIGHT", 0, 0)
	local fill = slider:CreateTexture(nil, "BORDER")
	fill:SetTexture(FLAT)
	fill:SetVertexColor(1, 0.82, 0, 0.8)
	fill:SetHeight(4)
	fill:SetPoint("LEFT", slider, "LEFT", 0, 0)
	local thumb = slider:CreateTexture(nil, "OVERLAY")
	thumb:SetTexture(FLAT)
	thumb:SetWidth(8)
	thumb:SetHeight(14)
	slider:SetThumbTexture(thumb)
	local text = Text(slider, "GameFontHighlight", SMALL)
	text:SetPoint("BOTTOM", slider, "TOP", 0, 1)
	local least = Text(slider, "GameFontDisableSmall")
	least:SetPoint("TOPLEFT", slider, "BOTTOMLEFT", 0, 0)
	least:SetText(shown(low))
	local most = Text(slider, "GameFontDisableSmall")
	most:SetPoint("TOPRIGHT", slider, "BOTTOMRIGHT", 0, 0)
	most:SetText(shown(high))
	slider:SetScript("OnValueChanged", function()
		if not this.reading then
			set(math.floor(this:GetValue() / step + 0.5) * step)
			page.Draw()
		end
	end)
	slider:SetScript("OnMouseWheel", function()
		this:SetValue(this:GetValue() + arg1 * step)
	end)
	-- To a value of the hero's, which may sit between two steps or past the end.
	function slider.Read(value)
		local kept = math.max(low, math.min(high, value))
		slider.reading = true
		slider:SetValue(kept)
		text:SetText(SurvivorUI_TF("{1}: {2}", label, shown(value)))
		-- A texture of no width draws at its art's size, so at least a sliver.
		fill:SetWidth(math.max(0.01, (kept - low) / (high - low) * width))
		slider.reading = nil
	end
	return slider
end

local function MyHero(page, x, y)
	local again = FlatButton(page, SurvivorUI_T("My hero"), 84)
	again:SetPoint("TOPLEFT", page, "TOPLEFT", x, y)
	again:SetScript("OnClick", function()
		FromHero()
		page.Draw()
	end)
end

local function Signed(value)
	return string.format("%+.0f%%", value * 100)
end

local function Whole(value)
	return string.format("%.0f%%", value * 100)
end

------------------------------------------------------------------------------
-- Luck.

-- A hundred cards out of the shares, the largest remainders getting the rest.
local function Hundred(odds)
	local counts, rest, total = {}, {}, 0
	for index = 1, 5 do
		local share = odds[index] * 100
		counts[index] = math.floor(share)
		rest[index] = share - counts[index]
		total = total + counts[index]
	end
	while total < 100 do
		local best = 1
		for index = 2, 5 do
			if rest[index] > rest[best] then
				best = index
			end
		end
		counts[best] = counts[best] + 1
		rest[best] = -1
		total = total + 1
	end
	return counts
end

-- A card's legendary at a Luck, level 30 and up, as the page writes a share.
function LADDER.Legendary(luck)
	local odds = CardOdds(1.3 + luck)
	return string.format("%.0f%%", odds[5] * 100)
end

-- The page's "?": the rule in words, the weights left out (2026-11-09: "m x m x m
-- x m" read as nothing). Luck grows a rarity's weight by m once for Uncommon, up
-- to four times for Legendary, Common's never: the rarer, the faster.
function LADDER.Tip()
	GameTooltip:SetOwner(this, "ANCHOR_NONE")
	GameTooltip:ClearAllPoints()
	GameTooltip:SetPoint("TOPLEFT", this, "BOTTOMLEFT", 0, -4)
	GameTooltip:SetText(SurvivorUI_T("How Luck works"))
	GameTooltip:AddLine(SurvivorUI_T("Each of the 3 cards rolls its color on its own."), 1, 1, 1, 1)
	GameTooltip:AddLine(SurvivorUI_T("Luck never removes Commons: it adds more of every other color, and the rarer the color, the more it adds."),
		1, 1, 1, 1)
	GameTooltip:AddLine(SurvivorUI_TF("That is why Legendary grows fastest: {1} a card at +0% Luck, {2} at +100%, {3} at +300%.",
		LADDER.Legendary(0), LADDER.Legendary(1), LADDER.Legendary(3)), 1, 1, 1, 1)
	GameTooltip:Show()
	SolidTip()
end

-- The five colors in a line over the bars, or over the whole ladder when they
-- are wider than the bars' side (a language's longer words).
function LADDER.Legend(ladder)
	local names, wide = {}, -14
	for index = 1, 5 do
		local rarity = RARITIES[index]
		local name = Text(ladder, "GameFontHighlight", TEXT)
		name:SetText(SurvivorUI_T(rarity[1]))
		Paint(name, rarity[2])
		names[index] = name
		wide = wide + 15 + name:GetStringWidth() + 14
	end
	local x = math.floor((PAGE_WIDTH - wide) / 2)
	if wide <= LADDER.split - 12 then
		x = math.floor((LADDER.split - wide) / 2)
	end
	for index = 1, 5 do
		local color = RARITIES[index][2]
		local marble = ladder:CreateTexture(nil, "ARTWORK")
		marble:SetTexture(MARBLE)
		marble:SetVertexColor(color[1], color[2], color[3])
		marble:SetWidth(12)
		marble:SetHeight(12)
		marble:SetPoint("TOPLEFT", ladder, "TOPLEFT", x, -11)
		names[index]:SetPoint("LEFT", marble, "RIGHT", 4, 0)
		x = x + 15 + names[index]:GetStringWidth() + 14
	end
end

-- A row of the ladder: its Luck, a bar of 100 cards in the five colors, a
-- legendary among 3 cards. The hero's row is framed in gold.
function LADDER.Row(ladder, mine)
	local row
	if mine then
		row = Tinted(ladder, YELLOW, 4, 0, PAGE_WIDTH - 8, LADDER.row - 2)
	else
		row = CreateFrame("Frame", nil, ladder)
		row:SetWidth(PAGE_WIDTH - 8)
		row:SetHeight(LADDER.row - 2)
	end
	row.luck = Text(row, mine and "GameFontNormal" or "GameFontHighlight", TEXT)
	row.luck:SetPoint("RIGHT", row, "LEFT", 6 + LADDER.label, 0)
	row.parts = {}
	for index = 1, 5 do
		local color = RARITIES[index][2]
		local part = row:CreateTexture(nil, "ARTWORK")
		part:SetTexture(FLAT)
		part:SetVertexColor(color[1], color[2], color[3])
		part:SetHeight(22)
		-- The count dark on the light colors, white on Rare's and Epic's.
		part.count = Text(row, "GameFontHighlight", TEXT)
		part.count:SetPoint("CENTER", part, "CENTER", 0, 0)
		part.count:SetShadowOffset(0, 0)
		if index ~= 3 and index ~= 4 then
			part.count:SetTextColor(0.08, 0.08, 0.08)
		end
		row.parts[index] = part
	end
	row.pick = Text(row, "GameFontHighlight", TEXT + 3)
	row.pick:SetPoint("CENTER", row, "LEFT", 16 + LADDER.label + LADDER.bar + 20 + LADDER.pick / 2, 0)
	Paint(row.pick, RARITIES[5][2])
	return row
end

-- A row's numbers for a Luck, at level 30 and up (m = 1.3 + Luck). A count
-- shows on its color from 5 cards.
function LADDER.Fill(row, luck, label)
	local odds = CardOdds(1.3 + luck)
	local counts = Hundred(odds)
	row.luck:SetText(label)
	local done, x = 0, 16 + LADDER.label
	for index = 1, 5 do
		local part = row.parts[index]
		local left = math.floor(done * LADDER.bar / 100 + 0.5)
		done = done + counts[index]
		local width = math.floor(done * LADDER.bar / 100 + 0.5) - left
		if width > 0 then
			part:ClearAllPoints()
			part:SetPoint("LEFT", row, "LEFT", x + left, 0)
			part:SetWidth(width)
			part:Show()
		else
			part:Hide()
		end
		part.count:SetText(counts[index] >= 5 and tostring(counts[index]) or "")
	end
	local none = 1 - odds[5]
	row.pick:SetText(string.format("%.0f%%", (1 - none * none * none) * 100))
end

local function BuildLuck(page)
	local title = Title(page, SurvivorUI_T("Luck: better cards"))
	local why = Tinted(page, YELLOW, 0, 0, 18, 18)
	why:ClearAllPoints()
	why:SetPoint("LEFT", title, "RIGHT", 8, 0)
	why:EnableMouse(true)
	why:SetScript("OnEnter", LADDER.Tip)
	why:SetScript("OnLeave", CloseTip)
	local mark = Text(why, "GameFontNormal", TEXT)
	mark:SetPoint("CENTER", why, "CENTER", 0, 0)
	mark:SetText("?")
	Para(page, SurvivorUI_T("Each bar is 100 cards, at level 30 and up. More Luck, more color."), 1)
	local top = page.y
	local ladder = Box(page, "", nil, 0, top, PAGE_WIDTH, 1)
	LADDER.Legend(ladder)
	local column = Words(ladder, LADDER.split + 6, -30, PAGE_WIDTH - LADDER.split - 12,
		SurvivorUI_T("Chances of\nat least 1\nin 3 choices"), SMALL - 1, GREY)
	column:SetJustifyH("CENTER")
	LADDER.top = math.max(62, 30 + math.ceil(column:GetHeight()) + 8)
	local height = LADDER.top + 7 * LADDER.row + 6
	ladder:SetHeight(height)
	column = Words(ladder, 10, -(LADDER.top - 18), LADDER.label, SurvivorUI_T("Luck"), SMALL, GREY)
	column:SetJustifyH("RIGHT")
	-- The line between the bars and their chances, under the colors.
	local split = ladder:CreateTexture(nil, "ARTWORK")
	split:SetTexture(FLAT)
	split:SetVertexColor(GREY[1], GREY[2], GREY[3], 0.8)
	split:SetWidth(2)
	split:SetPoint("TOP", ladder, "TOPLEFT", LADDER.split, -28)
	split:SetPoint("BOTTOM", ladder, "BOTTOMLEFT", LADDER.split, 6)
	local rows = {}
	for index = 1, 6 do
		local step = LADDER.steps[index]
		rows[index] = LADDER.Row(ladder)
		LADDER.Fill(rows[index], step, Signed(step))
	end
	local mine = LADDER.Row(ladder, true)
	page.y = top - height - 26
	local luck = Try(page, 8, page.y, 360, SurvivorUI_T("Your Luck"), 0, 3, 0.05, Signed, function(value) try.luck = value end)
	MyHero(page, 400, page.y + 4)
	page.y = page.y - 34
	Tip(page, SurvivorUI_T("|cffffd100Level|r counts as 1% Luck a level, up to 30%. |cffffd100Luck has no cap.|r"))
	Tip(page, SurvivorUI_T("|cffffd100Amulets|r roll with +50% Luck. |cffffd100A guardian's hoard|r adds +25%."))

	-- The hero's row in its place on the ladder, over a step of the same Luck.
	local function Place(row, slot)
		row:ClearAllPoints()
		row:SetPoint("TOPLEFT", ladder, "TOPLEFT", 4, -LADDER.top - slot * LADDER.row)
		row:Show()
	end

	function page.Draw()
		luck.Read(try.luck)
		LADDER.Fill(mine, try.luck, SurvivorUI_TF("You {1}", Signed(try.luck)))
		local slot, placed = 0, false
		for index = 1, 6 do
			local step = LADDER.steps[index]
			if not placed and try.luck <= step + 0.001 then
				Place(mine, slot)
				slot, placed = slot + 1, true
			end
			if math.abs(try.luck - step) < 0.001 then
				rows[index]:Hide()
			else
				Place(rows[index], slot)
				slot = slot + 1
			end
		end
		if not placed then
			Place(mine, slot)
		end
	end
end

------------------------------------------------------------------------------
-- Damage.

local function BuffEnter()
	local buff = this.buff
	GameTooltip:SetOwner(this, "ANCHOR_NONE")
	GameTooltip:ClearAllPoints()
	GameTooltip:SetPoint("BOTTOMLEFT", this, "TOPLEFT", 0, 4)
	GameTooltip:SetText(SurvivorUI_Native(buff[1]))
	GameTooltip:AddLine(string.format(SurvivorUI_T("Increases all your damage by %d%% for %d sec."), buff[4], buff[5]), 1, 1, 1, 1)
	GameTooltip:AddLine(string.format(SurvivorUI_T("Cooldown: %d sec."), buff[6]), 1, 1, 1)
	GameTooltip:AddLine(SurvivorUI_T(buff[3]), 0.7, 0.7, 0.7)
	GameTooltip:AddLine(SurvivorUI_T("Numbers at rank 1."), 0.7, 0.7, 0.7)
	GameTooltip:Show()
	SolidTip()
end

-- One box of a hit: its band with its title, its icon, what goes in it, and
-- at its foot what it multiplies by.
local function HitBox(page, step, x, top, width)
	local color = step[2]
	local box = Tinted(page, color, x, top, width, BOX_HEIGHT)
	Band(box, color, "TOP", 22)
	local title = Text(box, "GameFontNormal", TEXT)
	title:SetPoint("CENTER", box, "TOP", 0, -15)
	title:SetText(SurvivorUI_T(step[1]))
	Paint(title, color)
	local icon = box:CreateTexture(nil, "ARTWORK")
	icon:SetTexture("Interface\\Icons\\"..step[3])
	icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
	icon:SetWidth(30)
	icon:SetHeight(30)
	icon:SetPoint("TOP", box, "TOP", 0, -30)
	box.rows = {}
	for each = 1, table.getn(step[4]) do
		local row = step[4][each]
		local y = -66 - (each - 1) * ROW_STEP
		local dot = box:CreateTexture(nil, "ARTWORK")
		dot:SetTexture(MARBLE)
		dot:SetVertexColor(row[2][1], row[2][2], row[2][3])
		dot:SetWidth(8)
		dot:SetHeight(8)
		dot:SetPoint("TOPLEFT", box, "TOPLEFT", 9, y - 2)
		box.rows[each] = Words(box, 20, y, width - 22, SurvivorUI_T(row[1]), SMALL)
	end
	Band(box, color, "BOTTOM", 26)
	box.foot = Text(box, "GameFontHighlight", 16)
	box.foot:SetPoint("CENTER", box, "BOTTOM", 0, 17)
	Paint(box.foot, color)
	return box
end

local function BuildDamage(page)
	Title(page, SurvivorUI_T("Damage: four boxes"))
	Para(page, SurvivorUI_T("Every hit goes through four boxes, left to right. |cffffd100Inside a box, numbers are added. From one box to the next, they multiply.|r"), 2)
	local count = table.getn(STEPS)
	local width = math.floor((PAGE_WIDTH - (count - 1) * BOX_GAP) / count)
	local top = page.y
	local boxes = {}
	for index = 1, count do
		boxes[index] = HitBox(page, STEPS[index], (index - 1) * (width + BOX_GAP), top, width)
		if index < count then
			-- A gold marble between two boxes, the sign on it.
			local ball = page:CreateTexture(nil, "ARTWORK")
			ball:SetTexture(MARBLE)
			ball:SetVertexColor(1, 0.8, 0.2)
			ball:SetWidth(BOX_GAP)
			ball:SetHeight(BOX_GAP)
			ball:SetPoint("CENTER", boxes[index], "RIGHT", BOX_GAP / 2, 0)
			local times = Text(page, "GameFontNormal", 13)
			times:SetPoint("CENTER", ball, "CENTER", 0, 1)
			times:SetText("x")
			times:SetTextColor(0.15, 0.08, 0)
			times:SetShadowOffset(0, 0)
		end
	end
	page.y = top - BOX_HEIGHT - 6
	local strip = Tinted(page, YELLOW, 0, page.y, PAGE_WIDTH, 28)
	page.sum = Text(strip, "GameFontHighlight", TEXT)
	page.sum:SetPoint("CENTER", strip, "CENTER", 0, 0)
	page.y = page.y - 28 - 10
	Heading(page, SurvivorUI_T("Buffs go in the |cff59f273green box|r"))
	local items = {}
	for index = 1, table.getn(BUFFS) do
		local buff = BUFFS[index]
		local icon = page:CreateTexture(nil, "ARTWORK")
		icon:SetTexture(buff[2])
		icon:SetWidth(24)
		icon:SetHeight(24)
		local name = Text(page, "GameFontHighlight", SMALL)
		name:SetPoint("LEFT", icon, "RIGHT", 4, 0)
		name:SetText(SurvivorUI_Native(buff[1]))
		local spot = CreateFrame("Frame", nil, page)
		spot.noHoverOutline = true
		spot:SetWidth(24 + 4 + name:GetStringWidth())
		spot:SetHeight(24)
		spot:SetPoint("TOPLEFT", icon, "TOPLEFT", 0, 0)
		spot:EnableMouse(true)
		spot.buff = buff
		spot:SetScript("OnEnter", BuffEnter)
		spot:SetScript("OnLeave", CloseTip)
		items[index] = { icon = icon, name = name, spot = spot, wide = name:GetStringWidth() }
	end
	-- A row too long for the page (a language's longer names): the longest
	-- names in two lines, one by one, until it fits.
	local function Row()
		local total = (table.getn(items) - 1) * 12
		for index = 1, table.getn(items) do
			total = total + 24 + 4 + items[index].wide
		end
		return total
	end
	while Row() > PAGE_WIDTH do
		local longest
		for index = 1, table.getn(items) do
			local item = items[index]
			if not item.split and (not longest or item.wide > longest.wide) then
				longest = item
			end
		end
		if not longest then
			break
		end
		longest.split = true
		longest.wide = Fit.TwoLines(longest.name, longest.icon)
	end
	local x = 0
	for index = 1, table.getn(items) do
		local item = items[index]
		item.icon:SetPoint("TOPLEFT", page, "TOPLEFT", x, page.y)
		item.spot:SetWidth(24 + 4 + item.wide)
		x = x + 24 + 4 + item.wide + 12
	end
	page.y = page.y - 32
	Para(page, SurvivorUI_T("These add to Damage while they last, just like your level or your gear. They do not multiply it. So +95% and a +40% buff make +135%: that is 2.35 against 1.95, about 20% harder, not 40%. The fuller a box is, the less the same bonus gives."), 3)
	Tip(page, SurvivorUI_T("|cff59f273Buff Power|r makes a buff stronger before it goes in: with +25%, a +40% buff gives +50%."))
	Tip(page, SurvivorUI_T("|cff59f273The same buff twice|r counts once: the stronger one stays."))
	Tip(page, SurvivorUI_T("|cff73bfffTalents that name a spell,|r like \"Fire spells deal 8% more\", grow the first box, so they multiply with the rest."), 2)
	Tip(page, SurvivorUI_T("|cffff7366Enemy bonuses|r count only on the right enemy, and they add up with each other."))

	function page.Draw()
		local all, average, chance, real = Worth(try.damage, try.crit, try.double)
		boxes[1].foot:SetText("100")
		boxes[2].foot:SetText(string.format("x %.2f", try.damage))
		boxes[3].foot:SetText(string.format("x %.2f", average))
		boxes[3].rows[1]:SetText(SurvivorUI_T("How often: ")..Whole(chance))
		boxes[3].rows[2]:SetText(SurvivorUI_T("How hard: ")..Whole(real))
		boxes[4].foot:SetText(SurvivorUI_T("x 1 or more"))
		page.sum:SetText(string.format(SurvivorUI_T("Your hero: 100 x %.2f x %.2f = |cffffd100%.0f|r on average, more on the right enemy."),
			try.damage, average, 100 * all))
	end
end

------------------------------------------------------------------------------
-- Crit.

-- One of the three picks, a card: its title, how much harder, and its box.
local function PickCard(page, color, x, y, width)
	local card = Tinted(page, color, x, y, width, CARD_HEIGHT)
	card.color = color
	card.band = Band(card, color, "TOP", 22)
	card.head = Text(card, "GameFontNormal", TEXT)
	card.head:SetPoint("CENTER", card, "TOP", 0, -15)
	card.big = Text(card, "GameFontHighlight", 22)
	card.big:SetPoint("CENTER", card, "TOP", 0, -42)
	card.what = Text(card, "GameFontHighlight", SMALL)
	card.what:SetPoint("CENTER", card, "TOP", 0, -61)
	card.what:SetText(SurvivorUI_T("harder hits"))
	card.box = Text(card, "GameFontHighlight", SMALL)
	card.box:SetPoint("CENTER", card, "TOP", 0, -77)
	return card
end

local function DrawCard(card, name, gain, won, label, before, after)
	local color = won and GREEN or card.color
	Tint(card, color, won and 1.4 or 0.5)
	card.band:SetVertexColor(color[1], color[2], color[3], won and 0.45 or 0.15)
	card.head:SetText((won and SurvivorUI_T("Best pick: ") or "")..name)
	Paint(card.head, color)
	card.big:SetText(string.format("+%.1f%%", gain * 100))
	Paint(card.big, won and GREEN or GREY)
	card.box:SetText(string.format(SurvivorUI_T("%s box: %.0f to %.0f"), label, before * 100, after * 100))
end

local function BuildCrit(page)
	Title(page, SurvivorUI_T("Crit: past 100%"))
	Para(page, SurvivorUI_T("Crit is how often a hit is critical. Crit Dmg is how hard it lands: at 200%, a critical hit counts double."), 2)
	Para(page, SurvivorUI_T("A hit can only be critical once, so Crit stops at 100%. Nothing is lost! |cffffd100Every point past 100% jumps into Crit Dmg, one for one.|r"), 2)
	page.y = page.y - 16
	local hit = Try(page, 8, page.y, 180, SurvivorUI_T("Damage"), 0, 5, 0.05, Signed, function(value) try.damage = 1 + value end)
	local crit = Try(page, 214, page.y, 180, SurvivorUI_T("Crit"), 0, 2, 0.01, Whole, function(value) try.crit = value end)
	local double = Try(page, 420, page.y, 180, SurvivorUI_T("Crit Dmg"), 2, 5, 0.05, Whole, function(value) try.double = value end)
	page.y = page.y - 34
	MyHero(page, PAGE_WIDTH - 84, page.y - 2)
	page.plays = Words(page, 0, page.y, PAGE_WIDTH - 92, "")
	page.y = page.y - 2 * LINE - 8
	Heading(page, SurvivorUI_T("You can take one +10. Which one makes you hit harder?"))
	local width = math.floor((PAGE_WIDTH - 2 * CARD_GAP) / 3)
	local cards = {}
	local colors = { GREEN, PEACH, PEACH }
	for index = 1, 3 do
		cards[index] = PickCard(page, colors[index], (index - 1) * (width + CARD_GAP), page.y, width)
	end
	page.y = page.y - CARD_HEIGHT - 10
	Para(page, SurvivorUI_T("|cffffd100Why not always the same one?|r Multiplying works in any order: 2 x 3 is 3 x 2, so no box gets a bonus for coming last. What counts is how full each box is. +10 on 100 is a lot, +10 on 300 is a little."), 3)
	Para(page, SurvivorUI_T("|cff66ff66So feed the emptiest box!|r Past 100%, Crit and Crit Dmg are the same pick, so look at your Damage box against your Crit Dmg. Under 100%, Crit always beats Crit Dmg."), 2)

	function page.Draw()
		hit.Read(try.damage - 1)
		crit.Read(try.crit)
		double.Read(try.double)
		local base, average, chance, real = Worth(try.damage, try.crit, try.double)
		if try.crit > 1 then
			page.plays:SetText(string.format(SurvivorUI_T("%s points jumped: it plays as Crit 100%% and Crit Dmg %s. An average hit is x %.2f."),
				string.format("%.0f", (try.crit - 1) * 100), Whole(real), average))
		else
			page.plays:SetText(string.format(SurvivorUI_T("%s of your hits are critical, for %s. An average hit is x %.2f."), Whole(chance), Whole(real), average))
		end
		local more, withCrit = Worth(try.damage, try.crit + 0.1, try.double)
		local deeper, withDouble = Worth(try.damage, try.crit, try.double + 0.1)
		local gains = { (try.damage + 0.1) / try.damage - 1, more / base - 1, deeper / base - 1 }
		local best = math.max(gains[1], math.max(gains[2], gains[3]))
		DrawCard(cards[1], SurvivorUI_T("+10 Damage"), gains[1], gains[1] >= best - 0.00001, SurvivorUI_T("Damage"), try.damage, try.damage + 0.1)
		DrawCard(cards[2], SurvivorUI_T("+10 Crit"), gains[2], gains[2] >= best - 0.00001, SurvivorUI_T("Crit"), average, withCrit)
		DrawCard(cards[3], SurvivorUI_T("+10 Crit Dmg"), gains[3], gains[3] >= best - 0.00001, SurvivorUI_T("Crit"), average, withDouble)
	end
end

------------------------------------------------------------------------------
-- DoTs.

local function Round(value)
	return math.floor(value + 0.5)
end

-- How many copies of a DoT one enemy carries at a level.
local function Copies(level)
	return 1 + math.min(math.floor(level / 15), MOST_COPIES - 1)
end

-- One thing to know, a tinted panel with its title on a band.
local function Fact(page, color, x, y, width, title, words)
	local box = Tinted(page, color, x, y, width, FACT_HEIGHT)
	Band(box, color, "TOP", 20)
	local head = Text(box, "GameFontNormal", TEXT)
	head:SetPoint("CENTER", box, "TOP", 0, -14)
	head:SetText(title)
	Paint(head, color)
	box.need = 28 + Words(box, 9, -28, width - 18, words, SMALL + 1):GetHeight() + 6
	return box
end

-- What must not be missed: a band in its color whose light comes and goes,
-- between two of the guide's own marks.
local function Warning(page, color, big, small)
	local box = Tinted(page, color, 0, page.y, PAGE_WIDTH, WARNING_HEIGHT)
	local band = Band(box, color, "TOP", WARNING_HEIGHT - 8)
	local head = Text(box, "GameFontNormal", 17)
	head:SetPoint("CENTER", box, "TOP", 0, -18)
	head:SetText(big)
	head:SetTextColor(1, 0.88, 0.25)
	local line = Text(box, "GameFontHighlight", TEXT)
	line:SetPoint("CENTER", box, "TOP", 0, -37)
	line:SetText(small)
	for index = 1, 2 do
		local mark = box:CreateTexture(nil, "ARTWORK")
		mark:SetTexture(NEW_MARK)
		mark:SetWidth(34)
		mark:SetHeight(34)
		mark:SetPoint("CENTER", box, index == 1 and "LEFT" or "RIGHT", index == 1 and 25 or -25, 0)
	end
	box:SetScript("OnUpdate", function()
		band:SetVertexColor(color[1], color[2], color[3], 0.34 + 0.16 * math.sin(GetTime() * 2.5))
	end)
	page.y = page.y - WARNING_HEIGHT - 8
end

local function BuildDots(page)
	Title(page, SurvivorUI_T("DoTs: damage that keeps biting"))
	Para(page, SurvivorUI_T("A DoT doesn't hit once. It sticks to the enemy and bites again and again. Each bite is a |cffffd100tick|r, about one a second."), 2)
	Warning(page, WARNING, SurvivorUI_T("CRIT AND CRIT DMG DO NOTHING FOR DOTS"), SurvivorUI_T("Building a DoT run? Don't pick them and don't rank them up."))
	local width = math.floor((PAGE_WIDTH - CARD_GAP) / 2)
	-- Two facts side by side, as tall as the longer one's words need.
	local function Row(one, two)
		local height = math.max(FACT_HEIGHT, math.max(one.need, two.need))
		one:SetHeight(height)
		two:SetHeight(height)
		return height
	end
	local top = page.y
	top = top - Row(Fact(page, GREEN, 0, top, width, SurvivorUI_T("Set when it lands"),
		SurvivorUI_T("Spell x Damage is counted once, as the DoT lands. A buff that ends later still counts. One that starts later doesn't.")),
		Fact(page, PEACH, width + CARD_GAP, top, width, SurvivorUI_T("Not plain DoTs"),
		SurvivorUI_T("Bleeds and burns born from a crit take a share of that crit. Ground spells like Consecration aren't DoTs: they can crit."))) - 6
	page.y = top - Row(Fact(page, RED, 0, top, width, SurvivorUI_T("The enemy box, every tick"),
		SurvivorUI_T("Each tick goes through the enemy box as it lands: elite or boss, under 30% health, more damage to afflicted enemies.")),
		Fact(page, PURPLE, width + CARD_GAP, top, width, SurvivorUI_T("Copies"),
		SurvivorUI_T("One enemy carries 1 copy of each DoT, 2 from level 15, 3 from 30, 4 from 45. A new one replaces the copy with the fewest ticks left."))) - 10
	Heading(page, SurvivorUI_T("Each marble is a tick, each row a copy on one enemy"))
	page.y = page.y - 14
	local level = Try(page, 8, page.y, 180, SurvivorUI_T("Level"), 1, 60, 1, function(value) return tostring(value) end,
		function(value) try.level = value end)
	local haste = Try(page, 214, page.y, 180, SurvivorUI_T("DoT Haste"), 0, 1, 0.05, Signed, function(value) try.haste = value end)
	local longer = Try(page, 420, page.y, 180, SurvivorUI_T("Lasts longer"), 0, 1, 0.05, Signed, function(value) try.longer = value end)
	page.y = page.y - 34
	local marbles = {}
	for copy = 1, MOST_COPIES do
		local color = COPY_COLORS[copy]
		marbles[copy] = {}
		for tick = 1, MOST_TICKS do
			local marble = page:CreateTexture(nil, "ARTWORK")
			marble:SetTexture(MARBLE)
			marble:SetVertexColor(color[1], color[2], color[3])
			marble:SetWidth(TICK - 1)
			marble:SetHeight(TICK - 1)
			marble:SetPoint("TOPLEFT", page, "TOPLEFT", (tick - 1) * TICK, page.y - (copy - 1) * TICK)
			marbles[copy][tick] = marble
		end
	end
	local right = MOST_TICKS * TICK + 12
	page.one = Words(page, right, page.y - 2, PAGE_WIDTH - right - 92, "")
	page.all = Words(page, right, page.y - 2 - LINE, PAGE_WIDTH - right - 92, "")
	MyHero(page, PAGE_WIDTH - 84, page.y + 2)
	page.y = page.y - MOST_COPIES * TICK - 8
	Tip(page, SurvivorUI_T("|cff4de6d9DoT Haste and lasting longer|r add ticks of the same size, so each copy deals more in all."))

	function page.Draw()
		level.Read(try.level)
		haste.Read(try.haste)
		longer.Read(try.longer)
		local copies = Copies(try.level)
		local ticks = Round(Round(SAMPLE_TICKS * (1 + try.longer)) * (1 + try.haste))
		local total = 100 * try.damage * (1 + try.longer) * (1 + try.haste)
		for copy = 1, MOST_COPIES do
			for tick = 1, MOST_TICKS do
				if copy <= copies and tick <= ticks then
					marbles[copy][tick]:Show()
				else
					marbles[copy][tick]:Hide()
				end
			end
		end
		page.one:SetText(string.format(SurvivorUI_T("%d ticks of %.0f = |cffffd100%.0f|r"), ticks, total / ticks, total))
		page.all:SetText(string.format("%d %s: "..GOLD.."%.0f|r", copies, SurvivorUI_T(copies > 1 and "copies" or "copy"), total * copies))
	end
end

------------------------------------------------------------------------------
-- Haste and Echo.

-- To a tenth, a whole number without its .0.
local function Count(value)
	if math.abs(value - math.floor(value + 0.5)) < 0.05 then
		return string.format("%d", math.floor(value + 0.5))
	end
	return string.format("%.1f", value)
end

local function Seconds(value)
	if value < 1 then
		return string.format(SurvivorUI_T("%.2f sec"), value)
	end
	return string.format(SurvivorUI_T("%.1f sec"), value)
end

-- Each strike past the first in one cast, by its chance. Under 100% Echo it is
-- one roll, rolled again while it lands as many more times as `again`; from
-- 100%, all of those land, one more for each 100% past it, and the rest is
-- one more roll.
local function Echoes(echo, again)
	local chances = {}
	if echo >= 1 then
		local whole = math.floor(echo - 1 + 0.0001)
		local sure = again + 1 + whole
		for index = 1, sure do
			chances[index] = 1
		end
		local rest = echo - 1 - whole
		if rest > 0.0001 then
			chances[sure + 1] = rest
		end
	elseif echo > 0 then
		local chance = 1
		for index = 1, again + 1 do
			chance = chance * echo
			chances[index] = chance
		end
	end
	return chances
end

-- A row's name, then its marbles, hidden until drawn.
local function MarbleRow(page, y, name, count, size, step, color)
	Words(page, 0, y - math.floor((size - 12) / 2), ROW_LABEL - 6, name, SMALL + 1)
	local row = {}
	for index = 1, count do
		local marble = page:CreateTexture(nil, "ARTWORK")
		marble:SetTexture(MARBLE)
		marble:SetVertexColor(color[1], color[2], color[3])
		marble:SetWidth(size - 1)
		marble:SetHeight(size - 1)
		marble:SetPoint("TOPLEFT", page, "TOPLEFT", ROW_LABEL + (index - 1) * step, y)
		marble:Hide()
		row[index] = marble
	end
	row.more = Text(page, "GameFontHighlight", SMALL)
	row.more:SetPoint("LEFT", row[count], "RIGHT", 4, 0)
	return row
end

-- A minute's casts, a marble each.
local function DrawCasts(row, many)
	local whole = math.floor(many + 0.0001)
	for index = 1, CASTS do
		if index <= whole then
			row[index]:Show()
		else
			row[index]:Hide()
		end
	end
	row.more:SetText(whole > CASTS and "+"..(whole - CASTS) or "")
end

-- One cast's strikes, each marble as bright as the strike is likely, with its
-- chance on it.
local function StrikeRow(page, y, name)
	local row = MarbleRow(page, y, name, STRIKES, STRIKE, STRIKE_STEP, YELLOW)
	for index = 1, STRIKES do
		local chance = Text(page, "GameFontHighlight", 8)
		chance:SetPoint("CENTER", row[index], "CENTER", 0, 0)
		chance:SetTextColor(0.15, 0.08, 0)
		chance:SetShadowOffset(0, 0)
		row[index].chance = chance
	end
	return row
end

local function DrawStrikes(row, chances)
	local total = 1
	for index = 1, table.getn(chances) do
		total = total + chances[index]
	end
	for index = 1, STRIKES do
		local marble = row[index]
		local chance = index == 1 and 1 or chances[index - 1]
		if chance then
			marble:SetAlpha(0.3 + 0.7 * chance)
			marble:Show()
		else
			marble:Hide()
		end
		if chance and chance < 1 then
			marble.chance:SetText(string.format("%.0f%%", chance * 100))
		else
			marble.chance:SetText("")
		end
	end
	row.more:SetText(string.format(SurvivorUI_T("= %.2f strikes"), total))
	return total
end

local function BuildHaste(page)
	Title(page, SurvivorUI_T("Haste and Echo: how often"))
	Para(page, SurvivorUI_T("Haste brings your spells back sooner. Echo makes a spell strike again, right away. Both give you more hits, and |cffffd100neither has a cap.|r"), 2)
	Warning(page, TEAL, SurvivorUI_T("HASTE 50% IS TWICE AS OFTEN"), SurvivorUI_T("The game shows how much sooner. No spell comes back faster than 0.25 sec."))
	Heading(page, SurvivorUI_T("Haste: sooner"))
	page.y = page.y - 14
	local bonus = Try(page, 8, page.y, 180, SurvivorUI_T("Cooldown bonuses"), 0, 3, 0.05, Signed, function(value) try.cooldowns = value end)
	local wait = Try(page, 214, page.y, 180, SurvivorUI_T("Its cooldown"), 0.5, 15, 0.5, Seconds, function(value) try.wait = value end)
	MyHero(page, PAGE_WIDTH - 84, page.y + 4)
	page.y = page.y - 34
	page.shown = Words(page, 0, page.y, PAGE_WIDTH, "")
	-- This spell's words in two lines' room, sitting on its marbles: one line
	-- when they fit, else a second one above it.
	page.spell = Words(page, 0, page.y - LINE, PAGE_WIDTH, "")
	page.spell:ClearAllPoints()
	page.spell:SetPoint("BOTTOMLEFT", page, "TOPLEFT", 0, page.y - 3 * LINE + 3)
	page.y = page.y - 3 * LINE - 6
	local slow = MarbleRow(page, page.y, SurvivorUI_T("No Haste"), CASTS, CAST_MARBLE, CAST_MARBLE, GREY)
	local fast = MarbleRow(page, page.y - CAST_MARBLE - 2, SurvivorUI_T("Your Haste"), CASTS, CAST_MARBLE, CAST_MARBLE, TEAL)
	page.y = page.y - 2 * CAST_MARBLE - 12
	Heading(page, SurvivorUI_T("Echo: again, right away"))
	page.y = page.y - 14
	local echo = Try(page, 8, page.y, 180, SurvivorUI_T("Echo"), 0, 3, 0.05, Whole, function(value) try.echo = value end)
	page.y = page.y - 32
	local plain = StrikeRow(page, page.y, SurvivorUI_T("Your spells"))
	local cascade = StrikeRow(page, page.y - STRIKE_STEP, SurvivorUI_T("Mage capstone"))
	page.y = page.y - 2 * STRIKE_STEP - 4
	page.together = Words(page, 0, page.y, PAGE_WIDTH, "")
	page.y = page.y - LINE - 6
	Tip(page, SurvivorUI_T("|cffffd100Each strike is a whole spell:|r it aims again and rolls its own Crit. A DoT lands again, a ground spell opens one more circle."), 2)
	Tip(page, SurvivorUI_T("|cff4de6d9Every \"-10% cooldowns\"|r goes into one number first. Two -50% don't make 0: they make half."))
	Tip(page, SurvivorUI_T("|cff4de6d9Demons|r echo only through Master Demonologist."))

	function page.Draw()
		bonus.Read(try.cooldowns)
		wait.Read(try.wait)
		echo.Read(try.echo)
		local divide = 1 + try.cooldowns
		local real = math.max(try.wait / divide, FLOOR)
		page.shown:SetText(string.format(SurvivorUI_T("Cooldown bonuses %s: every wait is divided by %.2f. The game shows it as Haste |cffffd100%s|r."),
			Signed(try.cooldowns), divide, Whole(1 - 1 / divide)))
		local before, after = 60 / try.wait, 60 / real
		if try.wait / divide < FLOOR then
			page.spell:SetText(string.format(SurvivorUI_T("This spell: %s becomes |cffffd1000.25 sec|r, the floor. |cffff7366Past %s, more Haste is lost on it.|r"),
				Seconds(try.wait), Signed(try.wait / FLOOR - 1)))
		else
			page.spell:SetText(string.format(SurvivorUI_T("This spell: %s becomes |cffffd100%s|r: it goes off %s times a minute instead of %s. A marble is one time:"),
				Seconds(try.wait), Seconds(real), Count(after), Count(before)))
		end
		DrawCasts(slow, before)
		DrawCasts(fast, after)
		local strikes = DrawStrikes(plain, Echoes(try.echo, 0))
		DrawStrikes(cascade, Echoes(try.echo, CASCADE))
		page.together:SetText(string.format(SurvivorUI_T("Together they multiply: %s times a minute x %.2f strikes = |cffffd100%s strikes a minute|r."),
			Count(after), strikes, Count(after * strikes)))
	end
end

------------------------------------------------------------------------------
-- Not DoTs: the spells that strike again and again from the ground.

local function ClassTint(class)
	local r, g, b = SurvivorUI_ClassColor(class)
	return { r or 0.8, g or 0.8, b or 0.8 }
end

local function GroundTip(spell, lines)
	GameTooltip:SetOwner(this, "ANCHOR_NONE")
	GameTooltip:ClearAllPoints()
	GameTooltip:SetPoint("BOTTOMLEFT", this, "TOPLEFT", 0, 4)
	GameTooltip:SetText(SurvivorUI_Native(spell[1]))
	for index = 1, table.getn(lines) do
		local line = lines[index]
		GameTooltip:AddLine(line[1], line[2], line[3], line[4], 1)
	end
	GameTooltip:AddLine(SurvivorUI_T(spell[4]), 0.7, 0.7, 0.7)
	if not spell[5] or spell[5] ~= "talent" then
		GameTooltip:AddLine(SurvivorUI_T("Numbers at rank 1."), 0.7, 0.7, 0.7)
	end
	GameTooltip:Show()
	SolidTip()
end

local function CardEnter()
	Tint(this, this.tint, 1.8)
	this.tip()
end

local function CardLeave()
	Tint(this, this.tint, 1)
	CloseTip()
end

-- A spell's card: its icon, its name in its class's color, what it does in a
-- few words, what works on it, and the rest in its tooltip.
local function SpellCard(page, spell, x, y, width, words, marks, tip)
	local tint = ClassTint(spell[3])
	local card = Tinted(page, tint, x, y, width, SPELL_ROW - 4)
	card.tint = tint
	card.tip = tip
	card:EnableMouse(true)
	card:SetScript("OnEnter", CardEnter)
	card:SetScript("OnLeave", CardLeave)
	local icon = card:CreateTexture(nil, "ARTWORK")
	icon:SetTexture("Interface\\Icons\\"..spell[2])
	icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
	icon:SetWidth(30)
	icon:SetHeight(30)
	icon:SetPoint("LEFT", card, "LEFT", 6, 0)
	local name = Text(card, "GameFontNormal", TEXT)
	name:SetPoint("TOPLEFT", card, "TOPLEFT", 42, -6)
	name:SetText(SurvivorUI_Native(spell[1]))
	Paint(name, tint)
	local line = Text(card, "GameFontHighlight", SMALL)
	line:SetPoint("TOPLEFT", card, "TOPLEFT", 42, -22)
	line:SetText(words)
	local tags = Text(card, "GameFontNormal", SMALL)
	tags:SetPoint("TOPRIGHT", card, "TOPRIGHT", -8, -7)
	tags:SetText(marks)
	-- Words past the card's edge (a language's longer ones): a size smaller,
	-- or two; the name so too beside its marks.
	for size = SMALL - 1, SMALL - 2, -1 do
		if line:GetStringWidth() > width - 45 then
			Fit.Size(line, size)
		end
	end
	if name:GetStringWidth() + tags:GetStringWidth() > width - 60 then
		Fit.Size(name, TEXT - 1)
	end
end

local function BuildGround(page)
	Title(page, SurvivorUI_T("Not DoTs: the ground bites"))
	Para(page, SurvivorUI_T("These spells strike again and again too, but the bites come from the ground, not from a curse on the enemy. An enemy takes a tick only while it stands inside."), 2)
	Warning(page, GREEN, SurvivorUI_T("CRIT AND CRIT DMG WORK HERE"), SurvivorUI_T("Every tick rolls Crit for every enemy inside. Two at once both count."))
	local width = math.floor((PAGE_WIDTH - CARD_GAP) / 2)
	local both = SurvivorUI_T("|cffffad61Crit|r  |cff59f273Stacks|r")
	for index = 1, table.getn(GROUND) do
		local spell = GROUND[index]
		local tip = function()
			local lines = {
				{ string.format(SurvivorUI_T(spell[5]), spell[6]), 1, 1, 1 },
				{ string.format(SurvivorUI_T("Every enemy within %d yd of that spot is struck every %s sec for %s sec."), spell[7], spell[8], spell[9]), 1, 1, 1 },
			}
			if spell[11] then
				table.insert(lines, { SurvivorUI_T(spell[11]), 1, 1, 1 })
			end
			table.insert(lines, { string.format(SurvivorUI_T("Cooldown: %d sec."), spell[10]), 1, 1, 1 })
			table.insert(lines, { SurvivorUI_T("Each tick rolls Crit for each enemy inside."), PEACH[1], PEACH[2], PEACH[3] })
			table.insert(lines, { SurvivorUI_T("Two at once both tick."), GREEN[1], GREEN[2], GREEN[3] })
			GroundTip(spell, lines)
		end
		local row = math.floor((index - 1) / 2)
		SpellCard(page, spell, math.mod(index - 1, 2) * (width + CARD_GAP), page.y - row * SPELL_ROW, width,
			string.format(SurvivorUI_T("Every %s sec for %s sec"), spell[8], spell[9]), both, tip)
	end
	local rows = math.ceil(table.getn(GROUND) / 2)
	SpellCard(page, HELLFIRE, 0, page.y - rows * SPELL_ROW, PAGE_WIDTH, SurvivorUI_T("Not on the ground: a blast around you, going off again and again."),
		SurvivorUI_T("|cffffad61Crit|r"), function()
			GroundTip(HELLFIRE, {
				{ SurvivorUI_T("Hits every enemy within 7 yd of you."), 1, 1, 1 },
				{ SurvivorUI_T("Cooldown: 1.5 sec."), 1, 1, 1 },
				{ SurvivorUI_T("Each blast rolls Crit for each enemy it hits."), PEACH[1], PEACH[2], PEACH[3] },
				{ SurvivorUI_T("Nothing stays behind, so there is nothing to stack."), 0.8, 0.8, 0.8 },
			})
		end)
	page.y = page.y - (rows + 1) * SPELL_ROW - 6
	Tip(page, SurvivorUI_T("|cff59f273Two at once:|r each one keeps its own clock, so an enemy inside both is struck by both. Haste brings the next one sooner."), 2)
	Tip(page, SurvivorUI_T("|cff4de6d9DoT Haste and DoT Stacks|r do nothing here. |cff4de6d9Area|r makes the circle wider."))
	Tip(page, SurvivorUI_T("|cffffd100Set when it lands:|r its damage is counted once, as a DoT's is. The enemy box still counts at every tick."))

	function page.Draw()
	end
end

------------------------------------------------------------------------------
-- Damage reduction.

local function ChipPaint(chip, strength)
	local tint = chip.tint
	chip.fill:SetVertexColor(tint[1] * strength, tint[2] * strength, tint[3] * strength, 1)
	chip:SetBackdropBorderColor(tint[1], tint[2], tint[3], 1)
end

local function ChipEnter()
	ChipPaint(this, CHIP_LIT)
	local spell = this.spell
	GroundTip(spell, {
		{ SurvivorUI_T(spell[6]), 1, 1, 1 },
		{ SurvivorUI_T("It adds to your reduction, and the cap holds."), GREEN[1], GREEN[2], GREEN[3] },
	})
end

local function ChipLeave()
	ChipPaint(this, CHIP_REST)
	CloseTip()
end

-- The talents as chips on their class's color, four to a row. A name too long
-- for its chip (a language's longer words) takes a size smaller in every
-- chip; one still too long, every chip grows and such a name takes two lines.
local function Chips(page, list)
	local width = math.floor((PAGE_WIDTH - 3 * CHIP_GAP) / 4)
	local room = width - 28           -- past the icon, to the edge
	local chips, widest, height = {}, 0, CHIP_HEIGHT
	for index = 1, table.getn(list) do
		local spell = list[index]
		local chip = Tinted(page, { 1, 1, 1 }, 0, page.y, width, CHIP_HEIGHT)
		chip.spell = spell
		chip.tint = ClassTint(spell[3])
		chip:EnableMouse(true)
		chip:SetScript("OnEnter", ChipEnter)
		chip:SetScript("OnLeave", ChipLeave)
		-- Over the panel's ground: on the same layer the two can land either way.
		chip.fill = chip:CreateTexture(nil, "BORDER")
		chip.fill:SetTexture(FLAT)
		chip.fill:SetPoint("TOPLEFT", chip, "TOPLEFT", 1, -1)
		chip.fill:SetPoint("BOTTOMRIGHT", chip, "BOTTOMRIGHT", -1, 1)
		ChipPaint(chip, CHIP_REST)
		local icon = chip:CreateTexture(nil, "ARTWORK")
		icon:SetTexture("Interface\\Icons\\"..spell[2])
		icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
		icon:SetWidth(16)
		icon:SetHeight(16)
		icon:SetPoint("LEFT", chip, "LEFT", 4, 0)
		local name = Text(chip, "GameFontHighlight", SMALL)
		name:SetPoint("LEFT", icon, "RIGHT", 4, 0)
		name:SetText(SurvivorUI_Native(spell[1]))
		chip.icon, chip.name = icon, name
		chips[index] = chip
		widest = math.max(widest, name:GetStringWidth())
	end
	if widest > room then
		widest = 0
		for index = 1, table.getn(chips) do
			Fit.Size(chips[index].name, SMALL - 1)
			widest = math.max(widest, chips[index].name:GetStringWidth())
		end
	end
	if widest > room then
		height = 32                   -- two lines
		for index = 1, table.getn(chips) do
			local chip = chips[index]
			Fit.Size(chip.name, SMALL)
			if chip.name:GetStringWidth() > room then
				Fit.TwoLines(chip.name, chip.icon)
			end
		end
	end
	for index = 1, table.getn(chips) do
		local chip = chips[index]
		chip:SetHeight(height)
		chip:ClearAllPoints()
		chip:SetPoint("TOPLEFT", page, "TOPLEFT", math.mod(index - 1, 4) * (width + CHIP_GAP),
			page.y - math.floor((index - 1) / 4) * (height + CHIP_GAP))
	end
	page.y = page.y - math.ceil(table.getn(list) / 4) * (height + CHIP_GAP)
end

-- A bar: what holds in green, what is lost past the cap in red, the cap in gold.
local function Wall(page)
	local wall = {}
	wall.ground = page:CreateTexture(nil, "BORDER")
	wall.ground:SetTexture(FLAT)
	wall.ground:SetVertexColor(0, 0, 0, 0.6)
	wall.ground:SetWidth(WALL_WIDTH)
	wall.ground:SetHeight(WALL_HEIGHT)
	wall.ground:SetPoint("TOPLEFT", page, "TOPLEFT", 0, page.y)
	wall.held = page:CreateTexture(nil, "ARTWORK")
	wall.held:SetTexture(FLAT)
	wall.held:SetVertexColor(GREEN[1] * 0.7, GREEN[2] * 0.7, GREEN[3] * 0.7)
	wall.held:SetHeight(WALL_HEIGHT)
	wall.held:SetPoint("TOPLEFT", wall.ground, "TOPLEFT", 0, 0)
	wall.lost = page:CreateTexture(nil, "ARTWORK")
	wall.lost:SetTexture(FLAT)
	wall.lost:SetVertexColor(RED[1] * 0.8, RED[2] * 0.5, RED[3] * 0.5)
	wall.lost:SetHeight(WALL_HEIGHT)
	wall.lost:SetPoint("TOPLEFT", wall.held, "TOPRIGHT", 0, 0)
	wall.line = page:CreateTexture(nil, "OVERLAY")
	wall.line:SetTexture(FLAT)
	wall.line:SetVertexColor(1, 0.82, 0)
	wall.line:SetWidth(2)
	wall.line:SetHeight(WALL_HEIGHT + 6)
	page.y = page.y - WALL_HEIGHT - 8
	return wall
end

-- What holds, what is lost and the cap, each a share of the bar.
local function DrawWall(wall, kept, over, cap)
	-- A texture of no width draws at its art's size, so at least a sliver.
	wall.held:SetWidth(math.max(1, kept * WALL_WIDTH))
	wall.lost:SetWidth(math.max(1, over * WALL_WIDTH))
	if over > 0 then
		wall.lost:Show()
	else
		wall.lost:Hide()
	end
	wall.line:ClearAllPoints()
	wall.line:SetPoint("CENTER", wall.ground, "LEFT", cap * WALL_WIDTH, 0)
end

local function BuildArmor(page)
	Title(page, SurvivorUI_T("Damage Reduction: the wall"))
	Para(page, SurvivorUI_T("Every hit on you meets this wall first. At 40%, a hit of 100 lands for 60. Your class, race, gear, jewelry and talents are all added into one number."), 2)
	Warning(page, BLUE, SurvivorUI_T("THE CAP IS 60%"), SurvivorUI_T("Whatever you add past it is lost. Only Titan moves it, to 70%."))
	local talks = {
		{ SurvivorUI_T("Your damage reduction can reach 70% instead of 60%."), SurvivorUI_T("Nothing else in the game moves the cap.") },
		{ SurvivorUI_T("Damage reduction past the cap is not wasted: each 1% of it becomes more damage."), SurvivorUI_T("At 3 ranks, each 1% is 3% more damage.") },
		{ SurvivorUI_T("You deal more damage for every 10% damage reduction you have."), SurvivorUI_T("It counts up to the cap: at 3 ranks, 60% gives +18% damage.") },
		{ SurvivorUI_T("Its Voidwalker gains 3% damage per 1% Damage Reduction."), SurvivorUI_T("It counts up to the cap.") },
	}
	local words = { SurvivorUI_T("The cap goes from 60% to 70%."), SurvivorUI_T("Each 1% past the cap becomes more damage."),
		SurvivorUI_T("More damage per 10% you have."), SurvivorUI_T("Its Voidwalker grows with your reduction.") }
	local marks = { SurvivorUI_T("|cff73bfffCap 70%|r"), SurvivorUI_T("|cffff7366Past the cap|r"), SurvivorUI_T("|cff59f273Up to the cap|r"), SurvivorUI_T("|cff59f273Up to the cap|r") }
	local width = math.floor((PAGE_WIDTH - CARD_GAP) / 2)
	for index = 1, table.getn(CAP_TALENTS) do
		local spell = CAP_TALENTS[index]
		local talk = talks[index]
		spell[5] = "talent"
		SpellCard(page, spell, math.mod(index - 1, 2) * (width + CARD_GAP), page.y - math.floor((index - 1) / 2) * SPELL_ROW, width,
			words[index], marks[index], function()
				GroundTip(spell, { { talk[1], 1, 1, 1 }, { talk[2], GREEN[1], GREEN[2], GREEN[3] } })
			end)
	end
	page.y = page.y - 2 * SPELL_ROW - 6
	Heading(page, SurvivorUI_T("Try it"))
	page.y = page.y - 14
	local armor = Try(page, 8, page.y, 180, SurvivorUI_T("Damage Reduction"), 0, 1, 0.01, Whole, function(value) try.armor = value end)
	local cap = Try(page, 214, page.y, 180, SurvivorUI_T("Cap"), 0.6, 0.7, 0.1, Whole, function(value) try.cap = value end)
	local crowd = Try(page, 420, page.y, 180, SurvivorUI_T("Enemies close"), 0, 0.2, 0.01, Whole, function(value) try.crowd = value end)
	page.y = page.y - 32
	local wall = Wall(page)
	page.land = Words(page, 0, page.y, PAGE_WIDTH, "")
	page.y = page.y - LINE - 8
	Tip(page, SurvivorUI_T("|cff59f273Past the wall:|r shields soak what gets through. Gear that cuts damage \"while 5 or more enemies are within 8 yards\" works on top of the cap: 60% and 10% make 64%."), 2)
	Tip(page, SurvivorUI_T("|cffffd100The last points count most:|r going from 50% to 60% takes 20% off every hit. From 0 to 10%, only 10%."))
	Tip(page, SurvivorUI_T("|cff73bfffThese talents only add to the number:|r"))
	Chips(page, OTHER_TALENTS)

	function page.Draw()
		armor.Read(try.armor)
		cap.Read(try.cap)
		crowd.Read(try.crowd)
		local kept = math.min(try.armor, try.cap)
		local over = math.max(try.armor - try.cap, 0)
		local lands = 100 * (1 - kept) * (1 - try.crowd)
		DrawWall(wall, kept, over, try.cap)
		local gone = over > 0 and string.format(SurvivorUI_T("  |cffff7366%.0f points past the cap are lost.|r"), over * 100) or ""
		page.land:SetText(string.format(SurvivorUI_T("A hit of 100 lands for |cffffd100%.0f|r, so your health counts |cffffd100%.1f|r times.%s"),
			lands, 100 / math.max(lands, 1), gone))
	end
end

------------------------------------------------------------------------------
-- Speed, pickup and area.

-- A reach as the game grows it: past 70 yd, slower and slower.
local function Reach(yards)
	if yards <= SOFT_REACH then
		return yards
	end
	return SOFT_REACH + 10 * math.log(1 + (yards - SOFT_REACH) / 10)
end

local function Yards(value)
	return string.format(SurvivorUI_T("%.1f yd"), value)
end

-- A tinted panel with its title on a band, sliders of the page standing on it.
local function Panel(page, color, x, y, width, title)
	local box = Tinted(page, color, x, y, width, REACH_BOX)
	Band(box, color, "TOP", 20)
	local head = Text(box, "GameFontNormal", TEXT)
	head:SetPoint("CENTER", box, "TOP", 0, -14)
	head:SetText(title)
	Paint(head, color)
	return box
end

local function Disc(box, layer, color, alpha)
	local disc = box:CreateTexture(nil, layer)
	disc:SetTexture(DISC)
	disc:SetVertexColor(color[1], color[2], color[3], alpha)
	return disc
end

local function BuildReach(page)
	Title(page, SurvivorUI_T("Speed, Pickup and Area: how far"))
	Para(page, SurvivorUI_T("Speed is how fast you run. Pickup is how far experience and gold fly to you. Area is how wide your spells strike, and how far they reach."), 2)
	Warning(page, BLUE, SurvivorUI_T("SPEED STOPS AT +120%"), SurvivorUI_T("You run 7 yards a second, 15.4 at most. Past +120%, more Speed does nothing."))
	page.y = page.y - 14
	local speed = Try(page, 8, page.y, 180, SurvivorUI_T("Speed"), 0, 2, 0.05, Signed, function(value) try.speed = value end)
	MyHero(page, PAGE_WIDTH - 84, page.y + 4)
	page.y = page.y - 30
	local wall = Wall(page)
	page.run = Words(page, 0, page.y, PAGE_WIDTH, "")
	page.y = page.y - LINE - 8
	local width = math.floor((PAGE_WIDTH - CARD_GAP) / 2)
	local top = page.y
	local pickup = Panel(page, YELLOW, 0, top, width, SurvivorUI_T("Pickup: bonuses multiply"))
	local one = Try(page, 12, top - 46, 170, SurvivorUI_T("A bonus"), 0, 1, 0.05, Signed, function(value) try.pickup = value end)
	local two = Try(page, 12, top - 94, 170, SurvivorUI_T("Another"), 0, 1, 0.05, Signed, function(value) try.pickup2 = value end)
	page.times = Words(pickup, 10, -132, width - 20, "")
	page.added = Words(pickup, 10, -150, width - 20, "", SMALL + 1, { 0.8, 0.8, 0.8 })
	Words(pickup, 10, -168, width - 20, SurvivorUI_T("Two together give more than their sum."), SMALL + 1, { 0.8, 0.8, 0.8 })
	local area = Panel(page, GREEN, width + CARD_GAP, top, width, SurvivorUI_T("Area: wider and further"))
	local grow = Try(page, width + CARD_GAP + 12, top - 46, 150, SurvivorUI_T("Area"), 0, 2, 0.05, Signed, function(value) try.area = value end)
	for _, slider in pairs({ one, two, grow }) do
		slider:SetFrameLevel(pickup:GetFrameLevel() + 2)
	end
	page.radius = Words(area, 10, -84, 180, "")
	page.ground = Words(area, 10, -102, 180, "")
	page.circle = Words(area, 10, -128, 180, "", SMALL + 1)
	page.reach = Words(area, 10, -146, 180, "", SMALL + 1)
	page.soft = Words(area, 10, -164, 180, "", SMALL + 1, { 0.8, 0.8, 0.8 })
	local wide = Disc(area, "ARTWORK", GREEN, 0.75)
	local base = Disc(area, "OVERLAY", GREY, 0.9)
	page.y = top - REACH_BOX - 8
	Tip(page, SurvivorUI_T("|cff73bfffEverything that speeds you up|r goes into one number, the speed rune too, and the cap holds."))
	Tip(page, SurvivorUI_T("|cff59f273Targets:|r every spell that picks its targets picks that many more. Only gear gives it, like the Rare set's +1."), 2)

	function page.Draw()
		speed.Read(try.speed)
		one.Read(try.pickup)
		two.Read(try.pickup2)
		grow.Read(try.area)
		local kept = math.min(try.speed, MOST_SPEED - 1)
		local over = math.max(try.speed - (MOST_SPEED - 1), 0)
		DrawWall(wall, kept / 2, over / 2, (MOST_SPEED - 1) / 2)
		local gone = over > 0 and string.format(SurvivorUI_T("  |cffff7366%.0f points past the cap are lost.|r"), over * 100) or ""
		page.run:SetText(string.format(SurvivorUI_T("You run |cffffd100%.1f yards a second|r, x%.2f.%s"), RUN * (1 + kept), 1 + kept, gone))
		local times = PICKUP * (1 + try.pickup) * (1 + try.pickup2)
		page.times:SetText(string.format(SurvivorUI_T("9 yd x %.2f x %.2f = |cffffd100%s|r"), 1 + try.pickup, 1 + try.pickup2, Yards(times)))
		page.added:SetText(string.format(SurvivorUI_T("Added up, they would make %s."), Yards(PICKUP * (1 + try.pickup + try.pickup2))))
		local grown = 1 + try.area
		page.radius:SetText(string.format(SurvivorUI_T("Every radius x |cffffd100%.2f|r"), grown))
		page.ground:SetText(string.format(SurvivorUI_T("Ground covered x |cffffd100%.2f|r"), grown * grown))
		page.circle:SetText(string.format(SurvivorUI_T("An 8 yd circle: %s"), Yards(8 * grown)))
		page.reach:SetText(string.format(SurvivorUI_T("A 30 yd reach: %s"), Yards(Reach(30 * grown))))
		page.soft:SetText(30 * grown > SOFT_REACH and SurvivorUI_T("Slower past 70 yd.") or "")
		-- The widest circle the slider allows fills the room on the right.
		local unit = DISC_MOST / 3
		for _, each in pairs({ { wide, unit * grown }, { base, unit } }) do
			each[1]:SetWidth(2 * each[2])
			each[1]:SetHeight(2 * each[2])
			each[1]:ClearAllPoints()
			each[1]:SetPoint("CENTER", area, "TOPRIGHT", -DISC_MOST - 10, -REACH_BOX / 2 - 14)
		end
	end
end

------------------------------------------------------------------------------
-- Marks.

-- A class's color lifted until words in it read on the dark ground.
local function Readable(tint)
	local lift = 0.35 * (1 - (0.3 * tint[1] + 0.59 * tint[2] + 0.11 * tint[3]))
	return { math.min(tint[1] + lift, 1), math.min(tint[2] + lift, 1), math.min(tint[3] + lift, 1) }
end

local function ColorCode(tint)
	return string.format("|cff%02x%02x%02x", math.floor(tint[1] * 255 + 0.5), math.floor(tint[2] * 255 + 0.5), math.floor(tint[3] * 255 + 0.5))
end

-- A star's marks at a discount, rounded up to a tenth as the game does.
local function StarCost(cost, off)
	return math.ceil(cost * (1 - off) * 10 - 0.001) / 10
end

-- Marks as the Armory writes them: whole, or to a tenth.
local function Tenths(value)
	local whole = math.floor(value + 0.5)
	if math.abs(value - whole) < 0.01 then
		return string.format("%d", whole)
	end
	return string.format("%.1f", value)
end

local function Discount(value)
	if value == 0 then
		return "0"
	end
	return string.format(SurvivorUI_T("%d, %d%% off"), value, value * 5)
end

-- An 8-piece bonus in words, its numbers in the color. A Tier 0.5 one has
-- words of its own at 5/5, after its numbers, and can have a third number.
local function SetWords(line, strong, color)
	local v, v2, v3, words = line[2], line[3], line[7], line[1]
	if strong then
		v, v2, v3, words = line[4], line[5], line[8], line[6] or line[1]
	end
	words = string.gsub(SurvivorUI_T(words), "{v2}", color..v2.."|r")
	words = string.gsub(words, "{v}", color..v.."|r")
	if v3 then
		words = string.gsub(words, "{v3}", color..v3.."|r")
	end
	return words
end

local function HeroSet()
	local _, key = UnitClass("player")
	for index = 1, table.getn(SETS) do
		if SETS[index][1] == key then
			return index
		end
	end
	return 1
end

-- Dark words on a bright color, white on a dark one.
local function Fore(tint)
	if 0.3 * tint[1] + 0.59 * tint[2] + 0.11 * tint[3] > 0.5 then
		return { 0.08, 0.07, 0.05 }
	end
	return { 1, 1, 1 }
end

-- An 8-piece bonus of the hero's class that reads in percents, for the example.
local function ExampleLine()
	local lines = SETS[HeroSet()][4]
	for index = 1, table.getn(lines) do
		if string.find(lines[index][1], "{v}%", 1, true) then
			return lines[index]
		end
	end
	return lines[1]
end

local function EmpoweredTip()
	local line = ExampleLine()
	GameTooltip:SetOwner(this, "ANCHOR_NONE")
	GameTooltip:ClearAllPoints()
	GameTooltip:SetPoint("BOTTOMLEFT", this, "TOPLEFT", 0, 4)
	GameTooltip:SetText(SurvivorUI_T("Empowered"))
	GameTooltip:AddLine(SurvivorUI_T("All 8 pieces of a set at 5/5 make its 8-piece bonus 50% stronger."), 1, 1, 1, 1)
	GameTooltip:AddLine(" ")
	GameTooltip:AddLine(SurvivorUI_T("At 3/5 or 4/5:"), 1, 0.82, 0)
	GameTooltip:AddLine(SetWords(line, false, GOLD), 1, 1, 1, 1)
	GameTooltip:AddLine(SurvivorUI_T("At 5/5, Empowered:"), 1, 0.82, 0)
	GameTooltip:AddLine(SetWords(line, true, GOLD), 1, 1, 1, 1)
	GameTooltip:AddLine(" ")
	GameTooltip:AddLine(SurvivorUI_T("Tier 0.5 has numbers of its own at 5/5:"), 1, 0.82, 0)
	GameTooltip:AddLine(SetWords(SETS[HeroSet()][4][TIER], true, GOLD), 1, 1, 1, 1)
	GameTooltip:AddLine(" ")
	GameTooltip:AddLine(SurvivorUI_T("Numbers that count things round to a whole number."), 0.7, 0.7, 0.7, 1)
	GameTooltip:Show()
	SolidTip()
end

local function BuildMarks(page)
	Title(page, SurvivorUI_T("Marks: what stars cost"))
	Para(page, SurvivorUI_T("Marks are what bosses pay you, and what your gear's stars cost."), 1)
	local width = math.floor((PAGE_WIDTH - 2 * CARD_GAP) / 3)
	local steps = {
		{ SurvivorUI_T("1. Earn"), SurvivorUI_T("Bosses pay marks when they fall. A piece you already own pays marks instead. Heroic pays more; Hyper Mode the same.") },
		{ SurvivorUI_T("2. Keep"), SurvivorUI_T("Marks stay with the class that earned them. Each class saves its own.") },
		{ SurvivorUI_T("3. Spend"), SurvivorUI_T("In the Armory, each piece goes up one star at a time, up to 5.") },
	}
	-- A row of cards as tall as the longest words in it need.
	local cards, tall = {}, MARK_CARD
	local function Even()
		for index = 1, 3 do
			cards[index]:SetHeight(tall)
		end
		page.y = page.y - tall - 8
	end
	for index = 1, 3 do
		local card = Tinted(page, YELLOW, (index - 1) * (width + CARD_GAP), page.y, width, MARK_CARD)
		Band(card, YELLOW, "TOP", 20)
		local title = Text(card, "GameFontNormal", TEXT)
		title:SetPoint("CENTER", card, "TOP", 0, -14)
		title:SetText(steps[index][1])
		tall = math.max(tall, 26 + Words(card, 9, -26, width - 18, steps[index][2], SMALL + 1):GetHeight() + 6)
		cards[index] = card
	end
	Even()
	Heading(page, SurvivorUI_T("What stars open on a set"))
	local opens = {
		{ SurvivorUI_T("1/5: 4-piece bonus"), SurvivorUI_T("4 pieces of one set at 1/5 or more") },
		{ SurvivorUI_T("3/5: 8-piece bonus"), SurvivorUI_T("All 8 pieces at 3/5 or more") },
		{ SurvivorUI_T("5/5: Empowered"), SurvivorUI_T("The 8-piece bonus gets 50% stronger: 20% becomes 30%. Hover for your class.") },
	}
	tall = OPEN_CARD
	for index = 1, 3 do
		local card = Tinted(page, YELLOW, (index - 1) * (width + CARD_GAP), page.y, width, OPEN_CARD)
		Tint(card, YELLOW, 0.5)
		Words(card, 9, -7, width - 18, opens[index][1], TEXT, YELLOW)
		tall = math.max(tall, 25 + Words(card, 9, -25, width - 18, opens[index][2], SMALL):GetHeight() + 6)
		if index == 3 then
			card:EnableMouse(true)
			card:SetScript("OnEnter", EmpoweredTip)
			card:SetScript("OnLeave", CloseTip)
		end
		cards[index] = card
	end
	Even()
	Heading(page, SurvivorUI_T("Cost per upgrade, per piece"))
	-- The discount to play with: the game counts it for each star on its own,
	-- the page takes one count for all of them.
	try.others = try.others or 0
	page.y = page.y - 14
	local others = Try(page, 8, page.y, 180, SurvivorUI_T("Other classes done"), 0, 8, 1, Discount, function(value) try.others = value end)
	Words(page, 212, page.y + 12, PAGE_WIDTH - 212, SurvivorUI_T("|cffffd100Your other classes make it cheaper:|r each one with all 8 pieces of that rarity at that star or higher takes 5% off, up to 40%."), SMALL + 1)
	page.y = page.y - 30
	local count = table.getn(SET_KINDS)
	local table_height = (count + 1) * COST_ROW + 10
	local panel = Tinted(page, GREY, 0, page.y, PAGE_WIDTH, table_height)
	Tint(panel, GREY, 0.5)
	local function Cell(x, y, words, color)
		local cell = Text(panel, "GameFontHighlight", SMALL + 1)
		cell:SetPoint("TOPRIGHT", panel, "TOPLEFT", x, y)
		cell:SetText(words)
		if color then
			Paint(cell, color)
		end
		return cell
	end
	Words(panel, 9, -6, 120, SurvivorUI_T("Rarity"), SMALL + 1, GREY)
	for star = 1, 5 do
		Cell(140 + star * 44, -6, star.."/5", GREY)
	end
	Cell(490, -6, SurvivorUI_T("8 pieces at 3/5"), GREY)
	Cell(PAGE_WIDTH - 10, -6, SurvivorUI_T("8 pieces at 5/5"), GREY)
	local cells = {}
	for index = 1, count do
		local kind = SET_KINDS[index]
		local y = -6 - index * COST_ROW
		Words(panel, 9, y, 120, SurvivorUI_T(kind[1]), SMALL + 1, kind[2])
		local row = {}
		for star = 1, 5 do
			row[star] = Cell(140 + star * 44, y, "", kind[2])
		end
		row[6] = Cell(490, y, "", kind[2])
		row[7] = Cell(PAGE_WIDTH - 10, y, "", kind[2])
		cells[index] = row
	end
	page.y = page.y - table_height - 6
	Tip(page, SurvivorUI_T("|cffffd100Stars open with Heroic:|r beat Heroic N in a zone, and this class's gear from there can go to N stars."), 2)

	function page.Draw()
		others.Read(try.others)
		local off = math.min(0.05 * try.others, 0.4)
		for index = 1, count do
			local costs = SET_KINDS[index][7]
			local row = cells[index]
			local three, five = 0, 0
			for star = 1, 5 do
				local cost = StarCost(costs[star], off)
				row[star]:SetText(Tenths(cost))
				five = five + cost
				if star <= 3 then
					three = three + cost
				end
			end
			row[6]:SetText(Tenths(three * 8))
			row[7]:SetText(Tenths(five * 8))
		end
	end
end

------------------------------------------------------------------------------
-- Sets.

-- A set's name as an item tooltip writes an item's: the tooltip's own font
-- (read in the game's 0.139: 14, the quality's color, no outline, no shadow).
local function ItemName(text, size)
	local font = GameTooltipTextLeft1 and GameTooltipTextLeft1:GetFont()
	if font then
		text:SetFont(font, size)
	end
	text:SetShadowOffset(0, 0)
end

-- A button of the Sets page: its edge, and a color filling it inside the
-- edge; with stars, five of them before its words.
local function SetButton(page, x, y, width, height, stars)
	local button = CreateFrame("Button", nil, page)
	button.noHoverOutline = true
	button:SetWidth(width)
	button:SetHeight(height)
	button:SetPoint("TOPLEFT", page, "TOPLEFT", x, y)
	button:SetBackdrop(TINTED)
	-- Over the panel's ground: on the same layer the two can land either way.
	button.fill = button:CreateTexture(nil, "BORDER")
	button.fill:SetTexture(FLAT)
	button.fill:SetPoint("TOPLEFT", button, "TOPLEFT", 2, -2)
	button.fill:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -2, 2)
	if stars then
		button.stars = {}
		for each = 1, 5 do
			local star = button:CreateTexture(nil, "ARTWORK")
			star:SetTexture(STAR)
			star:SetWidth(STAR_SIZE)
			star:SetHeight(STAR_SIZE)
			button.stars[each] = star
		end
	end
	button.text = Text(button, "GameFontNormal", SMALL)
	button.text:SetPoint("CENTER", button, "CENTER", 0, 0)
	button.text:SetShadowOffset(0, 0)
	return button
end

-- The one chosen: a white edge, the only mark; the others a grey one. A star
-- button's stars, count of them full, and its words in its middle: dark on
-- the chosen one's gold, gold and grey on the others.
local function Chosen(button, lit, count)
	button:SetBackdropColor(0, 0, 0, 0.9)
	if lit then
		button:SetBackdropBorderColor(1, 1, 1, 1)
	else
		button:SetBackdropBorderColor(0.7, 0.7, 0.7, 0.6)
	end
	if not button.stars then
		return
	end
	local x = (button:GetWidth() - 5 * STAR_SIZE - 6 - button.text:GetStringWidth()) / 2
	for each = 1, 5 do
		local star = button.stars[each]
		star:ClearAllPoints()
		star:SetPoint("LEFT", button, "LEFT", x + (each - 1) * STAR_SIZE, 0)
		if lit then
			star:SetVertexColor(0.25, 0.15, 0, each <= count and 1 or 0.3)
		elseif each <= count then
			star:SetVertexColor(1, 0.82, 0, 1)
		else
			star:SetVertexColor(0.5, 0.5, 0.5, 0.45)
		end
	end
	button.text:ClearAllPoints()
	button.text:SetPoint("LEFT", button, "LEFT", x + 5 * STAR_SIZE + 6, 0)
end

-- A column of a set's panel: its own ground and edge, its name at its top
-- left, its bonus under it.
local CELL = { bgFile = FLAT, edgeFile = FLAT, edgeSize = 1, insets = { left = 1, right = 1, top = 1, bottom = 1 } }
local function SetCell(row, x, width, head)
	local cell = CreateFrame("Frame", nil, row)
	cell.noHoverOutline = true
	cell:SetPoint("TOPLEFT", row, "TOPLEFT", x, -3)
	cell:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", x, 3)
	cell:SetWidth(width)
	cell:SetBackdrop(CELL)
	cell.head = Words(cell, 7, -3, width - 12, head, SMALL - 1)
	cell.text = Words(cell, 7, -14, width - 12, "", SMALL)
	return cell
end

-- A set's panel at y: its name and zones over it, its two columns in it.
local function SetRow(page, kind, y)
	local height = (kind[5] == 6 or kind[5] == TIER) and SET_TALL or SET_ROW
	local row = Tinted(page, YELLOW, 0, y - SET_CAPTION, PAGE_WIDTH, height)
	-- Over the panel: the set's name in its rarity's color, as a tooltip has
	-- an item's, "(Epic set)" beside it; the zones it drops in to the right,
	-- by the Run History's map.
	row.name = Text(page, "GameFontNormal", TEXT)
	row.name:SetPoint("BOTTOMLEFT", row, "TOPLEFT", 2, 3)
	Paint(row.name, kind[8])
	row.rarity = Text(page, "GameFontHighlight", SMALL - 1)
	row.rarity:SetPoint("BOTTOMLEFT", row.name, "BOTTOMRIGHT", 5, 0)
	row.rarity:SetText(SurvivorUI_TF("({1} set)", SurvivorUI_T(kind[1])))
	Paint(row.rarity, kind[8])
	row.zones = Text(page, "GameFontHighlight", SMALL)
	row.zones:SetPoint("BOTTOMRIGHT", row, "TOPRIGHT", -2, 4)
	-- Tier 0.5 drops in one zone only.
	if kind[4] then
		row.zones:SetText(SurvivorUI_T(kind[3])..", "..SurvivorUI_T(kind[4]))
	else
		row.zones:SetText(SurvivorUI_T(kind[3]))
	end
	Paint(row.zones, ZONE_GREEN)
	row.map = page:CreateTexture(nil, "ARTWORK")
	row.map:SetTexture(MAP_ICON)
	row.map:SetWidth(16)
	row.map:SetHeight(16)
	row.map:SetPoint("RIGHT", row.zones, "LEFT", -3, 0)
	-- A class's own 4-piece bonus is longer: its column is wider.
	local four = kind[6] and 198 or 270
	row.four = SetCell(row, 3, four, SurvivorUI_T("4 pieces"))
	row.eight = SetCell(row, four + 5, PAGE_WIDTH - four - 8, SurvivorUI_T("8 pieces"))
	-- Under the column's name, inside its edge.
	row.four.room, row.eight.room = height - 22, height - 22
	return row, height
end

-- A column's bonus in its room: a size smaller, or two, while it is taller
-- (a language's longer words).
function Fit.Cell(cell)
	local text = cell.text
	for size = SMALL, SMALL - 2, -1 do
		if size == SMALL or text:GetHeight() > cell.room then
			Fit.Size(text, size)
			text:SetText(text:GetText())
		end
	end
end

-- A column lit, dim, or in gold.
local function Lit(cell, how, base, tint)
	if how == "dim" then
		cell:SetBackdropColor(0, 0, 0, 0.25)
		cell:SetBackdropBorderColor(1, 1, 1, 0.06)
		cell.head:SetTextColor(GREY[1], GREY[2], GREY[3], 0.7)
		cell.text:SetTextColor(GREY[1], GREY[2], GREY[3], 0.8)
	elseif how == "gold" then
		cell:SetBackdropColor(1, 0.82, 0, 0.12)
		cell:SetBackdropBorderColor(1, 0.82, 0, 0.9)
		cell.head:SetTextColor(1, 0.82, 0, 1)
		cell.text:SetTextColor(tint[1], tint[2], tint[3], 1)
	else
		cell:SetBackdropColor(base[1], base[2], base[3], 0.2)
		cell:SetBackdropBorderColor(base[1], base[2], base[3], 0.55)
		cell.head:SetTextColor(tint[1], tint[2], tint[3], 0.85)
		cell.text:SetTextColor(tint[1], tint[2], tint[3], 1)
	end
end

-- A set's panel for the class and the star chosen: the panel washed in the
-- class's color, as This Run's rows are in theirs. The 4 pieces lit at every
-- star; the 8 pieces dim at 4 pieces, lit at 8, and at Empowered in gold, the
-- numbers that grow in gold.
local function PaintSetRow(row, kind, entry, step, base, tint)
	row.name:SetText(SurvivorUI_T(entry[3][kind[5]] or PVP_SET))
	-- The set's name and its rarity, one size.
	ItemName(row.name, 14)
	ItemName(row.rarity, 14)
	row:SetBackdropColor(0.04 + (base[1] - 0.04) * 0.16, 0.04 + (base[2] - 0.04) * 0.16, 0.04 + (base[3] - 0.04) * 0.16, 0.95)
	row:SetBackdropBorderColor(base[1], base[2], base[3], 0.4)
	Lit(row.four, "lit", base, tint)
	-- One 4-piece bonus for every class, but Tier 0.5's, the class's own.
	row.four.text:SetText(SurvivorUI_T(kind[6] or entry[5]))
	local line = entry[4][kind[5]]
	if step == 1 then
		Lit(row.eight, "dim", base, tint)
		row.eight.text:SetText(SetWords(line, false, ColorCode(GREY)))
	elseif step == 2 then
		Lit(row.eight, "lit", base, tint)
		row.eight.text:SetText(SetWords(line, false, ColorCode({ 1, 1, 1 })))
	else
		Lit(row.eight, "gold", base, tint)
		row.eight.text:SetText(SetWords(line, true, GOLD))
	end
	Fit.Cell(row.four)
	Fit.Cell(row.eight)
end

local function BuildSets(page)
	page.class = HeroSet()
	page.step = 1
	-- Each time the page opens, on the hero's class.
	function page.Again()
		page.class = HeroSet()
	end
	Title(page, SurvivorUI_T("Sets: seven for each class, 8 armor pieces each"))
	local count = table.getn(SETS)
	local width = math.floor((PAGE_WIDTH - (count - 1) * 4) / count)
	local chips, steps, rows = {}, {}, {}
	for index = 1, count do
		local chip = SetButton(page, (index - 1) * (width + 4), page.y, width, CHIP_HEIGHT)
		chip.tint = ClassTint(SETS[index][1])
		chip.text:SetText(SurvivorUI_T(SETS[index][2]))
		chip.index = index
		chip:SetScript("OnClick", function()
			page.class = this.index
			page.Draw()
		end)
		chips[index] = chip
	end
	-- A row of buttons at y, each width wide: so they stay while all their words
	-- fit; else they share the page's width by their words (a language's longer
	-- names), each its words' width and an even part of the rest, and a size
	-- smaller when even that is too narrow.
	local function Share(page, buttons, width, y)
		local count = table.getn(buttons)
		local room = PAGE_WIDTH - (count - 1) * 4
		local needs, total, widest = {}, 0, 0
		local function Measure()
			total, widest = 0, 0
			for index = 1, count do
				needs[index] = buttons[index].text:GetStringWidth() + 10
				total = total + needs[index]
				widest = math.max(widest, needs[index])
			end
		end
		Measure()
		if widest <= width then
			return
		end
		if total > room then
			for index = 1, count do
				Fit.Size(buttons[index].text, SMALL - 1)
			end
			Measure()
		end
		local spare = (room - total) / count
		local x = 0
		for index = 1, count do
			local button = buttons[index]
			local wide = math.floor(needs[index] + spare)
			if index == count then
				wide = PAGE_WIDTH - x
			end
			button:SetWidth(wide)
			button:ClearAllPoints()
			button:SetPoint("TOPLEFT", page, "TOPLEFT", x, y)
			x = x + wide + 4
		end
	end
	Share(page, chips, width, page.y)
	page.y = page.y - CHIP_HEIGHT - 4
	local third = math.floor((PAGE_WIDTH - 2 * 4) / 3)
	for index = 1, 3 do
		local step = SetButton(page, (index - 1) * (third + 4), page.y, third, CHIP_HEIGHT, true)
		step.text:SetText(SurvivorUI_T(SET_STEPS[index][1]))
		step.index = index
		step:SetScript("OnClick", function()
			page.step = this.index
			page.Draw()
		end)
		steps[index] = step
	end
	page.y = page.y - CHIP_HEIGHT - 4
	-- The star's rule in green, underlined.
	page.rule = Words(page, 2, page.y, PAGE_WIDTH - 4, "", SMALL + 1, GREEN)
	page.underline = page:CreateTexture(nil, "ARTWORK")
	page.underline:SetTexture(FLAT)
	page.underline:SetVertexColor(GREEN[1], GREEN[2], GREEN[3], 0.8)
	page.underline:SetHeight(1)
	page.underline:SetPoint("TOPLEFT", page.rule, "BOTTOMLEFT", 0, -1)
	page.y = page.y - 20
	local y = page.y
	for index = 1, table.getn(SET_KINDS) do
		local row, height = SetRow(page, SET_KINDS[index], y)
		rows[index] = row
		y = y - SET_CAPTION - height - 2
	end

	function page.Draw()
		local entry = SETS[page.class]
		local base = ClassTint(entry[1])
		local tint = Readable(base)
		for index = 1, count do
			local chip = chips[index]
			local color = chip.tint
			Chosen(chip, index == page.class)
			Paint(chip.text, Fore(color))
			if index == page.class then
				chip.fill:SetVertexColor(color[1], color[2], color[3], 1)
			else
				chip.fill:SetVertexColor(color[1] * 0.72, color[2] * 0.72, color[3] * 0.72, 1)
			end
		end
		-- The star chosen in gold, its words dark; the others dark and grey.
		for index = 1, 3 do
			local step = steps[index]
			Chosen(step, index == page.step, SET_STEPS[index][2])
			if index == page.step then
				step.fill:SetVertexColor(1, 0.82, 0, 1)
				Paint(step.text, { 0.08, 0.07, 0.05 })
			else
				step.fill:SetVertexColor(1, 0.82, 0, 0.08)
				Paint(step.text, { 0.6, 0.6, 0.6 })
			end
		end
		page.rule:SetText(SurvivorUI_T(SET_STEPS[page.step][3]))
		page.underline:SetWidth(page.rule:GetStringWidth())
		for index = 1, table.getn(SET_KINDS) do
			PaintSetRow(rows[index], SET_KINDS[index], entry, page.step, base, tint)
		end
	end
end

------------------------------------------------------------------------------
-- Jewels (JEWELS, read in the game by make_jewels_data.py): nothing in them is
-- rolled. The rarity sets a ring's or trinket's numbers; each time it is
-- taken again it adds less, and near its most the game stops offering it. An
-- amulet has one rarity, and taken again all its numbers grow toward 3 times.

-- The page's numbers and helpers in one table: the file is near Lua 5.0's 200 locals.
local Jewel = {}
Jewel.KINDS = { { SurvivorUI_T("Rings"), "ring" }, { SurvivorUI_T("Trinkets"), "trinket" }, { SurvivorUI_T("Amulets"), "amulet" } }
-- An item tooltip's name colors, Common to Legendary.
Jewel.QUALITY = { { 1, 1, 1 }, { 0.12, 1, 0 }, { 0, 0.44, 0.87 }, { 0.64, 0.21, 0.93 }, { 1, 0.5, 0 } }
Jewel.ROW = 27                  -- the amulets' 16 and their note over the foot's buttons
Jewel.ICON = 24
Jewel.ROWS = 16           -- the most a kind has: the amulets
Jewel.PICK = 62          -- a ring's or trinket's five: its first pick, three averages, its most
-- A ring's or trinket's columns (Lucas, 2026-11-09): its first pick, then the
-- average pick of 2 to 4, 5 to 8 and 9 to 14, every pick within about 11% of
-- its average, for one that divides each pick by 1 + 0.08 x picks so far.
-- One the game stops offering shows how many picks instead, and one with a
-- soft cap where it slows. Same groups as make_jewels_lua.py's GROUPS.
Jewel.GROUPS = { { 2, 4 }, { 5, 8 }, { 9, 14 } }
-- An amulet's columns (Lucas, 2026-11-08): ranks 1, 5 and 10, and a wider
-- one with its lines at the cap they close in on (x3, never quite reached:
-- the game has no last rank).
Jewel.RANK = 50
Jewel.CAP = 100                 -- the amulet's icon, its words in its tooltip
Jewel.RANKS = { 1, 5, 10 }
Jewel.TIP_RANKS = { 1, 5, 10 }

-- A jewel's line in the game's words, its numbers in.
function Jewel.Filled(template, fields, hits)
	return (string.gsub(SurvivorUI_T(template), "{(%a+)}", function(key)
		if key == "max" then
			return fields.max and SurvivorUI_T(" (max)") or ""
		elseif key == "hits" then
			return SurvivorUI_T(hits)
		elseif key == "who" then
			return SurvivorUI_T(JEWELS.who)
		end
		return fields[key]
	end))
end

-- Parts joined on one line, as many as fit the room, "..." for the rest.
-- A single part too wide (a language's longer words) goes a size smaller.
function Jewel.OneLine(text, parts, room)
	Fit.Size(text, SMALL - 1)
	local shown = parts[1]
	text:SetText(shown)
	if text:GetStringWidth() > room then
		Fit.Size(text, SMALL - 2)
		text:SetText(shown)
		-- Still too wide: words off its end, "..." for them (the tooltip has it whole).
		while text:GetStringWidth() > room do
			local _, _, before = string.find(shown, "^(.*) ")
			if not before then
				break
			end
			shown = before
			text:SetText(shown.." ...")
		end
		if text:GetText() ~= parts[1] then
			return
		end
	end
	for index = 2, table.getn(parts) do
		local more = shown..", "..parts[index]
		text:SetText(more)
		if text:GetStringWidth() > room then
			text:SetText(shown.." ...")
			return
		end
		shown = more
	end
end

-- A pick's number as its cell has it: what the pick adds (g, with a "+"), or
-- the total (v) for the Most column; "%" when the line has it after {v}.
function Jewel.PickNumber(entry, fields, total)
	return Jewel.Unit(entry, total and fields.v or "+"..fields.g)
end

-- A number of the line's {v}, with its "%" when the line has one.
function Jewel.Unit(entry, number)
	if string.find(entry[3], "{v}%", 1, true) then
		return number.."%"
	end
	return number
end

function Jewel.Tip()
	local entry, page = this.entry, this.page
	GameTooltip:SetOwner(this, "ANCHOR_NONE")
	GameTooltip:ClearAllPoints()
	GameTooltip:SetPoint("TOPLEFT", this, "BOTTOMLEFT", 0, -2)
	if page.kind == 3 then
		local tint = Jewel.QUALITY[entry[3]]
		GameTooltip:SetText(SurvivorUI_Native(entry[1]), tint[1], tint[2], tint[3])
		GameTooltip:AddLine(SurvivorUI_T(RARITIES[entry[3]][1]), 0.7, 0.7, 0.7)
		for each = 1, table.getn(Jewel.TIP_RANKS) do
			local rank = Jewel.TIP_RANKS[each]
			GameTooltip:AddLine(" ")
			GameTooltip:AddLine(SurvivorUI_TF("Rank {1}", rank), 1, 0.82, 0)
			for line = 1, table.getn(entry[6]) do
				local words = entry[6][line]
				GameTooltip:AddLine(Jewel.Filled(words[1], words[2][rank], entry[4]), 1, 1, 1, 1)
			end
		end
		GameTooltip:AddLine(" ")
		GameTooltip:AddLine(SurvivorUI_T("Taken again while worn: one rank more. Every number grows toward 3 times its first."), 0.7, 0.7, 0.7, 1)
	else
		local tint = Jewel.QUALITY[page.rarity]
		local picks = entry[5][page.rarity]
		GameTooltip:SetText(SurvivorUI_Native(entry[1]), tint[1], tint[2], tint[3])
		GameTooltip:AddLine(SurvivorUI_TF("Taken at {1} each time", SurvivorUI_T(RARITIES[page.rarity][1])), 0.7, 0.7, 0.7)
		-- A long climb (the Seal of the Damned's 22 at Common): its first 8, "...", its last.
		local count = table.getn(picks)
		for pick = 1, count do
			if count <= 10 or pick <= 8 or pick == count then
				-- What the pick adds, and the line as the game shows it then.
				GameTooltip:AddDoubleLine(SurvivorUI_TF("Pick {1}: {2}", pick, Jewel.PickNumber(entry, picks[pick])),
					Jewel.Filled(entry[3], picks[pick]), 1, 0.82, 0, 1, 1, 1)
			elseif pick == 9 then
				GameTooltip:AddLine("...", 1, 0.82, 0)
			end
		end
		GameTooltip:AddLine(" ")
		if entry[4] then
			GameTooltip:AddLine(SurvivorUI_T("After its last pick here, the game stops offering it."), 0.7, 0.7, 0.7, 1)
		else
			GameTooltip:AddLine(SurvivorUI_T("No most: it is offered again and again, each pick adding a little less."), 0.7, 0.7, 0.7, 1)
		end
	end
	GameTooltip:Show()
	SolidTip()
end

-- An amulet at its cap, as its own tooltip would read: its name in its
-- rarity's color, its rarity, and its lines, the growing numbers at 3 times.
function Jewel.CapTip()
	local entry = this.row.entry
	local tint = Jewel.QUALITY[entry[3]]
	GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
	GameTooltip:SetText(SurvivorUI_Native(entry[1]), tint[1], tint[2], tint[3])
	GameTooltip:AddLine(SurvivorUI_T(RARITIES[entry[3]][1]), 0.7, 0.7, 0.7)
	GameTooltip:AddLine(SurvivorUI_T("Capped at x3.00"), 1, 0.82, 0)
	for line = 1, table.getn(entry[6]) do
		local words = entry[6][line]
		GameTooltip:AddLine(Jewel.Filled(words[1], words[3], entry[4]), 1, 1, 1, 1)
	end
	GameTooltip:Show()
	SolidTip()
end

local function BuildJewels(page)
	page.kind, page.rarity = 1, 5
	Title(page, SurvivorUI_T("Jewels: nothing is rolled"))
	Para(page, SurvivorUI_T("A jewel's rarity sets its numbers. Each pick adds a bit less than the one before: Avg is what one pick adds on average. Most is the total at its last."), 1)
	local kinds, grades = {}, {}
	local x = 0
	for index = 1, 3 do
		local chip = SetButton(page, x, page.y, 78, CHIP_HEIGHT)
		chip.text:SetText(SurvivorUI_T(Jewel.KINDS[index][1]))
		chip.index = index
		chip:SetScript("OnClick", function()
			page.kind = this.index
			page.Draw()
		end)
		kinds[index] = chip
		x = x + 82
	end
	x = x + 10
	local wide = math.floor((PAGE_WIDTH - x - 4 * 4) / 5)
	for index = 1, 5 do
		local grade = SetButton(page, x + (index - 1) * (wide + 4), page.y, wide, CHIP_HEIGHT)
		grade.text:SetText(SurvivorUI_T(RARITIES[index][1]))
		grade.index = index
		grade:SetScript("OnClick", function()
			page.rarity = this.index
			page.Draw()
		end)
		grades[index] = grade
	end
	page.y = page.y - CHIP_HEIGHT - 8
	-- The columns' names over them, right-aligned to the page's edge.
	local heads = {}
	for index = 1, 6 do
		local head = Text(page, "GameFontNormal", SMALL)
		head:SetJustifyH("CENTER")
		heads[index] = head
	end
	page.what = Text(page, "GameFontNormal", SMALL)
	page.what:SetPoint("TOPLEFT", page, "TOPLEFT", 2, page.y)
	local top = page.y
	page.y = page.y - 16
	local rows = {}
	for index = 1, Jewel.ROWS do
		local row = CreateFrame("Button", nil, page)
		row.noHoverOutline = true
		row.page = page
		row:SetWidth(PAGE_WIDTH)
		row:SetHeight(Jewel.ROW)
		row:SetPoint("TOPLEFT", page, "TOPLEFT", 0, page.y - (index - 1) * Jewel.ROW)
		row.stripe = row:CreateTexture(nil, "BACKGROUND")
		row.stripe:SetTexture(FLAT)
		row.stripe:SetAllPoints(row)
		row.stripe:SetVertexColor(1, 1, 1, math.mod(index, 2) == 1 and 0.04 or 0)
		row:SetHighlightTexture(HIGHLIGHT, "ADD")
		row.icon = row:CreateTexture(nil, "ARTWORK")
		row.icon:SetWidth(Jewel.ICON)
		row.icon:SetHeight(Jewel.ICON)
		row.icon:SetPoint("LEFT", row, "LEFT", 2, 0)
		row.name = Text(row, "GameFontNormal", SMALL + 1)
		row.name:SetPoint("TOPLEFT", row, "TOPLEFT", Jewel.ICON + 7, -2)
		ItemName(row.name, SMALL + 1)
		row.line = Text(row, "GameFontHighlight", SMALL - 1)
		row.line:SetPoint("TOPLEFT", row, "TOPLEFT", Jewel.ICON + 7, -16)
		row.cells = {}
		for each = 1, 6 do
			local cell = Text(row, "GameFontHighlight", SMALL)
			cell:SetJustifyH("CENTER")
			row.cells[each] = cell
		end
		row:SetScript("OnEnter", Jewel.Tip)
		row:SetScript("OnLeave", CloseTip)
		-- An amulet's icon in its Cap column (Lucas, 2026-11-08): hovered, the
		-- item as it reads at its cap.
		row.cap = CreateFrame("Button", nil, row)
		row.cap.noHoverOutline = true
		row.cap:SetWidth(Jewel.ICON - 2)
		row.cap:SetHeight(Jewel.ICON - 2)
		row.cap.icon = row.cap:CreateTexture(nil, "ARTWORK")
		row.cap.icon:SetAllPoints(row.cap)
		row.cap:SetHighlightTexture(HIGHLIGHT, "ADD")
		row.cap.row = row
		row.cap:SetScript("OnEnter", Jewel.CapTip)
		row.cap:SetScript("OnLeave", CloseTip)
		rows[index] = row
	end
	-- Under the amulets, how they grow, as simply as it goes (read in the
	-- game's 0.142: an amulet is offered in its own rarity only, and taking
	-- the one worn again is one rank up, whatever the card).
	page.note = Words(page, 2, page.y - Jewel.ROWS * Jewel.ROW - 6, PAGE_WIDTH - 4, "", SMALL, { 0.8, 0.8, 0.8 })

	function page.Draw()
		local amulets = page.kind == 3
		if amulets then
			page.note:SetText(SurvivorUI_T("An amulet never changes rarity. Take the one you wear again and it goes up a rank: its numbers grow, a bit less each time, toward 3 times. Rarer ones climb slower."))
			page.note:Show()
		else
			page.note:Hide()
		end
		for index = 1, 3 do
			local chip = kinds[index]
			Chosen(chip, index == page.kind)
			if index == page.kind then
				chip.fill:SetVertexColor(1, 0.82, 0, 1)
				Paint(chip.text, { 0.08, 0.07, 0.05 })
			else
				chip.fill:SetVertexColor(1, 0.82, 0, 0.08)
				Paint(chip.text, { 0.6, 0.6, 0.6 })
			end
		end
		for index = 1, 5 do
			local grade = grades[index]
			local tint = Jewel.QUALITY[index]
			if amulets then
				grade:Hide()
			else
				grade:Show()
				Chosen(grade, index == page.rarity)
				if index == page.rarity then
					grade.fill:SetVertexColor(tint[1], tint[2], tint[3], 1)
					Paint(grade.text, Fore(tint))
				else
					grade.fill:SetVertexColor(tint[1] * 0.3, tint[2] * 0.3, tint[3] * 0.3, 1)
					Paint(grade.text, tint)
				end
			end
		end
		local columns, width = 5, Jewel.PICK
		local left = PAGE_WIDTH - columns * width
		if amulets then
			-- Three rank columns, then the wide one at the cap.
			columns, width = 4, Jewel.RANK
			left = PAGE_WIDTH - 3 * width - Jewel.CAP
		end
		for index = 1, 6 do
			local head = heads[index]
			if index > columns then
				head:Hide()
			else
				head:Show()
				head:ClearAllPoints()
				head:SetPoint("TOPLEFT", page, "TOPLEFT", left + (index - 1) * width, top)
				head:SetWidth(amulets and index == 4 and Jewel.CAP or width)
				if amulets and index == 4 then
					head:SetText(SurvivorUI_T("Capped at x3.00"))
				elseif amulets then
					head:SetText(SurvivorUI_TF("Rank {1}", Jewel.RANKS[index]))
				elseif index == 5 then
					head:SetText(SurvivorUI_T("Most"))
				elseif index == 1 then
					head:SetText(SurvivorUI_T("First pick"))
				else
					local group = Jewel.GROUPS[index - 1]
					head:SetText(SurvivorUI_TF("Avg {1}-{2}", group[1], group[2]))
				end
			end
		end
		if amulets then
			page.what:SetText(SurvivorUI_T("Each number's size by rank"))
		else
			page.what:SetText(SurvivorUI_T("What each pick adds"))
		end
		page.what:ClearAllPoints()
		page.what:SetPoint("TOPRIGHT", page, "TOPLEFT", left - 6, top)
		local list = JEWELS[Jewel.KINDS[page.kind][2]]
		for index = 1, Jewel.ROWS do
			local row, entry = rows[index], list[index]
			if not entry then
				row:Hide()
			else
				row:Show()
				row.entry = entry
				row.icon:SetTexture("Interface\\Icons\\"..entry[2])
				row.name:SetText(SurvivorUI_Native(entry[1]))
				-- Room for the line, with a gap before the first column's centered number.
				local room = left - Jewel.ICON - 18
				-- A name too long for it (a language's longer words): a size smaller.
				Fit.Size(row.name, SMALL + 1)
				if row.name:GetStringWidth() > room then
					Fit.Size(row.name, SMALL)
				end
				local cells = row.cells
				if amulets then
					Paint(row.name, Jewel.QUALITY[entry[3]])
					local parts = {}
					for line = 1, table.getn(entry[6]) do
						local words = entry[6][line]
						parts[line] = Jewel.Filled(words[1], words[2][1], entry[4])
					end
					Jewel.OneLine(row.line, parts, room)
					for each = 1, 6 do
						local cell = cells[each]
						cell:ClearAllPoints()
						if each > 4 then
							cell:Hide()
						elseif each == 4 then
							-- Its icon in the middle of the Cap column; its words in its tooltip.
							cell:Hide()
							row.cap.icon:SetTexture("Interface\\Icons\\"..entry[2])
							row.cap:ClearAllPoints()
							row.cap:SetPoint("CENTER", row, "LEFT", left + 3 * width + Jewel.CAP / 2, 0)
							row.cap:Show()
						else
							cell:Show()
							cell:SetPoint("LEFT", row, "LEFT", left + (each - 1) * width, 0)
							cell:SetWidth(width)
							cell:SetJustifyH("CENTER")
							Fit.Size(cell, SMALL)
							cell:SetText(string.format("x%.2f", entry[5][Jewel.RANKS[each]] / 100))
							Paint(cell, { 1, 1, 1 })
						end
					end
				else
					row.cap:Hide()
					Paint(row.name, Jewel.QUALITY[page.rarity])
					local picks = entry[5][page.rarity]
					local count = table.getn(picks)
					-- Averages by rarity, a soft cap's number, or false (the game stops offering it).
					local averages = type(entry[6]) == "table" and entry[6][page.rarity]
					Jewel.OneLine(row.line, { Jewel.Filled(entry[3], picks[1]) }, room)
					for each = 1, 6 do
						local cell = cells[each]
						cell:ClearAllPoints()
						cell:SetPoint("LEFT", row, "LEFT", left + (each - 1) * width, 0)
						cell:SetWidth(width)
						-- Back from the amulets' wide cap cell.
						cell:SetJustifyH("CENTER")
						Fit.Size(cell, SMALL)
						cell:Show()
						if each == 6 or (each > 2 and each < 5 and not averages) then
							-- Past the columns, or under the words of a cell spread over the three averages.
							cell:Hide()
						elseif each == 5 then
							if entry[4] then
								cell:SetText(Jewel.PickNumber(entry, picks[count], true))
								Paint(cell, YELLOW)
							else
								cell:SetText(SurvivorUI_T("no cap"))
								Paint(cell, GREY)
							end
						elseif each == 1 then
							cell:SetText(Jewel.PickNumber(entry, picks[1]))
							Paint(cell, { 1, 1, 1 })
						elseif averages then
							cell:SetText(Jewel.Unit(entry, "+"..averages[each - 1]))
							Paint(cell, { 1, 1, 1 })
						else
							-- The three averages' room, in words: how many picks, or where it slows.
							cell:SetWidth(3 * width)
							if entry[6] then
								cell:SetText(SurvivorUI_TF("Slows down past {1}", Jewel.Unit(entry, entry[6])))
							elseif count == 1 then
								cell:SetText(SurvivorUI_T("Only one pick"))
							else
								cell:SetText(SurvivorUI_TF("Offered {1} times, then no more", count))
							end
							Paint(cell, GREY)
						end
					end
				end
				Paint(row.line, { 0.75, 0.75, 0.75 })
			end
		end
	end
end

------------------------------------------------------------------------------
-- The window: the pages' names down its left, as the options' tabs.

local PAGES = {
	{ "Luck", "luckladder", BuildLuck },  -- a new key: the page made over (2026-11-09) shows as unread
	{ "Damage", "damage", BuildDamage },
	{ "Crit", "crit", BuildCrit },
	{ "Haste", "haste", BuildHaste },
	{ "DoTs", "dots", BuildDots },
	{ "Not DoTs", "ground", BuildGround },
	{ "Reduction", "armor", BuildArmor },
	{ "Speed", "reach", BuildReach },
	{ "Marks", "marks", BuildMarks },
	{ "Sets", "sets", BuildSets },
	{ "Jewels", "jewels", BuildJewels },
}

local divider = window:CreateTexture(nil, "ARTWORK")
divider:SetTexture(FLAT)
divider:SetVertexColor(1, 0.82, 0, 0.25)
divider:SetWidth(1)
divider:SetPoint("TOPLEFT", window, "TOPLEFT", LEFT - 12, PAGE_TOP)
divider:SetPoint("BOTTOMLEFT", window, "BOTTOMLEFT", LEFT - 12, 36)

local back = FlatButton(window, SurvivorUI_T("Previous"), 84)
back:SetPoint("BOTTOMLEFT", window, "BOTTOMLEFT", LEFT, 10)
local forward = FlatButton(window, SurvivorUI_T("Next"), 84)
forward:SetPoint("LEFT", back, "RIGHT", 6, 0)
-- Close in the foot's right corner, in red, apart from the pages' two.
local shut = FlatButton(window, SurvivorUI_T("Close"), 84)
shut:SetPoint("BOTTOMRIGHT", window, "BOTTOMRIGHT", -14, 10)
shut:SetBackdropColor(0.32, 0.07, 0.07, 1)
shut:SetBackdropBorderColor(0.7, 0.22, 0.22, 1)
shut:SetScript("OnLeave", function() this:SetBackdropBorderColor(0.7, 0.22, 0.22, 1) end)
shut:SetScript("OnClick", function() window:Hide() end)
-- The page's number beside the title, small and grey, the two together in the
-- middle.
local numbered = Text(window, "GameFontDisableSmall")
numbered:SetPoint("LEFT", window.heading, "RIGHT", 5, 0)

-- The pages read, kept in the addon's settings.
local function Reads()
	SurvivorUIDB = SurvivorUIDB or {}
	SurvivorUIDB.guideRead = SurvivorUIDB.guideRead or {}
	return SurvivorUIDB.guideRead
end

local function Unread()
	local read = Reads()
	for index = 1, table.getn(PAGES) do
		if not read[PAGES[index][2]] then
			return true
		end
	end
	return false
end

local function Build(index)
	if pages[index] then
		return pages[index]
	end
	local page = CreateFrame("Frame", nil, window)
	page:SetPoint("TOPLEFT", window, "TOPLEFT", LEFT, PAGE_TOP)
	page:SetWidth(PAGE_WIDTH)
	page:SetHeight(HEIGHT + PAGE_TOP - 50)
	page.y = 0
	PAGES[index][3](page)
	page:Hide()
	pages[index] = page
	return page
end

local function Select(index)
	current = index
	for each = 1, table.getn(PAGES) do
		if pages[each] then
			pages[each]:Hide()
		end
		if each == index then
			tabs[each].selected:Show()
		else
			tabs[each].selected:Hide()
		end
	end
	Reads()[PAGES[index][2]] = true
	tabs[index].unread:Hide()
	FromHero()
	local page = Build(index)
	if page.Again then
		page.Again()
	end
	page:Show()
	page.Draw()
	numbered:SetText(SurvivorUI_TF("(page {1} of {2})", index, table.getn(PAGES)))
	local point, relative, relativePoint, _, y = window.heading:GetPoint(1)
	window.heading:SetPoint(point, relative, relativePoint, -(numbered:GetStringWidth() + 5) / 2, y)
	Able(back, index > 1)
	Able(forward, index < table.getn(PAGES))
	if SurvivorUI_PaintGuideButton then
		SurvivorUI_PaintGuideButton()
	end
end

back:SetScript("OnClick", function() Select(current - 1) end)
forward:SetScript("OnClick", function() Select(current + 1) end)

for index = 1, table.getn(PAGES) do
	local tab = CreateFrame("Button", nil, window)
	tab.noHoverOutline = true
	tab:SetWidth(LEFT - 34)
	tab:SetHeight(20)
	tab:SetPoint("TOPLEFT", window, "TOPLEFT", 18, PAGE_TOP - (index - 1) * 22)
	tab.text = Text(tab, "GameFontNormal")
	tab.text:SetPoint("LEFT", tab, "LEFT", 8, 0)
	tab.text:SetText(SurvivorUI_T(PAGES[index][1]))
	tab.lit = tab:CreateTexture(nil, "BACKGROUND")
	tab.lit:SetTexture(FLAT)
	tab.lit:SetVertexColor(1, 1, 1, 0.07)
	tab.lit:SetAllPoints(tab)
	tab.lit:Hide()
	tab.selected = tab:CreateTexture(nil, "BORDER")
	tab.selected:SetTexture(FLAT)
	tab.selected:SetVertexColor(1, 0.82, 0, 0.2)
	tab.selected:SetAllPoints(tab)
	tab.selected:Hide()
	tab.unread = tab:CreateTexture(nil, "OVERLAY")
	tab.unread:SetTexture(NEW_MARK)
	tab.unread:SetWidth(16)
	tab.unread:SetHeight(16)
	tab.unread:SetPoint("RIGHT", tab, "RIGHT", -4, 0)
	tab.index = index
	tab:SetScript("OnEnter", function() this.lit:Show() end)
	tab:SetScript("OnLeave", function() this.lit:Hide() end)
	tab:SetScript("OnClick", function()
		Select(this.index)
	end)
	tabs[index] = tab
end

-- Closed with a tooltip up, no card hears the mouse leave.
window:SetScript("OnHide", function()
	if tipFloor then
		tipFloor:Hide()
	end
end)

-- A page by its number.
function SurvivorUI_GuidePage(index)
	window:Show()
	Select(index)
end

function SurvivorUI_ToggleGuide()
	if window:IsShown() then
		window:Hide()
	else
		window:Show()
		Select(current or 1)
	end
end

-- Whether a page waits to be read, for the button on the stack.
SurvivorUI_GuideUnread = Unread

local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_ENTERING_WORLD")
loader:SetScript("OnEvent", function()
	for index = 1, table.getn(PAGES) do
		if Reads()[PAGES[index][2]] then
			tabs[index].unread:Hide()
		end
	end
end)
