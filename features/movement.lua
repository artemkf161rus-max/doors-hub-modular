local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local player = Players.LocalPlayer

local Movement = {}

local Config
local Toggles
local Hub
local Elements
local page

local connections = {}

local speedState = { enabled = false, value = 16, bv = nil, loop = nil }
local fovState   = { enabled = false, value = 70, loop = nil }
local fbState    = { enabled = false, saved = {} }

local function track(conn)
	table.insert(connections, conn)
	return conn
end

------------------------------------------------------------
-- SPEED
------------------------------------------------------------
local function cleanupSpeed()
	if speedState.loop then speedState.loop:Disconnect() speedState.loop = nil end
	if speedState.bv and speedState.bv.Parent then speedState.bv:Destroy() end
	speedState.bv = nil

	local char = player.Character
	if char then
		local hum = char:FindFirstChildOfClass("Humanoid")
		if hum then hum.WalkSpeed = Config.FAKE_SPEED end
		local root = char:FindFirstChild("HumanoidRootPart")
		if root then root.CustomPhysicalProperties = nil end
	end
end

local function applySpeed()
	local char = player.Character
	if not char then return end
	local root = char:FindFirstChild("HumanoidRootPart")
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not root or not hum then return end

	hum.WalkSpeed = Config.FAKE_SPEED

	if not speedState.bv or not speedState.bv.Parent then
		speedState.bv = Instance.new("BodyVelocity")
		speedState.bv.MaxForce = Vector3.new(1e5, 0, 1e5)
		speedState.bv.P = 1e5
		speedState.bv.Parent = root
	end

	root.CustomPhysicalProperties = PhysicalProperties.new(0.7, 0.3, 0.5, 1, 1)

	if not speedState.loop then
		speedState.loop = RunService.Heartbeat:Connect(function()
			if not speedState.enabled then return end
			local c = player.Character
			if not c then return end
			local h = c:FindFirstChildOfClass("Humanoid")
			if not h or not speedState.bv or not speedState.bv.Parent then return end
			local md = h.MoveDirection
			speedState.bv.Velocity = md.Magnitude > 0 and md * speedState.value or Vector3.zero
		end)
		track(speedState.loop)
	end
end

------------------------------------------------------------
-- FOV
------------------------------------------------------------
local function cleanupFOV()
	if fovState.loop then fovState.loop:Disconnect() fovState.loop = nil end
	local cam = workspace.CurrentCamera
	if cam then cam.FieldOfView = Config.FOV_DEFAULT end
end

local function applyFOV()
	local cam = workspace.CurrentCamera
	if cam then cam.FieldOfView = fovState.value end

	if not fovState.loop then
		fovState.loop = RunService.RenderStepped:Connect(function()
			if not fovState.enabled then return end
			local c = workspace.CurrentCamera
			if c and c.FieldOfView ~= fovState.value then
				c.FieldOfView = fovState.value
			end
		end)
		track(fovState.loop)
	end
end

------------------------------------------------------------
-- FULLBRIGHT
------------------------------------------------------------
local function applyFullbright()
	if not fbState.saved.saved then
		fbState.saved.Ambient        = Lighting.Ambient
		fbState.saved.OutdoorAmbient = Lighting.OutdoorAmbient
		fbState.saved.Brightness     = Lighting.Brightness
		fbState.saved.ClockTime      = Lighting.ClockTime
		fbState.saved.GlobalShadows  = Lighting.GlobalShadows
		fbState.saved.FogEnd         = Lighting.FogEnd
		fbState.saved.saved = true
	end

	Lighting.Ambient        = Color3.fromRGB(178, 178, 178)
	Lighting.OutdoorAmbient = Color3.fromRGB(178, 178, 178)
	Lighting.Brightness     = 3
	Lighting.ClockTime      = 12
	Lighting.GlobalShadows  = false
	Lighting.FogEnd         = 100000
end

local function cleanupFullbright()
	if fbState.saved.saved then
		Lighting.Ambient        = fbState.saved.Ambient
		Lighting.OutdoorAmbient = fbState.saved.OutdoorAmbient
		Lighting.Brightness     = fbState.saved.Brightness
		Lighting.ClockTime      = fbState.saved.ClockTime
		Lighting.GlobalShadows  = fbState.saved.GlobalShadows
		Lighting.FogEnd         = fbState.saved.FogEnd
		fbState.saved = {}
	end
end

------------------------------------------------------------
-- UI (page 1)
------------------------------------------------------------
local function buildUI()
	page = Hub.Page(1)
	if not page then
		warn("[movement] page 1 не найдена")
		return
	end

	-- WALKSPEED
	Elements.label(page, "WALKSPEED (16-150)", 2)
	local wsVal = Elements.label(page, "REAL 16 / FAKE 15", 18,
		{ color = Color3.fromRGB(255, 255, 255), size = 10 })

	Elements.slider(page, 36, Config.MIN_SPEED, Config.MAX_SPEED,
		Config.REAL_SPEED_DEFAULT, function(v)
			local iv = math.floor(v + 0.5)
			speedState.value = iv
			wsVal.Text = "REAL " .. iv .. " / FAKE " .. Config.FAKE_SPEED
		end)

	Elements.label(page, "ENABLE SPEED", 66)
	Hub.Toggles.speed = Elements.switch(page, 64, function(on)
		speedState.enabled = on
		if on then applySpeed() else cleanupSpeed() end
	end)

	-- FOV
	Elements.label(page, "FOV ENABLE", 86)
	local fovVal = Elements.label(page, "FOV: " .. Config.FOV_DEFAULT, 104,
		{ color = Color3.fromRGB(255, 255, 255), size = 10 })

	Elements.slider(page, 120, Config.FOV_MIN, Config.FOV_MAX,
		Config.FOV_DEFAULT, function(v)
			fovState.value = math.floor(v)
			fovVal.Text = "FOV: " .. fovState.value
		end)

	Hub.Toggles.fov = Elements.switch(page, 84, function(on)
		fovState.enabled = on
		if on then applyFOV() else cleanupFOV() end
	end)

	-- FULLBRIGHT
	Elements.label(page, "FULLBRIGHT", 138)
	Hub.Toggles.fullbright = Elements.switch(page, 136, function(on)
		fbState.enabled = on
		if on then applyFullbright() else cleanupFullbright() end
	end)
end

------------------------------------------------------------
-- INIT
------------------------------------------------------------
function Movement.init(hub)
	Hub = hub
	Config = hub.Config
	Toggles = hub.Toggles
	Elements = hub.Elements or (hub.Objects and hub.Objects.Elements)

	if not Elements then
		warn("[movement] Elements не найдены — ui.lua должен грузиться первым")
		return
	end

	buildUI()

	track(player.CharacterAdded:Connect(function()
		task.wait(1)
		if speedState.enabled then
			cleanupSpeed()
			applySpeed()
		end
	end))

	function Movement.cleanup()
		speedState.enabled = false
		fovState.enabled = false
		fbState.enabled = false

		cleanupSpeed()
		cleanupFOV()
		cleanupFullbright()

		for _, conn in ipairs(connections) do
			pcall(function() conn:Disconnect() end)
		end
		connections = {}
	end

	print("[MOVEMENT] Модуль инициализирован")
	return Movement
end

return Movement
