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
	{ "Common", { 0.62, 0.62, 0.62 }, "60" },
	{ "Uncommon", { 0.12, 1, 0 }, "25 x m" },
	{ "Rare", { 0.2, 0.55, 1 }, "10 x m x m" },
	{ "Epic", { 0.64, 0.21, 0.93 }, "4 x m x m x m" },
	{ "Legendary", { 1, 0.5, 0 }, "1 x m x m x m x m" },
}
local GRID, GRID_MARBLE = 10, 15
local BAG_HEIGHT = 190
local BAG_WIDTH = 442
local COUNT_AT, PERCENT_AT = 320, 416  -- the bag's columns
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

-- A hundred marbles out of the shares, the largest remainders getting the rest.
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

local function BuildLuck(page)
	Title(page, SurvivorUI_T("Luck: the bag of marbles"))
	Para(page, SurvivorUI_T("Every card the game shows you comes out of a big bag of marbles. The game reaches in without looking, pulls out one marble, and its color is the card's rarity."), 2)
	Para(page, SurvivorUI_T("Luck never takes a marble out. It pours new ones in, and the shinier the marble, the faster it multiplies!"), 2)
	local top = page.y
	local bag = Box(page, SurvivorUI_T("What's in the bag"), nil, 0, top, BAG_WIDTH, BAG_HEIGHT)
	Words(bag, 10, -28, BAG_WIDTH - 20, SurvivorUI_T("|cffffd100m|r is your magic number: 1 + Luck + Level"))
	page.magic = Words(bag, 10, -44, BAG_WIDTH - 20, "")
	local rows, widest = {}, 0
	for index = 1, table.getn(RARITIES) do
		local rarity = RARITIES[index]
		local y = -64 - (index - 1) * 16
		local marble = bag:CreateTexture(nil, "ARTWORK")
		marble:SetTexture(MARBLE)
		marble:SetVertexColor(rarity[2][1], rarity[2][2], rarity[2][3])
		marble:SetWidth(13)
		marble:SetHeight(13)
		marble:SetPoint("TOPLEFT", bag, "TOPLEFT", 10, y)
		local name = Words(bag, 28, y, 100, SurvivorUI_T(rarity[1]), TEXT, rarity[2])
		widest = math.max(widest, name:GetStringWidth())
		local formula = Words(bag, 118, y, 120, rarity[3], SMALL + 1, { 0.8, 0.8, 0.8 })
		local count = Text(bag, "GameFontHighlight", TEXT)
		count:SetPoint("TOPRIGHT", bag, "TOPLEFT", COUNT_AT, y)
		local percent = Text(bag, "GameFontHighlight", TEXT)
		percent:SetPoint("TOPRIGHT", bag, "TOPLEFT", PERCENT_AT, y)
		Paint(percent, rarity[2])
		rows[index] = { count = count, percent = percent, formula = formula, y = y }
	end
	-- The formulas past the longest name (a language's longer words).
	if 28 + widest + 8 > 118 then
		for index = 1, table.getn(rows) do
			rows[index].formula:ClearAllPoints()
			rows[index].formula:SetPoint("TOPLEFT", bag, "TOPLEFT", 28 + widest + 8, rows[index].y)
		end
	end
	page.total = Words(bag, 10, -148, BAG_WIDTH - 20, "")
	page.three = Words(bag, 10, -166, BAG_WIDTH - 20, "")
	local hundred = Box(page, SurvivorUI_T("Out of 100 cards"), nil, BAG_WIDTH + 8, top, PAGE_WIDTH - BAG_WIDTH - 8, BAG_HEIGHT)
	local marbles = {}
	local left = math.floor((PAGE_WIDTH - BAG_WIDTH - 8 - GRID * GRID_MARBLE) / 2)
	for index = 1, GRID * GRID do
		local marble = hundred:CreateTexture(nil, "ARTWORK")
		marble:SetTexture(MARBLE)
		marble:SetWidth(GRID_MARBLE - 1)
		marble:SetHeight(GRID_MARBLE - 1)
		marble:SetPoint("TOPLEFT", hundred, "TOPLEFT", left + math.mod(index - 1, GRID) * GRID_MARBLE,
			-28 - math.floor((index - 1) / GRID) * GRID_MARBLE)
		marbles[index] = marble
	end
	page.y = top - BAG_HEIGHT - 26
	local luck = Try(page, 8, page.y, 180, SurvivorUI_T("Luck"), 0, 3, 0.05, Signed, function(value) try.luck = value end)
	local level = Try(page, 212, page.y, 180, SurvivorUI_T("Level"), 1, 120, 1, function(value) return tostring(value) end,
		function(value) try.level = value end)
	MyHero(page, 412, page.y + 4)
	page.y = page.y - 34
	Tip(page, SurvivorUI_T("|cffffd100Three cards, three pulls.|r Every card is pulled on its own."))
	Tip(page, SurvivorUI_T("|cffffd100Level|r gives 1% a level, up to 30%. |cffffd100Luck has no top!|r"))
	Tip(page, SurvivorUI_T("|cffffd100Amulets are shinier:|r they pull with m + 0.5."))
	Tip(page, SurvivorUI_T("|cffffd100A guardian or boss hoard cache|r has 25% more Luck (m + 0.25)."))

	function page.Draw()
		local part = math.min(try.level * 0.01, 0.3)
		local m = 1 + try.luck + part
		local odds, weights = CardOdds(m)
		luck.Read(try.luck)
		level.Read(try.level)
		page.magic:SetText(string.format("1 + %.2f + %.2f = "..GOLD.."%.2f|r", try.luck, part, m))
		local total = 0
		for index = 1, 5 do
			total = total + weights[index]
			rows[index].count:SetText(string.format("%.0f", weights[index]))
			rows[index].percent:SetText(string.format("%.1f%%", odds[index] * 100))
		end
		page.total:SetText(string.format(SurvivorUI_T("%.0f marbles in the bag, %.0f of them orange."), total, weights[5]))
		local none = 1 - odds[5]
		page.three:SetText(string.format(SurvivorUI_T("A legendary among 3 cards: |cffffd100%.1f%%|r"), (1 - none * none * none) * 100))
		local counts = Hundred(odds)
		local at = 0
		for index = 5, 1, -1 do
			local color = RARITIES[index][2]
			for each = 1, counts[index] do
				at = at + 1
				marbles[at]:SetVertexColor(color[1], color[2], color[3])
			end
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
		{ SurvivorUI_T("1. Earn"), SurvivorUI_T("Bosses pay marks when they fall. A piece you already own pays marks instead. Heroic pays more.") },
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
-- The window: the pages' names down its left, as the options' tabs.

local PAGES = {
	{ "Luck", "luck", BuildLuck },
	{ "Damage", "damage", BuildDamage },
	{ "Crit", "crit", BuildCrit },
	{ "Haste", "haste", BuildHaste },
	{ "DoTs", "dots", BuildDots },
	{ "Not DoTs", "ground", BuildGround },
	{ "Reduction", "armor", BuildArmor },
	{ "Speed", "reach", BuildReach },
	{ "Marks", "marks", BuildMarks },
	{ "Sets", "sets", BuildSets },
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
