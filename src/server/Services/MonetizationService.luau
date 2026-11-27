--!strict
-- Game passes and developer products. Every item lives in Config.Monetization; an Id
-- of 0 means "not created yet": its button shows as coming soon and nothing can be
-- bought. Fill the ids in after the first publish and everything switches on.
--
-- Passes are checked once on join (and on purchase) and cached. Products go through
-- ProcessReceipt, which records each PurchaseId in the player's save so a retried
-- receipt is never granted twice.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Format = require(Shared.Format)
local Remotes = require(Shared.Remotes)

local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)

local MonetizationService = {}

local notify = Remotes.get("Notify")
local owned: { [Player]: { [string]: boolean } } = {}

-- Keep the receipt log bounded; Roblox only retries recent receipts.
local MAX_RECEIPTS = 200

local function passKeyForId(id: number): string?
	for key, pass in Config.Monetization.Passes do
		if pass.Id ~= 0 and pass.Id == id then
			return key
		end
	end
	return nil
end

local function productKeyForId(id: number): string?
	for key, product in Config.Monetization.Products do
		if product.Id ~= 0 and product.Id == id then
			return key
		end
	end
	return nil
end

local function publishOwnership(player: Player)
	local list = {}
	for key, has in owned[player] or {} do
		if has then
			table.insert(list, key)
		end
	end
	table.sort(list)
	player:SetAttribute("Passes", table.concat(list, ","))
end

function MonetizationService.owns(player: Player, passKey: string): boolean
	local set = owned[player]
	return set ~= nil and set[passKey] == true
end

-- Studio/testing: grant or revoke a pass without a purchase.
function MonetizationService.setOwned(player: Player, passKey: string, value: boolean)
	owned[player] = owned[player] or {}
	owned[player][passKey] = value
	publishOwnership(player)
	EconomyService.refresh(player)
end

-- Income multiplier from passes. Multiplies with rebirth and Index.
function MonetizationService.incomeMultiplier(player: Player): number
	return if MonetizationService.owns(player, "DoubleCash")
		then Config.Monetization.Passes.DoubleCash.Multiplier
		else 1
end

-- Launch speed multiplier from passes.
function MonetizationService.launchMultiplier(player: Player): number
	return if MonetizationService.owns(player, "SuperCannon")
		then Config.Monetization.Passes.SuperCannon.Multiplier
		else 1
end

-- Luck for Goober and mutation rolls: Lucky pass times any active Luck Boost.
function MonetizationService.luck(player: Player): number
	local luck = 1
	if MonetizationService.owns(player, "Lucky") then
		luck *= Config.Monetization.Passes.Lucky.Multiplier
	end
	local data = DataService.get(player)
	if data and data.LuckBoostUntil > os.time() then
		luck *= Config.Monetization.Products.LuckBoost.Multiplier
	end
	return luck
end

local function loadOwnership(player: Player)
	owned[player] = owned[player] or {}
	for key, pass in Config.Monetization.Passes do
		if pass.Id ~= 0 then
			local ok, has =
				pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, pass.Id)
			if ok and has then
				owned[player][key] = true
			end
		end
	end
	publishOwnership(player)
	EconomyService.refresh(player)
end

-- What each product does. Returns false if it couldn't be granted (the receipt is
-- then left unprocessed and Roblox retries later).
local grants: { [string]: (Player, DataService.PlayerData) -> boolean } = {
	CashPack = function(player, data)
		local income = EconomyService.income(player, data)
		local pack = Config.Monetization.Products.CashPack
		local amount = math.max(pack.MinCash, income * pack.IncomeSeconds)
		data.Cash += amount
		notify:FireClient(
			player,
			"+" .. Format.cash(amount) .. "! Thanks for the support!",
			Color3.fromRGB(120, 255, 120)
		)
		return true
	end,
	LuckBoost = function(player, data)
		local boost = Config.Monetization.Products.LuckBoost
		data.LuckBoostUntil = math.max(data.LuckBoostUntil, os.time()) + boost.Minutes * 60
		player:SetAttribute("LuckBoostUntil", data.LuckBoostUntil)
		notify:FireClient(
			player,
			"Luck x" .. boost.Multiplier .. " for " .. boost.Minutes .. " minutes!",
			Color3.fromRGB(120, 255, 120)
		)
		return true
	end,
}

local function processReceipt(receipt: any): Enum.ProductPurchaseDecision
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	local data = player and DataService.get(player)
	if not player or not data then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local purchaseId = tostring(receipt.PurchaseId)
	if table.find(data.Receipts, purchaseId) then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	local key = productKeyForId(receipt.ProductId)
	local grant = key and grants[key]
	if not grant then
		warn("Unknown developer product", receipt.ProductId)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local ok, granted = pcall(grant, player, data)
	if not ok or not granted then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	table.insert(data.Receipts, purchaseId)
	while #data.Receipts > MAX_RECEIPTS do
		table.remove(data.Receipts, 1)
	end
	EconomyService.refresh(player)
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

-- The client asks to buy something by its Config key; the server checks it exists
-- and is switched on, then shows Roblox's own purchase prompt.
local function onPromptRequest(player: Player, kind: unknown, key: unknown)
	if typeof(kind) ~= "string" or typeof(key) ~= "string" then
		return
	end
	if kind == "Pass" then
		local pass = Config.Monetization.Passes[key]
		if pass and pass.Id ~= 0 and not MonetizationService.owns(player, key) then
			MarketplaceService:PromptGamePassPurchase(player, pass.Id)
		end
	elseif kind == "Product" then
		local product = Config.Monetization.Products[key]
		if product and product.Id ~= 0 then
			MarketplaceService:PromptProductPurchase(player, product.Id)
		end
	end
end

function MonetizationService.start()
	EconomyService.setExtraMultiplier(MonetizationService.incomeMultiplier)
	MarketplaceService.ProcessReceipt = processReceipt
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		if purchased then
			local key = passKeyForId(passId)
			if key then
				MonetizationService.setOwned(player, key, true)
				notify:FireClient(
					player,
					Config.Monetization.Passes[key].Name .. " unlocked! Thank you!",
					Color3.fromRGB(255, 220, 90)
				)
			end
		end
	end)
	Remotes.get("PromptPurchase").OnServerEvent:Connect(onPromptRequest)

	DataService.onLoaded(function(player, data)
		player:SetAttribute("LuckBoostUntil", data.LuckBoostUntil)
		loadOwnership(player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		owned[player] = nil
	end)
end

return MonetizationService
