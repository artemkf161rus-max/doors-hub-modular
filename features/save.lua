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
-- REGISTER
-- ============================================================
function Save.register(key, getter, setter)
	saveState.subscriptions[key] = { get = getter, set = setter }
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
-- UI (внутри page 3, ГАРАНТИРОВАННО)
-- ============================================================
local function buildUI()
	-- берём page 3 из Hub
	local page3 = Hub.Page and Hub.Page(3)

	if not page3 then
		warn("[save] Hub.Page(3) = nil")
		return
	end

	-- проверяем что page3 внутри MenuUI
	if Hub.MenuGui and not page3:IsDescendantOf(Hub.MenuGui) then
		warn("[save] page3 не в MenuUI — ищу menu frame")

		for _, obj in ipairs(Hub.MenuGui:GetChildren()) do
			if obj:IsA("Frame") then
				local p3 = obj:FindFirstChild("Page3")
				if p3 then
					page3 = p3
					print("[save] Нашёл Page3 в menu frame:", page3)
					break
				end
			end
		end
	end

	page = page3

	print("[save] Page3:", page)
	print("[save] parent:", page.Parent)
	print("[save] в MenuUI:", Hub.MenuGui and page:IsDescendantOf(Hub.MenuGui))

	-- ============ РАЗДЕЛИТЕЛЬ ============
	local divider = Instance.new("Frame")
	divider.Name = "SaveDivider"
	divider.Size = UDim2.new(1, -20, 0, 1)
	divider.Position = UDim2.new(0, 10, 0, 145)
	divider.BackgroundColor3 = Color3.fromRGB(120, 80, 200)
	divider.BorderSizePixel = 0
	divider.Parent = page

	-- ============ СТАТУС ============
	local statusText = hasFs() and "Ready" or "NO FS"
	local statusColor = hasFs() and Color3.fromRGB(100, 255, 100) or Color3.fromRGB(255, 100, 100)

	local statusLabel = Elements.label(page,
		"SAVE — " .. statusText, 152,
		{ color = statusColor, size = 9, font = Enum.Font.GothamBold })

	-- ============ AUTO SAVE ============
	Elements.label(page, "Auto Save", 170)
	Hub.Toggles.autoSave = Elements.switch(page, 168, function(on)
		saveState.enabled = on
		print("[SAVE] Auto-save " .. (on and "ON" or "OFF"))
	end)

	-- ============ КНОПКИ ============
	local btnHolder = Instance.new("Frame")
	btnHolder.Name = "SaveButtons"
	btnHolder.Size = UDim2.new(1, -16, 0, 20)
	btnHolder.Position = UDim2.new(0, 8, 0, 188)
	btnHolder.BackgroundTransparency = 1
	btnHolder.Parent = page

	local btnLayout = Instance.new("UIListLayout")
	btnLayout.FillDirection = Enum.FillDirection.Horizontal
	btnLayout.Padding = UDim.new(0, 4)
	btnLayout.Parent = btnHolder

	-- SAVE
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

	-- LOAD
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

	-- RESET
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
		reg("bypass.anticheat",    Hub.Toggles.bypass)
		reg("bypass.doorReach",    Hub.Toggles.doorReach)

		-- Notify
		reg("notify.entity",       Hub.Toggles.entityNotify)

		-- Misc
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
