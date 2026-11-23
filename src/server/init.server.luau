--!strict
-- Server entry point. Order matters: the map and remotes exist before anyone can act.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes")) -- creates the RemoteEvents

local Services = script:WaitForChild("Services")
local MapBuilder = require(Services.MapBuilder)
local DataService = require(Services.DataService)
local EconomyService = require(Services.EconomyService)
local PlotService = require(Services.PlotService)
local LaunchService = require(Services.LaunchService)

local map = MapBuilder.build()
PlotService.start(map)
EconomyService.start()
LaunchService.start()
DataService.start() -- last, so every onLoaded hook is registered before profiles load
