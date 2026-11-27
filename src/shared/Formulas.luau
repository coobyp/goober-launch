--!strict
-- Pure economy and launch math. No Roblox services, so it runs in tests.

local Config = require(script.Parent.Config)
local GooberDefs = require(script.Parent.GooberDefs)

local GRAVITY = 196.2

local Formulas = {}

Formulas.GRAVITY = GRAVITY

function Formulas.isSweetSpot(charge: number): boolean
	return charge >= Config.Cannon.SweetSpotMin and charge <= Config.Cannon.SweetSpotMax
end

-- Maps a 0..1 charge to a speed multiplier, including the sweet-spot bonus.
function Formulas.chargeFactor(charge: number): number
	local c = math.clamp(charge, 0, 1)
	local factor = Config.Cannon.MinChargeFactor + (1 - Config.Cannon.MinChargeFactor) * c
	if Formulas.isSweetSpot(c) then
		factor *= Config.Cannon.SweetSpotBonus
	end
	return factor
end

function Formulas.baseLaunchSpeed(level: number): number
	return Config.Cannon.BaseSpeed + Config.Cannon.SpeedPerLevel * math.max(level, 0)
end

function Formulas.launchSpeed(level: number, charge: number, multiplier: number?): number
	return Formulas.baseLaunchSpeed(level) * Formulas.chargeFactor(charge) * (multiplier or 1)
end

-- Vacuum range of a projectile on flat ground. Real flights bounce and tumble, so
-- this is a guide for tuning and the base of the server's sanity cap.
function Formulas.ballisticRange(speed: number, pitchDegrees: number?): number
	local pitch = math.rad(pitchDegrees or Config.Cannon.PitchDegrees)
	return speed * speed * math.sin(2 * pitch) / GRAVITY
end

function Formulas.maxPlausibleDistance(speed: number): number
	return Formulas.ballisticRange(speed) * Config.Flight.RangeSlackMultiplier + Config.Flight.RangeSlackStuds
end

-- Cost to buy the next level when currently at `level`. nil when maxed.
function Formulas.upgradeCost(level: number): number?
	if level >= Config.Upgrades.MaxLaunchLevel then
		return nil
	end
	return math.floor(Config.Upgrades.BaseCost * Config.Upgrades.CostGrowth ^ level)
end

function Formulas.mutationMultiplier(mutationName: string?): number
	if mutationName == nil or mutationName == "None" then
		return 1
	end
	for _, mutation in Config.Mutations do
		if mutation.Name == mutationName then
			return mutation.Multiplier
		end
	end
	return 1
end

function Formulas.gooberIncome(id: string, mutationName: string?): number
	local def = GooberDefs.ById[id]
	if not def then
		return 0
	end
	return def.Income * Formulas.mutationMultiplier(mutationName)
end

function Formulas.sellValue(id: string, mutationName: string?): number
	return math.floor(Formulas.gooberIncome(id, mutationName) * Config.Plot.SellSeconds)
end

export type OwnedGoober = { Id: string, Mutation: string, Slot: number }

-- Income multiplier from rebirths. 0 rebirths = x1.
function Formulas.rebirthMultiplier(rebirths: number): number
	return 1 + Config.Rebirth.IncomeBonus * math.max(rebirths, 0)
end

-- Cash cost of the next rebirth when you have `rebirths` already. nil when maxed.
function Formulas.rebirthCost(rebirths: number): number?
	if rebirths >= Config.Rebirth.Max then
		return nil
	end
	return math.floor(Config.Rebirth.BaseCost * Config.Rebirth.CostGrowth ^ math.max(rebirths, 0))
end

function Formulas.canRebirth(rebirths: number, launchLevel: number, cash: number): boolean
	local cost = Formulas.rebirthCost(rebirths)
	return cost ~= nil and launchLevel >= Config.Rebirth.LevelRequired and cash >= cost
end

-- Cash per second for a whole plot, including the rebirth multiplier.
function Formulas.totalIncome(goobers: { OwnedGoober }, rebirths: number?): number
	local total = 0
	for _, g in goobers do
		total += Formulas.gooberIncome(g.Id, g.Mutation)
	end
	return total * Formulas.rebirthMultiplier(rebirths or 0)
end

function Formulas.offlineEarnings(incomePerSecond: number, secondsAway: number): (number, number)
	local credited = math.clamp(secondsAway, 0, Config.Plot.OfflineCapSeconds)
	return math.floor(incomePerSecond * credited * Config.Plot.OfflineRate), credited
end

return Formulas
