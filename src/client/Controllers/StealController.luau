--!strict
-- Client side of stealing:
--  * Shows each player only the prompts meant for them: Sell on your own Goobers,
--    Steal on everyone else's (and no Steal on a locked base). The server re-checks.
--  * The Lock Base button with its countdown.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Format = require(Shared.Format)
local Remotes = require(Shared.Remotes)

local player = Players.LocalPlayer

local StealController = {}

local FONT = Enum.Font.FredokaOne
local WHITE = Color3.new(1, 1, 1)

local gui = Instance.new("ScreenGui")
gui.Name = "GooberSteal"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local lockButton = Instance.new("TextButton")
lockButton.Name = "LockBase"
lockButton.Size = UDim2.fromOffset(230, 44)
lockButton.Position = UDim2.new(0, 12, 0.5, 120)
lockButton.BackgroundColor3 = Color3.fromRGB(70, 170, 230)
lockButton.Font = FONT
lockButton.TextScaled = true
lockButton.TextColor3 = WHITE
lockButton.TextStrokeTransparency = 0
lockButton.Text = "Lock Base"
lockButton.Parent = gui
local c = Instance.new("UICorner")
c.CornerRadius = UDim.new(0, 12)
c.Parent = lockButton
local s = Instance.new("UIStroke")
s.Thickness = 3
s.Color = Color3.fromRGB(30, 20, 40)
s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
s.Parent = lockButton

local function plotLocked(prompt: ProximityPrompt): boolean
	local node: Instance? = prompt
	while node and node ~= Workspace do
		if node:GetAttribute("Locked") then
			return true
		end
		node = node.Parent
	end
	return false
end

local function filter(prompt: ProximityPrompt)
	local only = prompt:GetAttribute("OnlyUserId") :: number?
	local notFor = prompt:GetAttribute("NotUserId") :: number?
	if only ~= nil then
		prompt.Enabled = only == player.UserId
	elseif notFor ~= nil then
		prompt.Enabled = notFor ~= player.UserId
			and player:GetAttribute("Carrying") == nil
			and not plotLocked(prompt)
	end
end

local tracked: { [ProximityPrompt]: boolean } = {}

local function track(prompt: ProximityPrompt)
	if tracked[prompt] then
		return
	end
	tracked[prompt] = true
	filter(prompt)
	prompt.AncestryChanged:Connect(function()
		if not prompt:IsDescendantOf(Workspace) then
			tracked[prompt] = nil
		end
	end)
end

local function refilterAll()
	for prompt in tracked do
		filter(prompt)
	end
end

local function refreshLockButton()
	local now = Workspace:GetServerTimeNow()
	local endsAt = (player:GetAttribute("LockEndsAt") :: number?) or 0
	local readyAt = (player:GetAttribute("LockReadyAt") :: number?) or 0
	if endsAt > now then
		lockButton.Text = "Locked " .. Format.duration(endsAt - now)
		lockButton.BackgroundColor3 = Color3.fromRGB(80, 200, 90)
	elseif readyAt > now then
		lockButton.Text = "Lock in " .. Format.duration(readyAt - now)
		lockButton.BackgroundColor3 = Color3.fromRGB(120, 120, 130)
	else
		lockButton.Text = "Lock Base"
		lockButton.BackgroundColor3 = Color3.fromRGB(70, 170, 230)
	end
end

function StealController.start()
	for _, d in Workspace:GetDescendants() do
		if d:IsA("ProximityPrompt") then
			track(d)
		end
	end
	Workspace.DescendantAdded:Connect(function(d)
		if d:IsA("ProximityPrompt") then
			-- Attributes replicate with the instance, but give it a frame to be safe.
			task.defer(track, d)
		end
	end)
	player:GetAttributeChangedSignal("Carrying"):Connect(refilterAll)
	lockButton.Activated:Connect(function()
		Remotes.get("LockBase"):FireServer()
	end)
	task.spawn(function()
		while true do
			-- Cheap: re-check locks and the countdown twice a second.
			refilterAll()
			refreshLockButton()
			task.wait(0.5)
		end
	end)
end

return StealController
