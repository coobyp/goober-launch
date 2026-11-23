--!strict
-- Cash, income ticks, offline earnings and Launch Power upgrades.
-- The client never sends an amount of anything; it only asks to buy the next level.
-- Values the HUD needs are mirrored onto Player attributes, which replicate for free.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Format = require(Shared.Format)
local Formulas = require(Shared.Formulas)
local Remotes = require(Shared.Remotes)

local DataService = require(script.Parent.DataService)

local EconomyService = {}

local notify = Remotes.get("Notify")
local lastPurchase: { [Player]: number } = {}

local function leaderstat(player: Player, name: string): IntValue
	local folder = player:FindFirstChild("leaderstats")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "leaderstats"
		folder.Parent = player
	end
	local value = folder:FindFirstChild(name)
	if not value then
		value = Instance.new("IntValue")
		value.Name = name
		value.Parent = folder
	end
	return value :: IntValue
end

function EconomyService.refresh(player: Player)
	local data = DataService.get(player)
	if not data then
		return
	end
	local income = Formulas.totalIncome(data.Goobers)
	player:SetAttribute("Cash", data.Cash)
	player:SetAttribute("Income", income)
	player:SetAttribute("LaunchLevel", data.LaunchLevel)
	player:SetAttribute("UpgradeCost", Formulas.upgradeCost(data.LaunchLevel))
	player:SetAttribute("BestDistance", data.BestDistance)
	player:SetAttribute("LaunchSpeed", Formulas.baseLaunchSpeed(data.LaunchLevel))
	leaderstat(player, "Cash").Value = math.floor(math.min(data.Cash, 2 ^ 53))
	leaderstat(player, "Best").Value = math.floor(data.BestDistance)
end

function EconomyService.addCash(player: Player, amount: number)
	local data = DataService.get(player)
	if not data or amount ~= amount or amount <= 0 then
		return
	end
	data.Cash += amount
end

function EconomyService.trySpend(player: Player, amount: number): boolean
	local data = DataService.get(player)
	if not data or data.Cash < amount then
		return false
	end
	data.Cash -= amount
	return true
end

local function buyLaunchPower(player: Player)
	-- Simple debounce against remote spam.
	local now = os.clock()
	if (lastPurchase[player] or 0) > now - 0.15 then
		return
	end
	lastPurchase[player] = now

	local data = DataService.get(player)
	if not data then
		return
	end
	local cost = Formulas.upgradeCost(data.LaunchLevel)
	if cost == nil then
		notify:FireClient(player, "Launch Power is maxed out!")
		return
	end
	if not EconomyService.trySpend(player, cost) then
		notify:FireClient(
			player,
			"Need " .. Format.cash(cost - data.Cash) .. " more",
			Color3.fromRGB(255, 120, 120)
		)
		return
	end
	data.LaunchLevel += 1
	EconomyService.refresh(player)
end

local function onLoaded(player: Player, data: DataService.PlayerData)
	local now = os.time()
	if data.LastOnline > 0 then
		local income = Formulas.totalIncome(data.Goobers)
		local earned, credited = Formulas.offlineEarnings(income, now - data.LastOnline)
		if earned > 0 then
			data.Cash += earned
			task.delay(3, function()
				if player.Parent then
					notify:FireClient(
						player,
						"Welcome back! Your Goobers made "
							.. Format.cash(earned)
							.. " in "
							.. Format.duration(credited)
							.. " while you were gone.",
						Color3.fromRGB(120, 255, 120)
					)
				end
			end)
		end
	end
	data.LastOnline = now
	EconomyService.refresh(player)
end

function EconomyService.start()
	DataService.onLoaded(onLoaded)
	DataService.onReleasing(function(_, data)
		data.LastOnline = os.time()
	end)
	Players.PlayerRemoving:Connect(function(player)
		lastPurchase[player] = nil
	end)
	Remotes.get("BuyLaunchPower").OnServerEvent:Connect(buyLaunchPower)

	-- Income tick. Uses real elapsed time so a slow server doesn't shortchange anyone.
	task.spawn(function()
		local last = os.clock()
		while true do
			task.wait(1)
			local now = os.clock()
			local dt = math.min(now - last, 5)
			last = now
			local stamp = os.time()
			for _, player in Players:GetPlayers() do
				local data = DataService.get(player)
				if data then
					local income = Formulas.totalIncome(data.Goobers)
					if income > 0 then
						data.Cash += income * dt
					end
					data.LastOnline = stamp
					EconomyService.refresh(player)
				end
			end
		end
	end)
end

-- Unused but handy in the command bar: give yourself cash while tuning.
function EconomyService.debugGive(player: Player, amount: number)
	EconomyService.addCash(player, amount)
	EconomyService.refresh(player)
end

return EconomyService
