--!strict
-- Builds the launch field from code so the place works straight out of `rojo build`.
-- Layout: plots sit in a row along X at negative Z, cannons face +Z, and the field
-- runs from Z = 0 out to Config.FieldLength, striped by zone.

local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")

local Config = require(game:GetService("ReplicatedStorage").Shared.Config)

local MapBuilder = {}

local function block(name: string, size: Vector3, cframe: CFrame, color: Color3, parent: Instance): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = Enum.Material.Grass
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function sign(text: string, color: Color3, cframe: CFrame, parent: Instance)
	local post = block(
		"SignPost",
		Vector3.new(1, 18, 1),
		cframe * CFrame.new(0, 9, 0),
		Color3.fromRGB(90, 60, 40),
		parent
	)
	post.Material = Enum.Material.Wood
	local board = block(
		"Sign",
		Vector3.new(40, 10, 1),
		cframe * CFrame.new(0, 20, 0),
		Color3.fromRGB(250, 245, 230),
		parent
	)
	board.Material = Enum.Material.SmoothPlastic
	-- The outer plots fire straight through these, so they must not stop a flight.
	post.CanCollide = false
	board.CanCollide = false
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local gui = Instance.new("SurfaceGui")
		gui.Face = face
		gui.PixelsPerStud = 25
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.Parent = board
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.FredokaOne
		label.TextScaled = true
		label.TextColor3 = color
		label.TextStrokeTransparency = 0
		label.Text = text
		label.Parent = gui
	end
end

function MapBuilder.build(): Folder
	local existing = Workspace:FindFirstChild("Map")
	if existing then
		existing:Destroy()
	end
	local map = Instance.new("Folder")
	map.Name = "Map"

	local width = Config.FieldWidth
	local length = Config.FieldLength

	-- Zone stripes.
	for i, zone in Config.Zones do
		local startZ = zone.StartDistance
		local nextZone = Config.Zones[i + 1]
		local endZ = if nextZone then nextZone.StartDistance else length
		local depth = endZ - startZ
		local ground = block(
			"Zone_" .. zone.Name,
			Vector3.new(width, 4, depth),
			CFrame.new(0, -2, startZ + depth / 2),
			zone.GroundColor,
			map
		)
		ground.Material = if i == 3 then Enum.Material.Sand else Enum.Material.Grass
		ground:SetAttribute("ZoneIndex", i)
		-- Signs on the left and right edges of each zone's start line.
		for _, x in { -width / 2 + 30, width / 2 - 30 } do
			sign(
				zone.Name .. "  " .. zone.StartDistance .. "+",
				Color3.fromRGB(40, 40, 40),
				CFrame.new(x, 0, startZ + 2),
				map
			)
		end
		-- A thin painted line at the zone start.
		local line = block(
			"ZoneLine",
			Vector3.new(width, 0.2, 2),
			CFrame.new(0, 0.1, startZ + 1),
			Color3.new(1, 1, 1),
			map
		)
		line.Material = Enum.Material.SmoothPlastic
		line.CanCollide = false
	end

	-- Distance markers every 100 studs, so people can eyeball a launch.
	for z = 100, length - 100, 100 do
		local marker = block(
			"Marker_" .. z,
			Vector3.new(4, 0.3, 4),
			CFrame.new(0, 0.15, z),
			Color3.fromRGB(255, 255, 255),
			map
		)
		marker.Material = Enum.Material.Neon
		marker.CanCollide = false
	end

	-- Base area for plots, behind the start line.
	local base = block(
		"PlotGround",
		Vector3.new(width, 4, 140),
		CFrame.new(0, -2, -70),
		Color3.fromRGB(120, 180, 90),
		map
	)
	base.Material = Enum.Material.Grass

	-- Invisible walls so nobody tumbles off the edge of the world.
	local wallHeight = 400
	local walls = {
		{
			Vector3.new(4, wallHeight, length + 160),
			CFrame.new(-width / 2 - 2, wallHeight / 2, length / 2 - 80),
		},
		{
			Vector3.new(4, wallHeight, length + 160),
			CFrame.new(width / 2 + 2, wallHeight / 2, length / 2 - 80),
		},
		{ Vector3.new(width, wallHeight, 4), CFrame.new(0, wallHeight / 2, length + 2) },
		{ Vector3.new(width, wallHeight, 4), CFrame.new(0, wallHeight / 2, -142) },
	}
	for _, w in walls do
		local wall = block("Wall", w[1], w[2], Color3.new(1, 1, 1), map)
		wall.Transparency = 1
		wall.CanQuery = false
	end

	-- Spawn sits in the middle of the plot row; players get sent to their own plot after.
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "Spawn"
	spawn.Anchored = true
	spawn.Size = Vector3.new(12, 1, 12)
	spawn.CFrame = CFrame.new(0, 0.5, -110)
	spawn.Duration = 0
	spawn.Color = Color3.fromRGB(255, 200, 60)
	spawn.Material = Enum.Material.SmoothPlastic
	spawn.Parent = map

	Lighting.ClockTime = 14
	Lighting.Brightness = 2.5
	Lighting.OutdoorAmbient = Color3.fromRGB(150, 150, 160)

	map.Parent = Workspace
	return map
end

return MapBuilder
