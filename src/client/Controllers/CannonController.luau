--!strict
-- Client side of a launch: the hold-to-charge meter, the cannon camera, and the live
-- distance readout. The only thing it sends the server is the final 0..1 charge.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Format = require(Shared.Format)
local Formulas = require(Shared.Formulas)
local Remotes = require(Shared.Remotes)

local HUD = require(script.Parent.HUD)

local player = Players.LocalPlayer

local CannonController = {}

local ACTION = "GooberCharge"

local charging = false
local holding = false
local holdTime = 0
local meterValue = 0
local flying = false
local flightOrigin: Vector3? = nil

local pad = Instance.new("ScreenGui")
pad.Name = "ChargePad"
pad.ResetOnSpawn = false
pad.DisplayOrder = 10
pad.Enabled = false
pad.Parent = player:WaitForChild("PlayerGui")
local padButton = Instance.new("TextButton")
padButton.Size = UDim2.fromScale(1, 1)
padButton.BackgroundTransparency = 1
padButton.Text = ""
padButton.Parent = pad

local function pingPong(t: number): number
	local cycle = Config.Cannon.MeterCycleSeconds
	local phase = (t / cycle) % 2
	return if phase <= 1 then phase else 2 - phase
end

local function restoreCamera()
	local camera = Workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Custom
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		camera.CameraSubject = humanoid
	end
end

local function stopCharging()
	charging = false
	holding = false
	pad.Enabled = false
	HUD.showMeter(false)
	ContextActionService:UnbindAction(ACTION)
end

local function release()
	if not charging or not holding then
		return
	end
	local value = meterValue
	stopCharging()
	Remotes.get("Launch"):FireServer(value)
end

local function press()
	if not charging or holding then
		return
	end
	holding = true
	holdTime = 0
end

local function onAction(_: string, state: Enum.UserInputState): Enum.ContextActionResult
	if state == Enum.UserInputState.Begin then
		press()
	elseif state == Enum.UserInputState.End then
		release()
	end
	return Enum.ContextActionResult.Sink
end

local function beginCharge(muzzle: CFrame)
	charging = true
	holding = false
	meterValue = 0
	pad.Enabled = true
	HUD.showMeter(true)
	-- Space / gamepad buttons charge too; sinking them also stops the jump.
	ContextActionService:BindActionAtPriority(
		ACTION,
		onAction,
		false,
		Enum.ContextActionPriority.High.Value,
		Enum.KeyCode.Space,
		Enum.KeyCode.ButtonA,
		Enum.KeyCode.ButtonR2
	)

	-- Over-the-shoulder view down the barrel.
	local camera = Workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Scriptable
	local flat = Vector3.new(muzzle.LookVector.X, 0, muzzle.LookVector.Z).Unit
	local eye = muzzle.Position - flat * 22 + Vector3.new(0, 10, 0)
	camera.CFrame = CFrame.lookAt(eye, muzzle.Position + flat * 60 + Vector3.new(0, 15, 0))
end

local function onLaunched(origin: Vector3, _speed: number, sweetSpot: boolean)
	flying = true
	flightOrigin = origin
	restoreCamera()
	if sweetSpot then
		HUD.notify("PERFECT LAUNCH!", Color3.fromRGB(255, 230, 60))
	end
end

local function onResult(result: any)
	flying = false
	flightOrigin = nil
	HUD.setDistance(Format.studs(result.Distance))
	HUD.showResult(result)
	task.delay(3, function()
		if not flying then
			HUD.setDistance(nil)
		end
	end)
end

function CannonController.start()
	Remotes.get("BeginCharge").OnClientEvent:Connect(beginCharge)
	Remotes.get("Launched").OnClientEvent:Connect(onLaunched)
	Remotes.get("LaunchResult").OnClientEvent:Connect(onResult)
	Remotes.get("ChargeCancelled").OnClientEvent:Connect(function()
		stopCharging()
		restoreCamera()
		HUD.notify("Cannon timed out. Hop back in!")
	end)

	padButton.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			press()
		end
	end)
	padButton.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			release()
		end
	end)

	player.CharacterAdded:Connect(function()
		stopCharging()
		flying = false
		flightOrigin = nil
		HUD.setDistance(nil)
		restoreCamera()
	end)

	RunService.RenderStepped:Connect(function(dt)
		if charging and holding then
			holdTime += dt
			meterValue = pingPong(holdTime)
			HUD.setMeter(meterValue, Formulas.isSweetSpot(meterValue))
		end
		if flying and flightOrigin then
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if root then
				local d = root.Position - flightOrigin
				HUD.setDistance(Format.studs(Vector3.new(d.X, 0, d.Z).Magnitude))
			end
		end
	end)
end

return CannonController
