--!strict
-- Pure roll logic. Takes a random function so tests can feed it fixed numbers.
-- rng() must return a number in [0, 1).

local Config = require(script.Parent.Config)
local GooberDefs = require(script.Parent.GooberDefs)

export type Rng = () -> number

local Rolls = {}

-- Zone index (1-based) for a landing distance in studs.
function Rolls.zoneForDistance(distance: number): number
	local index = 1
	for i, zone in Config.Zones do
		if distance >= zone.StartDistance then
			index = i
		end
	end
	return index
end

function Rolls.pickWeighted(weights: { [string]: number }, order: { string }, rng: Rng): string?
	local total = 0
	for _, key in order do
		total += math.max(weights[key] or 0, 0)
	end
	if total <= 0 then
		return nil
	end
	local roll = rng() * total
	for _, key in order do
		local w = math.max(weights[key] or 0, 0)
		if w > 0 then
			if roll < w then
				return key
			end
			roll -= w
		end
	end
	-- Floating point edge: fall back to the last non-zero entry.
	for i = #order, 1, -1 do
		if (weights[order[i]] or 0) > 0 then
			return order[i]
		end
	end
	return nil
end

function Rolls.rollRarity(zoneIndex: number, rng: Rng, luck: number?): string
	local zone = Config.Zones[math.clamp(zoneIndex, 1, #Config.Zones)]
	local weights = zone.RarityWeights
	local boost = luck or 1
	if boost ~= 1 then
		-- Luck multiplies every tier above Common, which shifts odds toward rare tiers.
		local boosted = {}
		for key, w in weights do
			boosted[key] = if key == "Common" then w else w * boost
		end
		weights = boosted
	end
	-- Only consider rarities that actually have Goobers defined.
	local available = {}
	for _, rarity in Config.RarityOrder do
		if GooberDefs.ByRarity[rarity] and #GooberDefs.ByRarity[rarity] > 0 then
			table.insert(available, rarity)
		end
	end
	return Rolls.pickWeighted(weights, available, rng) or "Common"
end

function Rolls.rollMutation(rng: Rng, luck: number?): string
	local boost = luck or 1
	local roll = rng()
	local cumulative = 0
	for _, mutation in Config.Mutations do
		cumulative += mutation.Chance * boost
		if roll < cumulative then
			return mutation.Name
		end
	end
	return "None"
end

export type RollResult = {
	Id: string,
	Mutation: string,
	Rarity: string,
	ZoneIndex: number,
}

function Rolls.rollGoober(distance: number, rng: Rng, luck: number?): RollResult
	local zoneIndex = Rolls.zoneForDistance(distance)
	local rarity = Rolls.rollRarity(zoneIndex, rng, luck)
	local pool = GooberDefs.ByRarity[rarity]
	local pick = pool[math.clamp(math.floor(rng() * #pool) + 1, 1, #pool)]
	return {
		Id = pick.Id,
		Mutation = Rolls.rollMutation(rng, luck),
		Rarity = rarity,
		ZoneIndex = zoneIndex,
	}
end

-- Odds table for display (Roblox requires visible odds on anything paid and random,
-- and showing them on free crates builds trust too). Returns percent per rarity.
function Rolls.rarityOdds(zoneIndex: number): { [string]: number }
	local weights = Config.Zones[zoneIndex].RarityWeights
	local total = 0
	for _, w in weights do
		total += w
	end
	local odds = {}
	for key, w in weights do
		odds[key] = if total > 0 then w / total * 100 else 0
	end
	return odds
end

return Rolls
