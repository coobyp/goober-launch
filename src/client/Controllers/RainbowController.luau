--!strict
-- Cycles the color of Rainbow-mutation Goobers. Runs on each client so the server
-- never spends a frame on cosmetics.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local GooberVisual = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GooberVisual"))

local RainbowController = {}

function RainbowController.start()
	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		local hue = (elapsed * 0.25) % 1
		for _, inst in CollectionService:GetTagged(GooberVisual.RAINBOW_TAG) do
			if inst:IsA("BasePart") then
				inst.Color = Color3.fromHSV(hue, 0.8, 1)
			end
		end
	end)
end

return RainbowController
