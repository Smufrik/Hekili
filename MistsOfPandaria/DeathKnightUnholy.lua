-- DeathKnightUnholy.lua
-- Updated August 27, 2025

-- MoP: Use UnitClass instead of UnitClassBase
local _, playerClass = UnitClass("player")
if playerClass ~= "DEATHKNIGHT" then
	return
end

local addon, ns = ...
local Hekili = _G[addon]
local class, state = Hekili.Class, Hekili.State

-- Ensure state.runes exists before any resource registration to prevent metatable lookups from erroring.
do
	local runes = rawget(state, "runes")
	if not runes then
		runes = { expiry = { 0, 0, 0, 0, 0, 0 }, cooldown = 10, max = 6 }
		rawset(state, "runes", runes)
	end
	if not runes.expiry then
		runes.expiry = { 0, 0, 0, 0, 0, 0 }
	end
	for i = 1, 6 do
		if not runes.expiry[i] then
			runes.expiry[i] = 0
		end
	end
end

-- Safe local references to WoW API (helps static analyzers and emulation)
local GetRuneCooldown = rawget(_G, "GetRuneCooldown") or function()
	return 0, 10, true
end
local GetRuneType = rawget(_G, "GetRuneType") or function()
	return 1
end

local FindUnitBuffByID, FindUnitDebuffByID = ns.FindUnitBuffByID, ns.FindUnitDebuffByID
local strformat = string.format

local spec = Hekili:NewSpecialization(252, true)

spec.name = "Unholy"
spec.role = "DAMAGER"
spec.primaryStat = 1 -- Strength

-- Local shim for resource changes to avoid global gain/spend errors and normalize names.
local function _normalizeResource(res)
	if res == "runicpower" or res == "rp" then
		return "runic_power"
	end
	return res
end

local function gain(amount, resource, overcap, noforecast)
	local r = _normalizeResource(resource)
	if r == "runes" and state.runes and state.runes.expiry then
		local n = tonumber(amount) or 0
		if n >= 6 then
			for i = 1, 6 do
				state.runes.expiry[i] = 0
			end
		else
			for _ = 1, n do
				local worstIdx, worstVal = 1, -math.huge
				for i = 1, 6 do
					local e = state.runes.expiry[i] or 0
					if e > worstVal then
						worstVal, worstIdx = e, i
					end
				end
				state.runes.expiry[worstIdx] = 0
			end
		end
		return
	end
	if state.gain then
		return state.gain(amount, r, overcap, noforecast)
	end
end

local function spend(amount, resource, noforecast)
	local r = _normalizeResource(resource)
	if state.spend then
		return state.spend(amount, r, noforecast)
	end
end

-- Local aliases for core state helpers and tables (improves static checks and readability).
local applyBuff, removeBuff, applyDebuff, removeDebuff =
	state.applyBuff, state.removeBuff, state.applyDebuff, state.removeDebuff
local removeDebuffStack = state.removeDebuffStack
local summonPet, dismissPet, setDistance, interrupt =
	state.summonPet, state.dismissPet, state.setDistance, state.interrupt
local buff, debuff, cooldown, active_dot, pet, totem, action =
	state.buff, state.debuff, state.cooldown, state.active_dot, state.pet, state.totem, state.action
local glyph = state.glyph

-- Runes (unified model on the resource itself to avoid collision with a state table)
do
	local function buildTypeCounter(indices, typeId)
		return setmetatable({}, {
			__index = function(_, k)
				if k == "count" then
					local ready = 0
					if typeId == 4 then
						for i = 1, 6 do
							local start, duration, isReady = GetRuneCooldown(i)
							local rtype = GetRuneType(i)
							if
								(isReady or (start and duration and (start + duration) <= state.query_time))
								and rtype == 4
							then
								ready = ready + 1
							end
						end
					else
						for _, i in ipairs(indices) do
							local start, duration, isReady = GetRuneCooldown(i)
							if isReady or (start and duration and (start + duration) <= state.query_time) then
								ready = ready + 1
							end
						end
					end
					return ready
				end
				return 0
			end,
		})
	end

	spec:RegisterResource(
		5,
		{},
		setmetatable({
			expiry = { 0, 0, 0, 0, 0, 0 },
			cooldown = 10,
			max = 6,
			reset = function()
				local t = state.runes
				for i = 1, 6 do
					local start, duration, ready = GetRuneCooldown(i)
					start = start or 0
					duration = duration or (10 * state.haste)
					t.expiry[i] = ready and 0 or (start + duration)
					t.cooldown = duration
				end
			end,
		}, {
			__index = function(t, k)
				-- runes.time_to_1 .. runes.time_to_6
				local idx = tostring(k):match("time_to_(%d)")
				if idx then
					local i = tonumber(idx)
					local e = t.expiry[i] or 0
					return math.max(0, e - state.query_time)
				end
				if k == "blood" then
					return buildTypeCounter({ 1, 2 }, 1)
				end
				if k == "frost" then
					return buildTypeCounter({ 5, 6 }, 2)
				end
				if k == "unholy" then
					return buildTypeCounter({ 3, 4 }, 3)
				end
				if k == "death" then
					return buildTypeCounter({}, 4)
				end
				if k == "count" or k == "current" then
					local c = 0
					for i = 1, 6 do
						if t.expiry[i] <= state.query_time then
							c = c + 1
						end
					end
					return c
				end
				return rawget(t, k)
			end,
		})
	) -- Runes = 5 in MoP with unified state

	-- Keep expiry fresh when we reset the simulation step
	spec:RegisterHook("reset_precast", function()
		if state.runes and state.runes.reset then
			state.runes.reset()
		end
		if state.death_runes and state.death_runes.reset then
			state.death_runes.reset()
		end
	end)
end

-- Register resources
spec:RegisterResource(6) -- RunicPower = 6 in MoP

-- Register individual rune types for MoP 5.5.0
spec:RegisterResource(
	20,
	{ -- Blood Runes = 20 in MoP
		rune_regen = {
			last = function()
				return state.query_time
			end,
			stop = function(x)
				return x == 2
			end,
			interval = function(time, val)
				local r = state.blood_runes
				if val == 2 then
					return -1
				end
				return r.expiry[val + 1] - time
			end,
			value = 1,
		},
	},
	setmetatable({
		expiry = { 0, 0 },
		cooldown = 10,
		regen = 0,
		max = 2,
		forecast = {},
		fcount = 0,
		times = {},
		values = {},
		resource = "blood_runes",

	reset = function()
		local t = state.blood_runes
		local count = 0
		-- Blood runes are in slots 1 and 2
		-- Death runes in these slots can also be used as blood runes
		for i = 1, 2 do
			local start, duration, ready = GetRuneCooldown(i)
			local runeType = GetRuneType(i)
			start = start or 0
			duration = duration or (10 * state.haste)
			
			-- Count blood runes (type 1) AND death runes (type 4) in blood slots
			if runeType == 1 or runeType == 4 then
				count = count + 1
				t.expiry[count] = ready and 0 or (start + duration)
				t.cooldown = duration
			end
		end
		for i = count + 1, 2 do
			t.expiry[i] = 999
		end
		table.sort(t.expiry)
		t.actual = nil
	end,

		gain = function(amount)
			local t = state.blood_runes
			for i = 1, amount do
				table.insert(t.expiry, 0)
				t.expiry[3] = nil
			end
			table.sort(t.expiry)
			t.actual = nil
		end,

		spend = function(amount)
			local t = state.blood_runes
			for i = 1, amount do
				local nextReady = (t.expiry[1] > 0 and t.expiry[1] or state.query_time) + t.cooldown
				table.remove(t.expiry, 1)
				table.insert(t.expiry, nextReady)
			end
			t.actual = nil
		end,

		timeTo = function(x)
			return state:TimeToResource(state.blood_runes, x)
		end,
	}, {
		__index = function(t, k)
			if k == "actual" then
				local amount = 0
				for i = 1, 2 do
					if t.expiry[i] <= state.query_time then
						amount = amount + 1
					end
				end
				return amount
			elseif k == "current" or k == "count" then
				return t.actual
			end
			return rawget(t, k)
		end,
	})
)

spec:RegisterResource(
	21,
	{ -- Frost Runes = 21 in MoP
		rune_regen = {
			last = function()
				return state.query_time
			end,
			stop = function(x)
				return x == 2
			end,
			interval = function(time, val)
				local r = state.frost_runes
				if val == 2 then
					return -1
				end
				return r.expiry[val + 1] - time
			end,
			value = 1,
		},
	},
	setmetatable({
		expiry = { 0, 0 },
		cooldown = 10,
		regen = 0,
		max = 2,
		forecast = {},
		fcount = 0,
		times = {},
		values = {},
		resource = "frost_runes",

	reset = function()
		local t = state.frost_runes
		local count = 0
		-- Frost runes are in slots 5 and 6
		-- Death runes in these slots can also be used as frost runes
		for i = 5, 6 do
			local start, duration, ready = GetRuneCooldown(i)
			local runeType = GetRuneType(i)
			start = start or 0
			duration = duration or (10 * state.haste)
			
			-- Count frost runes (type 3) AND death runes (type 4) in frost slots
			if runeType == 3 or runeType == 4 then
				count = count + 1
				t.expiry[count] = ready and 0 or (start + duration)
				t.cooldown = duration
			end
		end
		for i = count + 1, 2 do
			t.expiry[i] = 999
		end
		table.sort(t.expiry)
		t.actual = nil
	end,

		gain = function(amount)
			local t = state.frost_runes
			for i = 1, amount do
				table.insert(t.expiry, 0)
				t.expiry[3] = nil
			end
			table.sort(t.expiry)
			t.actual = nil
		end,

		spend = function(amount)
			local t = state.frost_runes
			for i = 1, amount do
				local nextReady = (t.expiry[1] > 0 and t.expiry[1] or state.query_time) + t.cooldown
				table.remove(t.expiry, 1)
				table.insert(t.expiry, nextReady)
			end
			t.actual = nil
		end,

		timeTo = function(x)
			return state:TimeToResource(state.frost_runes, x)
		end,
	}, {
		__index = function(t, k)
			if k == "actual" then
				local amount = 0
				for i = 1, 2 do
					if t.expiry[i] <= state.query_time then
						amount = amount + 1
					end
				end
				return amount
			elseif k == "current" or k == "count" then
				return t.actual
			end
			return rawget(t, k)
		end,
	})
)

spec:RegisterResource(
	22,
	{ -- Unholy Runes = 22 in MoP
		rune_regen = {
			last = function()
				return state.query_time
			end,
			stop = function(x)
				return x == 2
			end,
			interval = function(time, val)
				local r = state.unholy_runes
				if val == 2 then
					return -1
				end
				return r.expiry[val + 1] - time
			end,
			value = 1,
		},
	},
	setmetatable({
		expiry = { 0, 0 },
		cooldown = 10,
		regen = 0,
		max = 2,
		forecast = {},
		fcount = 0,
		times = {},
		values = {},
		resource = "unholy_runes",

	reset = function()
		local t = state.unholy_runes
		local count = 0
		-- Unholy runes are in slots 3 and 4
		-- Death runes in these slots can also be used as unholy runes
		for i = 3, 4 do
			local start, duration, ready = GetRuneCooldown(i)
			local runeType = GetRuneType(i)
			start = start or 0
			duration = duration or (10 * state.haste)
			
			-- Count unholy runes (type 2) AND death runes (type 4) in unholy slots
			if runeType == 2 or runeType == 4 then
				count = count + 1
				t.expiry[count] = ready and 0 or (start + duration)
				t.cooldown = duration
			end
		end
		for i = count + 1, 2 do
			t.expiry[i] = 999
		end
		table.sort(t.expiry)
		t.actual = nil
	end,

		gain = function(amount)
			local t = state.unholy_runes
			for i = 1, amount do
				table.insert(t.expiry, 0)
				t.expiry[3] = nil
			end
			table.sort(t.expiry)
			t.actual = nil
		end,

		spend = function(amount)
			local t = state.unholy_runes
			for i = 1, amount do
				local nextReady = (t.expiry[1] > 0 and t.expiry[1] or state.query_time) + t.cooldown
				table.remove(t.expiry, 1)
				table.insert(t.expiry, nextReady)
			end
			t.actual = nil
		end,

		timeTo = function(x)
			return state:TimeToResource(state.unholy_runes, x)
		end,
	}, {
		__index = function(t, k)
			if k == "actual" then
				local amount = 0
				for i = 1, 2 do
					if t.expiry[i] <= state.query_time then
						amount = amount + 1
					end
				end
				return amount
			elseif k == "current" or k == "count" then
				return t.actual
			end
			return rawget(t, k)
		end,
	})
)

spec:RegisterResource(6, {
	-- Frost Fever Tick RP (20% chance to generate 4 RP)
	frost_fever_tick = {

		aura = "frost_fever",

		last = function()
			local app = state.dot.frost_fever.applied

			return app + floor(state.query_time - app)
		end,

		interval = 1,
		value = function()
			-- 20% chance * 4 RP = 0.8 RP per tick
			-- We'll lowball to 0.6 RP for conservative estimate
			return 0.6 * min(state.active_dot.frost_fever or 0, 5)
		end,
	},

	-- Runic Attenuation (mainhand swings 50% chance to generate 3 RP)
	runic_attenuation = {
		talent = "runic_attenuation",
		swing = "mainhand",

		last = function()
			local swing = state.swings.mainhand
			local t = state.query_time
			if state.mainhand_speed == 0 then
				return 0
			else
				return swing + floor((t - swing) / state.mainhand_speed) * state.mainhand_speed
			end
		end,

		interval = "mainhand_speed",

		stop = function()
			return state.swings.mainhand == 0
		end,

		value = function()
			-- 50% chance * 3 RP = 1.5 RP per swing
			-- We'll lowball to 1.0 RP
			return state.talent.runic_attenuation.enabled and 1.0 or 0
		end,
	},

	-- Scourge Strike - Core Unholy ability
	scourge_strike = {
		id = 55090,
		cast = 0,
		cooldown = 0,
		gcd = "spell",
		
		spend_runes = {0, 0, 1}, -- 0 Blood, 0 Frost, 1 Unholy
		
		gain = 10,
		gainType = "runic_power",
		
		startsCombat = true,
		
		handler = function ()
			-- Shadow damage component scales with diseases
			local disease_count = 0
			if debuff.frost_fever.up then disease_count = disease_count + 1 end
			if debuff.blood_plague.up then disease_count = disease_count + 1 end
			
			-- Shadow damage is 50% of physical damage per disease
			-- This is handled by the simulation engine
		end,
	},

	-- Death Coil - Core Unholy ability
	death_coil = {
		id = 47541,
		cast = 0,
		cooldown = 0,
		gcd = "spell",
		
		spend = 40,
		spendType = "runic_power",
		
		startsCombat = true,
		
		handler = function ()
			-- Shadow Infusion proc chance (100% when active)
			if buff.shadow_infusion.up then
				removeBuff("shadow_infusion")
				-- Empower ghoul
			end
			
			-- Sudden Doom consumption
			if buff.sudden_doom.up then
				removeBuff("sudden_doom")
				-- Free cast
			end
		end,
	},

	-- Festering Strike - Disease application
	festering_strike = {
		id = 85948,
		cast = 0,
		cooldown = 0,
		gcd = "spell",
		
		spend_runes = {1, 1, 0}, -- 1 Blood, 1 Frost, 0 Unholy
		
		gain = 15,
		gainType = "runic_power",
		
		startsCombat = true,
		
		handler = function ()
			-- Apply both diseases
			applyDebuff("target", "frost_fever", 30)
			applyDebuff("target", "blood_plague", 30)
		end,
	},

	-- Summon Gargoyle - Major cooldown
	summon_gargoyle = {
		id = 49206,
		cast = 0,
		cooldown = 180,
		gcd = "spell",
		
		startsCombat = false,
		
		toggle = "cooldowns",
		
		handler = function ()
			summonPet("gargoyle", 30)
		end,
	},

	-- Dark Transformation - Pet enhancement
	dark_transformation = {
		id = 63560,
		cast = 0,
		cooldown = 60,
		gcd = "spell",
		
		startsCombat = false,
		
		usable = function ()
			return pet.ghoul.active
		end,
		
		handler = function ()
			applyBuff("dark_transformation")
			-- Enhance pet abilities
		end,
	},

	-- Blood Strike - Basic strike
	blood_strike = {
		id = 45529,
		cast = 0,
		cooldown = 0,
		gcd = "spell",
		
		spend_runes = {1, 0, 0}, -- 1 Blood, 0 Frost, 0 Unholy
		
		gain = 10,
		gainType = "runic_power",
		
		startsCombat = true,
		
		handler = function ()
			-- Basic damage ability
		end,
	},

	-- Death and Decay - AoE ground effect
	death_and_decay = {
		id = 43265,
		cast = 0,
		cooldown = 0,
		gcd = "spell",
		
		spend_runes = {0, 0, 1}, -- 0 Blood, 0 Frost, 1 Unholy
		
		gain = 10,
		gainType = "runic_power",
		
		startsCombat = true,
		
		handler = function ()
			applyDebuff("target", "death_and_decay", 10)
		end,
	},

	-- Soul Reaper - Execute ability (Unholy variant)
	soul_reaper = {
		id = 130736,
		cast = 0,
		cooldown = 6,
		gcd = "spell",
		
		spend_runes = {0, 0, 1}, -- 0 Blood, 0 Frost, 1 Unholy
		
		gain = 10,
		gainType = "runic_power",
		
		startsCombat = true,
		
		handler = function ()
			applyDebuff("target", "soul_reaper", 5)
		end,
	},

	-- Additional missing abilities for APL compatibility
	-- Pillar of Frost - Major cooldown
	pillar_of_frost = {
		id = 51271,
		cast = 0,
		cooldown = 60,
		gcd = "spell",
		
		startsCombat = false,
		
		toggle = "cooldowns",
		
		handler = function ()
			applyBuff("pillar_of_frost", 20)
		end,
	},

	-- Raise Dead - Pet summon
	raise_dead = {
		id = 46584,
		cast = 0,
		cooldown = 180,
		gcd = "spell",
		
		startsCombat = false,
		
		handler = function ()
			summonPet("ghoul", 60)
		end,
	},

	-- Outbreak - Disease application
	outbreak = {
		id = 77575,
		cast = 0,
		cooldown = 60,
		gcd = "spell",
		
		startsCombat = true,
		
		handler = function ()
			applyDebuff("target", "frost_fever", 30)
			applyDebuff("target", "blood_plague", 30)
		end,
	},

	-- Plague Strike - Blood Plague application
	plague_strike = {
		id = 45462,
		cast = 0,
		cooldown = 0,
		gcd = "spell",
		
		spend_runes = {1, 0, 0}, -- 1 Blood, 0 Frost, 0 Unholy
		
		gain = 10,
		gainType = "runic_power",
		
		startsCombat = true,
		
		handler = function ()
			applyDebuff("target", "blood_plague", 30)
		end,
	},

	-- Icy Touch - Frost Fever application
	icy_touch = {
		id = 45477,
		cast = 0,
		cooldown = 0,
		gcd = "spell",
		
		spend_runes = {0, 1, 0}, -- 0 Blood, 1 Frost, 0 Unholy
		
		gain = 10,
		gainType = "runic_power",
		
		startsCombat = true,
		
		handler = function ()
			applyDebuff("target", "frost_fever", 30)
		end,
	},

	-- Empower Rune Weapon - Rune refresh
	empower_rune_weapon = {
		id = 47568,
		cast = 0,
		cooldown = 300,
		gcd = "spell",
		
		startsCombat = false,
		
		toggle = "cooldowns",

		usable = function ()
			-- Gate ERW to true starvation moments per APL: no Unholy+Death runes and sufficient RP deficit.
			local rp = (state.runic_power and state.runic_power.current) or 0
			local rpMax = (state.runic_power and state.runic_power.max) or 100
			local rpDeficit = max(0, rpMax - rp)
			local uh = (state.runes and state.runes.unholy and state.runes.unholy.count) or 0
			local dr = (state.runes and state.runes.death and state.runes.death.count) or 0
			local runeStarved = (uh + dr) == 0
			local exec = false
			if class and class.variables and type(class.variables.execute) == "function" then
				exec = class.variables.execute() and true or false
			end
			local needed = exec and 40 or 60
			return runeStarved and rpDeficit >= needed
		end,
		
		handler = function ()
			gain(6, "runes")
			gain(25, "runic_power")
		end,
	},

	-- Horn of Winter - Runic power generation
	horn_of_winter = {
		id = 57330,
		cast = 0,
		cooldown = 20,
		gcd = "spell",
		
		startsCombat = false,
		
		handler = function ()
			gain(25, "runic_power")
			applyBuff("horn_of_winter", 10)
		end,
	},

	-- Mind Freeze - Interrupt
	mind_freeze = {
		id = 47528,
		cast = 0,
		cooldown = 15,
		gcd = "off",
		
		startsCombat = true,
		
		toggle = "interrupts",
		
		debuff = "casting",
		readyTime = state.timeToInterrupt,
		
		handler = function ()
			interrupt()
		end,
	},

	-- Anti-Magic Shell - Defensive
	antimagic_shell = {
		id = 48707,
		cast = 0,
		cooldown = 45,
		gcd = "off",
		
		startsCombat = false,
		
		toggle = function()
			if settings.dps_shell then
				return
			end
			return "defensives"
		end,
		
		handler = function ()
			applyBuff("antimagic_shell")
		end,
	},

	-- Unholy Blight - Disease spread
	unholy_blight = {
		id = 115989,
		cast = 0,
		cooldown = 60,
		gcd = "spell",
		
		talent = "unholy_blight",
		startsCombat = true,
		
		handler = function ()
			applyDebuff("target", "unholy_blight", 10)
		end,
	},

	-- Plague Leech - Rune recovery
	plague_leech = {
		id = 123693,
		cast = 0,
		cooldown = 25,
		gcd = "spell",
		
		talent = "plague_leech",
		startsCombat = true,
		
		usable = function ()
			return debuff.frost_fever.up and debuff.blood_plague.up
		end,
		
		handler = function ()
			removeDebuff("target", "frost_fever")
			removeDebuff("target", "blood_plague")
			gain(1, "runes")
		end,
	},
})

local spendHook = function(amt, resource, noHook)
	if amt > 0 and resource == "runes" and active_dot.shackle_the_unworthy > 0 then
		reduceCooldown("shackle_the_unworthy", 4 * amt)
	end
end

spec:RegisterHook("spend", spendHook)

-- Talents
spec:RegisterTalents({
	-- Tier 1 (Level 56)
	roiling_blood = { 1, 1, 108170 }, -- Your Blood Boil ability now also triggers Pestilence if it strikes a diseased target.
	plague_leech = { 1, 2, 123693 }, -- Extract diseases from an enemy target, consuming up to 2 diseases on the target to gain 1 Rune of each type that was removed.
	unholy_blight = { 1, 3, 115989 }, -- Causes you to spread your diseases to all enemy targets within 10 yards.

	-- Tier 2 (Level 57)
	lichborne = { 2, 1, 49039 }, -- Draw upon unholy energy to become undead for 10 sec. While undead, you are immune to Charm, Fear, and Sleep effects.
	anti_magic_zone = { 2, 2, 51052 }, -- Places a large, stationary Anti-Magic Zone that reduces spell damage taken by party or raid members by 40%. The Anti-Magic Zone lasts for 30 sec or until it absorbs a massive amount of spell damage.
	purgatory = { 2, 3, 114556 }, -- An unholy pact that prevents fatal damage, instead absorbing incoming healing equal to the damage that would have been fatal for 3 sec.

	-- Tier 3 (Level 58)
	deaths_advance = { 3, 1, 96268 }, -- For 8 sec, you are immune to movement impairing effects and your movement speed is increased by 50%.
	chilblains = { 3, 2, 50041 }, -- Victims of your Chains of Ice take 5% increased damage from your abilities for 8 sec.
	asphyxiate = { 3, 3, 108194 }, -- Lifts the enemy target off the ground, crushing their throat and stunning them for 5 sec.

	-- Tier 4 (Level 60)
	death_pact = { 4, 1, 48743 }, -- Drains 50% of your summoned minion's health to heal you for 25% of your maximum health.
	death_siphon = { 4, 2, 108196 }, -- Deals Shadow damage to the target and heals you for 150% of the damage dealt.
	conversion = { 4, 3, 119975 }, -- Continuously converts 2% of your maximum health per second into 20% of maximum health as healing.

	-- Tier 5 (Level 75)
	blood_tap = { 5, 1, 45529 }, -- Consume 5 charges from your Blood Charges to immediately activate a random depleted rune.
	runic_empowerment = { 5, 2, 81229 }, -- When you use a rune, you have a 45% chance to immediately regenerate that rune.
	runic_corruption = { 5, 3, 51462 }, -- When you hit with a Death Coil, Frost Strike, or Rune Strike, you have a 45% chance to regenerate a rune.

	-- Tier 6 (Level 90)
	gorefiends_grasp = { 6, 1, 108199 }, -- Shadowy tendrils coil around all enemies within 20 yards of a hostile target, pulling them to the target's location.
	remorseless_winter = { 6, 2, 108200 }, -- Surrounds the Death Knight with a swirling blizzard that grows over 8 sec, slowing enemies by up to 50% and reducing their melee and ranged attack speed by up to 20%.
	desecrated_ground = { 6, 3, 108201 }, -- Corrupts the ground beneath you, causing all nearby enemies to deal 10% less damage for 30 sec.
})

-- Glyphs
spec:RegisterGlyphs({
	-- Major Glyphs (affecting tanking and mechanics)
	[58623] = "antimagic_shell", -- Causes your Anti-Magic Shell to absorb all incoming magical damage, up to the absorption limit.
	[58620] = "chains_of_ice", -- Your Chains of Ice also causes 144 to 156 Frost damage, with additional damage depending on your attack power.
	[63330] = "dancing_rune_weapon", -- Increases your threat generation by 100% while your Dancing Rune Weapon is active, but reduces its damage dealt by 25%.
	[63331] = "dark_simulacrum", -- Reduces the cooldown of Dark Simulacrum by 30 sec and increases its duration by 4 sec.
	[96279] = "dark_succor", -- When you kill an enemy that yields experience or honor, while in Frost or Unholy Presence, your next Death Strike within 15 sec is free and will restore at least 20% of your maximum health.
	[58629] = "death_and_decay", -- Your Death and Decay also reduces the movement speed of enemies within its radius by 50%.
	[63333] = "death_coil", -- Your Death Coil spell is now usable on all allies.  When cast on a non-undead ally, Death Coil shrouds them with a protective barrier that absorbs up to [(1133 + 0.514 * Attack Power) * 1] damage.
	[62259] = "death_grip", -- Increases the range of your Death Grip ability by 5 yards.
	[58671] = "enduring_infection", -- Your diseases are undispellable, but their damage dealt is reduced by 15%.
	[146650] = "festering_blood", -- Blood Boil will now treat all targets as though they have Blood Plague or Frost Fever applied.
	[58673] = "icebound_fortitude", -- Reduces the cooldown of your Icebound Fortitude by 50%, but also reduces its duration by 75%.
	[58631] = "icy_touch", -- Your Icy Touch dispels one helpful Magic effect from the target.
	[58686] = "mind_freeze", -- Reduces the cooldown of your Mind Freeze ability by 1 sec, but also raises its cost by 10 Runic Power.
	[59332] = "outbreak", -- Your Outbreak spell no longer has a cooldown, but now costs 30 Runic Power.
	[58657] = "pestilence", -- Increases the radius of your Pestilence effect by 5 yards.
	[58635] = "pillar_of_frost", -- Empowers your Pillar of Frost, making you immune to all effects that cause loss of control of your character, but also reduces your movement speed by 70% while the ability is active.
	[146648] = "regenerative_magic", -- If Anti-Magic Shell expires after its full duration, the cooldown is reduced by up to 50%, based on the amount of damage absorbtion remaining.
	[58647] = "shifting_presences", -- You retain 70% of your Runic Power when switching Presences.
	[58618] = "strangulate", -- Increases the Silence duration of your Strangulate ability by 2 sec when used on a target who is casting a spell.
	[146645] = "swift_death", -- The haste effect granted by Soul Reaper now also increases your movement speed by 30% for the duration.
	[146646] = "loud_horn", -- Your Horn of Winter now generates an additional 10 Runic Power, but the cooldown is increased by 100%.
	[59327] = "unholy_command", -- Immediately finishes the cooldown of your Death Grip upon dealing a killing blow to a target that grants experience or honor.
	[58616] = "unholy_frenzy", -- Causes your Unholy Frenzy to no longer deal damage to the affected target.
	[58676] = "vampiric_blood", -- Increases the bonus healing received while your Vampiric Blood is active by an additional 15%, but your Vampiric Blood no longer grants you health.

	-- Minor Glyphs (convenience and visual)
	[58669] = "army_of_the_dead", -- The ghouls summoned by your Army of the Dead no longer taunt their target.
	[59336] = "corpse_explosion", -- Teaches you the ability Corpse Explosion.
	[60200] = "death_gate", -- Reduces the cast time of your Death Gate spell by 60%.
	[58677] = "deaths_embrace", -- Your Death Coil refunds 20 Runic Power when used to heal an allied minion, but will no longer trigger Blood Tap when used this way.
	[58642] = "foul_menagerie", -- Causes your Army of the Dead spell to summon an assortment of undead minions.
	[58680] = "horn_of_winter", -- When used outside of combat, your Horn of Winter ability causes a brief, localized snow flurry.
	[59307] = "path_of_frost", -- Your Path of Frost ability allows you to fall from a greater distance without suffering damage.
	[59309] = "resilient_grip", -- When your Death Grip ability fails because its target is immune, its cooldown is reset.
	[58640] = "geist", -- Your Raise Dead spell summons a geist instead of a ghoul.
	[146653] = "long_winter", -- The effect of your Horn of Winter now lasts for 1 hour.
	[146652] = "skeleton", -- Your Raise Dead spell summons a skeleton instead of a ghoul.
	[63335] = "tranquil_grip", -- Your Death Grip spell no longer taunts the target.
})

-- Auras
spec:RegisterAuras({
	-- Army of the Dead channel window while ghouls are summoned.
	-- https://wowhead.com/spell=42650
	army_of_the_dead = {
		id = 42650,
		duration = 4,
		max_stack = 1,
		generate = function(t)
			local name, _, count, _, duration, expires, caster = FindUnitBuffByID("player", 42650)

			if name then
				t.name = name
				t.count = count or 1
				t.expires = expires
				t.applied = expires - duration
				t.caster = caster
				return
			end

			t.count = 0
			t.expires = 0
			t.applied = 0
			t.caster = "nobody"
		end,
	},
	-- Talent: Absorbing up to $w1 magic damage. Immune to harmful magic effects.
	-- https://wowhead.com/spell=48707
	antimagic_shell = {
		id = 48707,
		duration = 5,
		max_stack = 1,
	},
	-- Talent: Stunned.
	-- https://wowhead.com/spell=108194
	asphyxiate = {
		id = 108194,
		duration = 5.0,
		mechanic = "stun",
		type = "Magic",
		max_stack = 1,
	},
	-- Talent: Movement slowed $w1% $?$w5!=0[and Haste reduced $w5% ][]by frozen chains.
	-- https://wowhead.com/spell=45524
	chains_of_ice = {
		id = 45524,
		duration = 8,
		mechanic = "snare",
		type = "Magic",
		max_stack = 1,
	},
	-- Taunted.
	-- https://wowhead.com/spell=56222
	dark_command = {
		id = 56222,
		duration = 3,
		mechanic = "taunt",
		max_stack = 1,
	},
	-- Your next Death Strike is free and heals for an additional $s1% of maximum health.
	-- https://wowhead.com/spell=101568
	dark_succor = {
		id = 101568,
		duration = 15,
		max_stack = 1,
	},
	-- Talent: $?$w2>0[Transformed into an undead monstrosity.][Gassy.] Damage dealt increased by $w1%.
	-- https://wowhead.com/spell=63560
	dark_transformation = {
		id = 63560,
		duration = 30,
		max_stack = 1,
		generate = function(t)
			local name, _, count, _, duration, expires, caster = FindUnitBuffByID("pet", 63560)

			if name then
				t.name = name
				t.count = 1
				t.expires = expires
				t.applied = expires - duration
				t.caster = caster
				return
			end

			t.count = 0
			t.expires = 0
			t.applied = 0
			t.caster = "nobody"
		end,
	},
	-- Inflicts $s1 Shadow damage every sec.
	death_and_decay = {
		id = 43265,
		duration = 10,
		tick_time = 1.0,
		max_stack = 1,
	},
	-- Your movement speed is increased by $w1%, you cannot be slowed below $s2% of normal speed, and you are immune to forced movement effects and knockbacks.
	deaths_advance = {
		id = 96268,
		duration = 8,
		type = "Magic",
		max_stack = 1,
	},
	-- Defile the targeted ground, dealing Shadow damage to all enemies over $d. While you remain within your Defile, your Scourge Strike will hit multiple enemies near the target. If any enemies are standing in the Defile, it grows in size and deals increasing damage every sec.
	defile = {
		id = 43265, -- In MoP, Defile uses the same spell ID as Death and Decay
		duration = 30,
		tick_time = 1,
		max_stack = 1,
	},
	-- Suffering $w1 Frost damage every $t1 sec.
	-- https://wowhead.com/spell=55095
	frost_fever = {
		id = 55095,
		duration = 30,
		tick_time = 3,
		max_stack = 1,
		type = "Disease",
	},
	-- Talent: Damage taken reduced by $w3%. Immune to Stun effects.
	-- https://wowhead.com/spell=48792
	icebound_fortitude = {
		id = 48792,
		duration = 8,
		max_stack = 1,
	},
	-- Leech increased by $s1%$?a389682[, damage taken reduced by $s8%][] and immune to Charm, Fear and Sleep. Undead.
	-- https://wowhead.com/spell=49039
	lichborne = {
		id = 49039,
		duration = 10,
		tick_time = 1,
		max_stack = 1,
	},
	-- A necrotic strike shield that absorbs the next $w1 healing received.
	necrotic_strike = {
		id = 73975,
		duration = 10,
		max_stack = 1,
	},
	-- Grants the ability to walk across water.
	-- https://wowhead.com/spell=3714
	path_of_frost = {
		id = 3714,
		duration = 600,
		tick_time = 0.5,
		max_stack = 1,
	},
	-- Inflicted with a plague that spreads to nearby enemies when dispelled.
	plague_leech = {
		id = 123693,
		duration = 3,
		max_stack = 1,
	},
	-- An unholy pact that prevents fatal damage.
	purgatory = {
		id = 114556,
		duration = 3,
		max_stack = 1,
	},
	-- TODO: Is a pet.
	raise_dead = {
		id = 46584,
		max_stack = 1,
	},
	-- Frost damage taken from the Death Knight's abilities increased by $s1%.
	-- https://wowhead.com/spell=51714
	razorice = {
		id = 51714,
		duration = 20,
		tick_time = 1,
		type = "Magic",
		max_stack = 5,
	},
	-- Increases your rune regeneration rate for 3 sec.
	runic_corruption = {
		id = 51460,
		duration = function()
			return 3 * haste
		end,
		max_stack = 1,
	},
	-- Talent: Afflicted by Soul Reaper, if the target is below $s3% health this effect will explode dealing additional Shadowfrost damage.
	-- https://wowhead.com/spell=130736
	soul_reaper = {
		id = 130736,
		duration = 5,
		tick_time = 5,
		type = "Magic",
		max_stack = 1,
	},
	-- Your next Death Coil cost no Runic Power and is guaranteed to critically strike.
	sudden_doom = {
		id = 81340,
		duration = 10,
		max_stack = 1,
	},

	-- Grants your successful Death Coils a chance to empower your active Ghoul, increasing its damage dealt by 10% for 30 sec.  Stacks up to 5 times.
	shadow_infusion = {
		id = 91342,
		duration = 30,
		max_stack = 5,
		generate = function(t)
			local name, _, count, _, duration, expires, caster = FindUnitBuffByID("pet", 91342)

			if name then
				t.name = name
				t.count = count
				t.expires = expires
				t.applied = expires - duration
				t.caster = caster
				return
			end

			t.count = 0
			t.expires = 0
			t.applied = 0
			t.caster = "nobody"
		end,
	},
	-- Silenced.
	strangulate = {
		id = 47476,
		duration = 5,
		max_stack = 1,
	},
	-- Presence Tracking
	blood_presence = {
		id = 48263,
		duration = 3600,
		max_stack = 1,
	},

	unholy_presence = {
		id = 48265,
		duration = 3600,
		max_stack = 1,
	},

	frost_presence = {
		id = 48266,
		duration = 3600,
		max_stack = 1,
	},
	-- Suffering $w1 Shadow damage every $t1 sec. Erupts for damage split among all nearby enemies when the infected dies.
	-- https://wowhead.com/spell=191587
	virulent_plague = {
		id = 191587,
		duration = 21,
		tick_time = 3,
		type = "Disease",
		max_stack = 1,
	},
	-- The touch of the spirit realm lingers....
	-- https://wowhead.com/spell=97821
	voidtouched = {
		id = 97821,
		duration = 300,
		max_stack = 1,
	},
	-- Talent: Movement speed increased by $w1%. Cannot be slowed below $s2% of normal movement speed. Cannot attack.
	-- https://wowhead.com/spell=212552
	wraith_walk = {
		id = 212552,
		duration = 4,
		max_stack = 1,
	},

	-- PvP Talents
	-- Your next spell with a mana cost will be copied by the Death Knight's runeblade.
	dark_simulacrum = {
		id = 77606,
		duration = 12,
		max_stack = 1,
	},
	-- Your runeblade contains trapped magical energies, ready to be unleashed.
	dark_simulacrum_buff = {
		id = 77616,
		duration = 12,
		max_stack = 1,
	},

	-- Blood Tap charges for converting runes to Death Runes
	blood_charge = {
		id = 114851,
		duration = 25,
		max_stack = 12,
	},

	-- Horn of Winter buff - increases Attack Power
	horn_of_winter = {
		id = 57330,
		duration = 300,
		max_stack = 1,
	},

	-- Unholy Frenzy buff - increase Attack Speed
	unholy_frenzy = {
		id = 49016,
		duration = 30,
		max_stack = 1,
	},

	-- Orc Racial: Blood Fury (AP/Haste variant used in MoP APL windows)
	blood_fury = {
		id = 33697,
		duration = 15,
		max_stack = 1,
	},

	-- Troll Racial: Berserking (used in MoP APL windows)
	berserking = {
		id = 26297,
		duration = 10,
		max_stack = 1,
	},

	-- Engineering: Synapse Springs (on-use gloves)
	synapse_springs = {
		id = 126734,
		duration = 10,
		max_stack = 1,
	},

	-- Unholy Blight area effect
	unholy_blight = {
		id = 115989,
		duration = 10,
		max_stack = 1,
	},

	-- Inflicted with a disease that deals Shadow damage over time.
	blood_plague = {
		id = 55078,
		duration = 30,
		tick_time = 3,
		type = "Disease",
		max_stack = 1,
	},
	fallen_crusader = {
		id = 53344,
		duration = 15,
		max_stack = 1,
		type = "Physical",
	},
	-- Unholy Strength buff - increases Strength by 15% for 15 seconds, procs from Fallen Crusader
	-- Used for snapshotting other abilities
	unholy_strength = {
		id = 53365,
		duration = 15,
		max_stack = 1,
		type = "Physical",
	},


	-- Ebon Plaguebringer - Disease enhancement
	ebon_plaguebringer = {
		id = 51160,
		duration = 30,
		max_stack = 1,
	},

	-- Unholy Might - Mastery buff
	unholy_might = {
		id = 53365,
		duration = 15,
		max_stack = 1,
	},
})

-- Pets
spec:RegisterPets({
	ghoul = {
		id = 26125,
		spell = "raise_dead",
		duration = 3600,
	},
	risen_skulker = {
		id = 99541,
		spell = "raise_dead",
		duration = function()
			return talent.raise_dead_2.enabled and 3600 or 60
		end,
	},
})

-- Totems (which are sometimes pets in MoP)
spec:RegisterTotems({
	gargoyle = {
		id = 49206,
		duration = 30,
	},
	ghoul = {
		id = 26125,
		duration = 3600,
	},
	army_ghoul = {
		id = 24207,
		duration = 40,
	},
})

local dmg_events = {
	SPELL_DAMAGE = 1,
	SPELL_PERIODIC_DAMAGE = 1,
}

local aura_removals = {
	SPELL_AURA_REMOVED = 1,
	SPELL_AURA_REMOVED_DOSE = 1,
}

local dnd_damage_ids = {
	[43265] = "death_and_decay",
}

local last_dnd_tick, dnd_spell = 0, "death_and_decay"

local sd_consumers = {
	death_coil = "doomed_bidding_magus_coil",
	epidemic = "doomed_bidding_magus_epi",
}

local db_casts = {}
local doomed_biddings = {}

local last_bb_summon = 0

-- 20250426: Decouple Death and Decay *buff* from dot.death_and_decay.ticking
spec:RegisterCombatLogEvent(
	function(
		_,
		subtype,
		_,
		sourceGUID,
		sourceName,
		sourceFlags,
		_,
		destGUID,
		destName,
		destFlags,
		_,
		spellID,
		spellName
	)
		if sourceGUID ~= state.GUID then
			return
		end

		if dnd_damage_ids[spellID] and dmg_events[subtype] then
			last_dnd_tick = GetTime()
			dnd_spell = dnd_damage_ids[spellID]
			return
		end

		if state.talent.doomed_bidding.enabled then
			if subtype == "SPELL_CAST_SUCCESS" then
				local consumer = class.abilities[spellID]
				if not consumer then
					return
				end
				consumer = consumer and consumer.key

				if sd_consumers[consumer] then
					db_casts[GetTime()] = consumer
				end
				return
			end

			if spellID == class.auras.sudden_doom.id and aura_removals[subtype] and #doomed_biddings > 0 then
				local now = GetTime()
				for time, consumer in pairs(db_casts) do
					if now - time < 0.5 then
						doomed_biddings[now + 6] = sd_consumers[consumer]
						db_casts[time] = nil
					end
				end
				return
			end
		end

		if subtype == "SPELL_SUMMON" and spellID == 434237 then
			last_bb_summon = GetTime()
			return
		end
	end
)

local dnd_model = setmetatable({}, {
	__index = function(t, k)
		if k == "ticking" then
			-- Disabled
			-- if state.query_time - class.abilities.any_dnd.lastCast < 10 then return true end
			return debuff.death_and_decay.up
		elseif k == "remains" then
			return debuff.death_and_decay.remains
		end

		return false
	end,
})

spec:RegisterStateTable("death_and_decay", dnd_model)
spec:RegisterStateTable("defile", dnd_model)

-- Death Knight state table with runeforge support
local mt_runeforges = {
	__index = function(t, k)
		return false
	end,
}

spec:RegisterStateTable(
	"death_knight",
	setmetatable({
		disable_aotd = false,
		delay = 6,
		runeforge = setmetatable({}, mt_runeforges),
	}, {
		__index = function(t, k)
			if k == "disable_iqd_execute" then
				return state.settings.disable_iqd_execute and 1 or 0
			end
			return 0
		end,
	})
)

spec:RegisterStateExpr("dnd_ticking", function()
	return state.debuff.death_and_decay.up
end)

spec:RegisterStateExpr("unholy_frenzy_haste", function()
	if buff.unholy_frenzy.up and buff.unholy_frenzy.on_self then
		-- TODO: Add haste increase
	end
end)

spec:RegisterStateExpr("fallen_crusader_up", function()
	return buff.unholy_strength.up
end)

spec:RegisterStateExpr("dnd_remains", function()
	return state.debuff.death_and_decay.remains
end)

-- Execute window helpers and HolyMoly gating
-- Equivalent to: target.health.pct - 3 * ( target.health.pct / target.time_to_die ) <= 35
-- Mirrors Frost's helper for consistent Soul Reaper planning
spec:RegisterStateExpr("sr_exec_window_3s", function()
	if not target or not target.time_to_die or target.time_to_die <= 0 then return false end
	local hp = target.health and target.health.pct or 100
	return ( hp - 3 * ( hp / target.time_to_die ) ) <= 35
end)

-- Hardcoded variables so APL-imported variable entries defer to these runtime values.
-- variable.execute: true when target HP is at/below the configured execute threshold.
spec:RegisterVariable("execute", function()
	local threshold = (state.settings and state.settings.unholy_execute_threshold) or 35
	local hp = (target and target.health and target.health.pct) or 100
	return hp <= threshold
end)

-- variable.dots_up: both diseases are ticking on the target.
spec:RegisterVariable("dots_up", function()
	return (debuff.blood_plague and debuff.blood_plague.up) and (debuff.frost_fever and debuff.frost_fever.up)
end)

-- variable.proc_window: window to stack/sync cooldowns with temporary procs and major buffs.
spec:RegisterVariable("proc_window", function()
	return (
		(buff.unholy_strength and buff.unholy_strength.up) or
		(buff.dark_transformation and buff.dark_transformation.up) or
		(buff.bloodlust and buff.bloodlust.up) or
		(buff.heroism and buff.heroism.up) or
		(buff.time_warp and buff.time_warp.up) or
		(buff.ancient_hysteria and buff.ancient_hysteria.up) or
		(buff.blood_fury and buff.blood_fury.up) or
		(buff.berserking and buff.berserking.up)
	) and true or false
end)

-- variable.holy_moly: gate certain actions during execute if Soul Reaper will be ready within ~2 GCDs.
-- Matches the SimC approximation: !(variable.execute & (cooldown.soul_reaper.remains <= gcd.max * 2))
spec:RegisterVariable("holy_moly", function()
	-- Prefer a dynamic execute window (3s lookahead) and fall back to threshold-based execute if needed.
	local dyn_exec = false
	if target and target.time_to_die and target.time_to_die > 0 then
		local hp = (target and target.health and target.health.pct) or 100
		-- Dynamic execute window similar to sr_exec_window_3s
		dyn_exec = ( hp - 3 * ( hp / target.time_to_die ) ) <= 35
	end

	local flat_exec
	if class and class.variables and type(class.variables.execute) == "function" then
		flat_exec = class.variables.execute()
	else
		local threshold = (state.settings and state.settings.unholy_execute_threshold) or 35
		local hp = (target and target.health and target.health.pct) or 100
		flat_exec = hp <= threshold
	end

	local exec = dyn_exec or flat_exec

	local sr_cd = state.cooldown and state.cooldown.soul_reaper and state.cooldown.soul_reaper.remains or 999
	local gcd_max = state.gcd and state.gcd.max or 1.5
	return not ( exec and ( sr_cd <= ( 2 * gcd_max ) ) )
end)

spec:RegisterHook("step", function(time)
	if Hekili.ActiveDebug then
		Hekili:Debug(
			"Rune Regeneration Time: 1=%.2f, 2=%.2f, 3=%.2f, 4=%.2f, 5=%.2f, 6=%.2f\n",
			runes.time_to_1,
			runes.time_to_2,
			runes.time_to_3,
			runes.time_to_4,
			runes.time_to_5,
			runes.time_to_6
		)
	end
end)

spec:RegisterGear({
	-- Mists of Pandaria Tier Sets
	tier16 = {
		items = { 99369, 99370, 99371, 99372, 99373 }, -- Death Knight T16
		auras = {
			death_shroud = {
				id = 144901,
				duration = 30,
				max_stack = 5,
			},
		},
	},
	tier15 = {
		items = { 95339, 95340, 95341, 95342, 95343 }, -- Death Knight T15
		auras = {
			unholy_vigor = {
				id = 138547,
				duration = 15,
				max_stack = 1,
			},
		},
	},
	tier14 = {
		items = { 84407, 84408, 84409, 84410, 84411 }, -- Death Knight T14
		auras = {
			shadow_clone = {
				id = 123556,
				duration = 8,
				max_stack = 1,
			},
		},
	},
})

spec:RegisterHook("TALENTS_UPDATED", function()
	class.abilityList.any_dnd = "|T136144:0|t |cff00ccff[Any " .. class.abilities.death_and_decay.name .. "]|r"
	local dnd = talent.defile.enabled and "defile" or "death_and_decay"

	class.abilities.any_dnd = class.abilities[dnd]
	rawset(cooldown, "any_dnd", nil)
	rawset(cooldown, "death_and_decay", nil)
	rawset(cooldown, "defile", nil)

	if dnd == "defile" then
		rawset(cooldown, "death_and_decay", cooldown.defile)
	else
		rawset(cooldown, "defile", cooldown.death_and_decay)
	end
end)

-- MoP ghoul/pet summoning system - much simpler than later expansions
local ghoul_applicators = {
	army_of_the_dead = {
		army_ghoul = { 40 },
	},
	summon_gargoyle = {
		gargoyle = { 30 },
	},
}

spec:RegisterHook("reset_precast", function()
	if totem.gargoyle.remains > 0 then
		summonPet("gargoyle", totem.gargoyle.remains)
	end

	local control_expires = action.control_undead.lastCast + 300
	if control_expires > state.query_time and pet.up and not pet.ghoul.up then
		summonPet("controlled_undead", control_expires - state.query_time)
	end

	for spell, ghouls in pairs(ghoul_applicators) do
		local cast_time = action[spell].lastCast

		for ghoul, info in pairs(ghouls) do
			dismissPet(ghoul)

			if cast_time > 0 then
				local expires = cast_time + info[1]

				if expires > state.query_time then
					summonPet(ghoul, expires - state.query_time)
				end
			end
		end
	end

	if buff.death_and_decay.up then
		local duration = buff.death_and_decay.duration
		if duration > 4 then
			if Hekili.ActiveDebug then
				Hekili:Debug(
					"Death and Decay buff extended by 4; %.2f to %.2f.",
					buff.death_and_decay.remains,
					buff.death_and_decay.remains + 4
				)
			end
			buff.death_and_decay.expires = buff.death_and_decay.expires + 4
		else
			if Hekili.ActiveDebug then
				Hekili:Debug(
					"Death and Decay buff with duration of %.2f not extended; %.2f remains.",
					duration,
					buff.death_and_decay.remains
				)
			end
		end
	end

	-- Death and Decay tick time is 1s; if we haven't seen a tick in 2 seconds, it's not ticking.
	local last_dnd = action[dnd_spell].lastCast
	local dnd_expires = last_dnd + 10
	if state.query_time - last_dnd_tick < 2 and dnd_expires > state.query_time then
		applyDebuff("target", "death_and_decay", dnd_expires - state.query_time)
		debuff.death_and_decay.duration = 10
		debuff.death_and_decay.applied = debuff.death_and_decay.expires - 10
	end

	if Hekili.ActiveDebug then
		Hekili:Debug("Pet is %s.", pet.alive and "alive" or "dead")
	end
end)

-- MoP runeforges are different
local runeforges = {
	[3370] = "razorice",
	[3368] = "fallen_crusader",
	[3847] = "stoneskin_gargoyle",
}

local function ResetRuneforges()
	if not state.death_knight then
		state.death_knight = {}
	end
	if not state.death_knight.runeforge then
		state.death_knight.runeforge = {}
	end
	table.wipe(state.death_knight.runeforge)
end

local function UpdateRuneforge(slot, item)
	if slot == 16 or slot == 17 then
		if not state.death_knight then
			state.death_knight = {}
		end
		if not state.death_knight.runeforge then
			state.death_knight.runeforge = {}
		end

		local link = GetInventoryItemLink("player", slot)
		local enchant = link and link:match("item:%d+:(%d+)")

		if enchant then
			enchant = tonumber(enchant)
			local name = runeforges[enchant]

			if name then
				state.death_knight.runeforge[name] = true

				if name == "razorice" and slot == 16 then
					state.death_knight.runeforge.razorice_mh = true
				elseif name == "razorice" and slot == 17 then
					state.death_knight.runeforge.razorice_oh = true
				elseif name == "fallen_crusader" and slot == 16 then
					state.death_knight.runeforge.fallen_crusader_mh = true
				elseif name == "fallen_crusader" and slot == 17 then
					state.death_knight.runeforge.fallen_crusader_oh = true
				end
			end
		end
	end
end

-- Keep runeforge state fresh using classic-safe events.
do
	local f = CreateFrame("Frame")
	f:RegisterEvent("PLAYER_ENTERING_WORLD")
	f:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
	f:SetScript("OnEvent", function(_, evt, ...)
		if evt == "PLAYER_ENTERING_WORLD" then
			ResetRuneforges()
			UpdateRuneforge(16)
			UpdateRuneforge(17)
		elseif evt == "PLAYER_EQUIPMENT_CHANGED" then
			local slot = ...
			if slot == 16 or slot == 17 then
				ResetRuneforges()
				UpdateRuneforge(16)
				UpdateRuneforge(17)
			end
		end
	end)
end

Hekili:RegisterGearHook(ResetRuneforges, UpdateRuneforge)

-- Abilities
spec:RegisterAbilities({
	-- Talent: Surrounds you in an Anti-Magic Shell for $d, absorbing up to $<shield> magic ...
	antimagic_shell = {
		id = 48707,
		cast = 0,
		cooldown = 45,
		gcd = "off",

		startsCombat = false,

		toggle = function()
			if settings.dps_shell then
				return
			end
			return "defensives"
		end,

		handler = function()
			applyBuff("antimagic_shell")
		end,
	},

	-- Talent: Places an Anti-Magic Zone that reduces spell damage taken by party or raid me...
	antimagic_zone = {
		id = 51052,
		cast = 0,
		cooldown = 120,
		gcd = "spell",

		talent = "antimagic_zone",
		startsCombat = false,

		toggle = "cooldowns",

		handler = function()
			applyBuff("antimagic_zone")
		end,
	},

	-- Talent: Summons a legion of ghouls who swarms your enemies, fighting anything they ca...
	army_of_the_dead = {
		id = 42650,
		cast = 4,
		cooldown = 600,
		gcd = "spell",

		spend_runes = { 1, 1, 1 }, -- 1 Blood, 1 Frost, 1 Unholy

		startsCombat = false,
		texture = 237511,

		toggle = "cooldowns",

		handler = function()
			applyBuff("army_of_the_dead", 4)
			summonPet("army_ghoul", 40)
		end,
	},

	-- Talent: Lifts the enemy target off the ground, crushing their throat with dark energy...
	asphyxiate = {
		id = 108194,
		cast = 0,
		cooldown = 30,
		gcd = "spell",

		talent = "asphyxiate",
		startsCombat = true,

		toggle = "interrupts",

		debuff = "casting",
		readyTime = state.timeToInterrupt,

		handler = function()
			applyDebuff("target", "asphyxiate")
		end,
	},

	-- Talent: Convert Blood Charges to Death Runes.
	blood_tap = {
		id = 45529,
		cast = 0,
		cooldown = 1,
		gcd = "off",

		talent = "blood_tap",
		startsCombat = false,

		usable = function()
			return buff.blood_charge.stack >= 5
		end,

		handler = function()
			removeBuff("blood_charge", 5)
			--TODO: Add in generation of Death rune
		end,
	},

	-- Empower Rune Weapon: Instantly activates all your runes and grants RP
	empower_rune_weapon = {
		id = 47568,
		cast = 0,
		cooldown = 300,
		gcd = "off",

		startsCombat = false,
		toggle = "cooldowns",

		usable = function()
			-- Mirror APL gating: only when no UH/Death runes and enough RP deficit
			local rp = (state.runic_power and state.runic_power.current) or 0
			local rpMax = (state.runic_power and state.runic_power.max) or 100
			local rpDeficit = max(0, rpMax - rp)
			local uh = (state.runes and state.runes.unholy and state.runes.unholy.count) or 0
			local dr = (state.runes and state.runes.death and state.runes.death.count) or 0
			local runeStarved = (uh + dr) == 0
			local exec = false
			if class and class.variables and type(class.variables.execute) == "function" then
				exec = class.variables.execute() and true or false
			end
			local needed = exec and 40 or 60
			return runeStarved and rpDeficit >= needed
		end,

		handler = function()
			gain(6, "runes")
			gain(25, "runic_power")
		end,
	},

	-- Festering Strike: A vicious strike that deals weapon damage and infects the target with a disease
	festering_strike = {
		id = 85948,
		cast = 0,
		cooldown = 0,
		gcd = "spell",

		spend_runes = { 1, 1, 0 }, -- 1 Blood, 1 Frost, 0 Unholy

		startsCombat = true,

		--handler = function()
		--TODO: Increase the duration of Blood Plague, Frost Fever, and Chains of Ice effects on the target by up to 6 seconds
		--end,
	},

	-- Outbreak: Instantly applies both Frost Fever and Blood Plague to the target
	outbreak = {
		id = 77575,
		cast = 0,
		cooldown = function()
			if glyph and glyph.outbreak and glyph.outbreak.enabled then
				return 0
			end
			return 60
		end,
		gcd = "spell",

		spend = function()
			if glyph and glyph.outbreak and glyph.outbreak.enabled then
				return 30
			end
			return 0
		end,
		spendType = "runic_power",

		startsCombat = true,

		usable = function()
			if glyph and glyph.outbreak and glyph.outbreak.enabled then
				local current = (state.runic_power and state.runic_power.current) or 0
				if current < 30 then
					return false, "requires 30 runic power"
				end
			end
			return true
		end,

		handler = function()
			applyDebuff("target", "frost_fever")
			applyDebuff("target", "blood_plague")
		end,
	},

	-- Pestilence: Spreads diseases from the target to nearby enemies
	pestilence = {
		id = 50842,
		cast = 0,
		cooldown = 0,
		gcd = "spell",

		spend_runes = { 1, 0, 0 }, -- 1 Blood, 0 Frost, 0 Unholy

		startsCombat = true,

		usable = function()
			return debuff.frost_fever.up or debuff.blood_plague.up
		end,

		handler = function()
			gain(10, "runic_power")
			if debuff.frost_fever.up then
				active_dot.frost_fever = min(active_enemies, active_dot.frost_fever + active_enemies - 1)
			end
			if debuff.blood_plague.up then
				active_dot.blood_plague = min(active_enemies, active_dot.blood_plague + active_enemies - 1)
			end
		end,
	},

	-- Talent: Extract diseases from target to gain runes (MoP 5.5.0)
	plague_leech = {
		id = 123693,
		cast = 0,
		cooldown = 0,
		gcd = "spell",

		talent = "plague_leech",
		startsCombat = true,

		usable = function()
			-- MoP: Can only use when diseases are about to expire or for rune generation
			local deficit = state.rune_deficit
			return (debuff.frost_fever.up and debuff.frost_fever.remains < 3)
				or (debuff.blood_plague.up and debuff.blood_plague.remains < 3)
				or (deficit >= 2 and (debuff.frost_fever.up or debuff.blood_plague.up))
		end,

		handler = function()
			local runes_gained = 0
			if debuff.frost_fever.up then
				removeDebuff("target", "frost_fever")
				runes_gained = runes_gained + 1
			end
			if debuff.blood_plague.up then
				removeDebuff("target", "blood_plague")
				runes_gained = runes_gained + 1
			end
			gain(runes_gained, "runes")
		end,
	},

	-- Talent: Surrounds the caster with unholy energy that damages nearby enemies
	unholy_blight = {
		id = 115989,
		cast = 0,
		cooldown = 90,
		gcd = "spell",

		talent = "unholy_blight",
		startsCombat = true,

		handler = function()
			applyBuff("unholy_blight")
			applyDebuff("target", "frost_fever")
			applyDebuff("target", "blood_plague")
		end,
	},

	-- Talent: Shackles the target $?a373930[and $373930s1 nearby enemy ][]with frozen chain...
	chains_of_ice = {
		id = 45524,
		cast = 0,
		cooldown = 0,
		gcd = "spell",

		spend_runes = { 0, 1, 0 }, -- 0 Blood, 1 Frost, 0 Unholy

		startsCombat = true,

		handler = function()
			applyDebuff("target", "chains_of_ice")
		end,
	},

	-- Command the target to attack you.
	dark_command = {
		id = 56222,
		cast = 0,
		cooldown = 8,
		gcd = "off",

		startsCombat = true,

		handler = function()
			applyDebuff("target", "dark_command")
		end,
	},

	dark_simulacrum = {
		id = 77606,
		cast = 0,
		cooldown = 60,
		gcd = "off",

		spend = 20,
		spendType = "runic_power",

		pvptalent = "dark_simulacrum",
		startsCombat = false,
		texture = 135888,

		usable = function()
			if not target.is_player then
				return false, "target is not a player"
			end
			return true
		end,
		handler = function()
			applyDebuff("target", "dark_simulacrum")
		end,
	},

	-- Pet transformed into an undead monstrosity. Damage dealt increased by 100%.
	dark_transformation = {
		id = 63560,
		cast = 0,
		cooldown = 0,
		gcd = "spell",

		spend_runes = { 0, 0, 1 },

		startsCombat = false,
		texture = 342913,
		usable = function()
			if pet.ghoul.down then
				return false, "requires a living ghoul"
			end
			if buff.shadow_infusion.stacks < 5 then
				return false, "requires five stacks of shadow_infusion"
			end
			return true
		end,

		handler = function()
			applyBuff("dark_transformation")
			removeBuff("shadow_infusion")
		end,
	},

	-- Corrupts the targeted ground, causing ${$52212m1*11} Shadow damage over $d to...
	death_and_decay = {
		id = 43265,
		cast = 0,
		cooldown = 30,
		gcd = "spell",

		spend_runes = { 0, 0, 1 }, -- 0 Blood, 0 Frost, 1 Unholy

		startsCombat = true,
		notalent = "defile",

		usable = function()
			return (settings.dnd_while_moving or not moving), "cannot cast while moving"
		end,

		handler = function()
			applyBuff("death_and_decay")
			applyDebuff("target", "death_and_decay")
		end,

		bind = { "defile", "any_dnd" },

		copy = "any_dnd",
	},

	-- Fires a blast of unholy energy at the target$?a377580[ and $377580s2 addition...
	death_coil = {
		id = 47541,
		cast = 0,
		cooldown = 0,
		gcd = "spell",

		spend = function()
			return buff.sudden_doom.up and 0 or 32
		end,
		spendType = "runic_power",

		startsCombat = true,
		texture = 136145,

		handler = function()
			removeBuff("sudden_doom")
		end,
	},

	-- Opens a gate which you can use to return to Ebon Hold.    Using a Death Gate ...
	death_gate = {
		id = 50977,
		cast = 4,
		cooldown = 60,
		gcd = "spell",

		spend_runes = { 0, 0, 1 }, -- 0 Blood, 0 Frost, 1 Unholy

		startsCombat = false,

		handler = function() end,
	},

	-- Harnesses the energy that surrounds and binds all matter, drawing the target ...
	death_grip = {
		id = 49576,
		cast = 0,
		cooldown = 35,
		gcd = "off",
		icd = 0.5,

		startsCombat = true,

		handler = function()
			applyDebuff("target", "death_grip")
			setDistance(5)
		end,
	},

	-- Talent: Create a death pact that heals you for $s1% of your maximum health, but absor...
	death_pact = {
		id = 48743,
		cast = 0,
		cooldown = 120,
		gcd = "off",

		talent = "death_pact",
		startsCombat = false,

		toggle = "defensives",

		usable = function()
			return pet.alive, "requires an undead pet"
		end,

		handler = function()
			gain(health.max * 0.25, "health")
		end,
	},

	-- Talent: Focuses dark power into a strike$?s137006[ with both weapons, that deals a to...
	death_strike = {
		id = 49998,
		cast = 0,
		cooldown = 0,
		gcd = "spell",

		spend_runes = function()
			if buff.dark_succor.up then
				return { 0, 0, 0 }
			end
			return { 0, 1, 1 }
		end,

		startsCombat = true,

		handler = function()
			removeBuff("dark_succor")
		end,
	},

	-- For $d, your movement speed is increased by $s1%, you cannot be slowed below ...
	deaths_advance = {
		id = 96268,
		cast = 0,
		cooldown = 120,
		gcd = "off",

		talent = "deaths_advance",
		startsCombat = false,

		handler = function()
			applyBuff("deaths_advance")
		end,
	},

	-- Defile the targeted ground, dealing Shadow damage over time. While you remain within your Defile, your Scourge Strike will hit multiple enemies near the target. If any enemies are standing in the Defile, it grows in size and deals increasing damage every sec.
	defile = {
		id = 43265, -- In MoP, Defile uses the same spell ID as Death and Decay
		cast = 0,
		cooldown = 30,
		gcd = "spell",

		spend_runes = { 1, 0, 0 }, -- 1 Blood, 0 Frost, 0 Unholy

		talent = "defile",
		startsCombat = true,

		usable = function()
			return (settings.dnd_while_moving or not moving), "cannot cast while moving"
		end,

		handler = function()
			applyDebuff("target", "defile")
			applyBuff("death_and_decay")
			applyDebuff("target", "death_and_decay")
		end,

		bind = { "death_and_decay", "any_dnd" },
	},

	-- Strike an enemy for Frost damage and infect them with Frost Fever
	icy_touch = {
		id = 45477,
		cast = 0,
		cooldown = 0,
		gcd = "spell",

		spend_runes = { 0, 1, 0 }, -- 0 Blood, 1 Frost, 0 Unholy

		startsCombat = true,

		handler = function()
			applyDebuff("target", "frost_fever")
		end,
	},

	-- Talent: Your blood freezes, granting immunity to Stun effects and reducing all damage...
	icebound_fortitude = {
		id = 48792,
		cast = 0,
		cooldown = 180,
		gcd = "off",

		talent = "icebound_fortitude",
		startsCombat = false,

		toggle = "defensives",

		handler = function()
			applyBuff("icebound_fortitude")
		end,
	},

	-- Draw upon unholy energy to become Undead for $d, increasing Leech by $s1%$?a3...
	lichborne = {
		id = 49039,
		cast = 0,
		cooldown = 120,
		gcd = "off",

		talent = "lichborne",
		startsCombat = false,

		toggle = "defensives",

		handler = function()
			applyBuff("lichborne")
		end,
	},

	-- Talent: Smash the target's mind with cold, interrupting spellcasting and preventing a...
	mind_freeze = {
		id = 47528,
		cast = 0,
		cooldown = 15,
		gcd = "off",

		startsCombat = true,

		toggle = "interrupts",

		debuff = "casting",
		readyTime = state.timeToInterrupt,

		handler = function()
			interrupt()
		end,
	},

	-- A necrotic strike that deals weapon damage and applies a Necrotic Strike shield
	necrotic_strike = {
		id = 73975,
		cast = 0,
		cooldown = 0,
		gcd = "spell",

		spend_runes = { 0, 0, 1 }, -- 0 Blood, 0 Frost, 1 Unholy

		talent = "necrotic_strike",
		startsCombat = true,

		handler = function()
			applyDebuff("target", "necrotic_strike")
		end,
	},

	-- Activates a freezing aura for $d that creates ice beneath your feet, allowing...
	path_of_frost = {
		id = 3714,
		cast = 0,
		cooldown = 0,
		gcd = "spell",

		spend_runes = { 0, 1, 0 }, -- 0 Blood, 1 Frost, 0 Unholy

		startsCombat = false,

		handler = function()
			applyBuff("path_of_frost")
		end,
	},

	-- Strike an enemy for Unholy damage and infect them with Blood Plague
	plague_strike = {
		id = 45462,
		cast = 0,
		cooldown = 0,
		gcd = "spell",

		spend_runes = { 0, 0, 1 }, -- 0 Blood, 0 Frost, 1 Unholy

		startsCombat = true,

		handler = function()
			applyDebuff("target", "blood_plague")
		end,
	},

	-- An unholy pact that prevents fatal damage, instead absorbing incoming healing
	purgatory = {
		id = 114556,
		cast = 0,
		cooldown = 240,
		gcd = "off",

		talent = "purgatory",
		startsCombat = false,

		toggle = "defensives",

		handler = function()
			applyBuff("purgatory")
		end,
	},

	raise_ally = {
		id = 61999,
		cast = 0,
		cooldown = 600,
		gcd = "spell",

		spend = 30,
		spendType = "runic_power",

		startsCombat = false,
		texture = 136143,

		toggle = "cooldowns",

		handler = function() end,
	},

	-- Talent: Raises $?s207313[an abomination]?s58640[a geist][a ghoul] to fight by your si...
	raise_dead = {
		id = 46584,
		cast = 0,
		cooldown = 120,
		gcd = "spell",

		startsCombat = false,

		essential = true,
		nomounted = true,

		usable = function()
			return not pet.alive
		end,
		handler = function()
			summonPet("ghoul", 3600)
		end,
	},

	-- An unholy strike that deals Physical damage and Shadow damage
	scourge_strike = {
		id = 55090,
		cast = 0,
		cooldown = 0,
		gcd = "spell",

		spend_runes = { 0, 0, 1 }, -- 0 Blood, 0 Frost, 1 Unholy

		startsCombat = true,
	},

	-- Talent: Strike an enemy for Shadow damage and mark their soul. After 5 sec, if they are below 45% health, the mark will detonate for massive Shadow damage.
	soul_reaper = {
		id = 130736,
		cast = 0,
		cooldown = 6,
		gcd = "spell",

		spend_runes = { 0, 0, 1 }, -- 0 Blood, 0 Frost, 1 Unholy

		startsCombat = true,
        gain = 10,
        gainType = "runic_power",
        texture = 636333,

		handler = function()
			applyDebuff("target", "soul_reaper")
		end,
	},

	strangulate = {
		id = 47476,
		cast = 0,
		cooldown = 120,
		gcd = "off",

		startsCombat = false,
		texture = 136214,

		toggle = "interrupts",

		debuff = "casting",
		readyTime = state.timeToInterrupt,

		handler = function()
			interrupt()
			applyDebuff("target", "strangulate")
		end,
	},

	-- Blood Boil: Deals damage to nearby enemies and spreads diseases
	blood_boil = {
		id = 48721,
		cast = 0,
		cooldown = 0,
		gcd = "spell",

		spend_runes = { 1, 0, 0 }, -- 1 Blood, 0 Frost, 0 Unholy

		startsCombat = true,
		usable = function()
			local bloodReady = (state.blood or 0) > 0 or (state.death or 0) > 0
			if not bloodReady then
				return false, "no blood/death rune"
			end
			local enemies = active_enemies or state.active_enemies or 1
			if enemies > 1 then
				if
					(debuff.frost_fever.up and active_dot.frost_fever < enemies)
					or (debuff.blood_plague.up and active_dot.blood_plague < enemies)
				then
					return true
				end
				if enemies >= 2 and debuff.frost_fever.up and debuff.blood_plague.up then
					return true
				end
			end
			return false, "single target / no spread need"
		end,

		handler = function()
			-- Blood Boil base functionality for MoP
			-- Spreads diseases when Rolling Blood is talented
			if state.talent.roiling_blood.enabled then
				if debuff.frost_fever.up then
					active_dot.frost_fever = min(active_enemies, active_dot.frost_fever + active_enemies - 1)
				end
				if debuff.blood_plague.up then
					active_dot.blood_plague = min(active_enemies, active_dot.blood_plague + active_enemies - 1)
				end
			end
		end,
	},

	-- Horn of Winter: Increases Attack Power and generates 10 runic power
	horn_of_winter = {
		id = 57330,
		cast = 0,
		cooldown = 20,
		gcd = "spell",

		startsCombat = false,

		handler = function()
			applyBuff("horn_of_winter")
			gain(10, "runic_power") -- MoP gives 10 RP on cast
		end,
	},

	-- Racials and Engineering (for APL alignment)
	blood_fury = {
		id = 33697,
		cast = 0,
		cooldown = 120,
		gcd = "off",

		startsCombat = false,
		toggle = "cooldowns",

		handler = function()
			applyBuff("blood_fury")
		end,
	},

	berserking = {
		id = 26297,
		cast = 0,
		cooldown = 180,
		gcd = "off",

		startsCombat = false,
		toggle = "cooldowns",

		handler = function()
			applyBuff("berserking")
		end,
	},

	synapse_springs = {
		id = 126734,
		cast = 0,
		cooldown = 60,
		gcd = "off",

		startsCombat = false,
		toggle = "cooldowns",

		handler = function()
			applyBuff("synapse_springs")
		end,
	},

	-- Unholy Frenzy: Increases Attack Speed
	unholy_frenzy = {
		id = 49016,
		cast = 0,
		cooldown = 180,
		gcd = "off",

		startsCombat = false,
		toggle = "cooldowns",

		handler = function()
			applyBuff("unholy_frenzy")
			buff.unholy_frenzy.on_self = UnitIsUnit("target", "player") and true or false
		end,
	},

	-- Talent: Summon a Gargoyle into the area to bombard the target for $61777d.    The Gar...
	summon_gargoyle = {
		id = 49206,
		cast = 0,
		cooldown = 180,
		gcd = "off",

		startsCombat = true,

		toggle = "cooldowns",

		handler = function()
			summonPet("gargoyle", 30)
		end,
	},
	-- Presence switching
	blood_presence = {
		id = 48263,
		cast = 0,
		cooldown = 1,
		gcd = "off",

		startsCombat = false,

		handler = function()
			if buff.frost_presence.up then
				removeBuff("frost_presence")
			end
			if buff.unholy_presence.up then
				removeBuff("unholy_presence")
			end
			applyBuff("blood_presence")
		end,
	},

	frost_presence = {
		id = 48266,
		cast = 0,
		cooldown = 1,
		gcd = "off",

		startsCombat = false,

		handler = function()
			if buff.blood_presence.up then
				removeBuff("blood_presence")
			end
			if buff.unholy_presence.up then
				removeBuff("unholy_presence")
			end
			applyBuff("frost_presence")
		end,
	},

	unholy_presence = {
		id = 48265,
		cast = 0,
		cooldown = 1,
		gcd = "off",

		startsCombat = false,

		handler = function()
			if buff.frost_presence.up then
				removeBuff("frost_presence")
			end
			if buff.blood_presence.up then
				removeBuff("blood_presence")
			end
			applyBuff("unholy_presence")
		end,
	},

	-- Stub.
	any_dnd = {
		name = function()
			return "|T136144:0|t |cff00ccff[Any "
				.. (class.abilities.death_and_decay and class.abilities.death_and_decay.name or "Death and Decay")
				.. "]|r"
		end,
		cast = 0,
		cooldown = 0,
		copy = "any_dnd_stub",
	},

	control_undead = {
		id = 111673,
		cast = 0,
		cooldown = 0,
		gcd = "spell",

		startsCombat = true,

		handler = function()
			-- Control Undead: Take control of an undead target
		end,
	},
})

-- MoP-specific rune state expressions
-- Note: Do not register state expressions named blood_runes/frost_runes/unholy_runes/death_runes,
-- since they would shadow the resource/state tables registered above and break rune queries.

-- Legacy rune type expressions for SimC compatibility
-- Death Rune tracking system for MoP (based on Cataclysm implementation)
local death_rune_tracker = { 0, 0, 0, 0, 0, 0 }
local rune_base_type = { 1, 1, 2, 2, 3, 3 }

-- Keeps the internal death rune snapshot aligned with the live rune API for accurate snapshot displays.
local function refreshDeathRuneTracker()
	if not state.death_runes or not state.death_runes.state then
		return 0
	end

	if not GetRuneCooldown or not GetRuneType then
		for slot = 1, 6 do
			death_rune_tracker[slot] = 0
			if state.death_runes.state[slot] then
				state.death_runes.state[slot].ready = false
				state.death_runes.state[slot].type = rune_base_type[slot]
			end
		end
		state.death_runes._count = 0
		return 0
	end

	local readyDeathRunes = 0

	for slot = 1, 6 do
		local runeState = state.death_runes.state[slot]
		if not runeState then
			state.death_runes.state[slot] = {
				slot = slot,
				baseType = rune_base_type[slot],
				type = rune_base_type[slot],
				ready = false,
				expiry = 0,
				start = 0,
				duration = 0,
			}
			runeState = state.death_runes.state[slot]
		end

		local start, duration, ready = GetRuneCooldown(slot)
		local runeType = GetRuneType(slot) or runeState.type or rune_base_type[slot]
		start = start or state.query_time
		duration = duration or runeState.duration or (10 * state.haste)
		local expiry = ready and state.query_time or (start + duration)

		runeState.baseType = rune_base_type[slot]
		runeState.type = runeType
		runeState.ready = ready and true or false
		runeState.expiry = expiry
		runeState.start = start
		runeState.duration = duration

		if runeState.ready and runeState.type == 4 then
			readyDeathRunes = readyDeathRunes + 1
			death_rune_tracker[slot] = 1
		else
			death_rune_tracker[slot] = 0
		end
	end

	state.death_runes._count = readyDeathRunes
	return readyDeathRunes
end

spec:RegisterStateExpr("get_death_rune_tracker", function()
	refreshDeathRuneTracker()
	return death_rune_tracker
end)

spec:RegisterStateTable(
	"death_runes",
	setmetatable({
		state = {},

		reset = function()
			for i = 1, 6 do
				state.death_runes.state[i] = state.death_runes.state[i] or {}
				local runeState = state.death_runes.state[i]
				runeState.slot = i
				runeState.baseType = rune_base_type[i]
				runeState.type = rune_base_type[i]
				runeState.ready = false
				runeState.expiry = 0
				runeState.start = 0
				runeState.duration = 0
			end
			refreshDeathRuneTracker()
		end,

		spend = function(neededRunes)
			local usedRunes, err = state.death_runes.getRunesForRequirement(neededRunes)
			if not usedRunes then
				return
			end

			local runeMapping = {
				blood = { 1, 2 },
				frost = { 5, 6 },
				unholy = { 3, 4 },
			}

			for _, runeIndex in ipairs(usedRunes) do
				local rune = state.death_runes.state[runeIndex]
				rune.ready = false

				-- Determine other rune in the group
				local otherRuneIndex
				for type, runes in pairs(runeMapping) do
					if runes[1] == runeIndex then
						otherRuneIndex = runes[2]
						break
					elseif runes[2] == runeIndex then
						otherRuneIndex = runes[1]
						break
					end
				end

				local otherRune = state.death_runes.state[otherRuneIndex]
				local expiryTime = (otherRune.expiry > 0 and otherRune.expiry or state.query_time) + rune.duration
				rune.expiry = expiryTime
			end
		end,

		getActiveDeathRunes = function()
			refreshDeathRuneTracker()
			local activeRunes = {}
			local state_array = state.death_runes.state
			for i = 1, #state_array do
				if state_array[i].type == 4 and state_array[i].ready then
					table.insert(activeRunes, i)
				end
			end
			return activeRunes
		end,

		getLeftmostActiveDeathRune = function()
			local activeRunes = state.death_runes.getActiveDeathRunes()
			return #activeRunes > 0 and activeRunes[1] or nil
		end,

		getActiveRunes = function()
			refreshDeathRuneTracker()
			local activeRunes = {}
			local state_array = state.death_runes.state
			for i = 1, #state_array do
				if state_array[i].ready then
					table.insert(activeRunes, i)
				end
			end
			return activeRunes
		end,

		getRunesForRequirement = function(neededRunes)
			refreshDeathRuneTracker()
			local bloodNeeded, frostNeeded, unholyNeeded = unpack(neededRunes)
			-- for rune mapping, see the following in game...
			-- /run for i=1,6 do local t=GetRuneType(i); local s,d,r=GetRuneCooldown(i); print(i,"type",t,"ready",r) end
			local runeMapping = {
				blood = { 1, 2 },
				frost = { 5, 6 },
				unholy = { 3, 4 }, --
				any = { 1, 2, 3, 4, 5, 6 },
			}

			local activeRunes = state.death_runes.getActiveRunes()
			local usedRunes = {}
			local usedDeathRunes = {}

			local function useRunes(runetype, needed)
				local runes = runeMapping[runetype]
				for _, runeIndex in ipairs(runes) do
					if needed == 0 then
						break
					end
					local runeState = state.death_runes.state[runeIndex]
					if runeState.ready and runeState.type ~= 4 then
						table.insert(usedRunes, runeIndex)
						needed = needed - 1
					end
				end
				return needed
			end

			-- Use specific runes first
			bloodNeeded = useRunes("blood", bloodNeeded)
			frostNeeded = useRunes("frost", frostNeeded)
			unholyNeeded = useRunes("unholy", unholyNeeded)

			-- Use death runes if needed
			for _, runeIndex in ipairs(activeRunes) do
				if bloodNeeded == 0 and frostNeeded == 0 and unholyNeeded == 0 then
					break
				end
				local runeState = state.death_runes.state[runeIndex]
				if runeState.type == 4 and runeState.ready and not usedDeathRunes[runeIndex] then
					if bloodNeeded > 0 then
						table.insert(usedRunes, runeIndex)
						bloodNeeded = bloodNeeded - 1
					elseif frostNeeded > 0 then
						table.insert(usedRunes, runeIndex)
						frostNeeded = frostNeeded - 1
					elseif unholyNeeded > 0 then
						table.insert(usedRunes, runeIndex)
						unholyNeeded = unholyNeeded - 1
					end
					usedDeathRunes[runeIndex] = true
				end
			end

			return usedRunes
		end,
		}, {
		__index = function(t, k)
			local countDeathRunes = function()
				return refreshDeathRuneTracker() or 0
			end
			local runeMapping = {
				blood = { 1, 2 },
				frost = { 5, 6 },
				unholy = { 3, 4 },
				any = { 1, 2, 3, 4, 5, 6 },
			}
			-- Function to access the mappings
			local function getRuneSet(runeType)
				return runeMapping[runeType]
			end

			local countDRForType = function(type)
				refreshDeathRuneTracker()
				local state_array = t.state
				local count = 0
				local runes = getRuneSet(type)
				if runes then
					for _, rune in ipairs(runes) do
						if state_array[rune].type == 4 and state_array[rune].ready then
							count = count + 1
						end
					end
				end
				return count
			end

				if k == "state" then
				return t.state
			elseif k == "actual" then
				refreshDeathRuneTracker()
				return countDRForType("any")
			elseif k == "current" then
				refreshDeathRuneTracker()
				return countDRForType("any")
			elseif k == "count" then
				return countDeathRunes()
			elseif k == "current_frost" then
				return countDRForType("frost")
			elseif k == "current_blood" then
				return countDRForType("blood")
			elseif k == "current_unholy" then
				return countDRForType("unholy")
			elseif k == "current_non_frost" then
				return countDRForType("blood") + countDRForType("unholy")
			elseif k == "current_non_blood" then
				return countDRForType("frost") + countDRForType("unholy")
			elseif k == "current_non_unholy" then
				return countDRForType("blood") + countDRForType("frost")
			elseif k == "cooldown" then
				return t.state[1].duration
			elseif k == "active_death_runes" then
				return t.getActiveDeathRunes()
			elseif k == "leftmost_active_death_rune" then
				return t.getLeftmostActiveDeathRune()
			elseif k == "active_runes" then
				return t.getActiveRunes()
			elseif k == "runes_for_requirement" then
				return t.getRunesForRequirement
			end
		end,
	})
)

-- Provide a unified 'runes' table for APL expressions like runes.death.count
spec:RegisterStateExpr("runes", function()
	local function readyCount(indices, acceptType)
		local c = 0
		for _, idx in ipairs(indices) do
			local _, _, ready = GetRuneCooldown(idx)
			local rtype = GetRuneType(idx)
			if ready and (not acceptType or rtype == acceptType) then c = c + 1 end
		end
		return c
	end

	local blood = readyCount({1,2})
	local frost = readyCount({5,6})
	local unholy = readyCount({3,4})

	local death
	if state.death_runes and type(state.death_runes) == "table" and state.death_runes.count then
		death = state.death_runes.count
	else
		-- Fallback: count ready death runes directly
		death = readyCount({1,2,3,4,5,6}, 4)
	end

	return {
		blood = { count = blood },
		frost = { count = frost },
		unholy = { count = unholy },
		death = { count = death },
	}
end)

-- Mirror for compatibility if some lists reference runes_by_type
spec:RegisterStateExpr("runes_by_type", function()
	return state.runes
end)

-- Legacy rune type expressions for SimC compatibility
spec:RegisterStateExpr("blood", function()
	if GetRuneCooldown then
		local count = 0
		for i = 1, 2 do
			local start, duration, ready = GetRuneCooldown(i)
			if ready then
				count = count + 1
			end
		end
		return count
	else
		return 2 -- Fallback for emulation
	end
end)
spec:RegisterStateExpr("pure_blood", function()
	if GetRuneCooldown then
		local count = 0
		for i = 1, 2 do
			local start, duration, ready = GetRuneCooldown(i)
			local type = GetRuneType(i)
			if ready and type ~= 4 then
				count = count + 1
			end
		end
		return count
	else
		return 2 -- Fallback for emulation
	end
end)
spec:RegisterStateExpr("frost", function()
	if GetRuneCooldown then
		local count = 0
		for i = 5, 6 do
			local start, duration, ready = GetRuneCooldown(i)
			if ready then
				count = count + 1
			end
		end
		return count
	else
		return 2 -- Fallback for emulation
	end
end)
spec:RegisterStateExpr("pure_frost", function()
	if GetRuneCooldown then
		local count = 0
		for i = 5, 6 do
			local start, duration, ready = GetRuneCooldown(i)
			local type = GetRuneType(i)
			if ready and type ~= 4 then
				count = count + 1
			end
		end
		return count
	else
		return 2 -- Fallback for emulation
	end
end)
spec:RegisterStateExpr("unholy", function()
	if GetRuneCooldown then
		local count = 0
		for i = 3, 4 do
			local start, duration, ready = GetRuneCooldown(i)
			if ready then
				count = count + 1
			end
		end
		return count
	else
		return 2 -- Fallback for emulation
	end
end)
spec:RegisterStateExpr("death", function()
	if GetRuneCooldown and GetRuneType then
		local count = 0
		for i = 1, 6 do
			local start, duration, ready = GetRuneCooldown(i)
			local type = GetRuneType(i)
			if ready and type == 4 then
				count = count + 1
			end
		end
		return count
	else
		return 0 -- Fallback for emulation
	end
end)

-- MoP rune regeneration tracking
spec:RegisterStateExpr("rune_regeneration", function()
	local total = 0
	if state.blood_runes and state.blood_runes.current then
		total = total + state.blood_runes.current
	end
	if state.frost_runes and state.frost_runes.current then
		total = total + state.frost_runes.current
	end
	if state.unholy_runes and state.unholy_runes.current then
		total = total + state.unholy_runes.current
	end
	if state.death_runes and state.death_runes.count then
		total = total + state.death_runes.count
	end
	return 6 - total
end)

-- MoP Death Rune conversion tracking
spec:RegisterStateExpr("death_rune_conversion_available", function()
	local br = state.blood_runes and state.blood_runes.current or 0
	local fr = state.frost_runes and state.frost_runes.current or 0
	local ur = state.unholy_runes and state.unholy_runes.current or 0
	return br > 0 or fr > 0 or ur > 0
end)

-- Rune state expressions for MoP 5.5.0
spec:RegisterStateExpr("rune", function()
	local total = 0
	for i = 1, 6 do
		local start, duration, ready = GetRuneCooldown(i)
		if ready then
			total = total + 1
		end
	end
	return total
end)

spec:RegisterStateExpr("rune_deficit", function()
	if state.runes then
		local ready = state.runes.count or state.runes.current or 0
		return max(0, 6 - ready)
	end

	local ready = 0
	for slot = 1, 6 do
		local _, _, runeReady = GetRuneCooldown(slot)
		if runeReady then
			ready = ready + 1
		end
	end

	return max(0, 6 - ready)
end)

spec:RegisterStateExpr("rune_current", function()
	if state.runes and state.runes.ready then
		return state.runes.ready
	end
	local total = 0
	for i = 1, 6 do
		local _, _, ready = GetRuneCooldown(i)
		if ready then
			total = total + 1
		end
	end
	return total
end)

-- Alias for APL compatibility
spec:RegisterStateExpr("runes_current", function()
	return state.rune_current
end)

spec:RegisterStateExpr("rune_max", function()
	return 6
end)

-- MoP Unholy DK-specific state expressions
spec:RegisterStateExpr("sudden_doom_proc", function()
	return buff.sudden_doom.up
end)

spec:RegisterStateExpr("dark_transformation_available", function()
	return pet.alive and cooldown.dark_transformation.ready
end)

spec:RegisterStateExpr("ghoul_empowered", function()
	return buff.dark_transformation.up or buff.dark_empowerment.up
end)

spec:RegisterStateExpr("diseases_maintained", function()
	return (debuff.frost_fever.up and debuff.frost_fever.remains > 3)
		and (debuff.blood_plague.up and debuff.blood_plague.remains > 3)
end)

spec:RegisterStateExpr("diseases_refresh_needed", function()
	return (debuff.frost_fever.up and debuff.frost_fever.remains < 3)
		or (debuff.blood_plague.up and debuff.blood_plague.remains < 3)
end)

-- MoP Unholy rotation tracking
spec:RegisterStateExpr("unholy_rotation_phase", function()
	if not state.diseases_maintained then
		return "disease_setup"
	end
	if state.sudden_doom_proc then
		return "sudden_doom"
	end
	if (state.runic_power and state.runic_power.current or 0) >= 80 then
		return "runic_power_spend"
	end
	return "standard_rotation"
end)

-- Expose disease state for APL compatibility
spec:RegisterStateExpr("disease", function()
	local frost_fever_remains = debuff.frost_fever.remains or 0
	local blood_plague_remains = debuff.blood_plague.remains or 0

	local min_remains = 0
	if frost_fever_remains > 0 and blood_plague_remains > 0 then
		min_remains = math.min(frost_fever_remains, blood_plague_remains)
	elseif frost_fever_remains > 0 then
		min_remains = frost_fever_remains
	elseif blood_plague_remains > 0 then
		min_remains = blood_plague_remains
	end

	return {
		min_remains = min_remains,
	}
end)

-- Expose disease min remains (legacy)
spec:RegisterStateExpr("disease_min_remains", function()
	local frost_fever_remains = debuff.frost_fever.remains or 0
	local blood_plague_remains = debuff.blood_plague.remains or 0

	if frost_fever_remains > 0 and blood_plague_remains > 0 then
		return math.min(frost_fever_remains, blood_plague_remains)
	elseif frost_fever_remains > 0 then
		return frost_fever_remains
	elseif blood_plague_remains > 0 then
		return blood_plague_remains
	else
		return 0
	end
end)

spec:RegisterRanges("festering_strike", "mind_freeze", "death_coil")

spec:RegisterSetting("dnd_while_moving", true, {
	name = strformat("Allow %s while moving", Hekili:GetSpellLinkWithTexture(43265)),
	desc = strformat(
		"If checked, then allow recommending %s while the player is moving otherwise only recommend it if the player is standing still.",
		Hekili:GetSpellLinkWithTexture(43265)
	),
	type = "toggle",
	width = "full",
})

spec:RegisterSetting("dps_shell", false, {
	name = strformat("Use %s Offensively", Hekili:GetSpellLinkWithTexture(48707)),
	desc = strformat(
		"If checked, %s will not be on the Defensives toggle by default.",
		Hekili:GetSpellLinkWithTexture(48707)
	),
	type = "toggle",
	width = "full",
})

spec:RegisterSetting("pl_macro", nil, {
	name = function()
		local plague_strike = spec.abilities and spec.abilities.plague_strike
		return plague_strike and strformat("%s Macro", Hekili:GetSpellLinkWithTexture(plague_strike.id))
			or "Plague Strike Macro"
	end,
	desc = function()
		local plague_strike = spec.abilities and spec.abilities.plague_strike
		local blood_plague = spec.auras and spec.auras.blood_plague
		if plague_strike and blood_plague then
			return strformat(
				"Using a mouseover macro makes it easier to apply %s and %s to other enemies without retargeting.",
				Hekili:GetSpellLinkWithTexture(plague_strike.id),
				Hekili:GetSpellLinkWithTexture(blood_plague.id)
			)
		else
			return "Using a mouseover macro makes it easier to apply Plague Strike and Blood Plague to other enemies without retargeting."
		end
	end,
	type = "input",
	width = "full",
	multiline = true,
	get = function()
		local plague_strike = class.abilities and class.abilities.plague_strike
		return plague_strike and "#showtooltip\n/use [@mouseover,harm,nodead][] " .. plague_strike.name
			or "#showtooltip\n/use [@mouseover,harm,nodead][] Plague Strike"
	end,
	set = function() end,
})

spec:RegisterSetting("it_macro", nil, {
	name = strformat("%s Macro", Hekili:GetSpellLinkWithTexture(45477)),
	desc = strformat(
		"Using a mouseover macro makes it easier to apply %s and %s to other enemies without retargeting.",
		Hekili:GetSpellLinkWithTexture(45477),
		Hekili:GetSpellLinkWithTexture(59921)
	),
	type = "input",
	width = "full",
	multiline = true,
	get = function()
		return "#showtooltip\n/use [@mouseover,harm,nodead][] Icy Touch"
	end,
	set = function() end,
})

-- MoP Unholy DK-specific settings
spec:RegisterSetting("plague_leech_priority", "expire", {
	name = "Plague Leech Priority",
	desc = "When to use Plague Leech: 'expire' = only when diseases are about to expire, 'rune_generation' = for rune generation when needed",
	type = "select",
	values = {
		expire = "Disease Expiration Only",
		rune_generation = "Rune Generation Priority",
	},
	width = "full",
})

spec:RegisterSetting("sudden_doom_priority", true, {
	name = "Sudden Doom Priority",
	desc = "Prioritize Sudden Doom procs over other abilities",
	type = "toggle",
	width = "full",
})

spec:RegisterSetting("dark_transformation_auto", true, {
	name = "Auto Dark Transformation",
	desc = "Automatically use Dark Transformation when available",
	type = "toggle",
	width = "full",
})

-- Unholy Death Knight specific settings
spec:RegisterSetting( "unholy_runic_power_threshold", 50, {
	name = "Runic Power Threshold for Death Coil",
	desc = "Minimum runic power to spend on Death Coil",
	type = "range",
	min = 20,
	max = 100,
	step = 5,
	width = "full",
} )

spec:RegisterSetting( "unholy_shadow_infusion_priority", true, {
	name = "Prioritize Shadow Infusion",
	desc = "Always use Shadow Infusion procs to empower ghoul",
	type = "toggle",
	width = "full",
} )

spec:RegisterSetting( "unholy_sudden_doom_priority", true, {
	name = "Prioritize Sudden Doom",
	desc = "Always use Sudden Doom procs for free Death Coil",
	type = "toggle",
	width = "full",
} )

spec:RegisterSetting( "unholy_execute_threshold", 35, {
	name = "Execute Threshold for Soul Reaper",
	desc = "Target health percentage to use Soul Reaper",
	type = "range",
	min = 20,
	max = 50,
	step = 5,
	width = "full",
} )

spec:RegisterSetting( "unholy_dnd_while_moving", false, {
	name = "Use Death and Decay While Moving",
	desc = "Cast Death and Decay even when moving",
	type = "toggle",
	width = "full",
} )

spec:RegisterSetting( "unholy_blood_tap_threshold", 5, {
	name = "Blood Tap Threshold",
	desc = "Minimum Blood Charge stacks to use Blood Tap",
	type = "range",
	min = 1,
	max = 10,
	step = 1,
	width = "full",
} )

spec:RegisterOptions( {
	enabled = true,
	aoe = 4,
	cycle = false,
	nameplates = true,
	nameplateRange = 8,
	rangeFilter = false,
	damage = true,
	damageExpiration = 6,
	potion = "mogu_power_potion",
	package = "Unholy",
} )

spec:RegisterPack(	"Unholy",	20251030,	[[Hekili:TVvBVnoUr4FlbhGH9UbQYoXz3ueVFOTOO3w0dhGV(vlZitBlezjb9sY5dg(3EhsQxiPgsX4KDlk2(H9LqroZWHKpZdNHz10v)2QLBiL0v)Ym)zZN6FJV3SzZVF2NxTS8ygD1Yms4tKDW)jHCa(7)DY(04JSMpgNs2WgErAvEi8PvlFSkkU8Ntw9iUmVd6BgneAE(Svl3hTzdv0xAr4QL)2(OIZRz)HCEDTwpVoDl8ZHLrPjNxhhvucFEBA(51)d6trXrERwYBKBgrj7IPbLK8D0sOHFHp3OjKhJPBw9xwTmmpQKMhrGzgjMMu6Lft2vrdIP0W9E1D886rNx)mb6g8tEBsllcQY4no(8A4h9EmonDtGyOE50dKOeWME486BoV(0jrF2MNwugSL(mnxVltAKvEvcTWRI7o9ctRskpVEX51(cPi(6gkPCp(hd2q3gfgbT)f4dZabVAPWpbRnsZRvLG7EihHWkcEmoA3(sCprcLUjG5o6uJYOy65gJ6XMysRkFmNsEIjHBnkHRq8(LrHpbl69M4fL5rprzYB(qYtELQN4IcpguMwjCI39o4elsizbVeLSj9f09zw8TFAyFR7sx2L)5Hfm93PHvLuB7CzBcNACRB9xL2IcygXbGjKrZzgX9d5CfR7LKmfh7JvB3w)PW9SZ9EfLaWrTc97ux7Wzkd(GjTzzQjM7mb(mnGMqperlAp8XM3TURS004aaKkyhysPhJPkZCUJjGKahdOHKJCdYmsLrdsYvcndtDPD9tnFGxipU7O)8t8r(rcd6AlTGjOKDYAZHJ9GKJcdsHtzHKmH7IV2vuXIbaacPhaGsqlIVnU5Z7jWM5GOKTvfG(LxDVTXIb5ML(cnVUzFoeBTqA1p)W0b4VWh1N8rwIctJI5ZpZGsCJCFAEsq6w2jpOz4W2ljDIs9JCXzgtsYU8uG3VZ32zVpAjCH0SIEGl5aE0JxGJEqJmOfy6ULuf3fYSzahaOKGT5u6FqLnyRbuA94KnptscbW(OqnqWWnfmBiHTlcaI60xiBaXbmNQW1giOCmyCMgbqskJoq2b(WI904ygjKdCQl7PKyWZCG87FW37gFSinDgrCCG4hcyuleemQTKM5qH9ylTt1QcAamDDu6HaUbB3tH9Wnyqq32PcW1AudKuQ9yj6Yge9nUj6Wyk5zkwafxgTk3n(UYSCAy6HhjOu5eutfhQkcEemFblY8OmHY(BSJcNx)pty7z(ZNxlOTchH(xP)651Z9M7nDs7ozdhwv3ZBgL7QA0Q69PGHxqHDYEiXZB(MDUoWUykNVOV3CPD35hoYSUY9mYFa17M9GToysur9NunDluxq1uwk)F5ldDBkTZOMligMJDd2bKJgnwtLrpi(2Q8Jos20SKGDn0CozpRlegbKNPmnbGlyVBAEoWuXrKHS80q34QvVZbWHt(JJ2xnhBNeYi1yIAEhnsmusoO1UbR8X4ua7El7OvaOHw6HS(ioc7X2paUKGnrS9xmyK58aZtgy2wuD4aaq0Ox7OvzGI2Thys6jWT64eAH4WCvlqLzGyo1ELno7hXaUs15jtjUXr6Pz8mgnBoQYSGK)uqzojPawAoqQpMzHd(fnfVTRxikKZqr1WX6v39wbjUlCdl6zZEiBC3WPKzICLoX)wOyGGCHlhQ1wboc3bcablYyKuleRaWUQ40YgzIDbGgTcCAtEIwo1nfBB7(S5nATvMye91u8SVbkE2a3iWQJ1KwUZhjAHt3eWH7sALpRobEvC5BLSlJ8D7yXHeslfaJkOsSsB6n7)fxb)ZuEBnCtRz4HeAByjv7DRzNMXobjGkL1qTddlK3WAWukt4ErJ5)Ot5n4Zirjhw5wszJypSTCW0zdDPmcj06WwHm1m4sR0KDGVUs(sOyOFkDGpdIRGBfR08EAEAuXb1g5hvEHKNP2mC1MiGDqW(J8lqtquaNzJw7T8uuBxhMJfbTZHjXTaJVGJUm7XxgW5jBoAckqGjJeyFydRxSL79L1KswgWIRoSgSelxkC40BhISJY6HovmSaFVxM2mfpstFcksRHO1d9nSEBVJGkSKc)q0GBdlAm6w37RZeTgaus5O8prJZnSn8mkLC9eiP4iBcEzo6i(uqWawEIOFdfSGOdpfSWnDSm5OUCUAGD3hevsqZiBPiZnVxFCaLaMY5fIlVlerVptp5ZNEZXrxT0l9qe6DvzztlfwS5XRhMTDbRxUYuUi33PTLAl6sftOoraIe84sD1COsiUuojh4Soq5KmZhT2sHa4XSfrrcXLT0lJ5erjvfpwFjhRv16BSLKrlkJIBY5K5mt8dwjr)XRAExEH0(S((666OzUODou1kSYGnuD5WkBLTkoA68OXRHlxvYl8YRoyw8nMHhdBt4DbdtfJ9sRDPwIp380OAWuPt6vypNC(JSvZqu9BgkS1j7CTc13m1wWoLSIBlP(mrK(gIPDrbVEtxl()hL79ik3facENbqWF8cKCzG73lFMuAJJY5rZzM9)2iZMXhEhXT(bb(3nKzwIAP5Smg18mczVjXxi5SBDb89)5dzP5LSJsFs7fc6D(R8KGTnIDzRF68Axkg85VE(R)e03FTPSZN)QqOfETvI(Jl(tBJjfpDnR8ZlKR(mENvNG49rRWWxhTDXvgQMmUa0RYktcSR(9GpC9w0r0vNy8VlsOVQCeoN)AAoCe7VhdijnJe6V07erUzPNZX1S7uUqb8IjE0lapQTvTBzllBTx6X1Ih6XcT35HQ1O(YleMuJUkgURTfcxXYRZ)V8W1ENdIrd0myJJ1E37R4llUDWbkU2D)XU4MbhQYJQGTe2Sy3oRHr28)RxIetNRtZwuqlVMNOIftDzK1aWQJSxboEyXnZDrA1HMuLMjkcJmqpWff1MabvvDLjDD60vVbTjLlhv9zOifNozjh71FuU4e1n1vyI6gKlkrDtifKqwGnfJOPn5cru3w)Iq4IlaTAaiod0YpahyS6sCXauctRQyPYl8Lf377I06LBFvjouo7FyXuyg1pHDUEorj)FVwvpZPzOAI(1oFZIp4KHIMXEvHPumGVSy69(No1JFNdQslN6QkPvGshfpDACBZko0rJXwzUdXUMmXflRnr6AGnJ1f3OX2sA)dlQty)hM5MELdVEbq7AXHXoSINmEy3T38(OkiF1qY35DXftu6oogwVvOym(B22GjYXzBPmyHM2cF8(35Vu4BO)inWhBlA9RFSQVMn24rESfFrb7qE4kVwnfTl5P7O41KmzuzPbCXKM0cNoWR0IQ2evEDsbmt6dO4tMqMNmXXzasuk2Sq)rDnYweV5D6Qf)yKow58riGi2FxAtmyYTxj9vBP3oYyOzM0h5YZnJJTnAm(fNpDsjc9T(gMdmwSWLYoCn7HqTG)SVSDqyK9NpMl6O5rEztn47MMn)vi)zVFYV7sEgDl4OE4Id5XwPi72aB9ZyXh7LnMf(tgHI6CRVm8QY9BytjPA8WHxnxsRENFhn2uHSE4MtNmuaRhUzc2eAHpFJQ(Cs0yqhe6eZtLExv2wYe7MmT3MXSKBYXNYQJdJt5xToEwkmMXwJYO93NU2XB9EuVtofjUbwGTDYpDzIsIcNRNjaiDK9qqRw2Z0MwAjxtVeDpYqsUbr7Bw0A5ZTMvqFBE0yryIUeCmtkgBVq2wMmQP80Ocnla9mA2jcPmzYm5EzW0Qyvdp2o1uUuzZ9J7h(AS9WN6r3KzK2f7xPxFY3Itun)JmdwKEG()cRzwgga2rHNVZ3z8DfAY8uCD5hWrqVAfPRWDTdOR0esgaAzRgD55JQvBD1TIdj(nxD)VBeY36Me3GUTVV5vkJ3iG8NrePRaXdUXgdkepIdIOKdOPuMNftFpdW1Pp1GbiQ0vNqVOcgL1RkkH26ZLfEarC6fqQRlK0x9zb9blVf)nLVBH4(UaCku13hut5P1fFi(U30s2Rf(Q)c7fjGxpkJ(wa9V8DcXq28FRhcRn83k0JqmFJWDecxVo6KQsOPvlxEOAlOmET0x9F(d]]
)
