--[[
	Project: RobloxAntiCheater - Advanced Security System
	File: project.luau (Advanced Main Module)
	Description: Advanced anti-cheat system with behavioral analysis, machine learning-like detection,
				 memory scanning, injection detection, and comprehensive exploit prevention.
	Version: 2.0.0
	Author: Brenninho-Stuff
]]

-- =======================================================
-- SERVICES & DEPENDENCIES
-- =======================================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local DataStoreService = game:GetService("DataStoreService")
local TeleportService = game:GetService("TeleportService")
local MessagingService = game:GetService("MessagingService")
local MemoryStoreService = game:GetService("MemoryStoreService")

-- =======================================================
-- MODULE SETUP
-- =======================================================

local AdvancedAntiCheat = {}
AdvancedAntiCheat.__index = AdvancedAntiCheat
AdvancedAntiCheat.Version = "2.0.0"
AdvancedAntiCheat.BuildDate = os.date("%Y-%m-%d %H:%M:%S")

-- =======================================================
-- CONFIGURATION
-- =======================================================

local CONFIG = {
	-- System Settings
	SystemName = "Advanced Anti-Cheat System",
	DebugMode = false,
	EnableLogging = true,
	LogLevel = "Detailed", -- "Basic", "Detailed", "Debug"
	
	-- Security Thresholds
	Thresholds = {
		-- Movement Detection
		MaxWalkSpeed = 24,
		MaxSprintSpeed = 32,
		MaxVerticalVelocity = 80,
		MaxHorizontalAcceleration = 60,
		MaxTeleportDistance = 150,
		MaxFlyTime = 2.5, -- seconds in air before flagging
		
		-- Combat Detection
		MaxDamagePerSecond = 150,
		MaxKillsPerSecond = 3,
		MaxHealingPerSecond = 100,
		AimbotAngleThreshold = 0.5, -- radians
		AimbotTrackingTime = 0.8, -- seconds
		
		-- Inventory/Economy Detection
		MaxItemsPerSecond = 10,
		MaxCurrencyChangePerSecond = 10000,
		MaxToolEquipSpeed = 0.5,
		
		-- Network Detection
		MaxRemoteCallsPerSecond = 20,
		MaxPingVariance = 150,
		MinResponseTime = 0.05,
		MaxPacketLoss = 0.3,
		
		-- Injection Detection
		MemoryScanInterval = 30,
		ScriptScanInterval = 60,
		MaxLocalScripts = 50,
		MaxModuleScripts = 100
	},
	
	-- Punishment Settings
	Punishments = {
		WarningThreshold = 3,
		KickThreshold = 5,
		TempBanThreshold = 8,
		PermBanThreshold = 12,
		TempBanDuration = 86400, -- 24 hours in seconds
		AppealLink = "https://discord.gg/yourappealserver"
	},
	
	-- Whitelist Settings
	Whitelist = {
		Enabled = true,
		AutoWhitelistAdmins = true,
		AdminGroupId = 0, -- Your admin group ID
		TrustedUserIds = {} -- Add trusted user IDs
	},
	
	-- Webhook/Discord Integration
	Discord = {
		Enabled = false,
		WebhookURL = "",
		MentionRoles = {},
		LogChannel = "",
		AlertChannel = ""
	},
	
	-- DataStore Settings
	DataStores = {
		BanHistory = "AntiCheat_BanHistory_V2",
		PlayerLogs = "AntiCheat_PlayerLogs_V2",
		SuspiciousActivity = "AntiCheat_SuspiciousActivity_V2",
		SystemMetrics = "AntiCheat_SystemMetrics_V2"
	},
	
	-- Cross-Server Communication
	CrossServer = {
		Enabled = true,
		SyncBans = true,
		SyncFlags = true,
		TopicName = "AntiCheat_Global"
	},
	
	-- Performance Settings
	Performance = {
		MaxMonitoredPlayers = 100,
		CheckInterval = 0.1, -- seconds
		BatchProcessing = true,
		OptimizeMemory = true,
		CleanupInterval = 300 -- 5 minutes
	}
}

-- =======================================================
-- DATA STRUCTURES & CACHES
-- =======================================================

local AntiCheatData = {
	-- Player Monitoring Data
	Players = {}, -- [userId] = PlayerData
	
	-- Global Statistics
	Stats = {
		TotalFlags = 0,
		TotalBans = 0,
		TotalKicks = 0,
		ActiveExploiters = 0,
		DetectionsByType = {},
		StartTime = os.time()
	},
	
	-- Suspicious Patterns Database
	Patterns = {
		KnownExploits = {},
		BehavioralPatterns = {},
		SuspiciousIPs = {},
		CompromisedAccounts = {}
	},
	
	-- Cache for Performance
	Cache = {
		LastPositions = {}, -- [userId] = {Position, Timestamp, Velocity}
		LastHealth = {}, -- [userId] = {Health, Timestamp}
		LastAttacks = {}, -- [userId] = {Target, Timestamp, Damage}
		RemoteCallHistory = {}, -- [userId] = {RemoteName, Count, Timestamp}
		RaycastCache = {} -- For performance optimization
	},
	
	-- Active Sessions
	Sessions = {
		Active = {},
		TotalSessions = 0,
		AverageSessionTime = 0
	}
}

-- =======================================================
-- UTILITY FUNCTIONS
-- =======================================================

local Utilities = {}

-- Enhanced Logging System
function Utilities:Log(message, level, data)
	if not CONFIG.EnableLogging then return end
	
	level = level or "INFO"
	local timestamp = os.date("%Y-%m-%d %H:%M:%S")
	local logMessage = string.format("[%s] [%s] %s", timestamp, level, message)
	
	if CONFIG.LogLevel == "Debug" or 
	   (CONFIG.LogLevel == "Detailed" and level ~= "DEBUG") or
	   (CONFIG.LogLevel == "Basic" and (level == "WARN" or level == "ERROR" or level == "CRITICAL")) then
		
		if data then
			print(logMessage, HttpService:JSONEncode(data))
		else
			print(logMessage)
		end
	end
	
	-- Send to Discord if critical
	if (level == "CRITICAL" or level == "ALERT") and CONFIG.Discord.Enabled then
		self:SendDiscordAlert(message, data)
	end
end

-- Discord Webhook Integration
function Utilities:SendDiscordAlert(message, data)
	if not CONFIG.Discord.Enabled or CONFIG.Discord.WebhookURL == "" then return end
	
	local embed = {
		title = "🚨 Anti-Cheat Alert",
		description = message,
		color = 16711680, -- Red
		fields = {},
		timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
		footer = {
			text = string.format("Advanced Anti-Cheat v%s", AdvancedAntiCheat.Version)
		}
	}
	
	if data then
		for key, value in pairs(data) do
			table.insert(embed.fields, {
				name = tostring(key),
				value = tostring(value),
				inline = true
			})
		end
	end
	
	local payload = HttpService:JSONEncode({
		content = table.concat(CONFIG.Discord.MentionRoles, " "),
		embeds = {embed}
	})
	
	pcall(function()
		HttpService:PostAsync(CONFIG.Discord.WebhookURL, payload)
	end)
end

-- Mathematical & Physics Calculations
function Utilities.CalculateVelocity(prevPos, currentPos, timeDelta)
	if timeDelta <= 0 then return 0 end
	return (currentPos - prevPos).Magnitude / timeDelta
end

function Utilities.CalculateAcceleration(prevVel, currentVel, timeDelta)
	if timeDelta <= 0 then return 0 end
	return (currentVel - prevVel) / timeDelta
end

function Utilities.CalculateAngle(vector1, vector2)
	local dot = vector1:Dot(vector2)
	local mag1 = vector1.Magnitude
	local mag2 = vector2.Magnitude
	
	if mag1 == 0 or mag2 == 0 then return 0 end
	return math.acos(math.clamp(dot / (mag1 * mag2), -1, 1))
end

function Utilities.IsPointInViewport(point, camera, fovBuffer)
	local direction = (point - camera.Position).Unit
	local lookVector = camera.CFrame.LookVector
	local angle = Utilities.CalculateAngle(direction, lookVector)
	
	return angle <= (camera.FieldOfView / 2 + (fovBuffer or 10)) * math.pi / 180
end

-- Memory & Performance Optimization
function Utilities.CleanupOldData()
	local now = os.time()
	local cleanupThreshold = now - 3600 -- 1 hour
	
	for userId, data in pairs(AntiCheatData.Players) do
		if not data.IsActive and data.LastUpdate < cleanupThreshold then
			AntiCheatData.Players[userId] = nil
		end
	end
	
	for userId, _ in pairs(AntiCheatData.Cache.LastPositions) do
		if not AntiCheatData.Players[userId] or not AntiCheatData.Players[userId].IsActive then
			AntiCheatData.Cache.LastPositions[userId] = nil
			AntiCheatData.Cache.LastHealth[userId] = nil
			AntiCheatData.Cache.LastAttacks[userId] = nil
			AntiCheatData.Cache.RemoteCallHistory[userId] = nil
		end
	end
end

-- DataStore Operations with Retry Logic
function Utilities.DataStoreOperation(storeName, operation, key, value, retries)
	retries = retries or 3
	
	for attempt = 1, retries do
		local success, result = pcall(function()
			local store = DataStoreService:GetDataStore(storeName)
			
			if operation == "Get" then
				return store:GetAsync(key)
			elseif operation == "Set" then
				return store:SetAsync(key, value)
			elseif operation == "Update" then
				return store:UpdateAsync(key, function(oldValue)
					return value
				end)
			elseif operation == "Increment" then
				return store:IncrementAsync(key, value or 1)
			end
		end)
		
		if success then
			return true, result
		end
		
		if attempt < retries then
			task.wait(2 ^ attempt) -- Exponential backoff
		end
	end
	
	return false, nil
end

-- =======================================================
-- DETECTION MODULES
-- =======================================================

local DetectionModules = {}

-- Movement Exploit Detection
DetectionModules.Movement = {
	Name = "Movement Detection",
	Version = "2.0.0",
	
	CheckSpeed = function(player, currentPos, timeDelta)
		local userId = player.UserId
		local lastData = AntiCheatData.Cache.LastPositions[userId]
		
		if not lastData then return false end
		
		local velocity = Utilities.CalculateVelocity(lastData.Position, currentPos, timeDelta)
		local horizontalSpeed = Vector2.new(velocity.X, velocity.Z).Magnitude
		local verticalSpeed = math.abs(velocity.Y)
		
		-- Check for speed hacks
		if horizontalSpeed > CONFIG.Thresholds.MaxSprintSpeed + 5 then
			-- Buffer check to prevent false positives
			task.wait(0.2)
			local newData = AntiCheatData.Cache.LastPositions[userId]
			if newData then
				local newVelocity = Utilities.CalculateVelocity(newData.Position, currentPos, 0.2)
				local newHorizontalSpeed = Vector2.new(newVelocity.X, newVelocity.Z).Magnitude
				
				if newHorizontalSpeed > CONFIG.Thresholds.MaxSprintSpeed + 5 then
					return {
						Type = "SpeedHack",
						Severity = "High",
						Value = math.floor(horizontalSpeed),
						Threshold = CONFIG.Thresholds.MaxSprintSpeed,
						Excess = math.floor(horizontalSpeed - CONFIG.Thresholds.MaxSprintSpeed)
					}
				end
			end
		end
		
		-- Check for fly hacks
		if verticalSpeed > CONFIG.Thresholds.MaxVerticalVelocity then
			local character = player.Character
			if character then
				local humanoid = character:FindFirstChildOfClass("Humanoid")
				if humanoid and humanoid.FloorMaterial == Enum.Material.Air and not humanoid.Jump then
					return {
						Type = "FlyHack",
						Severity = "Critical",
						Value = math.floor(verticalSpeed),
						Threshold = CONFIG.Thresholds.MaxVerticalVelocity,
						Duration = timeDelta
					}
				end
			end
		end
		
		return false
	end,
	
	CheckTeleport = function(player, currentPos, timeDelta)
		local userId = player.UserId
		local lastData = AntiCheatData.Cache.LastPositions[userId]
		
		if not lastData then return false end
		
		local distance = (currentPos - lastData.Position).Magnitude
		
		-- Ignore if player is in vehicle or using legitimate teleport
		local character = player.Character
		if character then
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			if humanoid and humanoid.SeatPart then
				return false -- Player is in a seat/vehicle
			end
			
			-- Check for legitimate teleport items/tools
			local hasTeleportTool = false
			for _, tool in ipairs(character:GetChildren()) do
				if tool:IsA("Tool") and tool:GetAttribute("IsTeleporter") then
					hasTeleportTool = true
					break
				end
			end
			
			if hasTeleportTool then return false end
		end
		
		if distance > CONFIG.Thresholds.MaxTeleportDistance then
			return {
				Type = "TeleportHack",
				Severity = "High",
				Value = math.floor(distance),
				Threshold = CONFIG.Thresholds.MaxTeleportDistance,
				TimeDelta = timeDelta
			}
		end
		
		return false
	end,
	
	CheckNoclip = function(player, character, humanoid)
		if not character or not humanoid then return false end
		
		local rootPart = character:FindFirstChild("HumanoidRootPart")
		if not rootPart then return false end
		
		-- Perform raycast in multiple directions
		local directions = {
			Vector3.new(1, 0, 0),
			Vector3.new(-1, 0, 0),
			Vector3.new(0, 0, 1),
			Vector3.new(0, 0, -1),
			Vector3.new(0, 1, 0),
			Vector3.new(0, -1, 0)
		}
		
		local rayParams = RaycastParams.new()
		rayParams.FilterType = Enum.RaycastFilterType.Blacklist
		rayParams.FilterDescendantsInstances = {character}
		
		local insideWallCount = 0
		
		for _, dir in ipairs(directions) do
			local rayResult = workspace:Raycast(rootPart.Position, dir * 2, rayParams)
			if rayResult and rayResult.Instance then
				-- Check if ray is hitting from inside
				local backRay = workspace:Raycast(rootPart.Position + dir * 2, -dir * 4, rayParams)
				if backRay and backRay.Instance == rayResult.Instance then
					insideWallCount += 1
				end
			end
		end
		
		-- If surrounded by walls on multiple sides, likely noclipping
		if insideWallCount >= 3 then
			return {
				Type = "Noclip",
				Severity = "Critical",
				WallsDetected = insideWallCount
			}
		end
		
		return false
	end
}

-- Combat Exploit Detection
DetectionModules.Combat = {
	Name = "Combat Detection",
	Version = "2.0.0",
	
	CheckAimbot = function(player, target, hitPosition, timeDelta)
		local userId = player.UserId
		local character = player.Character
		
		if not character then return false end
		
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if not humanoid then return false end
		
		-- Get camera direction
		local camera = workspace.CurrentCamera
		if not camera then return false end
		
		-- Calculate angle between camera direction and hit position
		local cameraToTarget = (hitPosition - camera.CFrame.Position).Unit
		local angle = Utilities.CalculateAngle(camera.CFrame.LookVector, cameraToTarget)
		
		-- Track consistent aiming patterns
		local attackData = AntiCheatData.Cache.LastAttacks[userId]
		if not attackData then
			AntiCheatData.Cache.LastAttacks[userId] = {
				Target = target,
				Angles = {angle},
				Timestamps = {os.time()},
				Consistency = 0
			}
			return false
		end
		
		-- Update attack history
		table.insert(attackData.Angles, angle)
		table.insert(attackData.Timestamps, os.time())
		
		-- Keep last 10 attacks
		if #attackData.Angles > 10 then
			table.remove(attackData.Angles, 1)
			table.remove(attackData.Timestamps, 1)
		end
		
		-- Check for consistency (low angle variance)
		if #attackData.Angles >= 5 then
			local avgAngle = 0
			local variance = 0
			
			for _, a in ipairs(attackData.Angles) do
				avgAngle += a
			end
			avgAngle = avgAngle / #attackData.Angles
			
			for _, a in ipairs(attackData.Angles) do
				variance += (a - avgAngle) ^ 2
			end
			variance = variance / #attackData.Angles
			
			-- Low variance indicates aimbot
			if variance < 0.01 and avgAngle < CONFIG.Thresholds.AimbotAngleThreshold then
				attackData.Consistency += 1
				
				if attackData.Consistency > 3 then
					return {
						Type = "Aimbot",
						Severity = "Critical",
						AngleVariance = variance,
						Consistency = attackData.Consistency
					}
				end
			else
				attackData.Consistency = math.max(0, attackData.Consistency - 1)
			end
		end
		
		return false
	end,
	
	CheckDamageRate = function(player, damage, timeDelta)
		local userId = player.UserId
		local now = os.time()
		
		local attackData = AntiCheatData.Cache.LastAttacks[userId]
		if not attackData then
			AntiCheatData.Cache.LastAttacks[userId] = {
				DamageHistory = {{damage, now}},
				TotalDamage = damage,
				LastReset = now
			}
			return false
		end
		
		-- Clean old damage entries
		local newHistory = {}
		local totalDamage = 0
		
		for _, entry in ipairs(attackData.DamageHistory or {}) do
			if now - entry[2] < 1 then -- Last second
				table.insert(newHistory, entry)
				totalDamage += entry[1]
			end
		end
		
		table.insert(newHistory, {damage, now})
		totalDamage += damage
		
		attackData.DamageHistory = newHistory
		attackData.TotalDamage = totalDamage
		
		if totalDamage > CONFIG.Thresholds.MaxDamagePerSecond then
			return {
				Type = "DamageHack",
				Severity = "Critical",
				DamagePerSecond = totalDamage,
				Threshold = CONFIG.Thresholds.MaxDamagePerSecond
			}
		end
		
		return false
	end
}

-- Exploit Injection Detection
DetectionModules.Injection = {
	Name = "Injection Detection",
	Version = "2.0.0",
	
	ScanPlayerScripts = function(player)
		local suspiciousScripts = {}
		local totalScripts = 0
		
		-- This runs on client via remote call
		-- Server receives results for analysis
		
		-- Known exploit signatures
		local exploitSignatures = {
			"dex",
			"infinite yield",
			"dark dex",
			"synapse",
			"scriptware",
			"krnl",
			"fluxus",
			"electron",
			"vega x",
			"hydrogen",
			"oxygen u",
			"comet"
		}
		
		pcall(function()
			-- Scan PlayerGui
			local playerGui = player:FindFirstChildOfClass("PlayerGui")
			if playerGui then
				for _, child in ipairs(playerGui:GetDescendants()) do
					if child:IsA("LocalScript") or child:IsA("ModuleScript") then
						totalScripts += 1
						
						-- Check source for suspicious strings
						local source = child.Source or ""
						local lowerSource = source:lower()
						
						for _, signature in ipairs(exploitSignatures) do
							if lowerSource:find(signature) then
								table.insert(suspiciousScripts, {
									Name = child.Name,
									Signature = signature,
									Parent = child.Parent:GetFullName()
								})
								break
							end
						end
					end
				end
			end
			
			-- Scan PlayerScripts
			local playerScripts = player:FindFirstChild("PlayerScripts")
			if playerScripts then
				for _, child in ipairs(playerScripts:GetDescendants()) do
					if child:IsA("LocalScript") or child:IsA("ModuleScript") then
						totalScripts += 1
					end
				end
			end
		end)
		
		if #suspiciousScripts > 0 or totalScripts > CONFIG.Thresholds.MaxLocalScripts then
			return {
				Type = "Injection",
				Severity = "Critical",
				SuspiciousScripts = suspiciousScripts,
				TotalScripts = totalScripts,
				Threshold = CONFIG.Thresholds.MaxLocalScripts
			}
		end
		
		return false
	end
}

-- Network Analysis Detection
DetectionModules.Network = {
	Name = "Network Analysis",
	Version = "2.0.0",
	
	CheckRemoteSpam = function(player, remoteName)
		local userId = player.UserId
		local now = os.time()
		
		local remoteHistory = AntiCheatData.Cache.RemoteCallHistory[userId]
		if not remoteHistory then
			AntiCheatData.Cache.RemoteCallHistory[userId] = {}
			remoteHistory = AntiCheatData.Cache.RemoteCallHistory[userId]
		end
		
		if not remoteHistory[remoteName] then
			remoteHistory[remoteName] = {
				Count = 1,
				LastReset = now,
				Timestamps = {now}
			}
			return false
		end
		
		local history = remoteHistory[remoteName]
		
		-- Reset counter every second
		if now - history.LastReset >= 1 then
			history.Count = 1
			history.LastReset = now
			history.Timestamps = {now}
			return false
		end
		
		history.Count += 1
		table.insert(history.Timestamps, now)
		
		if history.Count > CONFIG.Thresholds.MaxRemoteCallsPerSecond then
			return {
				Type = "RemoteSpam",
				Severity = "Medium",
				RemoteName = remoteName,
				CallCount = history.Count,
				Threshold = CONFIG.Thresholds.MaxRemoteCallsPerSecond
			}
		end
		
		return false
	end,
	
	CheckPacketManipulation = function(player, ping, packetLoss)
		local userId = player.UserId
		
		-- Track ping variance
		local playerData = AntiCheatData.Players[userId]
		if not playerData then return false end
		
		if not playerData.PingHistory then
			playerData.PingHistory = {}
		end
		
		table.insert(playerData.PingHistory, ping)
		if #playerData.PingHistory > 10 then
			table.remove(playerData.PingHistory, 1)
		end
		
		-- Calculate ping variance
		if #playerData.PingHistory >= 5 then
			local avgPing = 0
			for _, p in ipairs(playerData.PingHistory) do
				avgPing += p
			end
			avgPing = avgPing / #playerData.PingHistory
			
			local variance = 0
			for _, p in ipairs(playerData.PingHistory) do
				variance += (p - avgPing) ^ 2
			end
			variance = math.sqrt(variance / #playerData.PingHistory)
			
			if variance > CONFIG.Thresholds.MaxPingVariance then
				return {
					Type = "PacketManipulation",
					Severity = "High",
					PingVariance = variance,
					Threshold = CONFIG.Thresholds.MaxPingVariance,
					PacketLoss = packetLoss
				}
			end
		end
		
		return false
	end
}

-- =======================================================
-- MAIN ANTI-CHEAT CLASS
-- =======================================================

function AdvancedAntiCheat.new()
	local self = setmetatable({}, AdvancedAntiCheat)
	
	self.Initialized = false
	self.ActiveMonitors = {}
	self.BlacklistedUsers = {}
	self.WhitelistedUsers = {}
	
	return self
end

function AdvancedAntiCheat:Initialize()
	if self.Initialized then
		Utilities:Log("System already initialized", "WARN")
		return
	end
	
	Utilities:Log("========================================", "INFO")
	Utilities:Log(string.format("Initializing %s v%s", CONFIG.SystemName, self.Version), "INFO")
	Utilities:Log(string.format("Build Date: %s", self.BuildDate), "INFO")
	Utilities:Log("========================================", "INFO")
	
	-- Load configuration from DataStore
	self:LoadConfiguration()
	
	-- Setup cross-server communication
	if CONFIG.CrossServer.Enabled then
		self:SetupCrossServerCommunication()
	end
	
	-- Initialize detection modules
	for name, module in pairs(DetectionModules) do
		Utilities:Log(string.format("Loading detection module: %s v%s", module.Name, module.Version), "DEBUG")
	end
	
	-- Setup player monitoring
	self:SetupPlayerMonitoring()
	
	-- Setup remote validation
	self:SetupRemoteValidation()
	
	-- Start periodic tasks
	self:StartPeriodicTasks()
	
	-- Load existing bans and suspicious patterns
	self:LoadSecurityData()
	
	self.Initialized = true
	Utilities:Log("✅ System initialization complete", "INFO")
end

function AdvancedAntiCheat:LoadConfiguration()
	-- Load custom thresholds from DataStore if exists
	local success, data = Utilities.DataStoreOperation("AntiCheat_Configuration", "Get", "GlobalConfig")
	
	if success and data then
		for key, value in pairs(data) do
			if CONFIG[key] then
				for subKey, subValue in pairs(value) do
					if CONFIG[key][subKey] then
						CONFIG[key][subKey] = subValue
					end
				end
			end
		end
		Utilities:Log("Custom configuration loaded", "INFO")
	end
end

function AdvancedAntiCheat:SetupCrossServerCommunication()
	if not MessagingService then
		Utilities:Log("MessagingService not available", "WARN")
		return
	end
	
	pcall(function()
		MessagingService:SubscribeAsync(CONFIG.CrossServer.TopicName, function(message)
			local data = HttpService:JSONDecode(message.Data)
			self:HandleCrossServerMessage(data)
		end)
		
		Utilities:Log("Cross-server communication established", "INFO")
	end)
end

function AdvancedAntiCheat:HandleCrossServerMessage(data)
	if data.Type == "Ban" and CONFIG.CrossServer.SyncBans then
		self.BlacklistedUsers[data.UserId] = data.BanInfo
		Utilities:Log(string.format("Global ban received for UserId: %d", data.UserId), "ALERT")
	elseif data.Type == "Flag" and CONFIG.CrossServer.SyncFlags then
		-- Record flag from other server
		local playerData = AntiCheatData.Players[data.UserId]
		if playerData then
			playerData.CrossServerFlags = (playerData.CrossServerFlags or 0) + 1
		end
	end
end

function AdvancedAntiCheat:SetupPlayerMonitoring()
	-- Handle joining players
	Players.PlayerAdded:Connect(function(player)
		self:OnPlayerAdded(player)
	end)
	
	-- Handle leaving players
	Players.PlayerRemoving:Connect(function(player)
		self:OnPlayerRemoving(player)
	end)
	
	-- Monitor existing players
	for _, player in ipairs(Players:GetPlayers()) do
		self:OnPlayerAdded(player)
	end
end

function AdvancedAntiCheat:OnPlayerAdded(player)
	local userId = player.UserId
	
	Utilities:Log(string.format("Player joined: %s (UserId: %d)", player.Name, userId), "INFO")
	
	-- Check if player is banned
	if self.BlacklistedUsers[userId] then
		local banInfo = self.BlacklistedUsers[userId]
		player:Kick(string.format("⛔ You are banned from this game.\nReason: %s\nBan ID: %s\nAppeal: %s", 
			banInfo.Reason, banInfo.BanId, CONFIG.Punishments.AppealLink))
		return
	end
	
	-- Check if whitelisted
	local isWhitelisted = self:IsPlayerWhitelisted(player)
	
	-- Initialize player data
	AntiCheatData.Players[userId] = {
		Player = player,
		UserId = userId,
		Name = player.Name,
		JoinTime = os.time(),
		IsActive = true,
		IsWhitelisted = isWhitelisted,
		Warnings = 0,
		Flags = {},
		DetectionHistory = {},
		LastUpdate = os.time(),
		SessionId = HttpService:GenerateGUID(false),
		PingHistory = {},
		RemoteCalls = {},
		Violations = {}
	}
	
	-- Increment session counter
	AntiCheatData.Sessions.TotalSessions += 1
	AntiCheatData.Sessions.Active[userId] = true
	
	-- Setup character monitoring
	player.CharacterAdded:Connect(function(character)
		self:OnCharacterAdded(player, character)
	end)
	
	if player.Character then
		self:OnCharacterAdded(player, player.Character)
	end
	
	-- Start performance monitoring
	if not isWhitelisted or CONFIG.DebugMode then
		self:StartPlayerMonitoring(player)
	end
	
	-- Load player history
	self:LoadPlayerHistory(player)
end

function AdvancedAntiCheat:OnCharacterAdded(player, character)
	local userId = player.UserId
	local playerData = AntiCheatData.Players[userId]
	
	if not playerData then return end
	
	-- Add protection attributes
	character:SetAttribute("Protected", true)
	character:SetAttribute("Owner", userId)
	
	-- Wait for humanoid
	local humanoid = character:WaitForChild("Humanoid")
	local rootPart = character:WaitForChild("HumanoidRootPart")
	
	-- Initialize position cache
	AntiCheatData.Cache.LastPositions[userId] = {
		Position = rootPart.Position,
		Timestamp = os.clock(),
		Velocity = Vector3.zero
	}
	
	-- Monitor humanoid changes
	humanoid:GetPropertyChangedSignal("WalkSpeed"):Connect(function()
		if not playerData.IsWhitelisted and humanoid.WalkSpeed > CONFIG.Thresholds.MaxWalkSpeed then
			local violation = {
				Type = "WalkSpeedModification",
				Value = humanoid.WalkSpeed,
				Threshold = CONFIG.Thresholds.MaxWalkSpeed
			}
			self:FlagPlayer(player, violation, "Medium")
			humanoid.WalkSpeed = 16 -- Reset to default
		end
	end)
	
	humanoid:GetPropertyChangedSignal("JumpPower"):Connect(function()
		if not playerData.IsWhitelisted and humanoid.JumpPower > 70 then
			local violation = {
				Type = "JumpPowerModification",
				Value = humanoid.JumpPower,
				Threshold = 70
			}
			self:FlagPlayer(player, violation, "Medium")
			humanoid.JumpPower = 50 -- Reset to default
		end
	end)
	
	-- Monitor health changes for god mode detection
	local lastHealth = humanoid.Health
	humanoid.HealthChanged:Connect(function(newHealth)
		if not playerData.IsWhitelisted then
			-- Check for instant health regeneration
			if newHealth > lastHealth and newHealth - lastHealth > 50 then
				local violation = {
					Type = "HealthModification",
					Change = newHealth - lastHealth
				}
				self:FlagPlayer(player, violation, "High")
			end
			
			-- Check for god mode (taking no damage)
			if newHealth < lastHealth and newHealth == lastHealth then
				local violation = {
					Type = "PossibleGodMode",
					Health = newHealth
				}
				self:FlagPlayer(player, violation, "Critical")
			end
		end
		
		lastHealth = newHealth
		AntiCheatData.Cache.LastHealth[userId] = {
			Health = newHealth,
			Timestamp = os.clock()
		}
	end)
end

function AdvancedAntiCheat:StartPlayerMonitoring(player)
	local userId = player.UserId
	
	-- Main monitoring loop
	local monitorConnection
	monitorConnection = RunService.Heartbeat:Connect(function()
		local playerData = AntiCheatData.Players[userId]
		if not playerData or not playerData.IsActive then
			monitorConnection:Disconnect()
			return
		end
		
		local character = player.Character
		if not character then return end
		
		local rootPart = character:FindFirstChild("HumanoidRootPart")
		if not rootPart then return end
		
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if not humanoid then return end
		
		local currentTime = os.clock()
		local lastPosData = AntiCheatData.Cache.LastPositions[userId]
		
		if lastPosData then
			local timeDelta = currentTime - lastPosData.Timestamp
			
			if timeDelta > 0 then
				local currentPos = rootPart.Position
				
				-- Run movement detections
				local speedViolation = DetectionModules.Movement.CheckSpeed(player, currentPos, timeDelta)
				if speedViolation then
					self:FlagPlayer(player, speedViolation, speedViolation.Severity)
				end
				
				local teleportViolation = DetectionModules.Movement.CheckTeleport(player, currentPos, timeDelta)
				if teleportViolation then
					self:FlagPlayer(player, teleportViolation, teleportViolation.Severity)
				end
				
				local noclipViolation = DetectionModules.Movement.CheckNoclip(player, character, humanoid)
				if noclipViolation then
					self:FlagPlayer(player, noclipViolation, noclipViolation.Severity)
				end
				
				-- Update position cache
				AntiCheatData.Cache.LastPositions[userId] = {
					Position = currentPos,
					Timestamp = currentTime,
					Velocity = (currentPos - lastPosData.Position) / timeDelta
				}
			end
		end
		
		playerData.LastUpdate = os.time()
	end)
	
	-- Store connection for cleanup
	local playerData = AntiCheatData.Players[userId]
	if playerData then
		playerData.MonitorConnection = monitorConnection
	end
	
	-- Network monitoring
	coroutine.wrap(function()
		while playerData and playerData.IsActive do
			local ping = player:GetNetworkPing()
			-- Packet loss detection would require more complex implementation
			
			local networkViolation = DetectionModules.Network.CheckPacketManipulation(player, ping, 0)
			if networkViolation then
				self:FlagPlayer(player, networkViolation, networkViolation.Severity)
			end
			
			task.wait(5)
		end
	end)()
end

function AdvancedAntiCheat:SetupRemoteValidation()
	-- Create secure remote folder
	local secureFolder = Instance.new("Folder")
	secureFolder.Name = "AntiCheat_SecureRemotes"
	secureFolder.Parent = ReplicatedStorage
	
	-- Create validation remote
	local validationRemote = Instance.new("RemoteFunction")
	validationRemote.Name = "SecurityValidation"
	validationRemote.Parent = secureFolder
	
	validationRemote.OnServerInvoke = function(player, request, ...)
		local userId = player.UserId
		local playerData = AntiCheatData.Players[userId]
		
		if not playerData or not playerData.IsActive then
			return false
		end
		
		-- Check remote spam
		local spamViolation = DetectionModules.Network.CheckRemoteSpam(player, request)
		if spamViolation then
			self:FlagPlayer(player, spamViolation, spamViolation.Severity)
			return false
		end
		
		-- Handle different request types
		if request == "Heartbeat" then
			return {
				ServerTime = os.time(),
				SessionId = playerData.SessionId,
				Warnings = playerData.Warnings
			}
		elseif request == "ReportSuspiciousActivity" then
			local activityData = ...
			self:ProcessClientReport(player, activityData)
			return true
		elseif request == "ScriptScan" then
			-- Client reports its script environment
			local scanResults = ...
			local injectionViolation = self:AnalyzeClientScan(player, scanResults)
			if injectionViolation then
				self:FlagPlayer(player, injectionViolation, injectionViolation.Severity)
			end
			return true
		end
		
		return false
	end
end

function AdvancedAntiCheat:ProcessClientReport(player, activityData)
	local userId = player.UserId
	
	Utilities:Log(string.format("Client report from %s", player.Name), "DEBUG", activityData)
	
	-- Validate client report
	if activityData and activityData.Type then
		local violation = {
			Type = "ClientReported_" .. activityData.Type,
			ClientData = activityData
		}
		
		self:FlagPlayer(player, violation, "Medium")
	end
end

function AdvancedAntiCheat:AnalyzeClientScan(player, scanResults)
	if not scanResults then return false end
	
	-- Analyze for known exploit signatures
	local suspiciousCount = 0
	local suspiciousItems = {}
	
	if scanResults.Scripts then
		for _, script in ipairs(scanResults.Scripts) do
			-- Check for exploit signatures
			local exploitSignatures = {
				"infinite yield",
				"dex explorer",
				"dark dex",
				"synapse",
				"scriptware"
			}
			
			for _, signature in ipairs(exploitSignatures) do
				if script.Source and string.find(string.lower(script.Source), signature) then
					suspiciousCount += 1
					table.insert(suspiciousItems, {
						Name = script.Name,
						Signature = signature
					})
					break
				end
			end
		end
	end
	
	if suspiciousCount > 0 then
		return {
			Type = "ExploitInjection",
			Severity = "Critical",
			SuspiciousCount = suspiciousCount,
			SuspiciousItems = suspiciousItems
		}
	end
	
	return false
end

function AdvancedAntiCheat:FlagPlayer(player, violation, severity)
	local userId = player.UserId
	local playerData = AntiCheatData.Players[userId]
	
	if not playerData then return end
	
	-- Skip if whitelisted
	if playerData.IsWhitelisted then
		if CONFIG.DebugMode then
			Utilities:Log(string.format("Whitelisted player %s triggered detection (ignored)", player.Name), "DEBUG", violation)
		end
		return
	end
	
	-- Increment warning counter
	playerData.Warnings += 1
	
	-- Record violation
	local flagData = {
		Timestamp = os.time(),
		Type = violation.Type or "Unknown",
		Severity = severity or "Medium",
		Data = violation,
		WarningNumber = playerData.Warnings
	}
	
	table.insert(playerData.Flags, flagData)
	
	-- Update global stats
	AntiCheatData.Stats.TotalFlags += 1
	AntiCheatData.Stats.DetectionsByType[violation.Type] = (AntiCheatData.Stats.DetectionsByType[violation.Type] or 0) + 1
	
	-- Log the flag
	local logLevel = severity == "Critical" and "CRITICAL" or "WARN"
	Utilities:Log(string.format("🚨 %s flagged - Type: %s - Severity: %s - Warning %d/%d", 
		player.Name, violation.Type, severity, playerData.Warnings, CONFIG.Punishments.PermBanThreshold), 
		logLevel, violation)
	
	-- Send Discord alert for critical violations
	if severity == "Critical" and CONFIG.Discord.Enabled then
		Utilities:SendDiscordAlert(
			string.format("Critical violation detected: %s", player.Name),
			{
				UserId = userId,
				Type = violation.Type,
				Warnings = playerData.Warnings,
				Data = HttpService:JSONEncode(violation)
			}
		)
	end
	
	-- Take action based on warning count
	self:EvaluatePunishment(player, playerData, violation)
	
	-- Save to DataStore
	self:SavePlayerViolation(userId, flagData)
	
	-- Sync across servers
	if CONFIG.CrossServer.Enabled and CONFIG.CrossServer.SyncFlags then
		self:SendCrossServerMessage({
			Type = "Flag",
			UserId = userId,
			Violation = violation,
			Severity = severity
		})
	end
end

function AdvancedAntiCheat:EvaluatePunishment(player, playerData, violation)
	local warnings = playerData.Warnings
	
	if warnings >= CONFIG.Punishments.PermBanThreshold then
		-- Permanent ban
		local banReason = string.format("Permanent ban: %d security violations", warnings)
		self:BanPlayer(player, banReason, nil, violation)
		
	elseif warnings >= CONFIG.Punishments.TempBanThreshold then
		-- Temporary ban
		local banReason = string.format("Temporary ban: %d security violations", warnings)
		self:BanPlayer(player, banReason, CONFIG.Punishments.TempBanDuration, violation)
		
	elseif warnings >= CONFIG.Punishments.KickThreshold then
		-- Kick
		local kickReason = string.format("Kicked: %d security violations\nLatest: %s", warnings, violation.Type)
		self:KickPlayer(player, kickReason, violation)
		
	elseif warnings >= CONFIG.Punishments.WarningThreshold then
		-- Warn (already handled by logging)
		pcall(function()
			-- Send warning message to player
			local message = string.format("⚠️ Anti-Cheat Warning (%d/%d): Suspicious activity detected", 
				warnings, CONFIG.Punishments.KickThreshold)
			
			-- Could use a remote to show UI warning
		end)
	end
end

function AdvancedAntiCheat:KickPlayer(player, reason, violation)
	local userId = player.UserId
	
	Utilities:Log(string.format("👢 Kicking player %s: %s", player.Name, reason), "ALERT")
	
	-- Update stats
	AntiCheatData.Stats.TotalKicks += 1
	
	-- Log to DataStore
	local kickData = {
		UserId = userId,
		Name = player.Name,
		Reason = reason,
		Violation = violation,
		Timestamp = os.time(),
		Warnings = AntiCheatData.Players[userId] and AntiCheatData.Players[userId].Warnings or 0
	}
	
	Utilities.DataStoreOperation(CONFIG.DataStores.PlayerLogs, "Set", 
		string.format("Kick_%d_%d", userId, os.time()), kickData)
	
	-- Execute kick
	player:Kick(string.format("🛡️ Security System\n\n%s\n\nAppeal: %s", reason, CONFIG.Punishments.AppealLink))
end

function AdvancedAntiCheat:BanPlayer(player, reason, duration, violation)
	local userId = player.UserId
	
	local banType = duration and "Temporary" or "Permanent"
	Utilities:Log(string.format("⛔ %s ban for %s: %s", banType, player.Name, reason), "CRITICAL")
	
	-- Update stats
	AntiCheatData.Stats.TotalBans += 1
	
	-- Create ban record
	local banInfo = {
		BanId = HttpService:GenerateGUID(false),
		UserId = userId,
		Name = player.Name,
		Reason = reason,
		Violation = violation,
		BanDate = os.time(),
		ExpiryDate = duration and (os.time() + duration) or nil,
		Duration = duration,
		BannedBy = "System",
		Warnings = AntiCheatData.Players[userId] and AntiCheatData.Players[userId].Warnings or 0
	}
	
	-- Store in blacklist
	self.BlacklistedUsers[userId] = banInfo
	
	-- Save to DataStore
	Utilities.DataStoreOperation(CONFIG.DataStores.BanHistory, "Set", 
		string.format("Ban_%d_%d", userId, os.time()), banInfo)
	
	-- Sync across servers
	if CONFIG.CrossServer.Enabled and CONFIG.CrossServer.SyncBans then
		self:SendCrossServerMessage({
			Type = "Ban",
			UserId = userId,
			BanInfo = banInfo
		})
	end
	
	-- Execute ban (kick with ban message)
	player:Kick(string.format("⛔ YOU HAVE BEEN BANNED\n\nReason: %s\nBan ID: %s\n%s\n\nAppeal: %s",
		reason, banInfo.BanId,
		duration and string.format("Duration: %d hours", math.floor(duration / 3600)) or "Duration: PERMANENT",
		CONFIG.Punishments.AppealLink))
end

function AdvancedAntiCheat:IsPlayerWhitelisted(player)
	local userId = player.UserId
	
	-- Check manual whitelist
	if CONFIG.Whitelist.TrustedUserIds[userId] then
		return true
	end
	
	-- Check admin group
	if CONFIG.Whitelist.AutoWhitelistAdmins and CONFIG.Whitelist.AdminGroupId > 0 then
		local success, inGroup = pcall(function()
			return player:IsInGroup(CONFIG.Whitelist.AdminGroupId)
		end)
		
		if success and inGroup then
			return true
		end
	end
	
	-- Check if player has admin permissions
	if player:GetRankInGroup(CONFIG.Whitelist.AdminGroupId) >= 250 then
		return true
	end
	
	return false
end

function AdvancedAntiCheat:SendCrossServerMessage(data)
	if not CONFIG.CrossServer.Enabled or not MessagingService then
		return
	end
	
	pcall(function()
		MessagingService:PublishAsync(CONFIG.CrossServer.TopicName, HttpService:JSONEncode(data))
	end)
end

function AdvancedAntiCheat:SavePlayerViolation(userId, flagData)
	-- Queue for batch save
	if not self.ViolationQueue then
		self.ViolationQueue = {}
	end
	
	table.insert(self.ViolationQueue, {
		UserId = userId,
		FlagData = flagData
	})
	
	-- Process queue if it gets too large
	if #self.ViolationQueue >= 10 then
		self:ProcessViolationQueue()
	end
end

function AdvancedAntiCheat:ProcessViolationQueue()
	if not self.ViolationQueue or #self.ViolationQueue == 0 then
		return
	end
	
	local queue = self.ViolationQueue
	self.ViolationQueue = {}
	
	for _, item in ipairs(queue) do
		local key = string.format("Flag_%d_%d", item.UserId, item.FlagData.Timestamp)
		Utilities.DataStoreOperation(CONFIG.DataStores.SuspiciousActivity, "Set", key, item.FlagData)
	end
end

function AdvancedAntiCheat:LoadPlayerHistory(player)
	local userId = player.UserId
	
	-- Check for previous bans
	local success, banHistory = Utilities.DataStoreOperation(CONFIG.DataStores.BanHistory, "Get", 
		string.format("Ban_%d", userId))
	
	if success and banHistory then
		-- Player has previous bans
		local playerData = AntiCheatData.Players[userId]
		if playerData then
			playerData.HasPreviousBans = true
			playerData.BanHistory = banHistory
			
			-- Increase scrutiny for previously banned players
			playerData.IncreasedScrutiny = true
			
			Utilities:Log(string.format("Player %s has previous ban history", player.Name), "WARN")
		end
	end
end

function AdvancedAntiCheat:LoadSecurityData()
	-- Load known exploiters
	local success, data = Utilities.DataStoreOperation(CONFIG.DataStores.BanHistory, "Get", "BanList")
	if success and data then
		for userId, banInfo in pairs(data) do
			if not banInfo.ExpiryDate or banInfo.ExpiryDate > os.time() then
				self.BlacklistedUsers[tonumber(userId)] = banInfo
			end
		end
	end
end

function AdvancedAntiCheat:StartPeriodicTasks()
	-- Performance cleanup
	task.spawn(function()
		while true do
			task.wait(CONFIG.Performance.CleanupInterval)
			Utilities.CleanupOldData()
		end
	end)
	
	-- Process violation queue
	task.spawn(function()
		while true do
			task.wait(30)
			self:ProcessViolationQueue()
		end
	end)
	
	-- Save system metrics
	task.spawn(function()
		while true do
			task.wait(300) -- Every 5 minutes
			self:SaveSystemMetrics()
		end
	end)
	
	-- Update session statistics
	task.spawn(function()
		while true do
			task.wait(60)
			self:UpdateSessionStats()
		end
	end)
end

function AdvancedAntiCheat:SaveSystemMetrics()
	local metrics = {
		Timestamp = os.time(),
		TotalFlags = AntiCheatData.Stats.TotalFlags,
		TotalBans = AntiCheatData.Stats.TotalBans,
		TotalKicks = AntiCheatData.Stats.TotalKicks,
		ActivePlayers = #Players:GetPlayers(),
		TotalSessions = AntiCheatData.Sessions.TotalSessions,
		Uptime = os.time() - AntiCheatData.Stats.StartTime,
		DetectionsByType = AntiCheatData.Stats.DetectionsByType
	}
	
	Utilities.DataStoreOperation(CONFIG.DataStores.SystemMetrics, "Set", 
		string.format("Metrics_%d", os.time()), metrics)
end

function AdvancedAntiCheat:UpdateSessionStats()
	local totalTime = 0
	local sessionCount = 0
	
	for userId, playerData in pairs(AntiCheatData.Players) do
		if playerData.IsActive and playerData.JoinTime then
			totalTime += os.time() - playerData.JoinTime
			sessionCount += 1
		end
	end
	
	if sessionCount > 0 then
		AntiCheatData.Sessions.AverageSessionTime = totalTime / sessionCount
	end
end

function AdvancedAntiCheat:OnPlayerRemoving(player)
	local userId = player.UserId
	local playerData = AntiCheatData.Players[userId]
	
	if not playerData then return end
	
	Utilities:Log(string.format("Player left: %s (Session: %.1f minutes, Warnings: %d)", 
		player.Name, 
		(os.time() - playerData.JoinTime) / 60,
		playerData.Warnings), "INFO")
	
	-- Mark as inactive
	playerData.IsActive = false
	playerData.LeaveTime = os.time()
	
	-- Update active sessions
	AntiCheatData.Sessions.Active[userId] = nil
	
	-- Save session data
	local sessionData = {
		UserId = userId,
		Name = player.Name,
		JoinTime = playerData.JoinTime,
		LeaveTime = playerData.LeaveTime,
		Duration = playerData.LeaveTime - playerData.JoinTime,
		Warnings = playerData.Warnings,
		Flags = playerData.Flags,
		WasWhitelisted = playerData.IsWhitelisted
	}
	
	Utilities.DataStoreOperation(CONFIG.DataStores.PlayerLogs, "Set", 
		string.format("Session_%d_%d", userId, playerData.JoinTime), sessionData)
	
	-- Cleanup monitoring connection
	if playerData.MonitorConnection then
		playerData.MonitorConnection:Disconnect()
	end
	
	-- Process any remaining violations
	self:ProcessViolationQueue()
end

-- =======================================================
-- PUBLIC API
-- =======================================================

function AdvancedAntiCheat:GetPlayerStatus(player)
	local userId = player.UserId
	local playerData = AntiCheatData.Players[userId]
	
	if not playerData then
		return {
			IsMonitored = false,
			Error = "Player not found"
		}
	end
	
	return {
		IsMonitored = true,
		IsWhitelisted = playerData.IsWhitelisted,
		Warnings = playerData.Warnings,
		TotalFlags = #playerData.Flags,
		SessionTime = os.time() - playerData.JoinTime,
		RecentFlags = playerData.Flags
	}
end

function AdvancedAntiCheat:GetSystemStats()
	return {
		Version = self.Version,
		Uptime = os.time() - AntiCheatData.Stats.StartTime,
		TotalFlags = AntiCheatData.Stats.TotalFlags,
		TotalBans = AntiCheatData.Stats.TotalBans,
		TotalKicks = AntiCheatData.Stats.TotalKicks,
		ActivePlayers = #Players:GetPlayers(),
		ActiveMonitoredPlayers = self:GetActiveMonitoredCount(),
		DetectionsByType = AntiCheatData.Stats.DetectionsByType,
		AverageSessionTime = AntiCheatData.Sessions.AverageSessionTime
	}
end

function AdvancedAntiCheat:GetActiveMonitoredCount()
	local count = 0
	for _, data in pairs(AntiCheatData.Players) do
		if data.IsActive and not data.IsWhitelisted then
			count += 1
		end
	end
	return count
end

function AdvancedAntiCheat:ManualFlag(player, reason, severity)
	local violation = {
		Type = "ManualFlag",
		Reason = reason,
		ManualFlag = true
	}
	
	self:FlagPlayer(player, violation, severity or "High")
end

function AdvancedAntiCheat:WhitelistUser(userId, reason)
	CONFIG.Whitelist.TrustedUserIds[userId] = {
		AddedAt = os.time(),
		Reason = reason or "Manual whitelist"
	}
	
	-- Update existing player if online
	local player = Players:GetPlayerByUserId(userId)
	if player then
		local playerData = AntiCheatData.Players[userId]
		if playerData then
			playerData.IsWhitelisted = true
		end
	end
	
	Utilities:Log(string.format("User %d whitelisted: %s", userId, reason), "INFO")
end

function AdvancedAntiCheat:UnbanUser(userId, reason)
	self.BlacklistedUsers[userId] = nil
	
	Utilities:Log(string.format("User %d unbanned: %s", userId, reason), "INFO")
	
	-- Remove from DataStore
	Utilities.DataStoreOperation(CONFIG.DataStores.BanHistory, "Set", 
		string.format("Ban_%d", userId), nil)
end

-- =======================================================
-- RETURN INSTANCE
-- =======================================================

local AntiCheatInstance = AdvancedAntiCheat.new()
AntiCheatInstance:Initialize()

return AntiCheatInstance