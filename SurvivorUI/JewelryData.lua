-- Survivor UI - Copyright (C) 2026 morderous - GPL-3.0 - github.com/morderous/survivor-ui
-- Survivor UI: the pieces every class can find, as the game's Codex lists
-- them, for the Jewelry Collection: their names, so the ones still to find
-- show by name, and what each gives.
--
-- Rings and trinkets come in every rarity: the bonus at each, Common to
-- Legendary (nil where not read). An amulet has one rarity of its own and its
-- bonuses. The legendary amulets made for one class's spell are left out: the
-- collection learns those as they are found.

SurvivorUI_JEWELRY = {
	edition = "c.1017.m",
	Ring = {
		{ "Archimtiros' Ring of Reckoning", { "+4.4% damage reduction, +18% max health", "+5.8% damage reduction, +23% max health", "+7% damage reduction, +28% max health", "+8.5% damage reduction, +34% max health", "+10% damage reduction, +40% max health" } },
		{ "Band of Accuria", { "+26% damage", "+36% damage", "+46% damage", "+61% damage", "+82% damage" } },
		{ "Blooddrinker's Band", { "1.5% of damage dealt heals", "2.1% of damage dealt heals", "2.7% of damage dealt heals", "3.0% of damage dealt heals", "3.0% of damage dealt heals" } },
		{ "Heavy Dark Iron Ring", { "+25% max health", "+33% max health", "+40% max health", "+48% max health", "+57% max health" } },
		{ "Master Dragonslayer's Ring", { "+6% critical strike chance", "+8% critical strike chance", "+11% critical strike chance", "+14% critical strike chance", "+19% critical strike chance" } },
		{ "Quick Strike Ring", { "-14% cooldowns", "-19% cooldowns", "-24% cooldowns", "-32% cooldowns", "-43% cooldowns" } },
		{ "Ring of Spell Power", { "+21% area of effect", "+29% area of effect", "+38% area of effect", "+50% area of effect", "+67% area of effect" } },
		{ "Ring of the Devoured", { "+2.2 health per second", "+3.1 health per second", "+4.0 health per second", "+4.5 health per second", "+4.5 health per second" } },
		{ "Seal of the Damned", { "Faster damage over time", "Faster damage over time", "Faster damage over time", "Faster damage over time", "Faster damage over time" } },
	},
	Trinket = {
		{ "Blackhand's Breadth", { "+29% critical strike damage", "+41% critical strike damage", "+53% critical strike damage", "+70% critical strike damage", "+94% critical strike damage" } },
		{ "Carrot on a Stick", { "+12% movement speed", "+17% movement speed", "+22% movement speed", "+29% movement speed", "+38% movement speed" } },
		{ "Earthstrike", { "+20% damage", "+27% damage", "+35% damage", "+47% damage", "+62% damage" } },
		{ "Gnomish Universal Remote", { "+52% pickup range", "+73% pickup range", "+94% pickup range", "+126% pickup range", "+168% pickup range" } },
		{ "Hand of Justice", { "9% chance to cast twice", "13% chance to cast twice", nil, "22% chance to cast twice", "29% chance to cast twice" } },
		{ "Horn of the Warchief", { "Buffs 22% stronger", "Buffs 32% stronger", "Buffs 41% stronger", "Buffs 54% stronger", "Buffs 72% stronger" } },
		{ "Insignia of the Horde", { "+18% experience", "+25% experience", "+32% experience", "+43% experience", "+58% experience" } },
		{ "Lifegiving Gem", { "+20% max health", "+26% max health", "+32% max health", "+39% max health", "+46% max health" } },
		{ "Major Soulstone", { "+1 return to life", "+1 return to life", nil, "+2 returns to life", "+2 returns to life" } },
		{ "Mark of the Chosen", { "+22% luck", "+32% luck", "+41% luck", "+54% luck", "+72% luck" } },
		{ "Onyxia Blood Talisman", { "Each kill heals 3.0", "Each kill heals 4.2", "Each kill heals 5.4", "Each kill heals 6.0", "Each kill heals 6.0" } },
		{ "Royal Seal of Eldre'Thalas", { "+38% gold", "+52% gold", "+67% gold", "+90% gold", "+120% gold" } },
		{ "Star of Mystaria", { "+25% max health, +4% damage reduction", nil, nil, nil, nil } },
		{ "Talisman of Ephemeral Power", { "-10% cooldowns", "-15% cooldowns", "-19% cooldowns", "-25% cooldowns", "-34% cooldowns" } },
	},
	-- Amulets: name, rarity, bonuses: the codex's 16 (the Star of Mystaria is
	-- a trinket since the game's 0.111).
	Neck = {
		{ "Amulet of Vek'nilash", "Epic", { "Your spells: +1 target", "+5% damage" } },
		{ "Amulet of the Darkmoon", "Uncommon", { "-12% cooldowns", "+8% movement speed" } },
		{ "Animated Chain Necklace", "Uncommon", { "+25% max health", "+8% damage reduction" } },
		{ "Choker of Enlightenment", "Epic", { "Your hits leap to 1 more enemy for 30%" } },
		{ "Choker of the Fire Lord", "Legendary", { "Enemies you kill explode for 15% of their max health" } },
		{ "Jeklik's Opaline Talisman", "Rare", { "3% of damage dealt heals", "Each kill heals 1.0" } },
		{ "Malice Stone Pendant", "Epic", { "20% chance to cast twice", "-8% cooldowns" } },
		{ "Mark of Fordring", "Common", { "+15% damage" } },
		{ "Medallion of Steadfast Might", "Rare", { "+10% damage reduction", "+15% max health", "Melee attackers take 100% of their damage" } },
		{ "Onyxia Tooth Pendant", "Legendary", { "+4% critical strike", "+20% critical strike damage", "Crits splash 30% within 5 yd" } },
		{ "Pendant of the Fallen Dragon", "Epic", { "A killing blow leaves you at 50% health, once every 60 sec", "+20% max health", "+5.0 health per second" } },
		{ "Prestor's Talisman of Connivery", "Uncommon", { "+16% damage", "+4% critical strike" } },
		{ "Pristine Enchanted South Seas Kelp", "Common", { "+30% luck", "+25% gold" } },
		{ "Talvash's Enhancing Necklace", "Common", { "-10% cooldowns" } },
		{ "The Eye of Hakkar", "Rare", { "+5% critical strike", "Crits burn and bleed for 80% more over 4 sec" } },
		{ "Woven Ivy Necklace", "Uncommon", { "+6.0 health per second", "+12% max health", "+12% movement speed" } },
	},
}
