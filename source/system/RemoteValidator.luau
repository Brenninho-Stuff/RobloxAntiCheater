--[[
	RemoteValidator.luau
	Description: Validates and secures remote events/functions
	Path: source/system/RemoteValidator.luau
]]

local RemoteValidator = {}
RemoteValidator.__index = RemoteValidator

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local CONFIG = {}
local ValidatedRemotes = {}
local RemoteCache = {}

-- Rate limiting
local RateLimits = {}
local MAX_CALLS_PER_SECOND = 10

function RemoteValidator:Initialize(config)
	CONFIG = config
	
	-- Create secure remote folder
	local secureFolder = Instance.new("Folder")
	secureFolder.Name = "SecureRemotes"
	secureFolder.Parent = ReplicatedStorage
	
	print("🔐 RemoteValidator Initialized")
end

function RemoteValidator:CreateSecureRemote(name, validationFunction)
	local remoteEvent = Instance.new("RemoteEvent")
	remoteEvent.Name = name
	remoteEvent.Parent = ReplicatedStorage:WaitForChild("SecureRemotes")
	
	ValidatedRemotes[name] = {
		Event = remoteEvent,
		Validator = validationFunction or function(...) return true end
	}
	
	-- Server-side handler
	remoteEvent.OnServerEvent:Connect(function(player, ...)
		if not self:ValidateCall(player, name, ...) then
			return
		end
		
		-- Rate limiting check
		if not self:CheckRateLimit(player, name) then
			local SecurityManager = require(script.Parent:WaitForChild("SecurityManager"))
			SecurityManager:FlagPlayer(player, "Remote spam detected: " .. name, "Medium")
			return
		end
		
		-- Call the actual handler if validation passes
		local handler = RemoteCache[name]
		if handler then
			handler(player, ...)
		end
	end)
	
	return remoteEvent
end

function RemoteValidator:ValidateCall(player, remoteName, ...)
	local remoteData = ValidatedRemotes[remoteName]
	if not remoteData then
		warn("⚠️ Attempt to fire unregistered remote: " .. remoteName)
		return false
	end
	
	-- Run custom validator
	local success, result = pcall(remoteData.Validator, player, ...)
	if not success or not result then
		warn(string.format("❌ Remote validation failed for %s - Player: %s", remoteName, player.Name))
		return false
	end
	
	return true
end

function RemoteValidator:CheckRateLimit(player, remoteName)
	local key = player.UserId .. "_" .. remoteName
	local now = os.time()
	
	if not RateLimits[key] then
		RateLimits[key] = {
			Count = 1,
			LastReset = now
		}
		return true
	end
	
	local limit = RateLimits[key]
	
	if now - limit.LastReset >= 1 then
		limit.Count = 1
		limit.LastReset = now
		return true
	end
	
	limit.Count += 1
	return limit.Count <= MAX_CALLS_PER_SECOND
end

function RemoteValidator:RegisterHandler(remoteName, handler)
	RemoteCache[remoteName] = handler
end

-- Example validation functions
function RemoteValidator.Validators.IsAlive(player)
	return player and player.Character and player.Character:FindFirstChild("Humanoid") and player.Character.Humanoid.Health > 0
end

function RemoteValidator.Validators.HasTool(player, toolName)
	local character = player.Character
	if not character then return false end
	
	for _, item in ipairs(character:GetChildren()) do
		if item:IsA("Tool") and item.Name == toolName then
			return true
		end
	end
	
	return false
end

function RemoteValidator.Validators.IsInRange(player, position, maxDistance)
	local character = player.Character
	if not character or not character.PrimaryPart then return false end
	
	local distance = (character.PrimaryPart.Position - position).Magnitude
	return distance <= maxDistance
end

return RemoteValidator
