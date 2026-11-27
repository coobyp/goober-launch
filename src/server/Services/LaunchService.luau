--!strict
-- The core loop: get in the cannon, charge, launch, fly as a ragdoll, land, open a crate.
-- Server-authoritative: the server takes network ownership of the character for the
-- flight, so it simulates the physics and measures the distance itself. The client
-- only sends a 0..1 charge value, which is clamped.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Formulas = require(Shared.Formulas)
local GooberDefs = require(Shared.GooberDefs)
local GooberVisual = require(Shared.GooberVisual)
local Remotes = require(Shared.Remotes)
local Rolls = require(Shared.Rolls)

local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local MonetizationService = require(script.Parent.MonetizationService)
local PlotService = require(script.Parent.PlotService)
local Ragdoll = require(script.Parent.Ragdoll)
local StealService = require(script.Parent.StealService)

type Phase = "Idle" | "Charging" | "Flying"
type State = { Phase: Phase, Token: number }

local LaunchService = {}

local states: { [Player]: State } = {}
local rng = Random.new()
local function roll(): number
	return rng:NextNumber()
end

local remotes = {
	BeginCharge = Remotes.get("BeginCharge"),
	Launch = Remotes.get("Launch"),
	Launched = Remotes.get("Launched"),
	LaunchResult = Remotes.get("LaunchResult"),
	ChargeCancelled = Remotes.get("ChargeCancelled"),
	Notify = Remotes.get("Notify"),
}

local function getState(player: Player): State
	local state = states[player]
	if not state then
		state = { Phase = "Idle", Token = 0 }
		states[player] = state
	end
	return state
end

local function getRig(player: Player): (Model?, Humanoid?, BasePart?)
	local character = player.Character
	if not character then
		return nil, nil, nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not humanoid or not root or humanoid.Health <= 0 then
		return nil, nil, nil
	end
	return character, humanoid, root
end

local function setOwner(character: Model, owner: Player?)
	for _, p in character:GetDescendants() do
		if p:IsA("BasePart") and not p.Anchored then
			pcall(function()
				p:SetNetworkOwner(owner)
			end)
		end
	end
end

local function resetToIdle(player: Player)
	local state = getState(player)
	state.Phase = "Idle"
	state.Token += 1
	local character = player.Character
	if character then
		local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root then
			root.Anchored = false
		end
		Ragdoll.disable(character)
		setOwner(character, player)
	end
end

local function onCannon(player: Player, plot: PlotService.Plot)
	if plot.Owner ~= player then
		remotes.Notify:FireClient(player, "That's someone else's cannon. Yours is on your plot!")
		return
	end
	if StealService.isCarrying(player) then
		remotes.Notify:FireClient(player, "Get that Goober home first!")
		return
	end
	local state = getState(player)
	if state.Phase ~= "Idle" or not DataService.get(player) then
		return
	end
	local character, _, root = getRig(player)
	if not character or not root then
		return
	end

	state.Phase = "Charging"
	state.Token += 1
	local token = state.Token

	-- Stand on the barrel tip, facing the field.
	local muzzle = plot.Muzzle
	local flat = Vector3.new(muzzle.LookVector.X, 0, muzzle.LookVector.Z).Unit
	local standAt = muzzle.Position + Vector3.new(0, 3, 0)
	root.Anchored = true
	character:PivotTo(CFrame.lookAt(standAt, standAt + flat))

	remotes.BeginCharge:FireClient(player, muzzle)

	task.delay(Config.Cannon.ChargeTimeoutSeconds, function()
		if state.Token == token and state.Phase == "Charging" then
			resetToIdle(player)
			remotes.ChargeCancelled:FireClient(player)
		end
	end)
end

local function groundBelow(position: Vector3, ignore: { Instance }): Vector3
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	local hit = Workspace:Raycast(position + Vector3.new(0, 5, 0), Vector3.new(0, -60, 0), params)
	return if hit then hit.Position else Vector3.new(position.X, 0, position.Z)
end

-- A crate drops where you landed, pops, and shows off what was inside for a moment.
local function crateReveal(at: Vector3, gooberId: string, mutation: string, ignore: { Instance })
	local ground = groundBelow(at, ignore)
	local crate = Instance.new("Part")
	crate.Name = "GooberCrate"
	crate.Anchored = true
	crate.CanCollide = false
	crate.Size = Vector3.new(5, 5, 5)
	crate.Color = Color3.fromRGB(170, 110, 60)
	crate.Material = Enum.Material.WoodPlanks
	crate.CFrame = CFrame.new(ground + Vector3.new(4, 2.5, 4))
	crate.Parent = Workspace

	task.delay(0.8, function()
		local explosion = Instance.new("Explosion")
		explosion.BlastPressure = 0
		explosion.BlastRadius = 0
		explosion.DestroyJointRadiusPercent = 0
		explosion.Position = crate.Position
		explosion.Parent = Workspace
		local goober = GooberVisual.build(gooberId, mutation, true)
		goober:PivotTo(CFrame.new(crate.Position - Vector3.new(0, 2.5, 0)) * CFrame.Angles(0, math.pi, 0))
		goober.Parent = Workspace
		crate:Destroy()
		task.delay(3, function()
			goober:Destroy()
		end)
	end)
end

local function finishFlight(
	player: Player,
	token: number,
	plot: PlotService.Plot,
	speed: number,
	sweetSpot: boolean
)
	local state = getState(player)
	if state.Token ~= token then
		return
	end
	local character, _, root = getRig(player)
	local data = DataService.get(player)
	if not character or not root or not data then
		resetToIdle(player)
		return
	end

	local origin = plot.Muzzle.Position
	local delta = root.Position - origin
	local distance = Vector3.new(delta.X, 0, delta.Z).Magnitude
	distance = math.min(distance, Formulas.maxPlausibleDistance(speed))

	local result = Rolls.rollGoober(distance, roll, MonetizationService.luck(player))
	data.TotalLaunches += 1
	local newBest = distance > data.BestDistance
	if newBest then
		data.BestDistance = distance
	end

	local newDiscovery = not data.Discovered[result.Id]
	crateReveal(root.Position, result.Id, result.Mutation, { character })
	local outcome = PlotService.grantGoober(player, result.Id, result.Mutation)
	EconomyService.refresh(player)

	local def = GooberDefs.ById[result.Id]
	remotes.LaunchResult:FireClient(player, {
		Distance = distance,
		ZoneIndex = result.ZoneIndex,
		ZoneName = Config.Zones[result.ZoneIndex].Name,
		GooberId = result.Id,
		GooberName = if def then def.Name else result.Id,
		Rarity = result.Rarity,
		Mutation = result.Mutation,
		Income = Formulas.gooberIncome(result.Id, result.Mutation),
		NewBest = newBest,
		NewDiscovery = newDiscovery,
		SweetSpot = sweetSpot,
		Placed = outcome.Placed,
		SoldName = if outcome.SoldId and GooberDefs.ById[outcome.SoldId]
			then GooberDefs.ById[outcome.SoldId].Name
			else nil,
		SoldValue = outcome.SoldValue,
	})

	task.delay(Config.Flight.ResultHoldSeconds, function()
		if state.Token ~= token then
			return
		end
		resetToIdle(player)
		PlotService.sendHome(player)
	end)
end

local function watchFlight(
	player: Player,
	token: number,
	plot: PlotService.Plot,
	speed: number,
	sweetSpot: boolean
)
	local state = getState(player)
	local started = os.clock()
	local restingFor = 0
	local grounded = false
	local step = 0.1
	local groundParams = RaycastParams.new()
	groundParams.FilterType = Enum.RaycastFilterType.Exclude
	while state.Token == token do
		task.wait(step)
		if player.Parent == nil then
			return
		end
		local character, _, root = getRig(player)
		if not character or not root then
			resetToIdle(player)
			return
		end
		local elapsed = os.clock() - started
		-- Once the ragdoll hits the ground, bleed off its horizontal speed so it tumbles
		-- to a stop instead of skating. Without this, ground sliding adds ~70% to the
		-- distance and makes Launch Power matter less than it should.
		if not grounded and elapsed > Config.Flight.MinFlightSeconds then
			groundParams.FilterDescendantsInstances = { character }
			grounded = Workspace:Raycast(
				root.Position,
				Vector3.new(0, -Config.Flight.GroundCheckStuds, 0),
				groundParams
			) ~= nil
		end
		if grounded then
			local keep = Config.Flight.GroundSpeedKeptPerStep
			for _, part in character:GetDescendants() do
				if part:IsA("BasePart") then
					local v = part.AssemblyLinearVelocity
					part.AssemblyLinearVelocity = Vector3.new(v.X * keep, v.Y, v.Z * keep)
				end
			end
		end
		if elapsed > Config.Flight.MinFlightSeconds then
			if root.AssemblyLinearVelocity.Magnitude < Config.Flight.RestSpeed then
				restingFor += step
			else
				restingFor = 0
			end
		end
		if
			restingFor >= Config.Flight.RestSeconds
			or elapsed > Config.Flight.MaxFlightSeconds
			or root.Position.Y < -40
		then
			finishFlight(player, token, plot, speed, sweetSpot)
			return
		end
	end
end

local function onLaunch(player: Player, charge: unknown)
	local state = getState(player)
	if state.Phase ~= "Charging" then
		return
	end
	-- Never trust the client: must be a finite number, clamped to 0..1.
	if typeof(charge) ~= "number" or charge ~= charge or math.abs(charge) == math.huge then
		return
	end
	local c = math.clamp(charge, 0, 1)

	local plot = PlotService.getPlot(player)
	local data = DataService.get(player)
	local character, _, root = getRig(player)
	if not plot or not data or not character or not root then
		resetToIdle(player)
		return
	end

	state.Phase = "Flying"
	state.Token += 1
	local token = state.Token

	local speed = Formulas.launchSpeed(data.LaunchLevel, c, MonetizationService.launchMultiplier(player))
	local sweetSpot = Formulas.isSweetSpot(c)
	local velocity = plot.Muzzle.LookVector * speed

	Ragdoll.enable(character)
	root.Anchored = false
	setOwner(character, nil)

	local spin = Config.Cannon.SpinStrength
	for _, p in character:GetDescendants() do
		if p:IsA("BasePart") then
			p.AssemblyLinearVelocity = velocity
		end
	end
	local torso = character:FindFirstChild("UpperTorso") :: BasePart?
	if torso then
		torso.AssemblyAngularVelocity =
			Vector3.new(rng:NextNumber(-spin, spin), rng:NextNumber(-spin, spin), rng:NextNumber(-spin, spin))
	end

	remotes.Launched:FireClient(player, plot.Muzzle.Position, speed, sweetSpot)
	task.spawn(watchFlight, player, token, plot, speed, sweetSpot)
end

-- Studio test hook (see DevCommands): climb into your own cannon and fire at `charge`,
-- running the exact same server path as a real player.
function LaunchService.devLaunch(player: Player, charge: number)
	local plot = PlotService.getPlot(player)
	if not plot then
		return
	end
	onCannon(player, plot)
	task.wait(0.2)
	onLaunch(player, charge)
end

function LaunchService.start()
	PlotService.setCannonHandler(onCannon)
	EconomyService.setRebirthGate(function(player)
		return getState(player).Phase == "Idle"
	end)
	remotes.Launch.OnServerEvent:Connect(onLaunch)

	local function hook(player: Player)
		player.CharacterAdded:Connect(function(character)
			local humanoid = character:WaitForChild("Humanoid") :: Humanoid
			humanoid.BreakJointsOnDeath = false
			local state = getState(player)
			state.Phase = "Idle"
			state.Token += 1
		end)
	end
	for _, player in Players:GetPlayers() do
		hook(player)
	end
	Players.PlayerAdded:Connect(hook)
	Players.PlayerRemoving:Connect(function(player)
		states[player] = nil
	end)
end

return LaunchService
