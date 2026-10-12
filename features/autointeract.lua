-- ============================================================
-- ============  MODULE: AUTO INTERACT  =======================
-- ============================================================
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer

local AutoInteract = {}

local Config, Toggles, Hub, Elements, page
local connections = {}

local aiState = {
	enabled = false,
	loop = nil,
	distance = 12,
	cooldown = {},
	lastFire = 0,
}

-- ============================================================
-- НАСТРОЙКИ ИГНОРА
-- ============================================================

-- Префиксы имён (проверяем начало имени, регистронезависимо)
local IGNORE_PREFIXES = {
	"Regal",
	"Wardrobe",
	"Backdoor_Wardrobe",
	"RetroWardrobe",
	"Rooms_Locker",
	"Locker_Large",
	"CircularVent",
	"Dumpster",
	"Bed",
	"Double_Bed",
	"Painting",
	"Paintings",
	"PaintingsContainer",
	"PaintingFrame",
	"FakeDoor",
	"DoorFake",
	"SideroomSpace",
	"Hide",
	"Climb",
	"Rift",
	"Star",
	"Donate",
	"Dialogue",
	"Animate",
	"ToolEvent",
	"PropPrompt",
}

-- Жёсткие подстроки (проверяем в любом месте имени, регистронезависимо)
local IGNORE_SUBSTRINGS = {
	"painting",
	"paintings",
	"paint",
	"regal",
	"wardrobe",
	"hideprompt",
	"climbprompt",
	"fakedoor",
	"doorfake",
	"fireplace",
	"movingdoor",
	"wax_door",
}

-- Точные имена prompt'ов (полное совпадение)
local IGNORE_PROMPT_NAMES = {
	HidePrompt = true,
	ClimbPrompt = true,
	RiftPrompt = true,
	StarRiftPrompt = true,
	DonatePrompt = true,
	DialoguePrompt = true,
	RevivePrompt = true,
	EnterPrompt = true,
	AnimatePrompt = true,
	ToolEventPrompt = true,
	PropPrompt = true,
}

-- ============================================================
-- ХЕЛПЕРЫ
-- ============================================================
local function containsSubstring(name, substrings)
	if not name then return false end
	local lowerName = string.lower(name)
	for _, s in ipairs(substrings) do
		if string.find(lowerName, s, 1, true) then
			return true
		end
	end
	return false
end

local function startsWithPrefix(name, prefixes)
	if not name then return false end
	local lowerName = string.lower(name)
	for _, prefix in ipairs(prefixes) do
		if string.sub(lowerName, 1, #prefix) == string.lower(prefix) then
			return true
		end
	end
	return false
end

local function isIgnored(prompt)
	-- 1. по имени prompt'а (точное)
	if IGNORE_PROMPT_NAMES[prompt.Name] then return true end

	-- 2. fake prompt (для Infinite Items)
	if prompt:GetAttribute("FakePrompt") then return true end

	-- 3. имя самого prompt'а содержит запретную подстроку
	if containsSubstring(prompt.Name, IGNORE_SUBSTRINGS) then return true end

	-- 4. по всей цепочке родителей вверх (до 15 уровней)
	local current = prompt.Parent
	local depth = 0
	while current and depth < 15 do
		local name = current.Name

		-- точное совпадение по имени
		if IGNORE_PROMPT_NAMES[name] then return true end

		-- префикс
		if startsWithPrefix(name, IGNORE_PREFIXES) then return true end

		-- подстрока (жёстко)
		if containsSubstring(name, IGNORE_SUBSTRINGS) then return true end

		-- проверяем атрибуты (некоторые модели имеют атрибут с "paint")
		for attrName in pairs(current:GetAttributes()) do
			if string.find(string.lower(attrName), "paint", 1, true) then
				return true
			end
		end

		current = current.Parent
		depth = depth + 1
	end

	return false
end

local function firePrompt(prompt)
	if not prompt or not prompt.Parent then return end

	if fireproximityprompt then
		pcall(function() fireproximityprompt(prompt) end)
	else
		pcall(function()
			prompt:InputHoldBegin()
			task.wait(math.max(prompt.HoldDuration, 0.05))
			prompt:InputHoldEnd()
		end)
	end
end

-- ============================================================
-- ОСНОВНОЙ ЦИКЛ
-- ============================================================
local function runLoop()
	local char = player.Character
	if not char then return end

	local root = char:FindFirstChild("HumanoidRootPart")
	if not root then return end

	local myPos = root.Position
	local now = tick()

	-- throttle: не чаще 20 раз в секунду
	if now - aiState.lastFire < 0.05 then return end

	for _, prompt in ipairs(workspace:GetDescendants()) do
		if prompt:IsA("ProximityPrompt")
			and prompt.Enabled
			and not isIgnored(prompt)
		then
			local parent = prompt.Parent
			if parent then
				local pos
				if parent:IsA("BasePart") then
					pos = parent.Position
				elseif parent:IsA("Model") then
					local pp = parent.PrimaryPart or parent:FindFirstChildWhichIsA("BasePart")
					pos = pp and pp.Position
				end

				if pos then
					local dist = (pos - myPos).Magnitude
					if dist <= aiState.distance then
						-- анти-спам: не чаще 0.5 сек на один prompt
						local lastUse = aiState.cooldown[prompt] or 0
						if now - lastUse > 0.5 then
							aiState.cooldown[prompt] = now
							firePrompt(prompt)
							aiState.lastFire = now
							break  -- один prompt за тик
						end
					end
				end
			end
		end
	end
end

-- ============================================================
-- UI (page 3)
-- ============================================================
local function buildUI()
	page = Hub.Page(3)
	if not page then
		warn("[autointeract] page 3 не найдена")
		return
	end

	-- ============ AUTO INTERACT ============
	Elements.label(page, "AUTO INTERACT", 134)
	Hub.Toggles.autoInteract = Elements.switch(page, 132, function(on)
		aiState.enabled = on
		if on then
			if not aiState.loop then
				aiState.loop = RunService.Heartbeat:Connect(function()
					if not aiState.enabled then return end
					runLoop()
				end)
				table.insert(connections, aiState.loop)
			end
			print("[AUTO INTERACT] ON (dist=" .. aiState.distance .. ")")
		else
			print("[AUTO INTERACT] OFF")
		end
	end)

	-- ============ ДИСТАНЦИЯ ============
	Elements.label(page, "DISTANCE (5-30)", 154)
	local distVal = Elements.label(page, "Distance: 12", 170,
		{ color = Color3.fromRGB(255, 255, 255), size = 10 })

	Elements.slider(page, 186, 5, 30, 12, function(v)
		aiState.distance = math.floor(v)
		distVal.Text = "Distance: " .. aiState.distance
	end)

	-- ============ ИНФО ============
	Elements.label(page,
		"Ignores: Regal*, Wardrobe*, Painting*, Hide...",
		206,
		{ color = Color3.fromRGB(150, 150, 150), size = 9,
		  font = Enum.Font.Gotham })
end

-- ============================================================
-- INIT
-- ============================================================
function AutoInteract.init(hub)
	Hub = hub
	Config = hub.Config
	Toggles = hub.Toggles
	Elements = hub.Elements or (hub.Objects and hub.Objects.Elements)

	if not Elements then
		warn("[autointeract] Elements не найдены — ui.lua должен грузиться первым")
		return
	end

	-- UI
	buildUI()

	-- ============ CLEANUP ============
	function AutoInteract.cleanup()
		aiState.enabled = false
		aiState.cooldown = {}

		if aiState.loop then
			aiState.loop:Disconnect()
			aiState.loop = nil
		end

		for _, conn in ipairs(connections) do
			pcall(function() conn:Disconnect() end)
		end
		connections = {}
	end

	print("[AUTOINTERACT] Модуль инициализирован")
	return AutoInteract
end

return AutoInteract
