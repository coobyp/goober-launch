--!strict
-- All on-screen UI, built in code: cash, income, upgrade button, charge meter,
-- live distance readout, result card, and toasts. Reads state from Player attributes.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Format = require(Shared.Format)
local Formulas = require(Shared.Formulas)
local Remotes = require(Shared.Remotes)

local player = Players.LocalPlayer

local HUD = {}

local FONT = Enum.Font.FredokaOne
local WHITE = Color3.new(1, 1, 1)

local function corner(parent: Instance, radius: number?)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius or 12)
	c.Parent = parent
end

local function stroke(parent: Instance, thickness: number?)
	local s = Instance.new("UIStroke")
	s.Thickness = thickness or 3
	s.Color = Color3.fromRGB(30, 20, 40)
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = parent
end

local function label(parent: Instance, text: string, size: UDim2, position: UDim2, color: Color3?): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Size = size
	l.Position = position
	l.Font = FONT
	l.TextScaled = true
	l.TextColor3 = color or WHITE
	l.TextStrokeTransparency = 0
	l.Text = text
	l.Parent = parent
	return l
end

local gui = Instance.new("ScreenGui")
gui.Name = "GooberHUD"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = player:WaitForChild("PlayerGui")

-- Top-left stats panel.
local stats = Instance.new("Frame")
stats.Name = "Stats"
stats.Size = UDim2.fromOffset(230, 96)
stats.Position = UDim2.fromOffset(12, 12)
stats.BackgroundColor3 = Color3.fromRGB(60, 40, 90)
stats.BackgroundTransparency = 0.15
stats.Parent = gui
corner(stats)
stroke(stats)
local cashLabel =
	label(stats, "$0", UDim2.new(1, -16, 0, 40), UDim2.fromOffset(8, 4), Color3.fromRGB(120, 255, 120))
local incomeLabel = label(stats, "$0/s", UDim2.new(1, -16, 0, 24), UDim2.fromOffset(8, 44))
local bestLabel = label(
	stats,
	"Best: 0 studs",
	UDim2.new(1, -16, 0, 22),
	UDim2.fromOffset(8, 70),
	Color3.fromRGB(255, 220, 120)
)

-- Bottom-right upgrade button.
local upgrade = Instance.new("TextButton")
upgrade.Name = "Upgrade"
upgrade.Size = UDim2.fromOffset(230, 70)
upgrade.AnchorPoint = Vector2.new(1, 1)
upgrade.Position = UDim2.new(1, -12, 1, -12)
upgrade.BackgroundColor3 = Color3.fromRGB(255, 140, 40)
upgrade.AutoButtonColor = true
upgrade.Text = ""
upgrade.Parent = gui
corner(upgrade)
stroke(upgrade)
local upgradeTitle = label(upgrade, "Launch Power Lv 0", UDim2.new(1, -16, 0.55, 0), UDim2.fromOffset(8, 2))
local upgradeCost =
	label(upgrade, "$30", UDim2.new(1, -16, 0.4, 0), UDim2.new(0, 8, 0.55, 0), Color3.fromRGB(255, 255, 180))
upgrade.Activated:Connect(function()
	Remotes.get("BuyLaunchPower"):FireServer()
end)

-- Rebirth button, stacked above the upgrade. Tap twice to confirm, since it resets
-- cash and Launch Power.
local rebirthButton = Instance.new("TextButton")
rebirthButton.Name = "Rebirth"
rebirthButton.Size = UDim2.fromOffset(230, 60)
rebirthButton.AnchorPoint = Vector2.new(1, 1)
rebirthButton.Position = UDim2.new(1, -12, 1, -90)
rebirthButton.BackgroundColor3 = Color3.fromRGB(120, 120, 130)
rebirthButton.AutoButtonColor = true
rebirthButton.Text = ""
rebirthButton.Parent = gui
corner(rebirthButton)
stroke(rebirthButton)
local rebirthTitle = label(rebirthButton, "Rebirth", UDim2.new(1, -16, 0.5, 0), UDim2.fromOffset(8, 3))
local rebirthDetail = label(
	rebirthButton,
	"",
	UDim2.new(1, -16, 0.38, 0),
	UDim2.new(0, 8, 0.55, 0),
	Color3.fromRGB(255, 220, 255)
)
local rebirthArmedUntil = 0
local refresh: () -> ()

rebirthButton.Activated:Connect(function()
	local rebirths = (player:GetAttribute("Rebirths") :: number?) or 0
	local level = (player:GetAttribute("LaunchLevel") :: number?) or 0
	local cash = (player:GetAttribute("Cash") :: number?) or 0
	if not Formulas.canRebirth(rebirths, level, cash) then
		HUD.notify(
			"Rebirth needs Launch Power "
				.. Config.Rebirth.LevelRequired
				.. " and "
				.. Format.cash(Formulas.rebirthCost(rebirths) or 0),
			Color3.fromRGB(255, 180, 255)
		)
		return
	end
	if os.clock() < rebirthArmedUntil then
		rebirthArmedUntil = 0
		Remotes.get("Rebirth"):FireServer()
	else
		rebirthArmedUntil = os.clock() + 3
		HUD.notify(
			"Resets cash and Launch Power. Goobers stay. Tap again to rebirth!",
			Color3.fromRGB(255, 180, 255)
		)
		task.delay(3, refresh)
	end
	refresh()
end)

-- Charge meter (hidden until you're in the cannon).
local meter = Instance.new("Frame")
meter.Name = "Meter"
meter.Visible = false
meter.AnchorPoint = Vector2.new(0.5, 1)
meter.Size = UDim2.fromOffset(420, 46)
meter.Position = UDim2.new(0.5, 0, 1, -110)
meter.BackgroundColor3 = Color3.fromRGB(40, 30, 60)
meter.Parent = gui
corner(meter, 10)
stroke(meter)
local sweet = Instance.new("Frame")
sweet.Name = "SweetSpot"
sweet.BackgroundColor3 = Color3.fromRGB(255, 230, 60)
sweet.BorderSizePixel = 0
sweet.Position = UDim2.fromScale(Config.Cannon.SweetSpotMin, 0)
sweet.Size = UDim2.fromScale(Config.Cannon.SweetSpotMax - Config.Cannon.SweetSpotMin, 1)
sweet.Parent = meter
local fill = Instance.new("Frame")
fill.Name = "Fill"
fill.BackgroundColor3 = Color3.fromRGB(255, 80, 80)
fill.BackgroundTransparency = 0.2
fill.BorderSizePixel = 0
fill.Size = UDim2.fromScale(0, 1)
fill.Parent = meter
corner(fill, 10)
local meterHint =
	label(meter, "HOLD to charge, RELEASE in the yellow!", UDim2.new(1, 0, 0, 28), UDim2.fromOffset(0, -34))

-- Big distance readout during flight.
local distanceLabel = label(gui, "", UDim2.fromOffset(500, 80), UDim2.new(0.5, -250, 0, 40))
distanceLabel.Visible = false

-- Result card.
local card = Instance.new("Frame")
card.Name = "Result"
card.Visible = false
card.AnchorPoint = Vector2.new(0.5, 0.5)
card.Size = UDim2.fromOffset(440, 200)
card.Position = UDim2.fromScale(0.5, 0.42)
card.BackgroundColor3 = Color3.fromRGB(60, 40, 90)
card.Parent = gui
corner(card, 16)
stroke(card, 4)
local cardDistance =
	label(card, "", UDim2.new(1, -20, 0, 50), UDim2.fromOffset(10, 8), Color3.fromRGB(255, 220, 120))
local cardZone = label(card, "", UDim2.new(1, -20, 0, 26), UDim2.fromOffset(10, 58))
local cardGoober = label(card, "", UDim2.new(1, -20, 0, 44), UDim2.fromOffset(10, 88))
local cardDetail =
	label(card, "", UDim2.new(1, -20, 0, 26), UDim2.fromOffset(10, 136), Color3.fromRGB(200, 255, 200))
local cardNote =
	label(card, "", UDim2.new(1, -20, 0, 22), UDim2.fromOffset(10, 168), Color3.fromRGB(220, 220, 220))

-- Toasts.
local toasts = Instance.new("Frame")
toasts.Name = "Toasts"
toasts.BackgroundTransparency = 1
toasts.AnchorPoint = Vector2.new(0.5, 0)
toasts.Size = UDim2.fromOffset(520, 300)
toasts.Position = UDim2.new(0.5, 0, 0, 130)
toasts.Parent = gui
local layout = Instance.new("UIListLayout")
layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
layout.Padding = UDim.new(0, 6)
layout.Parent = toasts

function HUD.notify(text: string, color: Color3?)
	local toast = Instance.new("TextLabel")
	toast.Size = UDim2.fromOffset(500, 36)
	toast.BackgroundColor3 = Color3.fromRGB(30, 20, 40)
	toast.BackgroundTransparency = 0.2
	toast.Font = FONT
	toast.TextScaled = true
	toast.TextColor3 = color or WHITE
	toast.Text = text
	toast.Parent = toasts
	corner(toast, 8)
	task.delay(3.5, function()
		local tween = TweenService:Create(
			toast,
			TweenInfo.new(0.4),
			{ BackgroundTransparency = 1, TextTransparency = 1 }
		)
		tween:Play()
		tween.Completed:Wait()
		toast:Destroy()
	end)
end

function HUD.showMeter(visible: boolean)
	meter.Visible = visible
	fill.Size = UDim2.fromScale(0, 1)
	meterHint.Text = "HOLD to charge, RELEASE in the yellow!"
end

function HUD.setMeter(value: number, inSweetSpot: boolean)
	fill.Size = UDim2.fromScale(math.clamp(value, 0, 1), 1)
	fill.BackgroundColor3 = if inSweetSpot then Color3.fromRGB(255, 230, 60) else Color3.fromRGB(255, 80, 80)
end

function HUD.setDistance(text: string?)
	distanceLabel.Visible = text ~= nil
	distanceLabel.Text = text or ""
end

export type LaunchResult = {
	Distance: number,
	ZoneName: string,
	GooberName: string,
	Rarity: string,
	Mutation: string,
	Income: number,
	NewBest: boolean,
	SweetSpot: boolean,
	Placed: boolean,
	SoldName: string?,
	SoldValue: number?,
}

local cardToken = 0
function HUD.showResult(result: LaunchResult)
	cardToken += 1
	local token = cardToken
	cardDistance.Text = Format.studs(result.Distance) .. (if result.NewBest then "  NEW BEST!" else "")
	cardZone.Text = "Landed in the "
		.. result.ZoneName
		.. (if result.SweetSpot then "  (perfect launch!)" else "")
	cardGoober.Text = (if result.Mutation ~= "None" then result.Mutation .. " " else "") .. result.GooberName
	cardGoober.TextColor3 = Config.RarityColors[result.Rarity] or WHITE
	cardDetail.Text = result.Rarity .. "  •  " .. Format.rate(result.Income)
	if result.Placed and result.SoldName then
		cardNote.Text = "Plot full: sold " .. result.SoldName .. " for " .. Format.cash(result.SoldValue or 0)
	elseif not result.Placed then
		cardNote.Text = "Plot full: sold it for " .. Format.cash(result.SoldValue or 0)
	else
		cardNote.Text = "Added to your plot!"
	end
	card.Visible = true
	card.Size = UDim2.fromOffset(220, 100)
	TweenService
		:Create(card, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Size = UDim2.fromOffset(440, 200) })
		:Play()
	task.delay(3.5, function()
		if cardToken == token then
			card.Visible = false
		end
	end)
end

function refresh()
	local cash = (player:GetAttribute("Cash") :: number?) or 0
	local income = (player:GetAttribute("Income") :: number?) or 0
	local level = (player:GetAttribute("LaunchLevel") :: number?) or 0
	local cost = player:GetAttribute("UpgradeCost") :: number?
	local best = (player:GetAttribute("BestDistance") :: number?) or 0
	cashLabel.Text = Format.cash(cash)
	incomeLabel.Text = Format.rate(income)
	bestLabel.Text = "Best: " .. Format.studs(best)
	upgradeTitle.Text = "Launch Power Lv " .. level
	if cost then
		upgradeCost.Text = Format.cash(cost)
		upgrade.BackgroundColor3 = if cash >= cost
			then Color3.fromRGB(80, 200, 90)
			else Color3.fromRGB(255, 140, 40)
	else
		upgradeCost.Text = "MAXED"
		upgrade.BackgroundColor3 = Color3.fromRGB(150, 150, 150)
	end

	local rebirths = (player:GetAttribute("Rebirths") :: number?) or 0
	local rebirthCost = Formulas.rebirthCost(rebirths)
	local nextMultiplier = Formulas.rebirthMultiplier(rebirths + 1)
	if rebirthCost == nil then
		rebirthTitle.Text = "Rebirth " .. rebirths .. " (max)"
		rebirthDetail.Text = "x" .. Formulas.rebirthMultiplier(rebirths) .. " income"
		rebirthButton.BackgroundColor3 = Color3.fromRGB(120, 120, 130)
	elseif os.clock() < rebirthArmedUntil then
		rebirthTitle.Text = "Tap again!"
		rebirthDetail.Text = "Rebirth for x" .. nextMultiplier .. " income"
		rebirthButton.BackgroundColor3 = Color3.fromRGB(255, 80, 200)
	else
		rebirthTitle.Text = if rebirths > 0
			then "Rebirth (x" .. Formulas.rebirthMultiplier(rebirths) .. " now)"
			else "Rebirth"
		if level < Config.Rebirth.LevelRequired then
			rebirthDetail.Text = "Needs Launch Power " .. Config.Rebirth.LevelRequired
		else
			rebirthDetail.Text = Format.cash(rebirthCost) .. " for x" .. nextMultiplier .. " income"
		end
		rebirthButton.BackgroundColor3 = if Formulas.canRebirth(rebirths, level, cash)
			then Color3.fromRGB(190, 70, 230)
			else Color3.fromRGB(120, 120, 130)
	end
end

function HUD.start()
	for _, name in { "Cash", "Income", "LaunchLevel", "UpgradeCost", "BestDistance", "Rebirths" } do
		player:GetAttributeChangedSignal(name):Connect(refresh)
	end
	refresh()
	Remotes.get("Notify").OnClientEvent:Connect(function(text: string, color: Color3?)
		HUD.notify(text, color)
	end)
end

return HUD
