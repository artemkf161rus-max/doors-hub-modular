-- ============================================================
-- ============  MODULE: BYPASS (Obsidian)  ===================
-- ============================================================
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer

local Bypass = {}

-- ==================== STATE ====================
local Config
local Toggles
local Options
local Hub
local Tabs

local connections = {}

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
-- UI (Obsidian Groupbox)
------------------------------------------------------------
local function buildUI()
	local ExploitsTab = Tabs.Exploits
	if not ExploitsTab then
		warn("[bypass] нет таба Exploits")
		return
	end

	local group = ExploitsTab:AddLeftGroupbox("Bypass")

	-- ============ ANTICHEAT BYPASS ============
	group:AddToggle("BypassAnticheat", {
		Text = "Anticheat Bypass",
		Default = false,
		Tooltip = "Климб на лестнице — отключит античит",
	})

	Toggles.BypassAnticheat:OnChanged(function(Value)
		bypassState.enabled = Value
		if Value then
			if player.Character then setupBypass(player.Character) end
			print("[BYPASS] Enabled — climb a ladder")
		else
			anticheatDisabled = false
			print("[BYPASS] Disabled")
		end
	end)

	group:AddLabel("Климб лестницу"):AddColorPicker("BypassHintColor", {
		Default = Color3.fromRGB(180, 180, 180),
	})

	-- ============ DOOR REACH ============
	group:AddDivider()

	group:AddToggle("DoorReach", {
		Text = "Door Reach",
		Default = false,
		Tooltip = "Авто-открытие дверей в радиусе 75 студов",
	})

	Toggles.DoorReach:OnChanged(function(Value)
		doorState.enabled = Value
		if Value then startDoorLoop() else stopDoorLoop() end
	end)

	group:AddSlider("DoorReachRange", {
		Text = "Дальность",
		Min = 20, Max = 200, Default = 75,
		Rounding = 0,
		Compact = true,
	})

	Options.DoorReachRange:OnChanged(function(Value)
		-- можно использовать для изменения радиуса (опционально)
	end)
end

------------------------------------------------------------
-- INIT
------------------------------------------------------------
function Bypass.init(hub)
	Hub = hub
	Config = hub.Config
	Toggles = hub.Toggles
	Options = hub.Options
	Tabs = hub.Tabs

	if not Tabs then
		warn("[bypass] Tabs не найдены — Obsidian UI не загружен")
		return
	end

	buildUI()
	watchResetEvents()

	track(player.CharacterAdded:Connect(function(char)
		task.wait(1)
		if bypassState.enabled then
			setupBypass(char)
		end
	end))

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

	print("[BYPASS] Модуль инициализирован (Obsidian)")
	return Bypass
end

return Bypass
