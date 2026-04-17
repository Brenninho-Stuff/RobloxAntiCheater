--[[
	SecurityManager.luau
	Description: Central security system manager for Roblox game
	Path: source/system/SecurityManager.luau
]]

local SecurityManager = {}
SecurityManager.__index = SecurityManager

-- Services
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

-- Module References
local AntiExploit = require(script:WaitForChild("AntiExploit"))
local RemoteValidator = require(script:WaitForChild("RemoteValidator"))
local ServerGuard = require(script:WaitForChild("ServerGuard"))

-- Configuration
local CONFIG = {
	EnableLogging = true,
	LogToDiscord = false, -- Set true if using webhook
	DiscordWebhook = "",
	AdminUserIds = {} -- Add admin user IDs here
}

function SecurityManager.new()
	local self = setmetatable({}, SecurityManager)
	
	self.ActiveMonitors = {}
	self.BannedPlayers = {}
	self.SuspiciousActions = {}
	
	return self
end

function SecurityManager:Initialize()
	print("🔒 Security Manager Initializing...")
	
	-- Initialize subsystems
	AntiExploit:Initialize(CONFIG)
	RemoteValidator:Initialize(CONFIG)
	ServerGuard:Initialize(CONFIG)
	
	-- Setup player monitoring
	self:SetupPlayerMonitoring()
	
	print("✅ Security Manager Fully Initialized")
end

function SecurityManager:SetupPlayerMonitoring()
	Players.PlayerAdded:Connect(function(player)
		self:OnPlayerJoined(player)
	end)
	
	Players.PlayerRemoving:Connect(function(player)
		self:OnPlayerLeft(player)
	end)
	
	-- Handle existing players
	for _, player in ipairs(Players:GetPlayers()) do
		self:OnPlayerJoined(player)
	end
end

function SecurityManager:OnPlayerJoined(player)
	local monitor = {
		Player = player,
		JoinTime = os.time(),
		Warnings = 0,
		Flags = {}
	}
	
	self.ActiveMonitors[player.UserId] = monitor
	
	-- Start anti-exploit monitoring
	AntiExploit:MonitorPlayer(player)
	
	-- Start server-side guard
	ServerGuard:ProtectPlayer(player)
	
	if CONFIG.EnableLogging then
		print(string.format("👤 Player %s (%d) joined - Monitoring active", player.Name, player.UserId))
	end
end

function SecurityManager:OnPlayerLeft(player)
	if self.ActiveMonitors[player.UserId] then
		self.ActiveMonitors[player.UserId] = nil
	end
	
	AntiExploit:CleanupPlayer(player)
	ServerGuard:CleanupPlayer(player)
end

function SecurityManager:FlagPlayer(player, reason, severity)
	severity = severity or "Medium"
	
	local monitor = self.ActiveMonitors[player.UserId]
	if not monitor then return end
	
	monitor.Warnings += 1
	table.insert(monitor.Flags, {
		Reason = reason,
		Severity = severity,
		Timestamp = os.time()
	})
	
	warn(string.format("⚠️ [SECURITY] %s flagged: %s (Severity: %s)", player.Name, reason, severity))
	
	-- Take action based on severity and warning count
	if severity == "Critical" or monitor.Warnings >= 5 then
		self:BanPlayer(player, "Multiple security violations: " .. reason)
	elseif severity == "High" or monitor.Warnings >= 3 then
		self:KickPlayer(player, "Security violation: " .. reason)
	end
end

function SecurityManager:KickPlayer(player, reason)
	player:Kick("🛡️ Security System: " .. reason)
end

function SecurityManager:BanPlayer(player, reason)
	self.BannedPlayers[player.UserId] = {
		Name = player.Name,
		Reason = reason,
		BanTime = os.time()
	}
	
	player:Kick("⛔ Banned: " .. reason)
	-- Add permanent ban logic here (DataStore)
end

return SecurityManager.new()
