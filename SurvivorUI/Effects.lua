-- Survivor UI - Copyright (C) 2026 morderous - GPL-3.0 - github.com/morderous/survivor-ui
-- Survivor UI: the records' effects (the Records tab). A record's notice (the
-- new best crit, SurvivorUI.lua; the new jump record, Jumps.lua) stands still
-- a moment over one of these, each record its own (asked for 2026-10-24):
--
--   Fire       a bed of flames licking up, embers rising and swaying, sparks
--              crackling, the number glowing like a coal
--   Lightning  bolts lashing out from the number and striking down on it,
--              the whole flashing blue-white, sparks at their ends
--   Radiant    a golden halo breathing, pillars of light rising and fading,
--              motes drifting up, stars twinkling round (the crit's, before)
--   Frost      ice shards flung out, a crown of frost crystals glinting,
--              snow drifting down, the number ice-white
--   Void       a violet core drawn in on itself, orbs circling with their
--              trails, motes spiralling into the middle
--   Physical   a blow: three claw slashes torn across the number, a
--              shockwave ring, red sparks and drops flung out and falling,
--              the number shaken; another blow every so often
--   Nature     sprouts growing up behind the number and swaying, leaves
--              spiralling out and drifting, pollen rising, the number leaf-green
--
-- In the kill pace orb's manner (Pace.lua): soft glows, pools of small art
-- added in light (ADD), each piece moving on its own. A soft dark smoke
-- behind each, so it reads on Elwynn's bright grass too.
--
--   SurvivorUI_RecordFxStart(host, kind, scale, numberY) as a notice shows,
--   SurvivorUI_RecordFxUpdate(host, age, elapsed, holding) every frame it
--   shows (holding: new pieces still come), SurvivorUI_RecordFxStop(host) as
--   it goes. host.number, the notice's number, takes the effect's colors.

local ART = "Interface\\AddOns\\SurvivorUI\\Art\\"
local PARTS = 64                -- particles at most
local DOTS = 320                -- the lightning's dots
local SHAPES = 9                -- flames, pillars of light, frost crystals

SurvivorUI_RECORD_FX = {
	{ "fire", "Fire" },
	{ "lightning", "Lightning" },
	{ "radiant", "Radiant" },
	{ "frost", "Frost" },
	{ "void", "Void" },
	{ "physical", "Physical" },
	{ "nature", "Nature" },
}
local DEFAULT_FX = { crit = "radiant", jump = "fire" }

-- The effects chosen for a class (asked for 2026-10-26), in
-- SurvivorUIDB.recordFxByClass[class]: { crit, jump }; made with make. The
-- class's token (WARRIOR...), the hero's unless given (the Records tab picks
-- any class).
local function ClassFx(make, class)
	if not class then
		local _, mine = UnitClass("player")
		class = mine or "UNKNOWN"
	end
	local byClass = SurvivorUIDB.recordFxByClass
	if make and not byClass then
		byClass = {}
		SurvivorUIDB.recordFxByClass = byClass
	end
	local mine = byClass and byClass[class]
	if make and not mine then
		mine = {}
		byClass[class] = mine
	end
	return mine
end

-- The effect a record wears (the Records tab): "crit" or "jump". A class's
-- (the hero's unless given); a class not chosen for yet wears what was chosen
-- for every class before (critRecordFx, jumpRecordFx), else the default.
function SurvivorUI_RecordFxKind(which, class)
	local key
	if SurvivorUIDB then
		local mine = ClassFx(false, class)
		key = mine and mine[which] or SurvivorUIDB[which.."RecordFx"]
	end
	for index = 1, table.getn(SurvivorUI_RECORD_FX) do
		if SurvivorUI_RECORD_FX[index][1] == key then
			return key
		end
	end
	return DEFAULT_FX[which] or "fire"
end

function SurvivorUI_SetRecordFx(which, kind, class)
	SurvivorUIDB = SurvivorUIDB or {}
	ClassFx(true, class)[which] = kind
end

------------------------------------------------------------------------------
-- The pieces, made once a host, on first use.

local function Texture(parent, layer, art, add)
	local texture = parent:CreateTexture(nil, layer)
	texture:SetTexture(ART..art)
	if add then
		texture:SetBlendMode("ADD")
	end
	texture:Hide()
	return texture
end

local function Rig(host)
	if host.fx then
		return host.fx
	end
	local fx = {}
	fx.smoke = Texture(host, "BACKGROUND", "PaceGlow", false)
	fx.smoke:SetVertexColor(0, 0, 0)
	fx.glow = Texture(host, "BACKGROUND", "PaceGlow", true)
	fx.core = Texture(host, "BORDER", "PaceGlow", true)
	fx.shapes = {}
	for index = 1, SHAPES do
		fx.shapes[index] = Texture(host, "ARTWORK", "Flame", true)
	end
	-- Over the number: the particles and the bolts.
	fx.front = CreateFrame("Frame", nil, host)
	fx.front:SetAllPoints(host)
	fx.front:SetFrameLevel(host:GetFrameLevel() + 6)
	fx.parts = {}
	for index = 1, PARTS do
		fx.parts[index] = Texture(fx.front, "OVERLAY", "PaceDot", true)
	end
	fx.dots = {}
	for index = 1, DOTS do
		fx.dots[index] = Texture(fx.front, "OVERLAY", "PaceDot", true)
	end
	host.fx = fx
	return fx
end

-- A piece at x, y from the number's middle, size by size, in the host's scale.
local function Put(fx, texture, x, y, width, height)
	local s = fx.scale
	texture:SetWidth(width * s)
	texture:SetHeight((height or width) * s)
	texture:ClearAllPoints()
	texture:SetPoint("CENTER", fx.host, "CENTER", x * s, fx.cy + y * s)
end

-- A shape standing on its bottom at x, y.
local function Stand(fx, texture, x, y, width, height)
	local s = fx.scale
	texture:SetWidth(width * s)
	texture:SetHeight(height * s)
	texture:ClearAllPoints()
	texture:SetPoint("BOTTOM", fx.host, "CENTER", x * s, fx.cy + y * s)
end

local function Glow(fx, texture, x, y, width, height, r, g, b, alpha)
	Put(fx, texture, x, y, width, height)
	texture:SetVertexColor(r, g, b)
	texture:SetAlpha(math.max(0, math.min(1, alpha)))
	texture:Show()
end

-- A particle: p = { x, y, vx, vy, ax, ay, drag, sway, swayRate, length, size,
-- size2, c1 = {r, g, b}, c2, curve ("fade", "twinkle", "in") } or an orbit
-- { orbit, angle, radius, w (turns a second, in radians), dr, ry }. A coin
-- (the coins' rain): solid (drawn as it is, not in light), spin (turns a
-- second, in radians: as wide as it faces, darker edge-on), floor (it
-- bounces there; land(fx, p) at its first, gone a moment after its second).
local function Spawn(fx, art, p)
	for index = 1, PARTS do
		local texture = fx.parts[index]
		if not texture.p then
			p.life = 0
			p.phase = p.phase or math.random() * 6.283
			texture.p = p
			texture:SetTexture(ART..art)
			texture:SetBlendMode(p.solid and "BLEND" or "ADD")
			-- A leaf mirrored, at random, so they do not all lean one way.
			if p.flip then
				texture:SetTexCoord(1, 0, 0, 1)
			else
				texture:SetTexCoord(0, 1, 0, 1)
			end
			return p
		end
	end
end

local function Lerp(a, b, t)
	return a + (b - a) * t
end

local function Particles(fx, elapsed)
	for index = 1, PARTS do
		local texture = fx.parts[index]
		local p = texture.p
		if p then
			p.life = p.life + elapsed
			local part = p.life / p.length
			if part >= 1 then
				texture.p = nil
				texture:Hide()
			else
				local x, y
				if p.orbit then
					p.angle = p.angle + p.w * elapsed
					p.radius = p.radius + (p.dr or 0) * elapsed
					if p.radius < 2 then
						p.radius = 2
					end
					x, y = math.cos(p.angle) * p.radius, math.sin(p.angle) * p.radius * (p.ry or 0.42)
				else
					local drag = 1 - (p.drag or 0) * elapsed
					p.vx = (p.vx + (p.ax or 0) * elapsed) * drag
					p.vy = (p.vy + (p.ay or 0) * elapsed) * drag
					p.x = p.x + p.vx * elapsed
					p.y = p.y + p.vy * elapsed
					if p.floor and p.y < p.floor and p.vy < 0 then
						p.y = p.floor
						p.vy = -p.vy * 0.42
						p.vx = p.vx * 0.5
						p.spin = (p.spin or 0) * 0.6
						p.bounces = (p.bounces or 0) + 1
						if p.bounces == 1 and p.land then
							p.land(fx, p)
						elseif p.bounces == 2 then
							p.ends = p.life
							p.length = p.life + 0.2
						end
					end
					x, y = p.x, p.y
				end
				if p.sway then
					x = x + p.sway * math.sin(p.life * p.swayRate + p.phase)
				end
				local size = Lerp(p.size, p.size2 or p.size, part)
				local face = p.spin and math.abs(math.cos(p.life * p.spin + p.phase)) or 1
				Put(fx, texture, x, y, size * math.max(0.18, face), size)
				local c1, c2 = p.c1, p.c2 or p.c1
				local shade = 0.6 + 0.4 * face
				texture:SetVertexColor(Lerp(c1[1], c2[1], part) * shade, Lerp(c1[2], c2[2], part) * shade, Lerp(c1[3], c2[3], part) * shade)
				local alpha
				if p.curve == "coin" then
					alpha = p.ends and math.max(0, 1 - (p.life - p.ends) / 0.2) or math.min(1, p.life * 12)
				elseif p.curve == "twinkle" then
					alpha = math.sin(part * 3.1416)
				elseif p.curve == "in" then
					alpha = math.min(1, part * 2.5) * (1 - part * part)
				else
					alpha = 1 - part * part
				end
				texture:SetAlpha(alpha * (p.alpha or 1))
				texture:Show()
			end
		end
	end
end

local function HideShapes(fx, from)
	for index = from, SHAPES do
		fx.shapes[index]:Hide()
	end
end

local function Number(host, r, g, b)
	if host.number then
		host.number:SetTextColor(r, g, b)
	end
end

local function Rand(low, high)
	return low + math.random() * (high - low)
end

------------------------------------------------------------------------------
-- The five.

local EFFECTS = {}

-- Fire's colors, born white-yellow, dying deep red.
local FIRE_HOT, FIRE_COOL = { 1, 0.92, 0.5 }, { 0.75, 0.15, 0.05 }

EFFECTS.fire = {
	smoke = 0.55,
	Start = function(fx)
		for index = 1, SHAPES do
			local shape = fx.shapes[index]
			shape:SetTexture(ART.."Flame")
			local across = (index - (SHAPES + 1) / 2) / ((SHAPES - 1) / 2)
			shape.x = across * 46 + Rand(-3, 3)
			shape.tall = 1 - 0.5 * math.abs(across)
			shape.phase = Rand(0, 6.283)
			shape.speed = Rand(9, 15)
		end
		for _ = 1, 20 do
			local angle, speed = Rand(0, 6.283), Rand(50, 110)
			Spawn(fx, "PaceDot", { x = 0, y = 0, vx = math.cos(angle) * speed, vy = math.sin(angle) * speed * 0.6 + 25,
				drag = 2, length = Rand(0.6, 1.1), size = Rand(4, 8), size2 = 2, c1 = FIRE_HOT, c2 = FIRE_COOL })
		end
	end,
	Update = function(fx, age, elapsed, holding, burst)
		local flicker = 0.5 * math.sin(age * 13) + 0.3 * math.sin(age * 21 + 1.3) + 0.2 * (math.random() - 0.5)
		Glow(fx, fx.glow, 0, -6, 180 + 80 * burst + 16 * flicker, 90 + 44 * burst + 10 * flicker, 1, 0.34, 0.04, 0.85 + 0.15 * burst + 0.1 * flicker)
		Glow(fx, fx.core, 0, -4, 120 + 12 * flicker, 48 + 8 * flicker, 1, 0.72, 0.22, 0.7 + 0.15 * flicker)
		for index = 1, SHAPES do
			local shape = fx.shapes[index]
			local wave = math.sin(age * shape.speed + shape.phase)
			local lick = 0.75 + 0.25 * wave + 0.1 * (math.random() - 0.5)
			Stand(fx, shape, shape.x + 3 * math.sin(age * 5 + shape.phase), -20,
				28 + 12 * shape.tall, (40 + 42 * shape.tall) * lick * (1 + 0.5 * burst))
			local cool = 0.4 + 0.35 * (1 - shape.tall) - 0.15 * wave
			shape:SetVertexColor(1 - 0.25 * cool, 0.85 - 0.6 * cool, 0.4 - 0.35 * cool)
			shape:SetAlpha(0.75 + 0.25 * lick)
			shape:Show()
		end
		if holding then
			fx.wait = fx.wait - elapsed
			if fx.wait <= 0 then
				fx.wait = Rand(0.03, 0.07)
				Spawn(fx, "PaceDot", { x = Rand(-50, 50), y = Rand(-16, -6), vx = 0, vy = Rand(40, 80), sway = Rand(3, 9),
					swayRate = Rand(3, 7), length = Rand(0.9, 1.7), size = Rand(4, 8), size2 = 1.6, c1 = FIRE_HOT, c2 = FIRE_COOL })
			end
			fx.wait2 = fx.wait2 - elapsed
			if fx.wait2 <= 0 then
				fx.wait2 = Rand(0.18, 0.5)
				Spawn(fx, "PaceSpark", { x = Rand(-60, 60), y = Rand(-12, 28), vx = 0, vy = 0, length = Rand(0.25, 0.45),
					size = Rand(9, 17), c1 = { 1, 0.92, 0.6 }, curve = "twinkle" })
			end
		end
		local hot = 0.5 + 0.5 * math.sin(age * 7)
		return 1, 0.62 + 0.25 * hot, 0.12 + 0.18 * hot
	end,
}

-- A bolt of lightning from (x1, y1) to (x2, y2): a jagged line of dots, a
-- glow at each bend, perhaps a branch. Returns the next free dot.
local function Bolt(fx, x1, y1, x2, y2, used, branch)
	local bends = math.floor(Rand(5, 9))
	local dx, dy = x2 - x1, y2 - y1
	local length = math.sqrt(dx * dx + dy * dy)
	if length < 1 then
		return used
	end
	-- Across the bolt, for its jags.
	local nx, ny = -dy / length, dx / length
	local px, py = x1, y1
	for bend = 1, bends do
		local t = bend / bends
		local jag = bend < bends and Rand(-1, 1) * length * 0.12 or 0
		local qx, qy = x1 + dx * t + nx * jag, y1 + dy * t + ny * jag
		local sx, sy = qx - px, qy - py
		local steps = math.max(1, math.floor(math.sqrt(sx * sx + sy * sy) / 1.6))
		for step = 1, steps do
			if used >= DOTS then
				return used
			end
			used = used + 1
			local dot = fx.dots[used]
			local f = step / steps
			Put(fx, dot, px + sx * f, py + sy * f, branch and 2.4 or 3.2)
			dot:SetVertexColor(0.88, 0.95, 1)
			dot.kind = "line"
			dot:Show()
			-- A blue halo along the bolt.
			if math.mod(step, 4) == 0 and used < DOTS then
				used = used + 1
				local halo = fx.dots[used]
				Put(fx, halo, px + sx * f, py + sy * f, branch and 7 or 10)
				halo:SetVertexColor(0.3, 0.55, 1)
				halo.kind = "halo"
				halo:Show()
			end
		end
		if used < DOTS and not branch then
			used = used + 1
			local halo = fx.dots[used]
			Put(fx, halo, qx, qy, 16)
			halo:SetVertexColor(0.35, 0.6, 1)
			halo.kind = "halo"
			halo:Show()
		end
		-- A branch from a bend midway.
		if not branch and bend == math.floor(bends / 2) and math.random() < 0.7 then
			used = Bolt(fx, qx, qy, qx + Rand(-40, 40), qy + Rand(-30, 30), used, true)
		end
		px, py = qx, qy
	end
	return used
end

EFFECTS.lightning = {
	smoke = 0.72,
	smokeColor = { 0.01, 0.02, 0.07 },
	Start = function(fx)
		HideShapes(fx, 1)
		fx.boltWait, fx.boltAge, fx.flash = 0, 0, 1
	end,
	Update = function(fx, age, elapsed, holding, burst)
		fx.flash = math.max(0, fx.flash - elapsed * 5)
		fx.boltAge = fx.boltAge + elapsed
		fx.boltWait = fx.boltWait - elapsed
		if holding and fx.boltWait <= 0 then
			fx.boltWait = Rand(0.08, 0.24)
			fx.boltAge = 0
			fx.flash = Rand(0.5, 1)
			for index = 1, DOTS do
				fx.dots[index]:Hide()
			end
			local used = 0
			-- Lashing out from the number, and now and then striking down on it.
			for _ = 1, math.floor(Rand(2, 4)) do
				local angle = Rand(0, 6.283)
				used = Bolt(fx, math.cos(angle) * 30, math.sin(angle) * 10, math.cos(angle) * Rand(80, 120), math.sin(angle) * Rand(30, 48), used)
			end
			if math.random() < 0.5 then
				used = Bolt(fx, Rand(-30, 30), 70, Rand(-10, 10), 10, used)
			end
			for _ = 1, 2 do
				Spawn(fx, "PaceSpark", { x = Rand(-110, 110), y = Rand(-40, 40), vx = 0, vy = 0, length = Rand(0.15, 0.3),
					size = Rand(10, 18), c1 = { 0.85, 0.95, 1 }, curve = "twinkle" })
			end
		end
		-- The bolts flare and die in a blink.
		local bright = math.max(0, 1 - fx.boltAge / 0.16)
		for index = 1, DOTS do
			local dot = fx.dots[index]
			if dot:IsShown() then
				dot:SetAlpha(dot.kind == "halo" and 0.6 * bright or bright)
			end
		end
		local hum = 0.5 + 0.5 * math.sin(age * 30)
		Glow(fx, fx.glow, 0, -2, 180 + 60 * burst + 50 * fx.flash, 84 + 30 * burst + 24 * fx.flash, 0.3, 0.55, 1, 0.65 + 0.35 * fx.flash + 0.1 * hum)
		Glow(fx, fx.core, 0, 0, 96 + 24 * fx.flash, 38 + 10 * fx.flash, 0.75, 0.88, 1, 0.5 + 0.5 * fx.flash)
		local white = math.min(1, fx.flash * 1.5)
		return 0.7 + 0.3 * white, 0.86 + 0.14 * white, 1
	end,
}

EFFECTS.radiant = {
	smoke = 0.6,
	Start = function(fx)
		for index = 1, SHAPES do
			local shape = fx.shapes[index]
			if index <= 7 then
				shape:SetTexture(ART.."PaceGlow")
				shape.x = (index - 4) * 22 + Rand(-4, 4)
				shape.phase = Rand(0, 6.283)
				shape.speed = Rand(1.5, 3)
			else
				shape:Hide()
			end
		end
		for _ = 1, 16 do
			local angle, speed = Rand(0, 6.283), Rand(30, 80)
			Spawn(fx, "PaceDot", { x = 0, y = 0, vx = math.cos(angle) * speed, vy = math.sin(angle) * speed * 0.6, drag = 2.5,
				length = Rand(0.8, 1.4), size = Rand(3, 6), size2 = 1.5, c1 = { 1, 0.95, 0.7 }, c2 = { 1, 0.7, 0.2 } })
		end
	end,
	Update = function(fx, age, elapsed, holding, burst)
		local wave = 0.5 + 0.5 * math.sin(age * 4)
		Glow(fx, fx.glow, 0, 0, 170 + 90 * burst + 20 * wave, 80 + 40 * burst + 10 * wave, 1, 0.7, 0.15, 0.8 + 0.2 * burst + 0.15 * wave)
		Glow(fx, fx.core, 0, 0, 110, 40, 1, 0.92, 0.6, 0.5 + 0.2 * wave)
		-- Pillars of light, each rising and fading on its own.
		for index = 1, 7 do
			local shape = fx.shapes[index]
			local rise = 0.5 + 0.5 * math.sin(age * shape.speed + shape.phase)
			Stand(fx, shape, shape.x, -24, 16 + 6 * rise, 64 + 56 * rise)
			shape:SetVertexColor(1, 0.82, 0.38)
			shape:SetAlpha(0.3 + 0.6 * rise)
			shape:Show()
		end
		if holding then
			fx.wait = fx.wait - elapsed
			if fx.wait <= 0 then
				fx.wait = Rand(0.06, 0.12)
				Spawn(fx, "PaceDot", { x = Rand(-80, 80), y = Rand(-20, 0), vx = 0, vy = Rand(15, 35), sway = Rand(2, 5),
					swayRate = Rand(1.5, 3), length = Rand(1.4, 2.2), size = Rand(3, 6), size2 = 2,
					c1 = { 1, 0.95, 0.65 }, c2 = { 1, 0.7, 0.2 } })
			end
			fx.wait2 = fx.wait2 - elapsed
			if fx.wait2 <= 0 then
				fx.wait2 = Rand(0.12, 0.3)
				local angle = Rand(0, 6.283)
				Spawn(fx, "LightStar", { x = math.cos(angle) * Rand(60, 95), y = math.sin(angle) * Rand(22, 36), vx = 0, vy = 0,
					length = Rand(0.5, 0.8), size = Rand(10, 20), c1 = { 1, 0.95, 0.7 }, curve = "twinkle" })
			end
		end
		return 1, 0.8 + 0.08 * wave, 0.2 + 0.15 * wave
	end,
}

-- The coins' rain (Tally.lua, as the gold comes to pay for the next cache):
-- the Radiant's halo and pillars of light, smaller and taller, and gold coins
-- (Art\Coin) falling into it, turning, each bouncing twice on the gold with
-- a twinkle and a flare at its first, gone at its second. Not one of the
-- records' choices.
local COIN_WHITE, GOLD_LIGHT, GOLD_DEEP = { 1, 1, 1 }, { 1, 0.95, 0.65 }, { 1, 0.7, 0.2 }

local function CoinLands(fx, p)
	fx.flash = math.min(1, fx.flash + 0.25)
	Spawn(fx, "LightStar", { x = p.x, y = p.y + 2, vx = 0, vy = 0, length = Rand(0.25, 0.4), size = Rand(10, 15),
		c1 = GOLD_LIGHT, curve = "twinkle" })
	for _ = 1, 2 do
		Spawn(fx, "PaceDot", { x = p.x, y = p.y, vx = Rand(-45, 45), vy = Rand(35, 75), ay = -220,
			length = Rand(0.3, 0.45), size = Rand(3, 5), size2 = 1.5, c1 = GOLD_LIGHT, c2 = GOLD_DEEP })
	end
end

-- A coin let fall from x, y (above the gold) at vy, down to the floor.
local function Coin(fx, x, y, vy)
	Spawn(fx, "Coin", { x = x, y = y, vx = Rand(-8, 8), vy = vy, ay = -520, floor = Rand(-3, 1), length = 3,
		size = Rand(15, 20), c1 = COIN_WHITE, solid = true, spin = Rand(7, 13), curve = "coin", land = CoinLands })
end

EFFECTS.coins = {
	smoke = 0.4,
	smokeSize = { 140, 92, 12 },
	Start = function(fx)
		fx.flash, fx.wait3 = 0.7, 0
		for index = 1, SHAPES do
			local shape = fx.shapes[index]
			if index <= 5 then
				shape:SetTexture(ART.."PaceGlow")
				shape.x = (index - 3) * 17 + Rand(-3, 3)
				shape.phase = Rand(0, 6.283)
				shape.speed = Rand(1.5, 3)
			else
				shape:Hide()
			end
		end
		-- The first close above, down with the sound's first clink; then a
		-- handful higher, to land one after another.
		Coin(fx, Rand(-6, 6), 12, -170)
		for _ = 1, 5 do
			Coin(fx, Rand(-40, 40), Rand(35, 90), Rand(-100, -40))
		end
		for _ = 1, 10 do
			local angle, speed = Rand(0, 6.283), Rand(20, 55)
			Spawn(fx, "PaceDot", { x = 0, y = 0, vx = math.cos(angle) * speed, vy = math.sin(angle) * speed * 0.6, drag = 2.5,
				length = Rand(0.7, 1.2), size = Rand(3, 5), size2 = 1.5, c1 = GOLD_LIGHT, c2 = GOLD_DEEP })
		end
	end,
	Update = function(fx, age, elapsed, holding, burst)
		fx.flash = math.max(0, fx.flash - elapsed * 2.5)
		local wave = 0.5 + 0.5 * math.sin(age * 4)
		Glow(fx, fx.glow, 0, 14, 124 + 46 * burst + 12 * wave, 86 + 30 * burst + 8 * wave, 1, 0.7, 0.15,
			0.7 + 0.2 * burst + 0.12 * wave)
		Glow(fx, fx.core, 0, 0, 56 + 30 * fx.flash, 34 + 16 * fx.flash, 1, 0.92, 0.6, 0.4 + 0.5 * fx.flash)
		for index = 1, 5 do
			local shape = fx.shapes[index]
			local rise = 0.5 + 0.5 * math.sin(age * shape.speed + shape.phase)
			Stand(fx, shape, shape.x, -12, 10 + 4 * rise, 34 + 40 * rise)
			shape:SetVertexColor(1, 0.82, 0.38)
			shape:SetAlpha(0.25 + 0.5 * rise)
			shape:Show()
		end
		if holding then
			fx.wait = fx.wait - elapsed
			if fx.wait <= 0 then
				fx.wait = Rand(0.035, 0.07)
				Coin(fx, Rand(-46, 46), Rand(70, 105), Rand(-60, -20))
			end
			fx.wait2 = fx.wait2 - elapsed
			if fx.wait2 <= 0 then
				fx.wait2 = Rand(0.15, 0.35)
				local angle = Rand(0, 6.283)
				Spawn(fx, "LightStar", { x = math.cos(angle) * Rand(48, 66), y = 14 + math.sin(angle) * Rand(24, 36), vx = 0, vy = 0,
					length = Rand(0.4, 0.7), size = Rand(9, 16), c1 = GOLD_LIGHT, curve = "twinkle" })
			end
			fx.wait3 = fx.wait3 - elapsed
			if fx.wait3 <= 0 then
				fx.wait3 = Rand(0.08, 0.14)
				Spawn(fx, "PaceDot", { x = Rand(-40, 40), y = Rand(-8, 4), vx = 0, vy = Rand(15, 35), sway = Rand(2, 5),
					swayRate = Rand(1.5, 3), length = Rand(1, 1.6), size = Rand(3, 5), size2 = 1.5, c1 = GOLD_LIGHT, c2 = GOLD_DEEP })
			end
		end
	end,
}

local ICE = { 0.85, 0.95, 1 }

EFFECTS.frost = {
	smoke = 0.7,
	smokeColor = { 0.01, 0.03, 0.07 },
	Start = function(fx)
		-- A crown of frost crystals round the number.
		for index = 1, SHAPES do
			local shape = fx.shapes[index]
			if index <= 6 then
				shape:SetTexture(ART.."PaceSpark")
				local angle = (index - 1) / 6 * 6.283 + 0.26
				shape.x, shape.y = math.cos(angle) * 78, math.sin(angle) * 28
				shape.phase = Rand(0, 6.283)
			else
				shape:Hide()
			end
		end
		-- Shards flung out, slowing, falling a little.
		for _ = 1, 20 do
			local angle, speed = Rand(0, 6.283), Rand(70, 140)
			Spawn(fx, "PaceDot", { x = 0, y = 0, vx = math.cos(angle) * speed, vy = math.sin(angle) * speed * 0.6, drag = 3, ay = -40,
				length = Rand(0.7, 1.2), size = Rand(4, 7), size2 = 2, c1 = { 1, 1, 1 }, c2 = { 0.5, 0.8, 1 } })
		end
	end,
	Update = function(fx, age, elapsed, holding, burst)
		local wave = 0.5 + 0.5 * math.sin(age * 2.5)
		Glow(fx, fx.glow, 0, 0, 180 + 80 * burst + 14 * wave, 82 + 36 * burst + 8 * wave, 0.35, 0.68, 1, 0.75 + 0.25 * burst + 0.1 * wave)
		Glow(fx, fx.core, 0, 0, 104, 38, 0.8, 0.93, 1, 0.45 + 0.5 * burst + 0.1 * wave)
		for index = 1, 6 do
			local shape = fx.shapes[index]
			local glint = 0.5 + 0.5 * math.sin(age * 3 + shape.phase)
			Put(fx, shape, shape.x, shape.y, 16 + 12 * glint)
			shape:SetVertexColor(0.75, 0.9, 1)
			shape:SetAlpha(0.5 + 0.5 * glint)
			shape:Show()
		end
		if holding then
			fx.wait = fx.wait - elapsed
			if fx.wait <= 0 then
				fx.wait = Rand(0.05, 0.11)
				Spawn(fx, "PaceDot", { x = Rand(-100, 100), y = Rand(38, 52), vx = 0, vy = Rand(-25, -12), sway = Rand(4, 10),
					swayRate = Rand(1.5, 3), length = Rand(1.6, 2.4), size = Rand(4, 8), size2 = 2.5, c1 = ICE, c2 = { 0.6, 0.8, 1 } })
			end
			fx.wait2 = fx.wait2 - elapsed
			if fx.wait2 <= 0 then
				fx.wait2 = Rand(0.15, 0.35)
				Spawn(fx, "PaceSpark", { x = Rand(-50, 50), y = Rand(-14, 20), vx = 0, vy = 0, length = Rand(0.25, 0.4),
					size = Rand(8, 14), c1 = { 1, 1, 1 }, curve = "twinkle" })
			end
		end
		-- A shimmer now and then: the sine's peaks, made sharp.
		local shimmer = math.max(0, math.sin(age * 5))
		shimmer = shimmer * shimmer * shimmer
		shimmer = shimmer * shimmer
		return 0.72 + 0.28 * shimmer, 0.9 + 0.1 * shimmer, 1
	end,
}

local VOID_ORB, VOID_PALE = { 0.85, 0.55, 1 }, { 1, 0.88, 1 }

EFFECTS.void = {
	smoke = 0.9,
	smokeColor = { 0.05, 0, 0.1 },
	Start = function(fx)
		HideShapes(fx, 1)
		-- Orbs circling wide, each in a halo with two trailing smaller ones;
		-- an inner ring turning the other way.
		for orb = 1, 5 do
			local angle = orb / 5 * 6.283
			Spawn(fx, "PaceGlow", { orbit = true, angle = angle, radius = 76, w = 2.4, ry = 0.4,
				length = fx.life, size = 30, c1 = { 0.6, 0.25, 1 }, alpha = 0.7 })
			for trail = 0, 2 do
				Spawn(fx, "PaceDot", { orbit = true, angle = angle - trail * 0.2, radius = 76, w = 2.4, ry = 0.4,
					length = fx.life, size = 11 - 3 * trail, c1 = VOID_ORB, c2 = { 0.6, 0.3, 1 },
					alpha = 1 - 0.3 * trail })
			end
		end
		for orb = 1, 4 do
			local angle = orb / 4 * 6.283
			Spawn(fx, "PaceGlow", { orbit = true, angle = angle, radius = 44, w = -3.2, ry = 0.4,
				length = fx.life, size = 18, c1 = { 0.7, 0.35, 1 }, alpha = 0.6 })
			Spawn(fx, "PaceDot", { orbit = true, angle = angle, radius = 44, w = -3.2, ry = 0.4,
				length = fx.life, size = 6, c1 = VOID_PALE })
		end
	end,
	Update = function(fx, age, elapsed, holding, burst)
		-- Drawn in on itself at first, then a slow pulse.
		local pull = math.max(0, 1 - age / 0.45)
		local pulse = 0.5 + 0.5 * math.sin(age * 4)
		Glow(fx, fx.glow, 0, 0, 150 + 180 * pull + 20 * pulse, 66 + 70 * pull + 10 * pulse, 0.55, 0.16, 1, 0.85 + 0.15 * pulse)
		Glow(fx, fx.core, 0, 0, 84 + 12 * pulse, 32 + 5 * pulse, 0.92, 0.72, 1, 0.55 + 0.25 * pulse)
		if holding then
			fx.wait = fx.wait - elapsed
			if fx.wait <= 0 then
				fx.wait = Rand(0.03, 0.06)
				local radius = Rand(90, 120)
				local length = Rand(0.8, 1.2)
				Spawn(fx, "PaceDot", { orbit = true, angle = Rand(0, 6.283), radius = radius, w = Rand(1.5, 3),
					dr = -radius / length, ry = 0.45, length = length, size = Rand(4, 7), size2 = 2,
					c1 = VOID_ORB, c2 = VOID_PALE, curve = "in" })
			end
		end
		return 0.82 + 0.18 * pulse, 0.62 + 0.25 * pulse, 1
	end,
}

-- The number's place, shaken by a blow (x, y), or back home.
local function Shake(fx, x, y)
	local number = fx.host.number
	if number then
		number:ClearAllPoints()
		number:SetPoint("CENTER", fx.host, "CENTER", x, fx.cy + y)
	end
end

local BLOOD, EMBER_RED = { 0.75, 0.05, 0.04 }, { 1, 0.35, 0.2 }

-- A blow: a shockwave, sparks and drops flung out, the slashes lit again,
-- the number shaken (strength 1 for the first, less for the next).
local function Blow(fx, strength)
	fx.blowAge = 0
	fx.blowStrength = strength
	fx.ring = (fx.ring == 4) and 5 or 4
	fx.shapes[fx.ring].age = 0
	for _ = 1, math.floor(10 + 14 * strength) do
		local angle, speed = Rand(0, 6.283), Rand(70, 170) * (0.6 + 0.4 * strength)
		Spawn(fx, "PaceDot", { x = Rand(-8, 8), y = Rand(-4, 4), vx = math.cos(angle) * speed,
			vy = math.sin(angle) * speed * 0.7 + 30, ay = -260, drag = 1.2, length = Rand(0.5, 0.9),
			size = Rand(3, 6), size2 = 2, c1 = { 1, 0.85, 0.75 }, c2 = BLOOD })
	end
	for _ = 1, 3 do
		Spawn(fx, "PaceSpark", { x = Rand(-40, 40), y = Rand(-14, 14), vx = 0, vy = 0, length = Rand(0.18, 0.3),
			size = Rand(14, 22), c1 = { 1, 0.9, 0.85 }, curve = "twinkle" })
	end
end

EFFECTS.physical = {
	smoke = 0.78,
	smokeColor = { 0.08, 0, 0 },
	Start = function(fx)
		-- Three claw slashes across the number, a step apart across them,
		-- torn in one after another.
		for index = 1, 3 do
			local shape = fx.shapes[index]
			shape:SetTexture(ART.."Slash")
			shape.step = (index - 2) * 13
			shape.delay = (index - 1) * 0.05
		end
		for index = 4, 5 do
			fx.shapes[index]:SetTexture(ART.."Ring")
			fx.shapes[index].age = nil
		end
		HideShapes(fx, 6)
		fx.ring = 5
		Blow(fx, 1)
		fx.nextBlow = Rand(0.8, 1.1)
	end,
	Update = function(fx, age, elapsed, holding, burst)
		fx.blowAge = fx.blowAge + elapsed
		local hit = math.max(0, 1 - fx.blowAge / 0.25)
		if holding then
			fx.nextBlow = fx.nextBlow - elapsed
			if fx.nextBlow <= 0 then
				fx.nextBlow = Rand(0.8, 1.2)
				Blow(fx, 0.55)
			end
			-- Drops falling now and then from the slashes.
			fx.wait = fx.wait - elapsed
			if fx.wait <= 0 then
				fx.wait = Rand(0.08, 0.16)
				Spawn(fx, "PaceDot", { x = Rand(-40, 40), y = Rand(-10, 16), vx = 0, vy = Rand(-10, 0), ay = -120,
					length = Rand(0.6, 1), size = Rand(2.5, 4.5), size2 = 2, c1 = EMBER_RED, c2 = BLOOD })
			end
		end
		Glow(fx, fx.glow, 0, 0, 170 + 80 * burst + 50 * hit, 80 + 40 * burst + 24 * hit, 1, 0.1, 0.06, 0.7 + 0.3 * hit)
		Glow(fx, fx.core, 0, 0, 96 + 30 * hit, 36 + 10 * hit, 1, 0.45 + 0.4 * hit, 0.35 + 0.4 * hit, 0.45 + 0.5 * hit)
		-- The slashes: torn in white-hot, then red, lit again by each blow.
		for index = 1, 3 do
			local shape = fx.shapes[index]
			local since = age - shape.delay
			if since < 0 then
				shape:Hide()
			else
				local tear = math.min(1, since / 0.06)
				Put(fx, shape, shape.step, -shape.step * 0.6, 130 * tear + 10, 72 * tear + 6)
				local hot = math.max(math.max(0, 1 - since / 0.35), hit * fx.blowStrength)
				shape:SetVertexColor(1, 0.15 + 0.75 * hot, 0.1 + 0.7 * hot)
				shape:SetAlpha(0.65 + 0.35 * hot)
				shape:Show()
			end
		end
		-- The shockwaves, each spreading and fading.
		for index = 4, 5 do
			local ring = fx.shapes[index]
			if ring.age then
				ring.age = ring.age + elapsed
				local part = ring.age / 0.5
				if part >= 1 then
					ring.age = nil
					ring:Hide()
				else
					local size = 40 + 210 * part
					Put(fx, ring, 0, 0, size, size * 0.5)
					ring:SetVertexColor(1, 0.3 + 0.5 * (1 - part), 0.25)
					ring:SetAlpha(1 - part)
					ring:Show()
				end
			end
		end
		-- The number shaken by the blow.
		local shake = 5 * hit * fx.blowStrength
		Shake(fx, Rand(-1, 1) * shake, Rand(-1, 1) * shake)
		fx.shook = true
		return 1, 0.3 + 0.7 * hit, 0.22 + 0.7 * hit
	end,
}

local LEAF, LEAF_YELLOW = { 0.35, 0.95, 0.3 }, { 0.85, 0.95, 0.3 }

EFFECTS.nature = {
	smoke = 0.65,
	smokeColor = { 0, 0.05, 0.01 },
	Start = function(fx)
		-- Sprouts growing up behind the number, one after another.
		for index = 1, SHAPES do
			local shape = fx.shapes[index]
			if index <= 7 then
				shape:SetTexture(ART.."Flame")
				local across = (index - 4) / 3
				shape.x = across * 52 + Rand(-4, 4)
				shape.tall = 1 - 0.45 * math.abs(across)
				shape.delay = Rand(0, 0.25)
				shape.phase = Rand(0, 6.283)
			else
				shape:Hide()
			end
		end
		-- Leaves bursting out in a spiral.
		for _ = 1, 14 do
			Spawn(fx, "Leaf", { orbit = true, angle = Rand(0, 6.283), radius = 10, dr = Rand(90, 140),
				w = (math.random() < 0.5 and -1 or 1) * Rand(2.5, 4), ry = 0.5, length = Rand(0.9, 1.4),
				size = Rand(11, 16), size2 = 8, c1 = LEAF, c2 = LEAF_YELLOW, flip = math.random() < 0.5 })
		end
	end,
	Update = function(fx, age, elapsed, holding, burst)
		local breath = 0.5 + 0.5 * math.sin(age * 3)
		Glow(fx, fx.glow, 0, -2, 170 + 70 * burst + 14 * breath, 82 + 34 * burst + 8 * breath, 0.25, 0.85, 0.2, 0.7 + 0.25 * burst + 0.1 * breath)
		Glow(fx, fx.core, 0, 0, 100, 36, 0.75, 1, 0.55, 0.4 + 0.15 * breath)
		for index = 1, 7 do
			local shape = fx.shapes[index]
			local grow = math.max(0, math.min(1, (age - shape.delay) / 0.6))
			grow = grow * (2 - grow)
			local sway = math.sin(age * 2.2 + shape.phase)
			Stand(fx, shape, shape.x + 3 * sway, -24, 14 + 6 * shape.tall, (30 + 46 * shape.tall) * grow * (0.94 + 0.06 * breath))
			shape:SetVertexColor(0.3 + 0.2 * shape.tall, 0.8, 0.22)
			shape:SetAlpha(0.8 * grow)
			if grow > 0 then
				shape:Show()
			else
				shape:Hide()
			end
		end
		if holding then
			-- Leaves drifting down across it.
			fx.wait = fx.wait - elapsed
			if fx.wait <= 0 then
				fx.wait = Rand(0.12, 0.22)
				Spawn(fx, "Leaf", { x = Rand(-110, 110), y = Rand(40, 56), vx = Rand(-10, 10), vy = Rand(-30, -16),
					sway = Rand(6, 14), swayRate = Rand(2, 4), length = Rand(1.4, 2.2), size = Rand(9, 14),
					c1 = LEAF, c2 = LEAF_YELLOW, flip = math.random() < 0.5, curve = "in" })
			end
			-- Pollen rising, and a green twinkle now and then.
			fx.wait2 = fx.wait2 - elapsed
			if fx.wait2 <= 0 then
				fx.wait2 = Rand(0.04, 0.09)
				Spawn(fx, "PaceDot", { x = Rand(-70, 70), y = Rand(-22, -8), vx = 0, vy = Rand(20, 45), sway = Rand(2, 5),
					swayRate = Rand(2, 4), length = Rand(1, 1.6), size = Rand(3, 5), size2 = 1.5,
					c1 = { 0.95, 1, 0.55 }, c2 = { 0.4, 0.9, 0.3 } })
				if math.random() < 0.15 then
					Spawn(fx, "LightStar", { x = Rand(-90, 90), y = Rand(-20, 30), vx = 0, vy = 0, length = Rand(0.4, 0.7),
						size = Rand(10, 16), c1 = { 0.8, 1, 0.6 }, curve = "twinkle" })
				end
			end
		end
		return 0.55 + 0.2 * breath, 1, 0.4 + 0.15 * breath
	end,
}

------------------------------------------------------------------------------

-- The smoke behind: width, height, its middle's height (an effect's own, smokeSize).
local SMOKE_SIZE = { 240, 124, -2 }

function SurvivorUI_RecordFxStart(host, kind, scale, numberY, life)
	local fx = Rig(host)
	local effect = EFFECTS[kind] or EFFECTS.fire
	fx.host, fx.effect = host, effect
	fx.scale, fx.cy, fx.life = scale or 1, numberY or 0, life or 4
	fx.wait, fx.wait2 = 0, 0.15
	for index = 1, PARTS do
		fx.parts[index].p = nil
		fx.parts[index]:Hide()
	end
	for index = 1, DOTS do
		fx.dots[index]:Hide()
	end
	local smoke = effect.smokeColor or { 0, 0, 0 }
	fx.smoke:SetVertexColor(smoke[1], smoke[2], smoke[3])
	for index = 1, SHAPES do
		fx.shapes[index]:SetTexCoord(0, 1, 0, 1)
	end
	-- A blow before shook the number: home again.
	if fx.shook then
		fx.shook = nil
		Shake(fx, 0, 0)
	end
	effect.Start(fx)
end

function SurvivorUI_RecordFxUpdate(host, age, elapsed, holding)
	local fx = host.fx
	if not (fx and fx.effect) then
		return
	end
	local effect = fx.effect
	local smoke = effect.smokeSize or SMOKE_SIZE
	Put(fx, fx.smoke, 0, smoke[3], smoke[1], smoke[2])
	fx.smoke:SetAlpha(effect.smoke or 0.5)
	fx.smoke:Show()
	local burst = math.max(0, 1 - age / 0.6)
	local r, g, b = effect.Update(fx, age, elapsed, holding, burst)
	Particles(fx, elapsed)
	if r then
		Number(host, r, g, b)
	end
end

function SurvivorUI_RecordFxStop(host)
	local fx = host.fx
	if not fx then
		return
	end
	fx.effect = nil
	if fx.shook then
		fx.shook = nil
		Shake(fx, 0, 0)
	end
	for index = 1, PARTS do
		fx.parts[index].p = nil
		fx.parts[index]:Hide()
	end
	for index = 1, DOTS do
		fx.dots[index]:Hide()
	end
	HideShapes(fx, 1)
	fx.smoke:Hide()
	fx.glow:Hide()
	fx.core:Hide()
end
