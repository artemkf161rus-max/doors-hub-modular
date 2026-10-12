-- ============================================================
-- ============  MODULE: AUTO INTERACT  =======================
-- ============================================================
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local player = Players.LocalPlayer

local AutoInteract = {}

-- ==================== STATE ====================
local Config
local Toggles
local Hub
local Elements
local page

local connections = {}

-- состояние
local aiState = {
	enabled = false,
	loop = nil,
	distance = 12,           -- радиус активации
	cooldown = {},           -- [prompt] = tick() — анти-спам
	lastFire = 0,
	ignoreBack = false,      -- если true — только prompts в поле зрения
}

-- ============================================================
-- НАСТРОЙКИ ИГНОРА
-- ============================================================

-- Игнор по имени родителя (начало имени)
local IGNORE_PREFIXES = {
	"Regal",      -- Regal / RegalDoor / Regal*
	"Wardrobe",   -- Wardrobe / Wardrobe-FOOLS26
	"Backdoor_Wardrobe",
	"RetroWardrobe",
	"Rooms_Locker",       -- на всякий
	"Locker_Large",
	"CircularVent",
	"Dumpster",
	"Bed",                -- кровати тоже не трогаем
	"Double_Bed",
	"HidePrompt",         -- само hiding
	"Hide",
}

-- Игнор по имени самого prompt'а (точное совпадение)
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
}

-- ============================================================
-- ХЕЛПЕРЫ
-- ============================================================
local function getPlayerPos()
	local char = player.Character
	if not char then return nil end
	local root = char:FindFirstChild("HumanoidRootPart")
	return root and root.Position
end

local function startsWith(str, prefix)
	return string.sub(str, 1, #prefix) == prefix
end

local function isIgnoredByPrefix(name)
	for _, prefix in ipairs(IGNORE_PREFIXES) do
		if startsWith(name, prefix) then
			return true
		end
	end
	return false
end

local function getPromptParent(prompt)
	local parent = prompt.Parent
	if not parent then return nil end
	return parent
end

local function isIgnored(prompt)
	-- 1. по имени prompt'а
	if IGNORE_PROMPT_NAMES[prompt.Name] then return true end

	-- 2. по имени родителя (точное или префикс)
	local parent = getPromptParent(prompt)
	if not parent then return true end

	local parentName = parent.Name

	-- 2a. точное совпадение по имени родителя
	if IGNORE_PROMPT_NAMES[parentName] then return true end

	-- 2b. префикс (Regal, Wardrobe, ...)
	if isIgnoredByPrefix(parentName) then return true end

	-- 2c. если родитель — Model, проверяем ещё и родителей выше
	if parent:IsA("Model") then
		local grand = parent.Parent
		if grand and grand.Name then
			if IGNORE_PROMPT_NAMES[grand.Name] then return true end
			if isIgnoredByPrefix(grand.Name) then return true end
		end
	end

	-- 3. если fake prompt — тоже пропускаем (это для Infinite Items)
	if prompt:GetAttribute("FakePrompt") then return true end

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

	-- не чаще 20 раз в секунду
	if now - aiState.lastFire < 0.05 then return end

	-- перебираем все prompts
	for _, prompt in ipairs(workspace:GetDescendants()) do
		if prompt:IsA("ProximityPrompt")
			and prompt.Enabled
			and not isIgnored(prompt)
		then
			-- позиция prompt'а
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
						-- проверка на cooldown (не спамим один и тот же prompt)
						local lastUse = aiState.cooldown[prompt] or 0
						if now - lastUse > 0.5 then
							aiState.cooldown[prompt] = now
							firePrompt(prompt)
							aiState.lastFire = now
							-- после активации одного prompt выходим из цикла
							-- чтобы не активировать всё сразу
							break
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

	-- ============ IGNORE INFO ============
	Elements.label(page,
		"Ignores: Regal*, Wardrobe*, Hide, Climb",
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
