--[[
	Project: RobloxAntiCheater
	File: project.luau (Main Module)
	Description: Client and server-side cheat detection system.
	Author: Base template for Brenninho-Stuff
]]

local AntiCheat = {}
AntiCheat.__index = AntiCheat

-- Roblox Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Security Configuration
local CONFIG = {
	MAX_SPEED = 100, -- Maximum allowed speed (studs/s)
	MAX_JUMP_POWER = 60,
	FLYING_CHECK_INTERVAL = 5, -- seconds
	TELEPORT_DISTANCE_THRESHOLD = 250 -- Distance considered suspicious teleport
}

-- Module Variables
local remoteEvent -- Will be created later
local playerData = {} -- Player data cache

--[[
	Function: Create Secure RemoteEvent
]]
local function setupRemotes()
	local remoteFolder = Instance.new("Folder")
	remoteFolder.Name = "AntiCheatRemotes"
	remoteFolder.Parent = ReplicatedStorage

	remoteEvent = Instance.new("RemoteEvent")
	remoteEvent.Name = "PingCheck"
	remoteEvent.Parent = remoteFolder
end

--[[
	Main AntiCheat Class
]]
function AntiCheat.new(player)
	local self = setmetatable({}, AntiCheat)
	self.Player = player
	self.Character = nil
	self.LastPosition = nil
	self.Warnings = 0
	self.IsBeingWatched = false
	
	-- Event Connections
	self.Connections = {}
	
	return self
end

--[[
	Start monitoring for a specific player
]]
function AntiCheat:StartMonitoring()
	local player = self.Player
	
	-- Wait for character to load
	local function onCharacterAdded(character)
		self.Character = character
		self.LastPosition = character:GetPivot().Position
		
		-- Connect to Heartbeat for per-frame checks
		local heartbeatConnection = RunService.Heartbeat:Connect(function()
			self:CheckSpeedAndFlight()
		end)
		table.insert(self.Connections, heartbeatConnection)
		
		-- Check for suspicious Humanoid changes
		local humanoid = character:WaitForChild("Humanoid")
		local humanoidConnection = humanoid:GetPropertyChangedSignal("JumpPower"):Connect(function()
			if humanoid.JumpPower > CONFIG.MAX_JUMP_POWER and not self.IsBeingWatched then
				self:FlagPlayer("Exploit: High Jump Power (" .. humanoid.JumpPower .. ")")
			end
		end)
		table.insert(self.Connections, humanoidConnection)
	end
	
	-- If character already exists
	if player.Character then
		onCharacterAdded(player.Character)
	end
	
	-- Connect respawn event
	local charAddConn = player.CharacterAdded:Connect(onCharacterAdded)
	table.insert(self.Connections, charAddConn)
	
	-- Teleport Check (Server-side)
	local teleportCheckConn
	teleportCheckConn = RunService.Heartbeat:Connect(function()
		if self.Character and self.Character.PrimaryPart then
			local currentPos = self.Character.PrimaryPart.Position
			if self.LastPosition then
				local distance = (currentPos - self.LastPosition).Magnitude
				-- If distance is huge and player isn't in a vehicle/seated
				if distance > CONFIG.TELEPORT_DISTANCE_THRESHOLD and not self.Character:FindFirstChildWhichIsA("Seat") then
					local humanoid = self.Character:FindFirstChildWhichIsA("Humanoid")
					if humanoid and humanoid.SeatPart == nil then
						self:FlagPlayer("Suspicious Teleport (" .. math.floor(distance) .. " studs)")
					end
				end
			end
			self.LastPosition = currentPos
		end
	end)
	table.insert(self.Connections, teleportCheckConn)
end

--[[
	Check Speed and Flight (Client-side check corroborated by Server)
]]
function AntiCheat:CheckSpeedAndFlight()
	if not self.Character or not self.Character.PrimaryPart then return end
	
	local root = self.Character.PrimaryPart
	local velocity = root.AssemblyLinearVelocity
	
	-- Ignore Y axis to check horizontal speed (Fly/Speed Hacks)
	local horizontalSpeed = Vector2.new(velocity.X, velocity.Z).Magnitude
	
	if horizontalSpeed > CONFIG.MAX_SPEED then
		-- Small buffer to avoid detecting explosion knockback
		task.wait(0.5)
		local newVelocity = root.AssemblyLinearVelocity
		local newSpeed = Vector2.new(newVelocity.X, newVelocity.Z).Magnitude
		
		if newSpeed > CONFIG.MAX_SPEED then
			self:FlagPlayer("Speed Hack Detected (" .. math.floor(horizontalSpeed) .. " studs/s)")
		end
	end
	
	-- Simple "Fly" check (if Y changes too much without jumping or falling)
	-- Note: Basic implementation, can be refined with Raycast
	if self.Character:FindFirstChildWhichIsA("Humanoid") then
		local humanoid = self.Character:FindFirstChildWhichIsA("Humanoid")
		if humanoid.FloorMaterial == Enum.Material.Air and velocity.Y > 20 and not humanoid.Jump then
			self:FlagPlayer("Possible Fly Hack")
		end
	end
end

--[[
	Flag player as suspicious and take action
]]
function AntiCheat:FlagPlayer(reason)
	self.Warnings += 1
	self.IsBeingWatched = true
	
	local logData = {
		Player = self.Player.Name,
		UserId = self.Player.UserId,
		Reason = reason,
		Warnings = self.Warnings,
		Timestamp = os.time()
	}
	
	-- Server Log
	warn("[ANTI-CHEAT] Flagged: ", HttpService:JSONEncode(logData))
	
	-- Action based on warning count
	if self.Warnings >= 3 then
		-- Kick or Ban (here we just kick)
		self.Player:Kick("Kicked by Anti-Cheat System. Reason: " .. reason)
		
		-- Option to notify admins via Webhook or System Message
		-- self:NotifyAdmins(logData)
	end
end

--[[
	Clean up connections when player leaves
]]
function AntiCheat:Destroy()
	for _, conn in ipairs(self.Connections) do
		conn:Disconnect()
	end
	playerData[self.Player] = nil
end

-- =======================================================
-- SERVER-SIDE INITIALIZATION (Server Script)
-- =======================================================

if RunService:IsServer() then
	setupRemotes()
	
	-- Connect joining players
	Players.PlayerAdded:Connect(function(player)
		local monitor = AntiCheat.new(player)
		playerData[player] = monitor
		monitor:StartMonitoring()
		
		-- Cleanup when leaving
		player.AncestryChanged:Connect(function()
			if not player:IsDescendantOf(Players) then
				monitor:Destroy()
			end
		end)
	end)
	
	-- Handle existing players (for Hot Reload)
	for _, player in ipairs(Players:GetPlayers()) do
		local monitor = AntiCheat.new(player)
		playerData[player] = monitor
		monitor:StartMonitoring()
	end
	
	print("🛡️ RobloxAntiCheater System Loaded Successfully.")
else
	-- =======================================================
	-- CLIENT-SIDE SECURITY (Local Script - Optional)
	-- =======================================================
	-- This block prevents client from running server code
	-- and can be used to send response pings.
	
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local remoteFolder = ReplicatedStorage:WaitForChild("AntiCheatRemotes")
	local pingRemote = remoteFolder:WaitForChild("PingCheck")
	
	-- Respond to ping to prove local script wasn't disabled
	pingRemote.OnClientEvent:Connect(function()
		pingRemote:FireServer("Pong")
	end)
end

return AntiCheat