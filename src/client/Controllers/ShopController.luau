--!strict
-- The Robux shop: game passes and developer products from Config.Monetization.
-- Buying only asks the server to show Roblox's purchase prompt; the server grants
-- everything. Items with Id 0 aren't on Roblox yet and show as "Coming soon".

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Format = require(Shared.Format)
local Remotes = require(Shared.Remotes)

local player = Players.LocalPlayer

local ShopController = {}

local FONT = Enum.Font.FredokaOne
local WHITE = Color3.new(1, 1, 1)
local GOLD = Color3.fromRGB(255, 210, 70)

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
gui.Name = "GooberShop"
gui.ResetOnSpawn = false
gui.DisplayOrder = 6
gui.Parent = player:WaitForChild("PlayerGui")

-- Toggle button, under the Index button on the left edge.
local openButton = Instance.new("TextButton")
openButton.Name = "OpenShop"
openButton.Size = UDim2.fromOffset(230, 44)
openButton.Position = UDim2.new(0, 12, 0.5, 68)
openButton.BackgroundColor3 = GOLD
openButton.Font = FONT
openButton.TextScaled = true
openButton.TextColor3 = WHITE
openButton.TextStrokeTransparency = 0
openButton.Text = "Shop"
openButton.Parent = gui
corner(openButton)
stroke(openButton)

local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.Visible = false
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.fromScale(0.5, 0.5)
panel.Size = UDim2.fromScale(0.7, 0.8)
panel.BackgroundColor3 = Color3.fromRGB(45, 30, 70)
panel.Parent = gui
corner(panel, 16)
stroke(panel, nil, 4)
local sizeLimit = Instance.new("UISizeConstraint")
sizeLimit.MaxSize = Vector2.new(760, 640)
sizeLimit.Parent = panel

local title = text(panel, "Shop", UDim2.new(1, -120, 0, 44), UDim2.fromOffset(16, 8), GOLD)
title.TextXAlignment = Enum.TextXAlignment.Left
local boostLabel =
	text(panel, "", UDim2.new(1, -120, 0, 24), UDim2.fromOffset(16, 52), Color3.fromRGB(120, 255, 120))
boostLabel.TextXAlignment = Enum.TextXAlignment.Left

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

local list = Instance.new("ScrollingFrame")
list.Name = "Items"
list.BackgroundTransparency = 1
list.BorderSizePixel = 0
list.Position = UDim2.fromOffset(12, 86)
list.Size = UDim2.new(1, -24, 1, -98)
list.CanvasSize = UDim2.new()
list.AutomaticCanvasSize = Enum.AutomaticSize.Y
list.ScrollBarThickness = 8
list.Parent = panel
local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 8)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = list

type Row = { kind: string, key: string, button: TextButton }
local rows: { Row } = {}
local prices: { [string]: number } = {}

local function ownedPasses(): { [string]: boolean }
	local set = {}
	for key in string.gmatch((player:GetAttribute("Passes") :: string?) or "", "[^,]+") do
		set[key] = true
	end
	return set
end

local function addRow(kind: string, key: string, item: any, order: number)
	local row = Instance.new("Frame")
	row.Name = key
	row.LayoutOrder = order
	row.Size = UDim2.new(1, -12, 0, 76)
	row.BackgroundColor3 = Color3.fromRGB(70, 50, 100)
	row.Parent = list
	corner(row, 12)
	stroke(row, if kind == "Pass" then GOLD else Color3.fromRGB(120, 200, 255), 2)

	local name = text(row, item.Name, UDim2.new(1, -190, 0, 32), UDim2.fromOffset(12, 6))
	name.TextXAlignment = Enum.TextXAlignment.Left
	local desc = text(
		row,
		item.Description,
		UDim2.new(1, -190, 0, 28),
		UDim2.fromOffset(12, 40),
		Color3.fromRGB(220, 220, 220)
	)
	desc.TextXAlignment = Enum.TextXAlignment.Left
	desc.TextWrapped = true

	local button = Instance.new("TextButton")
	button.Name = "Buy"
	button.AnchorPoint = Vector2.new(1, 0.5)
	button.Position = UDim2.new(1, -10, 0.5, 0)
	button.Size = UDim2.fromOffset(160, 54)
	button.Font = FONT
	button.TextScaled = true
	button.TextColor3 = WHITE
	button.TextStrokeTransparency = 0
	button.Parent = row
	corner(button, 10)
	stroke(button)
	button.Activated:Connect(function()
		if item.Id ~= 0 then
			Remotes.get("PromptPurchase"):FireServer(kind, key)
		end
	end)
	table.insert(rows, { kind = kind, key = key, button = button })

	if item.Id ~= 0 then
		task.spawn(function()
			local infoType = if kind == "Pass" then Enum.InfoType.GamePass else Enum.InfoType.Product
			local ok, info = pcall(MarketplaceService.GetProductInfo, MarketplaceService, item.Id, infoType)
			if ok and info and info.PriceInRobux then
				prices[kind .. key] = info.PriceInRobux
				ShopController.refresh()
			end
		end)
	end
end

local function sortedKeys(t: { [string]: any }): { string }
	local keys = {}
	for key in t do
		table.insert(keys, key)
	end
	table.sort(keys, function(a, b)
		return (t[a].SuggestedRobux or 0) > (t[b].SuggestedRobux or 0)
	end)
	return keys
end

function ShopController.refresh()
	local passes = ownedPasses()
	for _, row in rows do
		local items = if row.kind == "Pass" then Config.Monetization.Passes else Config.Monetization.Products
		local item = items[row.key]
		local price = prices[row.kind .. row.key]
		if row.kind == "Pass" and passes[row.key] then
			row.button.Text = "OWNED"
			row.button.BackgroundColor3 = Color3.fromRGB(80, 200, 90)
		elseif item.Id == 0 then
			row.button.Text = "Coming soon"
			row.button.BackgroundColor3 = Color3.fromRGB(120, 120, 130)
		else
			row.button.Text = if price then "R$ " .. price else "Buy"
			row.button.BackgroundColor3 = Color3.fromRGB(40, 170, 90)
		end
	end
	local boostUntil = (player:GetAttribute("LuckBoostUntil") :: number?) or 0
	local left = boostUntil - os.time()
	boostLabel.Text = if left > 0
		then "Luck Boost active: " .. Format.duration(left) .. " left"
		else "Support the game and get there faster."
end

function ShopController.start()
	local order = 0
	for _, key in sortedKeys(Config.Monetization.Passes) do
		order += 1
		addRow("Pass", key, Config.Monetization.Passes[key], order)
	end
	for _, key in sortedKeys(Config.Monetization.Products) do
		order += 1
		addRow("Product", key, Config.Monetization.Products[key], order)
	end
	openButton.Activated:Connect(function()
		panel.Visible = not panel.Visible
		ShopController.refresh()
	end)
	close.Activated:Connect(function()
		panel.Visible = false
	end)
	player:GetAttributeChangedSignal("Passes"):Connect(ShopController.refresh)
	player:GetAttributeChangedSignal("LuckBoostUntil"):Connect(ShopController.refresh)
	task.spawn(function()
		while true do
			task.wait(1)
			if panel.Visible then
				ShopController.refresh()
			end
		end
	end)
	ShopController.refresh()
end

return ShopController
