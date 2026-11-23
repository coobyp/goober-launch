--!strict
-- Builds a Goober model out of primitives. Blobby on purpose: fast to make,
-- reads well on a phone, and swappable for real meshes later without touching gameplay.
-- Every part is anchored and non-colliding; callers position the model with :PivotTo().

local CollectionService = game:GetService("CollectionService")

local Config = require(script.Parent.Config)
local Formulas = require(script.Parent.Formulas)
local Format = require(script.Parent.Format)
local GooberDefs = require(script.Parent.GooberDefs)

local GooberVisual = {}

GooberVisual.RAINBOW_TAG = "RainbowGoober"

local function part(name: string, size: Vector3, color: Color3, parent: Instance): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = true
	p.CanTouch = false
	p.CastShadow = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	p.Parent = parent
	return p
end

local function ellipsoid(name: string, size: Vector3, color: Color3, parent: Instance): Part
	local p = part(name, size, color, parent)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = p
	return p
end

local function mutationLook(mutation: string, base: Color3): (Color3, Enum.Material)
	if mutation == "Gold" then
		return Color3.fromRGB(255, 200, 40), Enum.Material.Foil
	elseif mutation == "Crispy" then
		return base:Lerp(Color3.fromRGB(30, 15, 5), 0.6), Enum.Material.CrackedLava
	elseif mutation == "Rainbow" then
		return base, Enum.Material.Neon
	end
	return base, Enum.Material.SmoothPlastic
end

local function addAccessory(kind: string, body: Part, s: number, model: Model)
	local top = body.Size.Y / 2
	if kind == "TopHat" then
		local brim = part("Brim", Vector3.new(1.8, 0.15, 1.8) * s, Color3.fromRGB(25, 25, 25), model)
		brim.CFrame = body.CFrame * CFrame.new(0, top - 0.1 * s, 0)
		local crown = part("Hat", Vector3.new(1.1, 1.2, 1.1) * s, Color3.fromRGB(25, 25, 25), model)
		crown.CFrame = brim.CFrame * CFrame.new(0, 0.65 * s, 0)
	elseif kind == "Antenna" then
		local stalk = part("Stalk", Vector3.new(0.12, 1.2, 0.12) * s, Color3.fromRGB(40, 40, 40), model)
		stalk.CFrame = body.CFrame * CFrame.new(0, top + 0.5 * s, 0)
		local bulb = ellipsoid("Bulb", Vector3.new(0.45, 0.45, 0.45) * s, Color3.fromRGB(255, 240, 90), model)
		bulb.Material = Enum.Material.Neon
		bulb.CFrame = stalk.CFrame * CFrame.new(0, 0.65 * s, 0)
	elseif kind == "Crown" then
		local crown = part("Crown", Vector3.new(1.4, 0.6, 1.4) * s, Color3.fromRGB(255, 205, 50), model)
		crown.Material = Enum.Material.Foil
		crown.CFrame = body.CFrame * CFrame.new(0, top + 0.1 * s, 0)
	elseif kind == "Toast" then
		local toast = part("Toast", Vector3.new(1.4, 1.4, 0.3) * s, Color3.fromRGB(230, 180, 100), model)
		toast.CFrame = body.CFrame * CFrame.new(0, top + 0.4 * s, 0) * CFrame.Angles(0, 0, math.rad(15))
	elseif kind == "Halo" then
		local halo = part("Halo", Vector3.new(0.15, 1.8, 1.8) * s, Color3.fromRGB(255, 250, 180), model)
		halo.Shape = Enum.PartType.Cylinder
		halo.Material = Enum.Material.Neon
		halo.CFrame = body.CFrame * CFrame.new(0, top + 0.6 * s, 0) * CFrame.Angles(0, 0, math.rad(90))
	elseif kind == "Leaf" then
		local leaf = ellipsoid("Leaf", Vector3.new(1.2, 0.15, 0.6) * s, Color3.fromRGB(70, 160, 60), model)
		leaf.CFrame = body.CFrame * CFrame.new(0.2 * s, top, 0) * CFrame.Angles(0, 0, math.rad(-20))
	elseif kind == "Cape" then
		local cape = part(
			"Cape",
			Vector3.new(body.Size.X * 0.9, body.Size.Y * 0.8, 0.1),
			Color3.fromRGB(170, 30, 40),
			model
		)
		cape.CFrame = body.CFrame * CFrame.new(0, -0.1 * s, body.Size.Z / 2 + 0.05)
	end
end

-- Builds a Goober model. Faces -Z (the model's LookVector), like every Roblox model.
function GooberVisual.build(id: string, mutation: string?, showTag: boolean?): Model
	local def = GooberDefs.ById[id]
	assert(def, "unknown Goober " .. tostring(id))
	local mut = mutation or "None"

	local scale = 1
	for _, m in Config.Mutations do
		if m.Name == mut and m.Scale then
			scale = m.Scale
		end
	end

	local model = Instance.new("Model")
	model.Name = def.Name
	model:SetAttribute("GooberId", id)
	model:SetAttribute("Mutation", mut)

	local color, material = mutationLook(mut, def.Color)
	local body = ellipsoid("Body", def.Squish * scale, color, model)
	body.Material = material
	body.CFrame = CFrame.new(0, def.Squish.Y * scale / 2, 0)
	model.PrimaryPart = body
	if mut == "Rainbow" then
		CollectionService:AddTag(body, GooberVisual.RAINBOW_TAG)
	end

	-- Big googly eyes on the front (-Z) face.
	local eyeSize = 0.8 * def.EyeScale * scale
	local front = -def.Squish.Z * scale / 2
	for _, side in { -1, 1 } do
		local eye = ellipsoid("Eye", Vector3.new(eyeSize, eyeSize, eyeSize * 0.6), Color3.new(1, 1, 1), model)
		eye.CFrame = body.CFrame
			* CFrame.new(
				side * def.Squish.X * scale * 0.2,
				def.Squish.Y * scale * 0.12,
				front + eyeSize * 0.15
			)
		local pupil = ellipsoid(
			"Pupil",
			Vector3.new(eyeSize, eyeSize, eyeSize * 0.6) * 0.45,
			Color3.new(0, 0, 0),
			model
		)
		-- Slightly cross-eyed. It's a Goober.
		pupil.CFrame = eye.CFrame * CFrame.new(-side * eyeSize * 0.12, 0, -eyeSize * 0.22)
	end

	addAccessory(def.Accessory, body, scale, model)

	if mut == "Crispy" then
		local smoke = Instance.new("Smoke")
		smoke.Size = 0.6 * scale
		smoke.RiseVelocity = 2
		smoke.Opacity = 0.15
		smoke.Parent = body
	elseif mut == "Gold" then
		local sparkles = Instance.new("Sparkles")
		sparkles.SparkleColor = Color3.fromRGB(255, 220, 80)
		sparkles.Parent = body
	end

	if showTag ~= false then
		local tag = Instance.new("BillboardGui")
		tag.Name = "Tag"
		tag.Size = UDim2.fromOffset(200, 54)
		tag.StudsOffsetWorldSpace = Vector3.new(0, def.Squish.Y * scale / 2 + 2.2 * scale, 0)
		tag.MaxDistance = 90
		tag.Adornee = body
		tag.Parent = body

		local nameLabel = Instance.new("TextLabel")
		nameLabel.BackgroundTransparency = 1
		nameLabel.Size = UDim2.new(1, 0, 0.55, 0)
		nameLabel.Font = Enum.Font.FredokaOne
		nameLabel.TextScaled = true
		nameLabel.TextColor3 = Config.RarityColors[def.Rarity] or Color3.new(1, 1, 1)
		nameLabel.TextStrokeTransparency = 0.3
		nameLabel.Text = (if mut ~= "None" then mut .. " " else "") .. def.Name
		nameLabel.Parent = tag

		local rateLabel = Instance.new("TextLabel")
		rateLabel.BackgroundTransparency = 1
		rateLabel.Position = UDim2.fromScale(0, 0.55)
		rateLabel.Size = UDim2.new(1, 0, 0.45, 0)
		rateLabel.Font = Enum.Font.FredokaOne
		rateLabel.TextScaled = true
		rateLabel.TextColor3 = Color3.fromRGB(120, 255, 120)
		rateLabel.TextStrokeTransparency = 0.3
		rateLabel.Text = Format.rate(Formulas.gooberIncome(id, mut))
		rateLabel.Parent = tag
	end

	return model
end

return GooberVisual
