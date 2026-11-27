--!strict
-- Player saves via ProfileStore (session-locked, auto-saving). In Studio without
-- API access, ProfileStore falls back to an in-memory mock, so playtests still work.

local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")

local ProfileStore = require(ServerScriptService:WaitForChild("ServerPackages"):WaitForChild("ProfileStore"))

export type OwnedGoober = { Id: string, Mutation: string, Slot: number }

export type PlayerData = {
	Cash: number,
	LaunchLevel: number,
	BestDistance: number,
	TotalLaunches: number,
	Rebirths: number,
	Goobers: { OwnedGoober },
	Discovered: { [string]: boolean }, -- Goober ids ever owned; feeds the Index in week 2
	LastOnline: number, -- os.time() of the last economy tick, for offline earnings
}

local TEMPLATE: PlayerData = {
	Cash = 0,
	LaunchLevel = 0,
	BestDistance = 0,
	TotalLaunches = 0,
	Rebirths = 0,
	Goobers = {},
	Discovered = {},
	LastOnline = 0,
}

-- Bump the store name only for a deliberate wipe. Schema additions go in TEMPLATE;
-- Reconcile() fills them into old saves.
local store = ProfileStore.New("PlayerData_v1", TEMPLATE)

local profiles: { [Player]: any } = {}
local loadedCallbacks: { (Player, PlayerData) -> () } = {}
local releasingCallbacks: { (Player, PlayerData) -> () } = {}

local DataService = {}

function DataService.get(player: Player): PlayerData?
	local profile = profiles[player]
	return if profile then profile.Data else nil
end

function DataService.onLoaded(callback: (Player, PlayerData) -> ())
	table.insert(loadedCallbacks, callback)
	for player, profile in profiles do
		task.spawn(callback, player, profile.Data)
	end
end

-- Runs right before the profile is released, while data is still writable.
function DataService.onReleasing(callback: (Player, PlayerData) -> ())
	table.insert(releasingCallbacks, callback)
end

local function onPlayerAdded(player: Player)
	local profile = store:StartSessionAsync(tostring(player.UserId), {
		Cancel = function()
			return player.Parent ~= Players
		end,
	})

	if profile == nil then
		player:Kick("Couldn't load your Goobers. Please rejoin.")
		return
	end

	profile:AddUserId(player.UserId) -- GDPR compliance
	profile:Reconcile()

	profile.OnSessionEnd:Connect(function()
		profiles[player] = nil
		player:Kick("Your save was opened somewhere else. Please rejoin.")
	end)

	if player.Parent ~= Players then
		profile:EndSession()
		return
	end

	profiles[player] = profile
	for _, callback in loadedCallbacks do
		task.spawn(callback, player, profile.Data)
	end
end

local function onPlayerRemoving(player: Player)
	local profile = profiles[player]
	if not profile then
		return
	end
	for _, callback in releasingCallbacks do
		local ok, err = pcall(callback, player, profile.Data)
		if not ok then
			warn("DataService releasing callback failed:", err)
		end
	end
	profiles[player] = nil
	profile:EndSession()
end

function DataService.start()
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
end

return DataService
