--!nocheck
-- Unit tests for the pure game math, run outside Roblox with Lune:
--   lune run tests/run
-- Loads modules from src/shared with a tiny `script`/`require` shim, so the same
-- files Rojo syncs into Studio are the files under test.

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local process = require("@lune/process")

local SHARED = "src/shared/"
local cache = {}

local function loadShared(name: string)
	if cache[name] then
		return cache[name]
	end
	local source = fs.readFile(SHARED .. name .. ".luau")
	local fakeParent = setmetatable({}, {
		__index = function(_, child)
			return { __module = child }
		end,
	})
	local env = setmetatable({
		script = { Parent = fakeParent },
		require = function(target)
			if type(target) == "table" and target.__module then
				return loadShared(target.__module)
			end
			return require(target)
		end,
		Color3 = roblox.Color3,
		Vector3 = roblox.Vector3,
		Enum = roblox.Enum,
	}, { __index = _G })
	local chunk = luau.load(source, { debugName = name, environment = env })
	local result = chunk()
	cache[name] = result
	return result
end

local Config = loadShared("Config")
local GooberDefs = loadShared("GooberDefs")
local Rolls = loadShared("Rolls")
local Formulas = loadShared("Formulas")
local Format = loadShared("Format")

local passed, failed = 0, 0
local function test(name: string, fn: () -> ())
	local ok, err = pcall(fn)
	if ok then
		passed += 1
		print("  ok  " .. name)
	else
		failed += 1
		print("  FAIL " .. name .. "\n       " .. tostring(err))
	end
end
local function eq(a, b, msg)
	if a ~= b then
		error(string.format("%s: expected %s, got %s", msg or "values differ", tostring(b), tostring(a)), 2)
	end
end
local function near(a, b, tolerance, msg)
	if math.abs(a - b) > tolerance then
		error(string.format("%s: expected ~%s, got %s", msg or "not close", tostring(b), tostring(a)), 2)
	end
end
local function seq(values)
	local i = 0
	return function()
		i += 1
		return values[((i - 1) % #values) + 1]
	end
end

print("Goober math")

test("roster has 14 Goobers across all 6 rarities", function()
	eq(#GooberDefs.List, 14, "count")
	for _, rarity in Config.RarityOrder do
		assert(GooberDefs.ByRarity[rarity] and #GooberDefs.ByRarity[rarity] > 0, "no Goobers for " .. rarity)
	end
end)

test("every Goober has positive income and a known rarity", function()
	for _, def in GooberDefs.List do
		assert(def.Income > 0, def.Id)
		assert(Config.RarityColors[def.Rarity], def.Id .. " rarity " .. def.Rarity)
	end
end)

test("6 zones, ordered by distance and inside the field", function()
	eq(#Config.Zones, 6, "zone count")
	assert(Config.Zones[#Config.Zones].StartDistance < Config.FieldLength, "last zone starts past the wall")
	for i = 2, #Config.Zones do
		assert(Config.Zones[i].StartDistance > Config.Zones[i - 1].StartDistance, "zones out of order")
	end
end)

test("zoneForDistance picks the right zone", function()
	eq(Rolls.zoneForDistance(0), 1)
	eq(Rolls.zoneForDistance(179.9), 1)
	eq(Rolls.zoneForDistance(180), 2)
	eq(Rolls.zoneForDistance(449), 2)
	eq(Rolls.zoneForDistance(450), 3)
	eq(Rolls.zoneForDistance(749), 3)
	eq(Rolls.zoneForDistance(750), 4)
	eq(Rolls.zoneForDistance(1050), 5)
	eq(Rolls.zoneForDistance(1400), 6)
	eq(Rolls.zoneForDistance(99999), 6)
end)

test("pickWeighted respects boundaries and skips zero weights", function()
	local order = { "A", "B", "C" }
	local w = { A = 1, B = 0, C = 3 }
	eq(
		Rolls.pickWeighted(w, order, function()
			return 0
		end),
		"A"
	)
	eq(
		Rolls.pickWeighted(w, order, function()
			return 0.2499
		end),
		"A"
	)
	eq(
		Rolls.pickWeighted(w, order, function()
			return 0.25
		end),
		"C"
	)
	eq(
		Rolls.pickWeighted(w, order, function()
			return 0.9999999
		end),
		"C"
	)
	eq(
		Rolls.pickWeighted({ A = 0 }, { "A" }, function()
			return 0.5
		end),
		nil
	)
end)

test("Backyard can never drop Epic or Legendary", function()
	for i = 0, 999 do
		local r = Rolls.rollRarity(1, function()
			return i / 1000
		end)
		assert(r ~= "Epic" and r ~= "Legendary", "got " .. r)
	end
end)

test("Mythic only drops from Downtown and beyond", function()
	for zone = 1, #Config.Zones do
		local canDrop = (Config.Zones[zone].RarityWeights.Mythic or 0) > 0
		eq(canDrop, Config.Zones[zone].StartDistance >= 750, Config.Zones[zone].Name)
	end
end)

test("rarity distribution matches weights (Mall, 200k rolls)", function()
	-- Deterministic Park-Miller RNG (Lune has no Random).
	local state = 42
	local function nextNumber()
		state = (state * 16807) % 2147483647
		return state / 2147483647
	end
	local counts = {}
	local n = 200000
	for _ = 1, n do
		local r = Rolls.rollRarity(3, nextNumber)
		counts[r] = (counts[r] or 0) + 1
	end
	local odds = Rolls.rarityOdds(3)
	for rarity, pct in odds do
		near((counts[rarity] or 0) / n * 100, pct, 0.5, rarity)
	end
end)

test("mutation rolls hit each mutation at its chance", function()
	eq(
		Rolls.rollMutation(function()
			return 0
		end),
		"Crispy"
	)
	eq(
		Rolls.rollMutation(function()
			return 0.0049
		end),
		"Crispy"
	)
	eq(
		Rolls.rollMutation(function()
			return 0.005
		end),
		"Rainbow"
	)
	eq(
		Rolls.rollMutation(function()
			return 0.02
		end),
		"Huge"
	)
	eq(
		Rolls.rollMutation(function()
			return 0.05
		end),
		"Gold"
	)
	eq(
		Rolls.rollMutation(function()
			return 0.1
		end),
		"None"
	)
	eq(
		Rolls.rollMutation(function()
			return 0.99
		end),
		"None"
	)
end)

test("rollGoober returns a valid Goober for every zone", function()
	for _, d in { 10, 200, 600 } do
		for i = 0, 99 do
			local r = Rolls.rollGoober(d, seq({ i / 100, (99 - i) / 100, 0.5 }))
			assert(GooberDefs.ById[r.Id], "bad id " .. tostring(r.Id))
			eq(GooberDefs.ById[r.Id].Rarity, r.Rarity, "rarity mismatch")
		end
	end
end)

test("charge factor: min at 0, bonus only inside the sweet spot", function()
	near(Formulas.chargeFactor(0), Config.Cannon.MinChargeFactor, 1e-9, "zero charge")
	near(Formulas.chargeFactor(1), 1, 1e-9, "full charge has no bonus")
	assert(Formulas.isSweetSpot(0.9))
	assert(not Formulas.isSweetSpot(0.98))
	assert(Formulas.chargeFactor(0.9) > Formulas.chargeFactor(1), "sweet spot beats full")
	near(Formulas.chargeFactor(-5), Formulas.chargeFactor(0), 1e-9, "clamps low")
	near(Formulas.chargeFactor(50), Formulas.chargeFactor(1), 1e-9, "clamps high")
end)

test("each zone is reachable with upgrades, and Backyard is the start", function()
	local startRange = Formulas.ballisticRange(Formulas.launchSpeed(0, 1))
	assert(startRange < Config.Zones[2].StartDistance, "level 0 already reaches Suburbs")
	local maxRange = Formulas.ballisticRange(Formulas.launchSpeed(Config.Upgrades.MaxLaunchLevel, 0.9))
	assert(maxRange > Config.Zones[#Config.Zones].StartDistance, "max level can't reach the last zone")
	assert(maxRange < Config.FieldLength, "max level overshoots the field")
end)

test("upgrade costs rise and stop at max level", function()
	local last = 0
	for level = 0, Config.Upgrades.MaxLaunchLevel - 1 do
		local cost = Formulas.upgradeCost(level)
		assert(cost and cost > last, "cost not increasing at " .. level)
		last = cost
	end
	eq(Formulas.upgradeCost(Config.Upgrades.MaxLaunchLevel), nil, "maxed")
end)

test("income applies mutation multipliers", function()
	eq(Formulas.gooberIncome("sir_blobbington", "None"), 1)
	eq(Formulas.gooberIncome("sir_blobbington", "Gold"), 2)
	eq(Formulas.gooberIncome("sir_blobbington", "Crispy"), 10)
	eq(Formulas.gooberIncome("not_a_goober", "Gold"), 0)
	eq(
		Formulas.totalIncome({
			{ Id = "mega_jeff", Mutation = "None", Slot = 1 },
			{ Id = "mega_jeff", Mutation = "Huge", Slot = 2 },
		}),
		24
	)
end)

test("rebirth: cost grows, multiplier stacks, gated by level and cash", function()
	eq(Formulas.rebirthMultiplier(0), 1)
	eq(Formulas.rebirthMultiplier(2), 1 + 2 * Config.Rebirth.IncomeBonus)
	local first = Formulas.rebirthCost(0)
	eq(first, Config.Rebirth.BaseCost)
	assert(Formulas.rebirthCost(1) > first, "cost should grow")
	eq(Formulas.rebirthCost(Config.Rebirth.Max), nil, "maxed")
	local lvl = Config.Rebirth.LevelRequired
	eq(Formulas.canRebirth(0, lvl, first), true)
	eq(Formulas.canRebirth(0, lvl - 1, first * 10), false, "level gate")
	eq(Formulas.canRebirth(0, lvl, first - 1), false, "cash gate")
	local plot = { { Id = "sir_blobbington", Mutation = "None", Slot = 1 } }
	eq(Formulas.totalIncome(plot, 2), 1 * Formulas.rebirthMultiplier(2))
	eq(Formulas.totalIncome(plot), 1, "no rebirths by default")
end)

test("index bonus counts only real Goobers and stacks with rebirth", function()
	eq(Formulas.discoveredCount(nil), 0)
	eq(Formulas.discoveredCount({ sir_blobbington = true, not_a_goober = true, mega_jeff = false }), 1)
	local plot = { { Id = "sir_blobbington", Mutation = "None", Slot = 1 } }
	local found = { sir_blobbington = true, toastgoblin = true }
	local expected = 1 * Formulas.rebirthMultiplier(1) * (1 + 2 * Config.Index.BonusPerGoober)
	assert(math.abs(Formulas.totalIncome(plot, 1, found) - expected) < 1e-9, "stacked multiplier")
end)

test("offline earnings cap at 2 hours", function()
	local earned, credited = Formulas.offlineEarnings(10, 60)
	eq(earned, 600)
	eq(credited, 60)
	earned, credited = Formulas.offlineEarnings(10, 99999)
	eq(credited, 7200)
	eq(earned, 72000)
	earned = Formulas.offlineEarnings(10, -50)
	eq(earned, 0, "clock skew gives nothing")
end)

test("number formatting", function()
	eq(Format.short(0), "0")
	eq(Format.short(999), "999")
	eq(Format.short(1000), "1K")
	eq(Format.short(1234), "1.23K")
	eq(Format.short(12345), "12.3K")
	eq(Format.short(120000), "120K")
	eq(Format.short(5600000), "5.6M")
	eq(Format.cash(1500), "$1.5K")
	eq(Format.rate(1.5), "$1.5/s")
	eq(Format.duration(7200), "2h 0m")
end)

print(string.format("\n%d passed, %d failed", passed, failed))
if failed > 0 then
	process.exit(1)
end
