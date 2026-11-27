--!strict
-- Every tunable number in the game lives here. Tune feel here first, code second.

export type Zone = {
	Name: string,
	StartDistance: number, -- studs from the muzzle where this zone begins
	GroundColor: Color3,
	GroundMaterial: Enum.Material,
	-- Rarity weights for crates that land in this zone. They don't need to sum to 100.
	RarityWeights: { [string]: number },
}

export type Mutation = {
	Name: string,
	Chance: number, -- 0..1, rolled once per Goober
	Multiplier: number, -- income multiplier
	Scale: number?, -- visual size multiplier
}

local Config = {}

Config.Cannon = {
	PitchDegrees = 40, -- launch angle above the horizon
	BaseSpeed = 110, -- studs/sec at Launch Power level 0 and a full charge
	SpeedPerLevel = 14, -- studs/sec added per Launch Power level
	MinChargeFactor = 0.35, -- a 0% charge still launches at 35% speed
	SweetSpotMin = 0.88, -- charge window that earns the bonus
	SweetSpotMax = 0.97,
	SweetSpotBonus = 1.12, -- speed multiplier for hitting the window
	MeterCycleSeconds = 1.1, -- time for the meter to go 0 -> 1 (it ping-pongs)
	ChargeTimeoutSeconds = 20, -- sitting in the cannon too long cancels
	SpinStrength = 6, -- random angular velocity for maximum flail
}

Config.Flight = {
	MinFlightSeconds = 0.6, -- ignore "stopped" checks right after launch
	RestSpeed = 4, -- studs/sec under which the ragdoll counts as resting
	RestSeconds = 0.5, -- how long it has to rest to count as landed
	MaxFlightSeconds = 15,
	ResultHoldSeconds = 2.5, -- time spent lying on the ground before teleporting home
	GroundCheckStuds = 4, -- ground within this far below the root counts as landed
	GroundSpeedKeptPerStep = 0.85, -- after landing, horizontal speed kept every 0.1s (lower = stops sooner)
	-- Server owns the physics, but cap the reported distance anyway:
	-- range can't exceed the vacuum ballistic range times this, plus bounce slack.
	RangeSlackMultiplier = 1.6,
	RangeSlackStuds = 80,
}

Config.Upgrades = {
	MaxLaunchLevel = 30,
	BaseCost = 30,
	CostGrowth = 1.38,
}

-- Rebirth: reset cash and Launch Power for a permanent income multiplier.
-- Goobers and best distance are kept, so a rebirth never leaves you with an empty plot.
Config.Rebirth = {
	LevelRequired = 15, -- Launch Power needed before you can rebirth
	BaseCost = 50000, -- cash cost of the first rebirth
	CostGrowth = 4, -- each rebirth costs this many times the last
	IncomeBonus = 0.5, -- +50% income per rebirth (1 rebirth = x1.5, 2 = x2, ...)
	Max = 50,
}

-- Goober Index: every Goober you've ever caught counts, even after you sell it.
Config.Index = {
	BonusPerGoober = 0.02, -- +2% income per discovered Goober (all 14 = +28%)
}

-- Robux items. Id = 0 means "not created on Roblox yet": the shop shows it as coming
-- soon and it can't be bought. Create each one in the Creator Dashboard after the first
-- publish, paste its id here, and it switches on. Prices are set on Roblox, not here.
Config.Monetization = {
	Passes = {
		DoubleCash = {
			Id = 0,
			Name = "2x Cash",
			Description = "Every Goober earns double, forever.",
			Multiplier = 2,
			SuggestedRobux = 199,
		},
		Lucky = {
			Id = 0,
			Name = "Lucky Launcher",
			Description = "1.5x luck on every crate: rarer Goobers and mutations.",
			Multiplier = 1.5,
			SuggestedRobux = 249,
		},
		SuperCannon = {
			Id = 0,
			Name = "Super Cannon",
			Description = "+15% launch speed. Reach new zones sooner.",
			Multiplier = 1.15,
			SuggestedRobux = 149,
		},
	},
	Products = {
		CashPack = {
			Id = 0,
			Name = "Cash Pack",
			Description = "10 minutes of your income, instantly (at least $1K).",
			IncomeSeconds = 600,
			MinCash = 1000,
			SuggestedRobux = 49,
		},
		LuckBoost = {
			Id = 0,
			Name = "Luck Boost",
			Description = "2x luck for 15 minutes. Stacks with Lucky Launcher.",
			Multiplier = 2,
			Minutes = 15,
			SuggestedRobux = 39,
		},
	},
}

Config.Plot = {
	Slots = 8,
	SellSeconds = 20, -- a Goober sells for this many seconds of its income
	OfflineCapSeconds = 2 * 60 * 60,
	OfflineRate = 1, -- fraction of normal income earned while offline
	MaxPlots = 6,
}

Config.RarityOrder = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic" }

Config.RarityColors = {
	Common = Color3.fromRGB(200, 200, 200),
	Uncommon = Color3.fromRGB(90, 220, 110),
	Rare = Color3.fromRGB(70, 150, 255),
	Epic = Color3.fromRGB(190, 90, 255),
	Legendary = Color3.fromRGB(255, 190, 40),
	Mythic = Color3.fromRGB(255, 70, 110),
}

-- Ordered by distance. A landing belongs to the last zone whose StartDistance it passed.
Config.Zones = {
	{
		Name = "Backyard",
		StartDistance = 0,
		GroundColor = Color3.fromRGB(96, 168, 76),
		GroundMaterial = Enum.Material.Grass,
		RarityWeights = { Common = 80, Uncommon = 18, Rare = 2, Epic = 0, Legendary = 0, Mythic = 0 },
	},
	{
		Name = "Suburbs",
		StartDistance = 180,
		GroundColor = Color3.fromRGB(140, 150, 120),
		GroundMaterial = Enum.Material.Grass,
		RarityWeights = { Common = 50, Uncommon = 32, Rare = 13, Epic = 4.5, Legendary = 0.5, Mythic = 0 },
	},
	{
		Name = "Mall",
		StartDistance = 450,
		GroundColor = Color3.fromRGB(205, 180, 130),
		GroundMaterial = Enum.Material.Sand,
		RarityWeights = { Common = 28, Uncommon = 35, Rare = 23, Epic = 11, Legendary = 3, Mythic = 0 },
	},
	{
		Name = "Downtown",
		StartDistance = 750,
		GroundColor = Color3.fromRGB(110, 110, 120),
		GroundMaterial = Enum.Material.Asphalt,
		RarityWeights = { Common = 12, Uncommon = 30, Rare = 31, Epic = 19, Legendary = 7, Mythic = 1 },
	},
	{
		Name = "Volcano",
		StartDistance = 1050,
		GroundColor = Color3.fromRGB(120, 50, 40),
		GroundMaterial = Enum.Material.Basalt,
		RarityWeights = { Common = 4, Uncommon = 18, Rare = 32, Epic = 28, Legendary = 14, Mythic = 4 },
	},
	{
		Name = "Outer Rim",
		StartDistance = 1400,
		GroundColor = Color3.fromRGB(90, 70, 140),
		GroundMaterial = Enum.Material.Slate,
		RarityWeights = { Common = 0, Uncommon = 8, Rare = 28, Epic = 34, Legendary = 21, Mythic = 9 },
	},
} :: { Zone }

-- Rolled after the Goober itself. Checked rarest first; anything that misses all is "None".
Config.Mutations = {
	{ Name = "Crispy", Chance = 0.005, Multiplier = 10 },
	{ Name = "Rainbow", Chance = 0.015, Multiplier = 5 },
	{ Name = "Huge", Chance = 0.03, Multiplier = 3, Scale = 1.7 },
	{ Name = "Gold", Chance = 0.05, Multiplier = 2 },
} :: { Mutation }

Config.FieldLength = 1800
Config.FieldWidth = 600

return Config
