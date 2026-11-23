--!strict
-- The Goober roster. Original characters only: no borrowed memes, no borrowed IP.
-- Visuals are built in code by GooberVisual, so adding a Goober is one entry here.

export type Accessory = "None" | "TopHat" | "Antenna" | "Crown" | "Toast" | "Halo" | "Leaf" | "Cape"

export type GooberDef = {
	Id: string,
	Name: string,
	Rarity: string,
	Income: number, -- cash per second before mutations
	Color: Color3,
	Squish: Vector3, -- body proportions (ellipsoid)
	EyeScale: number,
	Accessory: Accessory,
	Blurb: string,
}

local defs: { GooberDef } = {
	-- Common
	{
		Id = "sir_blobbington",
		Name = "Sir Blobbington",
		Rarity = "Common",
		Income = 1,
		Color = Color3.fromRGB(120, 200, 255),
		Squish = Vector3.new(3, 2.4, 3),
		EyeScale = 1,
		Accessory = "TopHat",
		Blurb = "Knighted for sitting very still.",
	},
	{
		Id = "toastgoblin",
		Name = "Toastgoblin",
		Rarity = "Common",
		Income = 1.5,
		Color = Color3.fromRGB(214, 160, 92),
		Squish = Vector3.new(2.8, 2.8, 2.2),
		EyeScale = 1.2,
		Accessory = "Toast",
		Blurb = "Smells faintly of breakfast.",
	},
	{
		Id = "soggy_steve",
		Name = "Soggy Steve",
		Rarity = "Common",
		Income = 2,
		Color = Color3.fromRGB(150, 170, 140),
		Squish = Vector3.new(3.4, 1.8, 3.4),
		EyeScale = 0.8,
		Accessory = "Leaf",
		Blurb = "Has never once been dry.",
	},
	-- Uncommon
	{
		Id = "mega_jeff",
		Name = "Mega Jeff",
		Rarity = "Uncommon",
		Income = 6,
		Color = Color3.fromRGB(255, 120, 150),
		Squish = Vector3.new(3.6, 3.6, 3.6),
		EyeScale = 0.7,
		Accessory = "None",
		Blurb = "Just Jeff, but more.",
	},
	{
		Id = "couch_wizard",
		Name = "Couch Wizard",
		Rarity = "Uncommon",
		Income = 8,
		Color = Color3.fromRGB(110, 90, 200),
		Squish = Vector3.new(3, 2.6, 3),
		EyeScale = 1,
		Accessory = "Antenna",
		Blurb = "Casts spells exclusively from the couch.",
	},
	{
		Id = "lil_bean_dip",
		Name = "Lil' Bean Dip",
		Rarity = "Uncommon",
		Income = 10,
		Color = Color3.fromRGB(150, 95, 60),
		Squish = Vector3.new(2.2, 2, 2.2),
		EyeScale = 1.5,
		Accessory = "None",
		Blurb = "Small. Brown. Unstoppable.",
	},
	-- Rare
	{
		Id = "professor_wobble",
		Name = "Professor Wobble",
		Rarity = "Rare",
		Income = 25,
		Color = Color3.fromRGB(240, 235, 120),
		Squish = Vector3.new(2.6, 3.4, 2.6),
		EyeScale = 1.1,
		Accessory = "TopHat",
		Blurb = "Tenured. Unclear in what.",
	},
	{
		Id = "grumblesnout",
		Name = "Grumblesnout",
		Rarity = "Rare",
		Income = 35,
		Color = Color3.fromRGB(110, 140, 80),
		Squish = Vector3.new(3.8, 2.4, 3),
		EyeScale = 0.6,
		Accessory = "Cape",
		Blurb = "Hates Mondays, Tuesdays, and you.",
	},
	-- Epic
	{
		Id = "captain_noodlefist",
		Name = "Captain Noodlefist",
		Rarity = "Epic",
		Income = 90,
		Color = Color3.fromRGB(255, 230, 170),
		Squish = Vector3.new(2.4, 3.8, 2.4),
		EyeScale = 1,
		Accessory = "Crown",
		Blurb = "Punches with noodles. Mostly misses.",
	},
	{
		Id = "duke_dumpling",
		Name = "Duke Dumpling",
		Rarity = "Epic",
		Income = 120,
		Color = Color3.fromRGB(250, 245, 235),
		Squish = Vector3.new(3.6, 2.6, 3.6),
		EyeScale = 0.9,
		Accessory = "Cape",
		Blurb = "Steamed to perfection. Knows it.",
	},
	-- Legendary
	{
		Id = "cosmic_gerald",
		Name = "Cosmic Gerald",
		Rarity = "Legendary",
		Income = 400,
		Color = Color3.fromRGB(40, 30, 90),
		Squish = Vector3.new(3.2, 3.2, 3.2),
		EyeScale = 1.6,
		Accessory = "Halo",
		Blurb = "Has seen the end of the universe. Was unimpressed.",
	},
	{
		Id = "the_unbothered_one",
		Name = "The Unbothered One",
		Rarity = "Legendary",
		Income = 500,
		Color = Color3.fromRGB(255, 255, 255),
		Squish = Vector3.new(3.4, 2.2, 3.4),
		EyeScale = 0.5,
		Accessory = "Crown",
		Blurb = "Cannot be stressed. Has tried.",
	},
}

local GooberDefs = {}

GooberDefs.List = defs
GooberDefs.ById = {} :: { [string]: GooberDef }
GooberDefs.ByRarity = {} :: { [string]: { GooberDef } }

for _, def in defs do
	assert(GooberDefs.ById[def.Id] == nil, "duplicate Goober id " .. def.Id)
	GooberDefs.ById[def.Id] = def
	local bucket = GooberDefs.ByRarity[def.Rarity]
	if not bucket then
		bucket = {}
		GooberDefs.ByRarity[def.Rarity] = bucket
	end
	table.insert(bucket, def)
end

function GooberDefs.get(id: string): GooberDef?
	return GooberDefs.ById[id]
end

return GooberDefs
