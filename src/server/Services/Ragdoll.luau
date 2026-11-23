--!strict
-- Server-side R15 ragdoll. Swaps every Motor6D (except the root joint) for a
-- BallSocketConstraint, then swaps back. The launch service takes network ownership
-- before calling this, so the server simulates the whole flight.

local Ragdoll = {}

local SOCKET_NAME = "RagdollSocket"
local ATTACH_NAME = "RagdollAttachment"
local COLLIDE_ATTR = "RagdollOriginalCanCollide"

-- Joint limits per joint name. Loose enough to flail, tight enough to not look broken.
local LIMITS: { [string]: { upper: number, twist: number } } = {
	Neck = { upper = 35, twist = 30 },
	Waist = { upper = 25, twist = 20 },
	LeftShoulder = { upper = 90, twist = 60 },
	RightShoulder = { upper = 90, twist = 60 },
	LeftElbow = { upper = 80, twist = 5 },
	RightElbow = { upper = 80, twist = 5 },
	LeftHip = { upper = 60, twist = 30 },
	RightHip = { upper = 60, twist = 30 },
	LeftKnee = { upper = 80, twist = 5 },
	RightKnee = { upper = 80, twist = 5 },
}
local DEFAULT_LIMIT = { upper = 30, twist = 10 }

function Ragdoll.isRagdolled(character: Model): boolean
	return character:GetAttribute("Ragdolled") == true
end

function Ragdoll.enable(character: Model)
	if Ragdoll.isRagdolled(character) then
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	character:SetAttribute("Ragdolled", true)

	humanoid.BreakJointsOnDeath = false
	humanoid.RequiresNeck = false
	humanoid.AutoRotate = false

	for _, motor in character:GetDescendants() do
		if motor:IsA("Motor6D") and motor.Name ~= "Root" and motor.Part0 and motor.Part1 then
			local a0 = Instance.new("Attachment")
			a0.Name = ATTACH_NAME
			a0.CFrame = motor.C0
			a0.Parent = motor.Part0

			local a1 = Instance.new("Attachment")
			a1.Name = ATTACH_NAME
			a1.CFrame = motor.C1
			a1.Parent = motor.Part1

			local limit = LIMITS[motor.Name] or DEFAULT_LIMIT
			local socket = Instance.new("BallSocketConstraint")
			socket.Name = SOCKET_NAME
			socket.Attachment0 = a0
			socket.Attachment1 = a1
			socket.LimitsEnabled = true
			socket.UpperAngle = limit.upper
			socket.TwistLimitsEnabled = true
			socket.TwistLowerAngle = -limit.twist
			socket.TwistUpperAngle = limit.twist
			socket.Parent = motor.Part1

			motor.Enabled = false
		end
	end

	for _, p in character:GetDescendants() do
		if p:IsA("BasePart") and p.Name ~= "HumanoidRootPart" and p.Parent == character then
			p:SetAttribute(COLLIDE_ATTR, p.CanCollide)
			p.CanCollide = true
		end
	end

	humanoid:ChangeState(Enum.HumanoidStateType.Physics)
end

function Ragdoll.disable(character: Model)
	if not Ragdoll.isRagdolled(character) then
		return
	end
	character:SetAttribute("Ragdolled", nil)

	for _, d in character:GetDescendants() do
		if
			(d:IsA("BallSocketConstraint") and d.Name == SOCKET_NAME)
			or (d:IsA("Attachment") and d.Name == ATTACH_NAME)
		then
			d:Destroy()
		elseif d:IsA("Motor6D") then
			d.Enabled = true
		elseif d:IsA("BasePart") then
			local original = d:GetAttribute(COLLIDE_ATTR)
			if original ~= nil then
				d.CanCollide = original :: boolean
				d:SetAttribute(COLLIDE_ATTR, nil)
			end
		end
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.AutoRotate = true
		humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
	end
end

return Ragdoll
