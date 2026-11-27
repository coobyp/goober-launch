--!strict
-- Client entry point.

local Controllers = script:WaitForChild("Controllers")

local HUD = require(Controllers.HUD)
local CannonController = require(Controllers.CannonController)
local RainbowController = require(Controllers.RainbowController)
local IndexController = require(Controllers.IndexController)

HUD.start()
CannonController.start()
RainbowController.start()
IndexController.start()
