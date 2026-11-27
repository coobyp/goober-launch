--!strict
-- Studio-only test hooks, so playtests (and agents driving Studio over MCP) can jump
-- ahead without grinding. Never created in a live server.
--
-- From the Studio command bar or execute_luau on the server:
--   game.ServerStorage.DevCommands:Invoke("cash", 1e6)
--   game.ServerStorage.DevCommands:Invoke("level", 20)
--   game.ServerStorage.DevCommands:Invoke("launch", 0.92) -- 0.92 = perfect
--   game.ServerStorage.DevCommands:Invoke("pass", "DoubleCash") -- "-DoubleCash" removes it
--   game.ServerStorage.DevCommands:Invoke("state")
-- Commands act on the first player in the server.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local LaunchService = require(script.Parent.LaunchService)
local MonetizationService = require(script.Parent.MonetizationService)

local DevCommands = {}

local handlers: { [string]: (Player, DataService.PlayerData, any) -> any } = {
	cash = function(player, data, amount)
		data.Cash += tonumber(amount) or 0
		EconomyService.refresh(player)
		return data.Cash
	end,
	level = function(player, data, level)
		data.LaunchLevel = math.clamp(tonumber(level) or 0, 0, Config.Upgrades.MaxLaunchLevel)
		EconomyService.refresh(player)
		return data.LaunchLevel
	end,
	-- Fires a launch at the given 0..1 charge (0.92 is a perfect one) and returns at once.
	launch = function(player, _, charge)
		task.spawn(LaunchService.devLaunch, player, tonumber(charge) or 0.92)
		return "launched"
	end,
	-- Pretend to own (or not own) a pass: pass = "DoubleCash" | "Lucky" | "SuperCannon".
	pass = function(player, _, key)
		local on = string.sub(key, 1, 1) ~= "-"
		local name = if on then key else string.sub(key, 2)
		MonetizationService.setOwned(player, name, on)
		return name .. (if on then " on" else " off")
	end,
	state = function(_, data)
		local goobers = {}
		for _, g in data.Goobers do
			table.insert(goobers, g.Id .. "/" .. g.Mutation)
		end
		return string.format(
			"cash=%d level=%d best=%d launches=%d goobers=[%s]",
			data.Cash,
			data.LaunchLevel,
			data.BestDistance,
			data.TotalLaunches,
			table.concat(goobers, ", ")
		)
	end,
}

function DevCommands.start()
	if not RunService:IsStudio() then
		return
	end
	local fn = Instance.new("BindableFunction")
	fn.Name = "DevCommands"
	fn.OnInvoke = function(command: string, arg: any): any
		local player = Players:GetPlayers()[1]
		local data = player and DataService.get(player)
		local handler = handlers[command]
		if not data or not handler then
			return "no player data or unknown command"
		end
		return handler(player, data, arg)
	end
	fn.Parent = ServerStorage
end

return DevCommands
