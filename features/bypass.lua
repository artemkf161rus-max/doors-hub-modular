local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer

local Bypass = {}

-- ==================== STATE ====================
local Config
local Toggles
local Hub
local Elements
local page

local connections = {}

-- state
local anticheatDisabled = false
local bypassState = { enabled = false }
local doorState   = { enabled = false, loop = nil }

local function track(conn)
	table.insert(connections, conn)
	return conn
end

------------------------------------------------------------
-- ANTICHEAT BYPASS
------------------------------------------------------------
local remotes = ReplicatedStorage:FindFirstChild("RemotesFolder")
	or ReplicatedStorage:WaitForChild("RemotesFolder", 10)

local climbLadder = remotes and remotes:FindFirstChild("ClimbLadder")

local function setupBypass(char)
	if not char then char = player.Character end
	if not char then return end
	if not remotes then return end

	-- подписка на атрибут Climbing
	track(char:GetAttributeChangedSignal("Climbing"):Connect(function()
		if not bypassState.enabled then return end
		if char:GetAttribute("Climbing") ~= true then return end

		task.wait(0.25)

		if char:GetAttribute("Climbing") == true then
			char:SetAttribute("Climbing", false)
			if climbLadder then
				pcall(function() climbLadder:FireServer() end)
			end
			anticheatDisabled = true
			print("[BYPASS] Anticheat disabled")
		end
	end))
end

-- слушаем события, которые сбрасывают флаг anticheatDisabled
local function watchResetEvents()
	if not remotes then return end

	local cutscene = remotes:FindFirstChild("Cutscene")
	if cutscene then
		track(cutscene.OnClientEvent:Connect(function(name)
			if anticheatDisabled and not tostring(name):find("SewerSeek") then
				anticheatDisabled = false
			end
		end))
	end

	local enemy = remotes:FindFirstChild("UseEnemyModule")
	if enemy then
		track(enemy.OnClientEvent:Connect(function(m)
			if m == "Void" or m == "Glitch" then
				anticheatDisabled = false
			end
		end))
	end
end

------------------------------------------------------------
-- DOOR REACH
------------------------------------------------------------
local function startDoorLoop()
	if doorState.loop then return end

	doorState.loop = RunService.Heartbeat:Connect(function()
		if not doorState.enabled then return end

		local char = player.Character
		if not char then return end
		local root = char:FindFirstChild("HumanoidRootPart")
		if not root then return end
		local myPos = root.Position

		for _, obj in ipairs(workspace:GetDescendants()) do
			if obj.Name == "ClientOpen" and obj:IsA("RemoteEvent") then
				local door = obj.Parent
				if door and door:FindFirstChild("Door") then
					local doorPart = door.Door
					if (doorPart.Position - myPos).Magnitude < 75 then
						pcall(function() obj:FireServer() end)
					end
				end
			end
		end
	end)
	track(doorState.loop)
end

local function stopDoorLoop()
	if doorState.loop then
		doorState.loop:Disconnect()
		doorState.loop = nil
	end
end

------------------------------------------------------------
-- UI (page 3)
------------------------------------------------------------
local function buildUI()
	page = Hub.Page(3)
	if not page then
		warn("[bypass] page 3 не найдена")
		return
	end

	-- ============ ANTICHEAT BYPASS ============
	Elements.label(page, "ANTICHEAT BYPASS", 2)

	local bypHint = Elements.label(page, "Климб лестницу", 18,
		{ color = Color3.fromRGB(180, 180, 180), size = 9,
		  font = Enum.Font.Gotham })

	Hub.Toggles.bypass = Elements.switch(page, 0, function(on)
		bypassState.enabled = on
		if on then
			if player.Character then setupBypass(player.Character) end
			print("[BYPASS] Enabled — climb a ladder")
		else
			anticheatDisabled = false
			print("[BYPASS] Disabled")
		end
	end)

	-- ============ DOOR REACH ============
	Elements.label(page, "DOOR REACH", 34)
	Hub.Toggles.doorReach = Elements.switch(page, 32, function(on)
		doorState.enabled = on
		if on then startDoorLoop() else stopDoorLoop() end
	end)
end

------------------------------------------------------------
-- INIT
------------------------------------------------------------
function Bypass.init(hub)
	Hub = hub
	Config = hub.Config
	Toggles = hub.Toggles
	Elements = hub.Elements or (hub.Objects and hub.Objects.Elements)

	if not Elements then
		warn("[bypass] Elements не найдены — ui.lua должен грузиться первым")
		return
	end

	-- UI
	buildUI()

	-- следим за событиями сброса
	watchResetEvents()

	-- подписка на респавн
	track(player.CharacterAdded:Connect(function(char)
		task.wait(1)
		if bypassState.enabled then
			setupBypass(char)
		end
	end))

	-- ============ CLEANUP ============
	function Bypass.cleanup()
		bypassState.enabled = false
		doorState.enabled = false
		anticheatDisabled = false

		stopDoorLoop()

		for _, conn in ipairs(connections) do
			pcall(function() conn:Disconnect() end)
		end
		connections = {}
	end

	print("[BYPASS] Модуль инициализирован")
	return Bypass
end

return Bypass
