--!strict
-- Stealing. Hold Steal on another player's Goober, and it rides on your head while
-- you walk it home (slowly). Reach your own plot and it's yours. The owner gets it
-- back by tagging you, and it also goes back if you take too long, die, or leave.
--
-- The Goober stays in the owner's save the whole time it's being carried, and only
-- moves when the thief makes it home, so a crash or a leave can never lose it.
-- Owners can Lock Base for a while (Config.Steal) to stop steals on their plot.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Format = require(Shared.Format)
local GooberDefs = require(Shared.GooberDefs)
local GooberVisual = require(Shared.GooberVisual)
local Remotes = require(Shared.Remotes)

local PlotService = require(script.Parent.PlotService)

local StealService = {}

type Carry = {
	Victim: Player,
	Plot: PlotService.Plot,
	Slot: number,
	Id: string,
	Mutation: string,
	Model: Model,
	Started: number,
	OldSpeed: number,
	LastPosition: Vector3,
}

local notify = Remotes.get("Notify")
local carrying: { [Player]: Carry } = {}
local beingStolen: { [PlotService.Plot]: { [number]: Player } } = {}
local lastAttempt: { [Player]: number } = {}
local lockedUntil: { [PlotService.Plot]: number } = {}
local lockReadyAt: { [Player]: number } = {}

local RED = Color3.fromRGB(255, 110, 110)
local GREEN = Color3.fromRGB(120, 255, 120)

local function gooberName(id: string, mutation: string): string
	local def = GooberDefs.ById[id]
	local name = if def then def.Name else id
	return if mutation ~= "None" then mutation .. " " .. name else name
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

function StealService.isCarrying(player: Player): boolean
	return carrying[player] ~= nil
end

function StealService.isLocked(plot: PlotService.Plot): boolean
	return (lockedUntil[plot] or 0) > os.clock()
end

local function attachToHead(player: Player, id: string, mutation: string): Model?
	local character = player.Character
	local head = character and character:FindFirstChild("Head") :: BasePart?
	if not head then
		return nil
	end
	local model = GooberVisual.build(id, mutation, true)
	model.Name = "CarriedGoober"
	local _, size = model:GetBoundingBox()
	model:PivotTo(head.CFrame * CFrame.new(0, head.Size.Y / 2 + size.Y / 2 + 0.5, 0))
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = false
			part.CanCollide = false
			part.Massless = true
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = head
			weld.Part1 = part
			weld.Parent = part
		end
	end
	model.Parent = character
	return model
end

local function finish(thief: Player, success: boolean, reason: string?)
	local carry = carrying[thief]
	if not carry then
		return
	end
	carrying[thief] = nil
	local stolenSlots = beingStolen[carry.Plot]
	if stolenSlots then
		stolenSlots[carry.Slot] = nil
	end
	carry.Model:Destroy()
	thief:SetAttribute("Carrying", nil)
	local character = thief.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = carry.OldSpeed
	end

	local name = gooberName(carry.Id, carry.Mutation)
	local victimStillHere = carry.Victim.Parent == Players and carry.Plot.Owner == carry.Victim
	if success and victimStillHere then
		local entry = PlotService.removeGoober(carry.Plot, carry.Slot, carry.Id)
		if entry then
			local outcome = PlotService.grantGoober(thief, entry.Id, entry.Mutation)
			notify:FireClient(
				thief,
				"You stole " .. name .. "!" .. (if outcome.Placed then "" else " (plot full, sold it)"),
				GREEN
			)
			notify:FireClient(carry.Victim, thief.DisplayName .. " stole your " .. name .. "!", RED)
			return
		end
	end
	-- Anything else: it goes home.
	if victimStillHere then
		PlotService.showSlot(carry.Plot, carry.Slot)
		if reason then
			notify:FireClient(carry.Victim, name .. " is back on your plot (" .. reason .. ")", GREEN)
		end
	end
	if reason and thief.Parent == Players then
		notify:FireClient(thief, "You lost " .. name .. " (" .. reason .. ")", RED)
	end
end

local function onSteal(thief: Player, plot: PlotService.Plot, slot: number)
	local victim = plot.Owner
	if not victim or victim == thief or carrying[thief] then
		return
	end
	if StealService.isLocked(plot) then
		notify:FireClient(thief, victim.DisplayName .. "'s base is locked!", RED)
		return
	end
	local now = os.clock()
	local remaining = (lastAttempt[thief] or -math.huge) + Config.Steal.CooldownSeconds - now
	if remaining > 0 then
		notify:FireClient(thief, "Catch your breath: " .. math.ceil(remaining) .. "s", RED)
		return
	end
	if beingStolen[plot] and beingStolen[plot][slot] then
		return
	end
	local entry = PlotService.gooberAt(plot, slot)
	local root = rootOf(thief)
	local humanoid = thief.Character and thief.Character:FindFirstChildOfClass("Humanoid")
	if not entry or not root or not humanoid or humanoid.Health <= 0 then
		return
	end
	-- Server-side reach check: you have to actually be at the pedestal.
	if (root.Position - plot.Slots[slot].Position).Magnitude > 14 then
		return
	end

	local model = attachToHead(thief, entry.Id, entry.Mutation)
	if not model then
		return
	end
	lastAttempt[thief] = now
	beingStolen[plot] = beingStolen[plot] or {}
	beingStolen[plot][slot] = thief
	PlotService.hideSlot(plot, slot)

	carrying[thief] = {
		Victim = victim,
		Plot = plot,
		Slot = slot,
		Id = entry.Id,
		Mutation = entry.Mutation,
		Model = model,
		Started = now,
		OldSpeed = humanoid.WalkSpeed,
		LastPosition = root.Position,
	}
	humanoid.WalkSpeed = Config.Steal.CarrySpeed
	thief:SetAttribute("Carrying", entry.Id)

	local name = gooberName(entry.Id, entry.Mutation)
	notify:FireClient(thief, "Got " .. name .. "! Run it back to your plot!", GREEN)
	notify:FireClient(victim, thief.DisplayName .. " is stealing your " .. name .. "! Tag them!", RED)
end

local TICK = 0.2

local function flatDistance(a: Vector3, b: Vector3): number
	return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude
end

local function tick()
	local now = os.clock()
	-- Flat ground distance a carrier can cover in one tick, with generous slack for lag.
	-- Anything more is a teleport (exploit or otherwise) and the Goober goes home.
	local maxStep = Config.Steal.CarrySpeed * TICK * 3 + 6
	for thief, carry in carrying do
		local root = rootOf(thief)
		local humanoid = thief.Character and thief.Character:FindFirstChildOfClass("Humanoid")
		if thief.Parent ~= Players or not root or not humanoid or humanoid.Health <= 0 then
			finish(thief, false, "the thief went down")
		elseif carry.Victim.Parent ~= Players or carry.Plot.Owner ~= carry.Victim then
			finish(thief, false, nil)
		elseif now - carry.Started > Config.Steal.TimeoutSeconds then
			finish(thief, false, "took too long")
		elseif flatDistance(root.Position, carry.LastPosition) > maxStep then
			finish(thief, false, "moved too fast")
		else
			carry.LastPosition = root.Position
			local victimRoot = rootOf(carry.Victim)
			local home = PlotService.getPlot(thief)
			if victimRoot and (victimRoot.Position - root.Position).Magnitude <= Config.Steal.TagDistance then
				finish(thief, false, "tagged by " .. carry.Victim.DisplayName)
			elseif home and PlotService.contains(home, root.Position) then
				finish(thief, true, nil)
			end
		end
	end
	for plot, untilTime in lockedUntil do
		-- Also clear it if the owner left, so the next owner starts unlocked.
		if untilTime <= now or plot.Owner == nil then
			lockedUntil[plot] = nil
			plot.Model:SetAttribute("Locked", nil)
			local barrier = plot.Model:FindFirstChild("LockBarrier")
			if barrier then
				barrier:Destroy()
			end
		end
	end
end

local function onLockBase(player: Player)
	local plot = PlotService.getPlot(player)
	if not plot then
		return
	end
	local now = os.clock()
	local ready = lockReadyAt[player] or 0
	if now < ready then
		notify:FireClient(player, "Lock recharging: " .. Format.duration(ready - now), RED)
		return
	end
	lockReadyAt[player] = now + Config.Steal.LockCooldownSeconds
	lockedUntil[plot] = now + Config.Steal.LockSeconds
	plot.Model:SetAttribute("Locked", true)
	-- Server time, so clients can count down with workspace:GetServerTimeNow().
	player:SetAttribute("LockEndsAt", workspace:GetServerTimeNow() + Config.Steal.LockSeconds)
	player:SetAttribute("LockReadyAt", workspace:GetServerTimeNow() + Config.Steal.LockCooldownSeconds)

	-- See-through dome so everyone can tell the plot is protected.
	local barrier = Instance.new("Part")
	barrier.Name = "LockBarrier"
	barrier.Shape = Enum.PartType.Cylinder
	barrier.Size = Vector3.new(30, 110, 110)
	barrier.CFrame = plot.Origin * CFrame.Angles(0, 0, math.rad(90))
	barrier.Anchored = true
	barrier.CanCollide = false
	barrier.CanQuery = false
	barrier.CanTouch = false
	barrier.Material = Enum.Material.ForceField
	barrier.Color = Color3.fromRGB(120, 200, 255)
	barrier.Transparency = 0.3
	barrier.Parent = plot.Model

	notify:FireClient(player, "Base locked for " .. Config.Steal.LockSeconds .. "s!", GREEN)
	-- Anyone already carrying one of your Goobers keeps running: locking stops new steals.
end

function StealService.start()
	PlotService.setStealHandler(onSteal)
	Remotes.get("LockBase").OnServerEvent:Connect(onLockBase)
	Players.PlayerRemoving:Connect(function(player)
		finish(player, false, nil)
		for thief, carry in carrying do
			if carry.Victim == player then
				finish(thief, false, nil)
			end
		end
		lastAttempt[player] = nil
		lockReadyAt[player] = nil
	end)
	task.spawn(function()
		while true do
			task.wait(TICK)
			tick()
		end
	end)
end

return StealService
