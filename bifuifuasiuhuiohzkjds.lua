--=====================================
-- Horst DONE Detector (Ngrok Version)
--=====================================

repeat task.wait() until game:IsLoaded()

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")

local player = Players.LocalPlayer

--------------------------------
-- CONFIG
--------------------------------

local SERVER = "http://171.99.152.42:5000"
local DELAY = 5
local RETRY_DELAY = 10
local MAX_RETRIES = 3

--------------------------------
-- STATE
--------------------------------

local DONE = false
local consecutiveErrors = 0
local lastSuccessTime = os.time()

--------------------------------
-- UTILITY FUNCTIONS
--------------------------------

local function safeRequest(data, retries)
	retries = retries or 0
	
	local ok, result = pcall(function()
		return request({
			Url = SERVER,
			Method = "POST",
			Headers = {
				["Content-Type"] = "application/json"
			},
			Body = HttpService:JSONEncode(data)
		})
	end)
	
	if ok then
		consecutiveErrors = 0
		lastSuccessTime = os.time()
		return true, result
	else
		consecutiveErrors = consecutiveErrors + 1
		
		-- Retry logic
		if retries < MAX_RETRIES then
			warn(string.format("⚠ Request failed (attempt %d/%d): %s", retries + 1, MAX_RETRIES, tostring(result)))
			task.wait(RETRY_DELAY)
			return safeRequest(data, retries + 1)
		else
			return false, result
		end
	end
end

--------------------------------
-- HOOK HORST DONE
--------------------------------

task.spawn(function()
	
	local hookAttempts = 0
	local maxHookAttempts = 60  -- Try for 60 seconds
	
	-- Wait for Horst to load
	while _G.Horst_AccountChangeDone == nil and hookAttempts < maxHookAttempts do
		task.wait(1)
		hookAttempts = hookAttempts + 1
	end
	
	if _G.Horst_AccountChangeDone == nil then
		warn("❌ Horst_AccountChangeDone not found after waiting")
		return
	end
	
	print("✅ Horst_AccountChangeDone found, hooking...")
	
	local original = _G.Horst_AccountChangeDone
	
	_G.Horst_AccountChangeDone = function(...)
		
		DONE = true
		
		print("🔥 Horst REAL DONE Detected")
		
		-- Immediately notify server
		task.spawn(function()
			local data = {
				user = player.Name,
				level = getLevel(),
				status = "DONE",
				time = os.time()
			}
			
			local success = safeRequest(data)
			
			if success then
				print("✅ DONE status sent to server")
			else
				warn("❌ Failed to send DONE status")
			end
		end)
		
		-- Call original function
		if original then
			return original(...)
		end
	end
	
	print("✅ Hook installed successfully")
end)

--------------------------------
-- GET LEVEL
--------------------------------

function getLevel()
	local stats = player:FindFirstChild("leaderstats")
	
	if stats and stats:FindFirstChild("Level") then
		return stats.Level.Value
	end
	
	return 0
end

--------------------------------
-- GET DATA
--------------------------------

local function getInfo()
	
	local data = {
		user = player.Name,
		level = getLevel(),
		status = DONE and "DONE" or "FARMING",
		time = os.time()
	}
	
	return data
end

--------------------------------
-- SEND
--------------------------------

local function send(data)
	
	local success, err = safeRequest(data)
	
	if success then
		print(string.format("✅ Sent: %s (Level %d)", data.status, data.level))
	else
		warn(string.format("❌ Error sending data: %s", tostring(err)))
		
		-- Alert if too many errors
		if consecutiveErrors >= MAX_RETRIES then
			warn(string.format("⚠ Server unreachable (%d consecutive errors)", consecutiveErrors))
		end
	end
end

--------------------------------
-- HEARTBEAT MONITOR
--------------------------------

task.spawn(function()
	while true do
		task.wait(60)  -- Check every minute
		
		local timeSinceLastSuccess = os.time() - lastSuccessTime
		
		if timeSinceLastSuccess > 120 then  -- 2 minutes
			warn(string.format("⚠ No successful requests in %d seconds", timeSinceLastSuccess))
		end
	end
end)

--------------------------------
-- MAIN LOOP
--------------------------------

task.spawn(function()
	
	print("🚀 Horst REAL Link Started (Ngrok Version)")
	print(string.format("📡 Server: %s", SERVER))
	print(string.format("👤 User: %s", player.Name))
	print(string.format("⏱ Update interval: %d seconds", DELAY))
	
	-- Initial send
	task.wait(2)
	local info = getInfo()
	send(info)
	
	-- Main loop
	while true do
		task.wait(DELAY)
		
		local info = getInfo()
		send(info)
	end
end)

--------------------------------
-- CLEANUP ON LEAVE
--------------------------------

game:GetService("Players").PlayerRemoving:Connect(function(playerWhoLeft)
	if playerWhoLeft == player then
		print("👋 Player leaving, sending final status...")
		
		local finalData = {
			user = player.Name,
			level = getLevel(),
			status = "OFFLINE",
			time = os.time()
		}
		
		safeRequest(finalData)
	end
end)

print("✅ Script loaded successfully (Ngrok Version)")
