--!strict
-- Client entry point.

local Controllers = script:WaitForChild("Controllers")

local HUD = require(Controllers.HUD)
local CannonController = require(Controllers.CannonController)
local RainbowController = require(Controllers.RainbowController)

HUD.start()
CannonController.start()
RainbowController.start()
