--!strict
-- One place that names every RemoteEvent. The server creates them, clients wait for them.
-- Rule: clients only ever send *intent* (a charge value, "buy upgrade"). The server decides
-- every outcome: speed, distance, rolls, cash.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local NAMES = {
	"BeginCharge", -- server -> client: you're in the cannon, show the meter. (muzzleCFrame)
	"Launch", -- client -> server: release. (charge: number 0..1)
	"Launched", -- server -> client: you're airborne. (muzzlePosition, speed, sweetSpot)
	"LaunchResult", -- server -> client: landed. (result table)
	"ChargeCancelled", -- server -> client: charge timed out or was refused.
	"BuyLaunchPower", -- client -> server: buy one Launch Power level.
	"Rebirth", -- client -> server: rebirth now (server checks it's allowed).
	"Notify", -- server -> client: toast message. (text, color?)
}

local folder: Folder
if RunService:IsServer() then
	local existing = ReplicatedStorage:FindFirstChild("Remotes")
	if existing then
		folder = existing :: Folder
	else
		folder = Instance.new("Folder")
		folder.Name = "Remotes"
		folder.Parent = ReplicatedStorage
	end
	for _, name in NAMES do
		if not folder:FindFirstChild(name) then
			local remote = Instance.new("RemoteEvent")
			remote.Name = name
			remote.Parent = folder
		end
	end
else
	folder = ReplicatedStorage:WaitForChild("Remotes") :: Folder
end

local Remotes = {}

function Remotes.get(name: string): RemoteEvent
	assert(table.find(NAMES, name), "unknown remote " .. name)
	if RunService:IsServer() then
		return folder:FindFirstChild(name) :: RemoteEvent
	end
	return folder:WaitForChild(name) :: RemoteEvent
end

return Remotes
