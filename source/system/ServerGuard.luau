--[[
	ServerGuard.luau
	Description: Server-side protection mechanisms
	Path: source/system/ServerGuard.luau
]]

local ServerGuard = {}
ServerGuard.__index = ServerGuard

local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")

local CONFIG = {}
local ProtectedInstances = {}
local PlayerDataCache = {}

-- Anti-Exploit DataStore
local BanDataStore = DataStoreService:GetDataStore("SecurityBans")

function ServerGuard:Initialize(config)
	CONFIG = config
	
	-- Protect critical instances
	self:ProtectCriticalInstances()
	
	-- Setup anti-tampering
	self:SetupAntiTampering()
	
	print("🛡️ ServerGuard Initialized")
end

function ServerGuard:ProtectCriticalInstances()
	-- Move important scripts to ServerStorage
	local secureModules = Instance.new("Folder")
	secureModules.Name = "SecureModules"
	secureModules.Parent = ServerStorage
	
	-- Protect against deletion
	for _, instance in ipairs(ProtectedInstances) do
		instance:SetAttribute("Protected", true)
	end
end

function ServerGuard:SetupAntiTampering()
	-- Monitor for suspicious server changes
	ServerScriptService.DescendantRemoving:Connect(function(descendant)
		if descendant:GetAttribute("Protected") then
			warn("⚠️ Attempt to delete protected instance: " .. descendant:GetFullName())
			-- Restore or take action
		end
	end)
end

function ServerGuard:ProtectPlayer(player)
	local playerData = {
		UserId = player.UserId,
		Name = player.Name,
		SessionStart = os.time(),
		IsBanned = false
	}
	
	-- Check if player is banned
	self:CheckBanStatus(player, playerData)
	
	-- Protect player's character
	player.CharacterAdded:Connect(function(character)
		self:ProtectCharacter(player, character)
	end)
	
	-- Protect player's backpack
	player.Backpack.ChildAdded:Connect(function(child)
		if child:IsA("Tool") then
			child:SetAttribute("Owner", player.UserId)
		end
	end)
	
	PlayerDataCache[player.UserId] = playerData
end

function ServerGuard:CheckBanStatus(player, playerData)
	local success, banInfo = pcall(function()
		return BanDataStore:GetAsync(tostring(player.UserId))
	end)
	
	if success and banInfo then
		playerData.IsBanned = true
		player:Kick("⛔ You are banned from this game. Reason: " .. (banInfo.Reason or "Violation"))
	end
end

function ServerGuard:ProtectCharacter(player, character)
	-- Add protection attributes
	character:SetAttribute("Owner", player.UserId)
	
	local humanoid = character:WaitForChild("Humanoid")
	local rootPart = character:WaitForChild("HumanoidRootPart")
	
	-- Protect against unauthorized changes
	humanoid:GetPropertyChangedSignal("WalkSpeed"):Connect(function()
		if humanoid.WalkSpeed > 25 and not self:IsAuthorizedSpeedChange(player) then
			humanoid.WalkSpeed = 16
			warn(string.format("⚠️ Unauthorized WalkSpeed change for %s", player.Name))
		end
	end)
	
	humanoid:GetPropertyChangedSignal("JumpPower"):Connect(function()
		if humanoid.JumpPower > 60 and not self:IsAuthorizedJumpChange(player) then
			humanoid.JumpPower = 50
			warn(string.format("⚠️ Unauthorized JumpPower change for %s", player.Name))
		end
	end)
end

function ServerGuard:IsAuthorizedSpeedChange(player)
	-- Check if speed change is from an authorized source
	return false -- Default: no external speed changes allowed
end

function ServerGuard:IsAuthorizedJumpChange(player)
	-- Check if jump change is from an authorized source
	return false -- Default: no external jump changes allowed
end

function ServerGuard:BanPlayer(userId, reason, duration)
	local banInfo = {
		UserId = userId,
		Reason = reason,
		BanDate = os.time(),
		Duration = duration, -- nil for permanent
		BannedBy = "System"
	}
	
	pcall(function()
		BanDataStore:SetAsync(tostring(userId), banInfo)
	end)
	
	-- Kick if online
	local player = Players:GetPlayerByUserId(userId)
	if player then
		player:Kick("⛔ Banned: " .. reason)
	end
end

function ServerGuard:CleanupPlayer(player)
	PlayerDataCache[player.UserId] = nil
end

return ServerGuard
