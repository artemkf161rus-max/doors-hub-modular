-- ============================================================
-- ============  MODULE: SAVE CONFIG  =========================
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
-- REGISTER / UNREGISTER
-- ============================================================
function Save.register(key, getter, setter)
	saveState.subscriptions[key] = {
		get = getter,
		set = setter,
	}
end

function Save.unregister(key)
	saveState.subscriptions[key] = nil
end

-- ============================================================
-- SAVE
-- ============================================================
local function collectValues()
	local data = {}
	for key, sub in pairs(saveState.subscriptions) do
		if sub and sub.get then
			local ok, value = pcall(sub.get)
			if ok then
				data[key] = value
			end
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

	if not ok then
		warn("[SAVE] Ошибка кодирования: " .. tostring(encoded))
		return false
	end

	local writeOk, err = pcall(function()
		writefile(CONFIG_FILE, encoded)
	end)

	if not writeOk then
		warn("[SAVE] Ошибка записи: " .. tostring(err))
		return false
	end

	saveState.lastSave = tick()
	print("[SAVE] Сохранено: " .. CONFIG_FILE .. " (" .. tostring(#encoded) .. " байт)")
	return true
end

-- ============================================================
-- LOAD
-- ============================================================
function Save.load()
	if not hasFs() then
		warn("[SAVE] Executor не поддерживает readfile")
		return false
	end

	if not fileExists(CONFIG_FILE) then
		print("[SAVE] Файл " .. CONFIG_FILE .. " не найден — используется дефолт")
		return false
	end

	local readOk, content = pcall(function()
		return readfile(CONFIG_FILE)
	end)

	if not readOk or not content then
		warn("[SAVE] Ошибка чтения файла")
		return false
	end

	local decodeOk, data = pcall(function()
		return HttpService:JSONDecode(content)
	end)

	if not decodeOk or type(data) ~= "table" then
		warn("[SAVE] Ошибка декодирования JSON")
		return false
	end

	local applied, skipped = 0, 0

	for key, sub in pairs(saveState.subscriptions) do
		if sub and sub.set and data[key] ~= nil then
			local ok = pcall(sub.set, data[key])
			if ok then
				applied = applied + 1
			else
				skipped = skipped + 1
			end
		end
	end

	saveState.loaded = true
	print("[SAVE] Загружено: " .. applied .. " применено, " .. skipped .. " пропущено")
	return true
end

-- ============================================================
-- RESET
-- ============================================================
function Save.reset()
	if hasFs() and fileExists(CONFIG_FILE) then
		local ok = pcall(function()
			writefile(CONFIG_FILE, "{}")
		end)
		if ok then
			print("[SAVE] Файл сброшен")
		end
	end
end

function Save.deleteFile()
	if hasFs() and fileExists(CONFIG_FILE) then
		pcall(function()
			writefile(CONFIG_FILE, "{}")
		end)
		print("[SAVE] Файл удалён")
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
-- UI (page 3) — КОМПАКТНАЯ ВЕРСИЯ
-- ============================================================
local function buildUI()
	page = Hub.Page(3)
	if not page then
		warn("[save] page 3 не найдена")
		return
	end

	local statusText = hasFs() and "Ready" or "NO FS"
	local statusColor = hasFs() and Color3.fromRGB(100, 255, 100) or Color3.fromRGB(255, 100, 100)

	-- статус-лейбл
	local statusLabel = Elements.label(page,
		"SAVE CONFIG — " .. statusText, 250,
		{ color = statusColor, size = 10, font = Enum.Font.GothamBold })

	-- auto save (компактно)
	Elements.label(page, "Auto Save", 268)
	Hub.Toggles.autoSave = Elements.switch(page, 266, function(on)
		saveState.enabled = on
		print("[SAVE] Auto-save " .. (on and "ON" or "OFF"))
	end)

	-- кнопки в одну строку
	local btnHolder = Instance.new("Frame")
	btnHolder.Size = UDim2.new(1, -20, 0, 24)
	btnHolder.Position = UDim2.new(0, 10, 0, 288)
	btnHolder.BackgroundTransparency = 1
	btnHolder.Parent = page

	local btnLayout = Instance.new("UIListLayout")
	btnLayout.FillDirection = Enum.FillDirection.Horizontal
	btnLayout.Padding = UDim.new(0, 4)
	btnLayout.Parent = btnHolder

	-- SAVE
	local saveBtn = Elements.button(btnHolder, "Save", 1,
		Color3.fromRGB(0, 130, 0), 80)
	saveBtn.Size = UDim2.new(0, 80, 0, 22)
	saveBtn.TextSize = 11
	saveBtn.MouseButton1Click:Connect(function()
		if Save.save() then
			statusLabel.Text = "SAVE CONFIG — Saved ✓"
			statusLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
			task.delay(2, function()
				statusLabel.Text = "SAVE CONFIG — " .. statusText
				statusLabel.TextColor3 = statusColor
			end)
		else
			statusLabel.Text = "SAVE CONFIG — FAILED"
			statusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
		end
	end)

	-- LOAD
	local loadBtn = Elements.button(btnHolder, "Load", 2,
		Color3.fromRGB(0, 100, 180), 80)
	loadBtn.Size = UDim2.new(0, 80, 0, 22)
	loadBtn.TextSize = 11
	loadBtn.MouseButton1Click:Connect(function()
		if Save.load() then
			statusLabel.Text = "SAVE CONFIG — Loaded ✓"
			statusLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
			task.delay(2, function()
				statusLabel.Text = "SAVE CONFIG — " .. statusText
				statusLabel.TextColor3 = statusColor
			end)
		else
			statusLabel.Text = "SAVE CONFIG — No file"
			statusLabel.TextColor3 = Color3.fromRGB(255, 200, 100)
		end
	end)

	-- RESET
	local resetBtn = Elements.button(btnHolder, "Reset", 3,
		Color3.fromRGB(150, 0, 0), 70)
	resetBtn.Size = UDim2.new(0, 70, 0, 22)
	resetBtn.TextSize = 11
	resetBtn.MouseButton1Click:Connect(function()
		Save.reset()
		statusLabel.Text = "SAVE CONFIG — Reset (restart)"
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

		-- ESP
		reg("esp.players",   Hub.Toggles.espPlayers)
		reg("esp.tools",     Hub.Toggles.espTools)
		reg("esp.prompts",   Hub.Toggles.espPrompts)
		reg("esp.monsters",  Hub.Toggles.espMonsters)
		reg("esp.instant",   Hub.Toggles.instantPrompt)

		-- Movement
		reg("movement.speed",      Hub.Toggles.speed)
		reg("movement.fov",        Hub.Toggles.fov)
		reg("movement.fullbright", Hub.Toggles.fullbright)

		-- Bypass
		reg("bypass.anticheat", Hub.Toggles.bypass)
		reg("bypass.doorReach", Hub.Toggles.doorReach)

		-- Notify
		reg("notify.entity", Hub.Toggles.entityNotify)

		-- Misc
		reg("misc.antiLag",       Hub.Toggles.antiLag)
		reg("misc.infiniteItems", Hub.Toggles.infiniteItems)

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
