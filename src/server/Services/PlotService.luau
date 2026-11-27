--!strict
-- Plots: one per player, 8 pedestals, one cannon. Assigns plots on join, renders
-- owned Goobers on pedestals, and handles placing and selling them.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Format = require(Shared.Format)
local Formulas = require(Shared.Formulas)
local GooberDefs = require(Shared.GooberDefs)
local GooberVisual = require(Shared.GooberVisual)
local Remotes = require(Shared.Remotes)

local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)

export type Plot = {
	Index: number,
	Model: Model,
	Owner: Player?,
	Origin: CFrame,
	Home: CFrame, -- where the owner gets teleported back to
	Muzzle: CFrame, -- position = barrel tip, LookVector = launch direction
	Slots: { CFrame },
	Rendered: { [number]: Model },
	OwnerLabel: TextLabel,
}

local PLOT_SPACING = 100
local PLOT_SIZE = Vector3.new(80, 1, 70)
local PLOT_CENTER_Z = -65
local SLOT_X = { -27, -9, 9, 27 }
local SLOT_Z = { -14, 12 }

local PlotService = {}

local plots: { Plot } = {}
local plotByPlayer: { [Player]: Plot } = {}
local cannonHandler: ((Player, Plot) -> ())? = nil
local stealHandler: ((Player, Plot, number) -> ())? = nil

local notify = Remotes.get("Notify")

local function makePart(name: string, size: Vector3, cf: CFrame, color: Color3, parent: Instance): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function buildCannon(plot: Plot, origin: CFrame, parent: Instance)
	local pitch = math.rad(Config.Cannon.PitchDegrees)
	local pivot = (origin * CFrame.new(0, 4, PLOT_SIZE.Z / 2 + 15)).Position
	local direction = Vector3.new(0, math.sin(pitch), math.cos(pitch))
	local barrelLength = 12

	local cannon = Instance.new("Model")
	cannon.Name = "Cannon"
	cannon.Parent = parent

	local base = makePart(
		"Base",
		Vector3.new(8, 4, 8),
		CFrame.new(pivot - Vector3.new(0, 2, 0)),
		Color3.fromRGB(70, 70, 80),
		cannon
	)
	base.Material = Enum.Material.Metal

	local barrelCF = CFrame.lookAt(pivot + direction * (barrelLength / 2), pivot + direction * barrelLength)
		* CFrame.Angles(0, math.rad(90), 0)
	local barrel =
		makePart("Barrel", Vector3.new(barrelLength, 4, 4), barrelCF, Color3.fromRGB(230, 80, 60), cannon)
	barrel.Shape = Enum.PartType.Cylinder
	barrel.Material = Enum.Material.Metal

	local muzzlePos = pivot + direction * barrelLength
	plot.Muzzle = CFrame.lookAt(muzzlePos, muzzlePos + direction)

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "LaunchPrompt"
	prompt.ActionText = "Get in!"
	prompt.ObjectText = "Goober Cannon"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.Parent = base
	prompt.Triggered:Connect(function(player)
		if cannonHandler then
			cannonHandler(player, plot)
		end
	end)
end

local function buildPlot(index: number, x: number, parent: Instance): Plot
	local origin = CFrame.new(x, 0, PLOT_CENTER_Z)
	local model = Instance.new("Model")
	model.Name = "Plot" .. index
	model.Parent = parent

	local floor =
		makePart("Floor", PLOT_SIZE, origin * CFrame.new(0, 0.5, 0), Color3.fromRGB(230, 220, 190), model)
	floor.Material = Enum.Material.WoodPlanks

	local slots = {}
	for _, z in SLOT_Z do
		for _, sx in SLOT_X do
			local cf = origin * CFrame.new(sx, 1, z)
			local pedestal = makePart(
				"Pedestal",
				Vector3.new(1, 8, 8),
				cf * CFrame.new(0, 0.5, 0) * CFrame.Angles(0, 0, math.rad(90)),
				Color3.fromRGB(255, 255, 255),
				model
			)
			pedestal.Shape = Enum.PartType.Cylinder
			table.insert(slots, cf * CFrame.new(0, 1, 0))
		end
	end

	-- Owner nameplate at the back of the plot.
	local board = makePart(
		"OwnerSign",
		Vector3.new(30, 6, 1),
		origin * CFrame.new(0, 6, -PLOT_SIZE.Z / 2 + 1),
		Color3.fromRGB(255, 210, 80),
		model
	)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Back
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 30
	gui.Parent = board
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(60, 40, 20)
	label.Text = "Empty plot"
	label.Parent = gui
	-- Same text on the front so it reads from the field side too.
	local frontGui = gui:Clone()
	frontGui.Face = Enum.NormalId.Front
	frontGui.Parent = board

	local plot: Plot = {
		Index = index,
		Model = model,
		Owner = nil,
		Origin = origin,
		Home = origin * CFrame.new(0, 4, PLOT_SIZE.Z / 2 + 4),
		Muzzle = CFrame.new(),
		Slots = slots,
		Rendered = {},
		OwnerLabel = label,
	}
	buildCannon(plot, origin, model)
	return plot
end

local function setOwnerText(plot: Plot, text: string)
	plot.OwnerLabel.Text = text
	local board = plot.OwnerLabel.Parent and plot.OwnerLabel.Parent.Parent
	if board then
		for _, g in board:GetChildren() do
			if g:IsA("SurfaceGui") then
				local l = g:FindFirstChildOfClass("TextLabel")
				if l then
					l.Text = text
				end
			end
		end
	end
end

local function clearRendered(plot: Plot)
	for slot, model in plot.Rendered do
		model:Destroy()
		plot.Rendered[slot] = nil
	end
end

local function sellSlot(player: Player, slot: number)
	local data = DataService.get(player)
	if not data then
		return
	end
	for i, g in data.Goobers do
		if g.Slot == slot then
			local value = Formulas.sellValue(g.Id, g.Mutation)
			table.remove(data.Goobers, i)
			EconomyService.addCash(player, value)
			local plot = plotByPlayer[player]
			if plot and plot.Rendered[slot] then
				plot.Rendered[slot]:Destroy()
				plot.Rendered[slot] = nil
			end
			local def = GooberDefs.ById[g.Id]
			notify:FireClient(player, "Sold " .. (def and def.Name or g.Id) .. " for " .. Format.cash(value))
			EconomyService.refresh(player)
			return
		end
	end
end

local function renderSlot(plot: Plot, goober: { Id: string, Mutation: string, Slot: number })
	local existing = plot.Rendered[goober.Slot]
	if existing then
		existing:Destroy()
	end
	if not GooberDefs.ById[goober.Id] then
		return
	end
	local model = GooberVisual.build(goober.Id, goober.Mutation, true)
	model:PivotTo(plot.Slots[goober.Slot])
	model.Parent = plot.Model
	plot.Rendered[goober.Slot] = model

	local body = model.PrimaryPart
	if body then
		local ownerId = if plot.Owner then plot.Owner.UserId else 0
		local slot = goober.Slot

		-- Two prompts on one Goober: the owner sees Sell, everyone else sees Steal.
		-- PromptFilter (client) hides the one that isn't yours; the server checks anyway.
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "SellPrompt"
		prompt.ActionText = "Sell " .. Format.cash(Formulas.sellValue(goober.Id, goober.Mutation))
		prompt.ObjectText = model.Name
		prompt.HoldDuration = 0.6
		prompt.MaxActivationDistance = 10
		prompt.RequiresLineOfSight = false
		prompt:SetAttribute("OnlyUserId", ownerId)
		prompt.Parent = body
		prompt.Triggered:Connect(function(who)
			if who == plot.Owner then
				sellSlot(who, slot)
			end
		end)

		local steal = Instance.new("ProximityPrompt")
		steal.Name = "StealPrompt"
		steal.ActionText = "Steal"
		steal.ObjectText = model.Name
		steal.HoldDuration = Config.Steal.HoldSeconds
		steal.MaxActivationDistance = 10
		steal.RequiresLineOfSight = false
		steal:SetAttribute("NotUserId", ownerId)
		steal.Parent = body
		steal.Triggered:Connect(function(who)
			if who ~= plot.Owner and stealHandler then
				stealHandler(who, plot, slot)
			end
		end)
	end
end

function PlotService.renderAll(player: Player)
	local plot = plotByPlayer[player]
	local data = DataService.get(player)
	if not plot or not data then
		return
	end
	clearRendered(plot)
	for _, g in data.Goobers do
		if g.Slot >= 1 and g.Slot <= #plot.Slots then
			renderSlot(plot, g)
		end
	end
end

function PlotService.getPlot(player: Player): Plot?
	return plotByPlayer[player]
end

function PlotService.setCannonHandler(handler: (Player, Plot) -> ())
	cannonHandler = handler
end

function PlotService.setStealHandler(handler: (Player, Plot, number) -> ())
	stealHandler = handler
end

-- The Goober entry in `slot` on this plot, if any.
function PlotService.gooberAt(plot: Plot, slot: number): DataService.OwnedGoober?
	local owner = plot.Owner
	local data = owner and DataService.get(owner)
	if not data then
		return nil
	end
	for _, g in data.Goobers do
		if g.Slot == slot then
			return g
		end
	end
	return nil
end

-- Hide a Goober while someone carries it off (it's still owned until they make it home).
function PlotService.hideSlot(plot: Plot, slot: number)
	local model = plot.Rendered[slot]
	if model then
		model:Destroy()
		plot.Rendered[slot] = nil
	end
end

-- Put a hidden Goober back on its pedestal.
function PlotService.showSlot(plot: Plot, slot: number)
	local g = PlotService.gooberAt(plot, slot)
	if g then
		renderSlot(plot, g)
	end
end

-- Take a Goober off its owner for good (a successful steal). Returns the entry.
function PlotService.removeGoober(plot: Plot, slot: number, id: string): DataService.OwnedGoober?
	local owner = plot.Owner
	local data = owner and DataService.get(owner)
	if not owner or not data then
		return nil
	end
	for i, g in data.Goobers do
		if g.Slot == slot and g.Id == id then
			table.remove(data.Goobers, i)
			PlotService.hideSlot(plot, slot)
			EconomyService.refresh(owner)
			return g
		end
	end
	return nil
end

-- True if a world position is on this plot's floor (with a little margin).
function PlotService.contains(plot: Plot, position: Vector3): boolean
	local localPos = plot.Origin:PointToObjectSpace(position)
	return math.abs(localPos.X) <= PLOT_SIZE.X / 2 + 2
		and math.abs(localPos.Z) <= PLOT_SIZE.Z / 2 + 2
		and localPos.Y < 30
end

function PlotService.all(): { Plot }
	return plots
end

export type GrantOutcome = {
	Placed: boolean,
	Slot: number?,
	SoldId: string?,
	SoldMutation: string?,
	SoldValue: number?,
}

-- Puts a new Goober on the plot. If the plot is full, the weakest Goober (new one
-- included) is auto-sold, so a catch is never wasted and never needs a menu.
function PlotService.grantGoober(player: Player, id: string, mutation: string): GrantOutcome
	local data = DataService.get(player)
	local plot = plotByPlayer[player]
	if not data then
		return { Placed = false }
	end
	data.Discovered[id] = true

	local used = {}
	for _, g in data.Goobers do
		used[g.Slot] = true
	end
	local freeSlot: number? = nil
	for slot = 1, Config.Plot.Slots do
		if not used[slot] then
			freeSlot = slot
			break
		end
	end

	local outcome: GrantOutcome
	if freeSlot then
		local entry = { Id = id, Mutation = mutation, Slot = freeSlot }
		table.insert(data.Goobers, entry)
		if plot then
			renderSlot(plot, entry)
		end
		outcome = { Placed = true, Slot = freeSlot }
	else
		local weakestIndex, weakestIncome = 1, math.huge
		for i, g in data.Goobers do
			local income = Formulas.gooberIncome(g.Id, g.Mutation)
			if income < weakestIncome then
				weakestIndex, weakestIncome = i, income
			end
		end
		local newIncome = Formulas.gooberIncome(id, mutation)
		if newIncome > weakestIncome then
			local old = data.Goobers[weakestIndex]
			local value = Formulas.sellValue(old.Id, old.Mutation)
			local entry = { Id = id, Mutation = mutation, Slot = old.Slot }
			data.Goobers[weakestIndex] = entry
			EconomyService.addCash(player, value)
			if plot then
				renderSlot(plot, entry)
			end
			outcome = {
				Placed = true,
				Slot = entry.Slot,
				SoldId = old.Id,
				SoldMutation = old.Mutation,
				SoldValue = value,
			}
		else
			local value = Formulas.sellValue(id, mutation)
			EconomyService.addCash(player, value)
			outcome = { Placed = false, SoldId = id, SoldMutation = mutation, SoldValue = value }
		end
	end
	EconomyService.refresh(player)
	return outcome
end

local function assign(player: Player)
	if plotByPlayer[player] then
		return
	end
	for _, plot in plots do
		if plot.Owner == nil then
			plot.Owner = player
			plotByPlayer[player] = plot
			player:SetAttribute("PlotIndex", plot.Index)
			setOwnerText(plot, player.DisplayName .. "'s Goobers")
			return
		end
	end
	warn("No free plot for", player.Name, "- raise Config.Plot.MaxPlots or lower MaxPlayers")
end

local function release(player: Player)
	local plot = plotByPlayer[player]
	if not plot then
		return
	end
	clearRendered(plot)
	plot.Owner = nil
	plotByPlayer[player] = nil
	setOwnerText(plot, "Empty plot")
end

local function sendHome(player: Player, character: Model)
	local plot = plotByPlayer[player]
	if plot then
		task.defer(function()
			if character.Parent then
				character:PivotTo(plot.Home)
			end
		end)
	end
end

function PlotService.sendHome(player: Player)
	local character = player.Character
	if character then
		sendHome(player, character)
	end
end

function PlotService.start(mapFolder: Instance)
	local folder = Instance.new("Folder")
	folder.Name = "Plots"
	folder.Parent = mapFolder or Workspace
	local count = Config.Plot.MaxPlots
	for i = 1, count do
		local x = (i - (count + 1) / 2) * PLOT_SPACING
		table.insert(plots, buildPlot(i, x, folder))
	end

	DataService.onLoaded(function(player)
		assign(player)
		PlotService.renderAll(player)
		if player.Character then
			sendHome(player, player.Character)
		end
	end)
	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function(character)
			sendHome(player, character)
		end)
	end)
	for _, player in Players:GetPlayers() do
		player.CharacterAdded:Connect(function(character)
			sendHome(player, character)
		end)
	end
	Players.PlayerRemoving:Connect(release)
end

return PlotService
