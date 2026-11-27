--!strict
-- The Goober Index: every Goober in the game, grouped by rarity. Ones you've caught
-- show as a live 3D model with their blurb; the rest are dark silhouettes. Each
-- discovery adds a permanent income bonus (Config.Index).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Format = require(Shared.Format)
local GooberDefs = require(Shared.GooberDefs)
local GooberVisual = require(Shared.GooberVisual)

local player = Players.LocalPlayer

local IndexController = {}

local FONT = Enum.Font.FredokaOne
local WHITE = Color3.new(1, 1, 1)
local CARD_W, CARD_H = 150, 190

local function corner(parent: Instance, radius: number?)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius or 12)
	c.Parent = parent
end

local function stroke(parent: Instance, color: Color3?, thickness: number?)
	local s = Instance.new("UIStroke")
	s.Thickness = thickness or 3
	s.Color = color or Color3.fromRGB(30, 20, 40)
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = parent
end

local function text(parent: Instance, value: string, size: UDim2, position: UDim2, color: Color3?): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Size = size
	l.Position = position
	l.Font = FONT
	l.TextScaled = true
	l.TextColor3 = color or WHITE
	l.TextStrokeTransparency = 0
	l.Text = value
	l.Parent = parent
	return l
end

local gui = Instance.new("ScreenGui")
gui.Name = "GooberIndex"
gui.ResetOnSpawn = false
gui.DisplayOrder = 5
gui.Parent = player:WaitForChild("PlayerGui")

-- Toggle button, under the HUD stats panel on the left edge.
local openButton = Instance.new("TextButton")
openButton.Name = "OpenIndex"
openButton.Size = UDim2.fromOffset(230, 44)
openButton.Position = UDim2.new(0, 12, 0.5, 16)
openButton.BackgroundColor3 = Color3.fromRGB(70, 150, 255)
openButton.Font = FONT
openButton.TextScaled = true
openButton.TextColor3 = WHITE
openButton.TextStrokeTransparency = 0
openButton.Text = "Index 0/0"
openButton.Parent = gui
corner(openButton)
stroke(openButton)

local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.Visible = false
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.fromScale(0.5, 0.5)
panel.Size = UDim2.fromScale(0.8, 0.8)
panel.BackgroundColor3 = Color3.fromRGB(45, 30, 70)
panel.Parent = gui
corner(panel, 16)
stroke(panel, nil, 4)
local sizeLimit = Instance.new("UISizeConstraint")
sizeLimit.MaxSize = Vector2.new(1000, 700)
sizeLimit.Parent = panel

local title = text(panel, "Goober Index", UDim2.new(1, -120, 0, 44), UDim2.fromOffset(16, 8))
title.TextXAlignment = Enum.TextXAlignment.Left
local bonusLabel =
	text(panel, "", UDim2.new(1, -120, 0, 24), UDim2.fromOffset(16, 52), Color3.fromRGB(120, 255, 120))
bonusLabel.TextXAlignment = Enum.TextXAlignment.Left

local close = Instance.new("TextButton")
close.Name = "Close"
close.AnchorPoint = Vector2.new(1, 0)
close.Position = UDim2.new(1, -12, 0, 12)
close.Size = UDim2.fromOffset(48, 48)
close.BackgroundColor3 = Color3.fromRGB(230, 70, 70)
close.Font = FONT
close.TextScaled = true
close.TextColor3 = WHITE
close.Text = "X"
close.Parent = panel
corner(close, 10)
stroke(close)

local scroll = Instance.new("ScrollingFrame")
scroll.Name = "Cards"
scroll.BackgroundTransparency = 1
scroll.BorderSizePixel = 0
scroll.Position = UDim2.fromOffset(12, 86)
scroll.Size = UDim2.new(1, -24, 1, -98)
scroll.CanvasSize = UDim2.new()
scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
scroll.ScrollBarThickness = 8
scroll.Parent = panel
local grid = Instance.new("UIGridLayout")
grid.CellSize = UDim2.fromOffset(CARD_W, CARD_H)
grid.CellPadding = UDim2.fromOffset(10, 10)
grid.SortOrder = Enum.SortOrder.LayoutOrder
grid.Parent = scroll

local function discoveredSet(): { [string]: boolean }
	local set = {}
	local raw = (player:GetAttribute("Discovered") :: string?) or ""
	for id in string.gmatch(raw, "[^,]+") do
		set[id] = true
	end
	return set
end

local function rarityRank(rarity: string): number
	return table.find(Config.RarityOrder, rarity) or 99
end

local cards: { [string]: { frame: Frame, found: boolean? } } = {}

local function buildCard(def: GooberDefs.GooberDef, order: number, found: boolean)
	local existing = cards[def.Id]
	if existing and existing.found == found then
		return
	end
	if existing then
		existing.frame:Destroy()
	end
	local rarityColor = Config.RarityColors[def.Rarity] or WHITE

	local frame = Instance.new("Frame")
	frame.Name = def.Id
	frame.LayoutOrder = order
	frame.BackgroundColor3 = if found then Color3.fromRGB(70, 50, 100) else Color3.fromRGB(35, 25, 50)
	frame.Parent = scroll
	corner(frame, 12)
	stroke(frame, rarityColor, 3)

	local view = Instance.new("ViewportFrame")
	view.BackgroundTransparency = 1
	view.Size = UDim2.new(1, -10, 0, 100)
	view.Position = UDim2.fromOffset(5, 4)
	view.Ambient = Color3.fromRGB(200, 200, 200)
	view.LightColor = WHITE
	view.Parent = frame
	if not found then
		-- Silhouette: same shape, no colors.
		view.ImageColor3 = Color3.new(0, 0, 0)
	end
	local model = GooberVisual.build(def.Id, "None", false)
	model:PivotTo(CFrame.new())
	model.Parent = view
	local camera = Instance.new("Camera")
	local _, size = model:GetBoundingBox()
	local reach = math.max(size.X, size.Y, size.Z)
	camera.CFrame = CFrame.lookAt(Vector3.new(0, size.Y * 0.15, -reach * 1.6), Vector3.new(0, 0, 0))
	camera.FieldOfView = 50
	camera.Parent = view
	view.CurrentCamera = camera

	text(
		frame,
		if found then def.Name else "???",
		UDim2.new(1, -10, 0, 24),
		UDim2.fromOffset(5, 106),
		rarityColor
	)
	text(frame, def.Rarity, UDim2.new(1, -10, 0, 18), UDim2.fromOffset(5, 130), Color3.fromRGB(220, 220, 220))
	local detail = text(
		frame,
		if found then def.Blurb else "Catch one to reveal it.",
		UDim2.new(1, -10, 0, 34),
		UDim2.fromOffset(5, 150),
		Color3.fromRGB(200, 255, 200)
	)
	detail.TextWrapped = true
	if found then
		detail.Text = Format.rate(def.Income) .. "  •  " .. def.Blurb
	end

	cards[def.Id] = { frame = frame, found = found }
end

local function refresh()
	local found = discoveredSet()
	local total, count = #GooberDefs.List, 0
	local ordered = table.clone(GooberDefs.List)
	table.sort(ordered, function(a, b)
		local ra, rb = rarityRank(a.Rarity), rarityRank(b.Rarity)
		if ra ~= rb then
			return ra < rb
		end
		return a.Income < b.Income
	end)
	for i, def in ordered do
		local isFound = found[def.Id] == true
		if isFound then
			count += 1
		end
		if panel.Visible then
			buildCard(def, i, isFound)
		end
	end
	openButton.Text = "Index " .. count .. "/" .. total
	title.Text = "Goober Index  " .. count .. "/" .. total
	bonusLabel.Text = string.format(
		"Index bonus: +%d%% income (+%d%% per Goober found)",
		math.floor(count * Config.Index.BonusPerGoober * 100 + 0.5),
		math.floor(Config.Index.BonusPerGoober * 100 + 0.5)
	)
end

function IndexController.setOpen(open: boolean)
	panel.Visible = open
	refresh()
end

function IndexController.start()
	openButton.Activated:Connect(function()
		IndexController.setOpen(not panel.Visible)
	end)
	close.Activated:Connect(function()
		IndexController.setOpen(false)
	end)
	player:GetAttributeChangedSignal("Discovered"):Connect(refresh)
	refresh()
end

return IndexController
