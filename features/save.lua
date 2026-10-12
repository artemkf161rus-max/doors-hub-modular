-- ============================================================
-- ============  MODULE: SAVE CONFIG (COMPACT)  ===============
-- ============================================================
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local player = Players.LocalPlayer

local Save = {}

local Config, Toggles, Hub, Elements, page
local connections = {}

local CONFIG_FILE = "hub_config.json"

local saveState = {
	enabled = true,
	loaded = false,
	lastSave = 0,
	saveDelay = 2,
	values = {},
	subscriptions = {},
}

-- ============================================================
-- FS HELPERS
-- ============================================================
local function hasFs()
	return writefile and readfile and isfile
end

local function fileExists(name)
	if isfile then
		local ok, result = pcall(isfile, name)
		return ok and result
	end
	return false
end

-- ============================================================
-- REGISTER
-- ============================================================
function Save.register(key, getter, setter)
	saveState.subscriptions[key] = { get = getter, set = setter }
end

function Save.unregister(key)
	saveState.subscriptions[key] = nil
end

-- ============================================================
-- SAVE / LOAD
-- ============================================================
local function collectValues()
	local data = {}
	for key, sub in pairs(saveState.subscriptions) do
		if sub and sub.get then
			local ok, value = pcall(sub.get)
			if ok then data[key] = value end
		end
	end
	return data
end

function Save.save()
	if not hasFs() then
		warn("[SAVE] Executor не поддерживает writefile")
		return false
	end

	local data = collectValues()
	data._version = 1
	data._savedAt = os.time()

	local ok, encoded = pcall(function()
		return HttpService:JSONEncode(data)
	end)
	if not ok then return false end

	local writeOk = pcall(function()
		writefile(CONFIG_FILE, encoded)
	end)
	if not writeOk then return false end

	saveState.lastSave = tick()
	print("[SAVE] Сохранено: " .. CONFIG_FILE .. " (" .. tostring(#encoded) .. " байт)")
	return true
end

function Save.load()
	if not hasFs() then return false end
	if not fileExists(CONFIG_FILE) then
		print("[SAVE] Файл не найден — используется дефолт")
		return false
	end

	local readOk, content = pcall(function() return readfile(CONFIG_FILE) end)
	if not readOk or not content then return false end

	local decodeOk, data = pcall(function()
		return HttpService:JSONDecode(content)
	end)
	if not decodeOk or type(data) ~= "table" then return false end

	local applied = 0
	for key, sub in pairs(saveState.subscriptions) do
		if sub and sub.set and data[key] ~= nil then
			local ok = pcall(sub.set, data[key])
			if ok then applied = applied + 1 end
		end
	end

	saveState.loaded = true
	print("[SAVE] Загружено: " .. applied .. " настроек")
	return true
end

function Save.reset()
	if hasFs() and fileExists(CONFIG_FILE) then
		pcall(function() writefile(CONFIG_FILE, "{}") end)
		print("[SAVE] Файл сброшен")
	end
end

function Save.deleteFile()
	if hasFs() and fileExists(CONFIG_FILE) then
		pcall(function() writefile(CONFIG_FILE, "{}") end)
	end
end

-- ============================================================
-- AUTO-SAVE LOOP
-- ============================================================
local function startAutoSave()
	if not hasFs() then return end
	local lastSnapshot = ""

	task.spawn(function()
		while true do
			task.wait(saveState.saveDelay)
			if saveState.enabled and saveState.loaded then
				local data = collectValues()
				local ok, encoded = pcall(function()
					return HttpService:JSONEncode(data)
				end)
				if ok and encoded ~= lastSnapshot then
					lastSnapshot = encoded
					Save.save()
				end
			end
		end
	end)
end

-- ============================================================
-- UI (page 3) — КОМПАКТНО (влезает в 260)
-- ============================================================
local function buildUI()
	page = Hub.Page(3)
	if not page then
		warn("[save] page 3 не найдена")
		return
	end

	local statusText = hasFs() and "Ready" or "NO FS"
	local statusColor = hasFs() and Color3.fromRGB(100, 255, 100) or Color3.fromRGB(255, 100, 100)

	-- заголовок + статус одной строкой
	local statusLabel = Elements.label(page,
		"SAVE — " .. statusText, 170,
		{ color = statusColor, size = 9, font = Enum.Font.GothamBold })

	-- Auto Save
	Elements.label(page, "Auto Save", 186)
	Hub.Toggles.autoSave = Elements.switch(page, 184, function(on)
		saveState.enabled = on
		print("[SAVE] Auto-save " .. (on and "ON" or "OFF"))
	end)

	-- 3 кнопки в строку
	local btnHolder = Instance.new("Frame")
	btnHolder.Size = UDim2.new(1, -16, 0, 20)
	btnHolder.Position = UDim2.new(0, 8, 0, 204)
	btnHolder.BackgroundTransparency = 1
	btnHolder.Parent = page

	local btnLayout = Instance.new("UIListLayout")
	btnLayout.FillDirection = Enum.FillDirection.Horizontal
	btnLayout.Padding = UDim.new(0, 4)
	btnLayout.Parent = btnHolder

	local saveBtn = Elements.button(btnHolder, "Save", 1, Color3.fromRGB(0, 130, 0), 70)
	saveBtn.Size = UDim2.new(0, 70, 0, 20)
	saveBtn.TextSize = 10
	saveBtn.MouseButton1Click:Connect(function()
		if Save.save() then
			statusLabel.Text = "SAVE — Saved ✓"
			statusLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
			task.delay(2, function()
				statusLabel.Text = "SAVE — " .. statusText
				statusLabel.TextColor3 = statusColor
			end)
		else
			statusLabel.Text = "SAVE — FAILED"
			statusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
		end
	end)

	local loadBtn = Elements.button(btnHolder, "Load", 2, Color3.fromRGB(0, 100, 180), 70)
	loadBtn.Size = UDim2.new(0, 70, 0, 20)
	loadBtn.TextSize = 10
	loadBtn.MouseButton1Click:Connect(function()
		if Save.load() then
			statusLabel.Text = "SAVE — Loaded ✓"
			statusLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
			task.delay(2, function()
				statusLabel.Text = "SAVE — " .. statusText
				statusLabel.TextColor3 = statusColor
			end)
		else
			statusLabel.Text = "SAVE — No file"
			statusLabel.TextColor3 = Color3.fromRGB(255, 200, 100)
		end
	end)

	local resetBtn = Elements.button(btnHolder, "Reset", 3, Color3.fromRGB(150, 0, 0), 60)
	resetBtn.Size = UDim2.new(0, 60, 0, 20)
	resetBtn.TextSize = 10
	resetBtn.MouseButton1Click:Connect(function()
		Save.reset()
		statusLabel.Text = "SAVE — Reset (restart)"
		statusLabel.TextColor3 = Color3.fromRGB(255, 200, 100)
	end)
end

-- ============================================================
-- INIT
-- ============================================================
function Save.init(hub)
	Hub = hub
	Config = hub.Config
	Toggles = hub.Toggles
	Elements = hub.Elements or (hub.Objects and hub.Objects.Elements)

	if not Elements then
		warn("[save] Elements не найдены")
		return
	end

	buildUI()
	Hub.Modules.save = Save

	task.defer(function()
		task.wait(3)

		local function reg(key, toggleObj)
			if toggleObj and toggleObj.get and toggleObj.set then
				Save.register(key, toggleObj.get, toggleObj.set)
			end
		end

		reg("esp.players",   Hub.Toggles.espPlayers)
		reg("esp.tools",     Hub.Toggles.espTools)
		reg("esp.prompts",   Hub.Toggles.espPrompts)
		reg("esp.monsters",  Hub.Toggles.espMonsters)
		reg("esp.instant",   Hub.Toggles.instantPrompt)
		reg("movement.speed",      Hub.Toggles.speed)
		reg("movement.fov",        Hub.Toggles.fov)
		reg("movement.fullbright", Hub.Toggles.fullbright)
		reg("bypass.anticheat",    Hub.Toggles.bypass)
		reg("bypass.doorReach",    Hub.Toggles.doorReach)
		reg("notify.entity",       Hub.Toggles.entityNotify)
		reg("misc.antiLag",        Hub.Toggles.antiLag)
		reg("misc.infiniteItems",  Hub.Toggles.infiniteItems)

		local count = 0
		for _ in pairs(saveState.subscriptions) do count = count + 1 end
		print("[SAVE] Зарегистрировано: " .. tostring(count) .. " настроек")

		task.wait(0.5)
		Save.load()
		startAutoSave()
	end)

	function Save.cleanup()
		if saveState.enabled then
			pcall(Save.save)
		end
		saveState.enabled = false
		saveState.subscriptions = {}
		for _, conn in ipairs(connections) do
			pcall(function() conn:Disconnect() end)
		end
		connections = {}
	end

	print("[SAVE] Модуль инициализирован")
	return Save
end

return Save
