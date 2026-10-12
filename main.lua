-- ============================================================
-- ================  MAIN.LUA  ================================
-- ============================================================
local Players = game:GetService("Players")
local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

local BASE = "https://raw.githubusercontent.com/artemkf161rus-max/doors-hub-modular/refs/heads/main/"

-- ============================================================
-- ============  PRE-CLEANUP (важно!)  ========================
-- ============================================================
do
	print("[MAIN] PRE-CLEANUP запущен")

	-- 1. Вызываем cleanup() у старого Hub, если он был
	local oldHub = getgenv().Hub
	if oldHub then
		-- cleanup у всех модулей
		if oldHub.Modules then
			for name, mod in pairs(oldHub.Modules) do
				if type(mod) == "table" and mod.cleanup then
					local ok, err = pcall(mod.cleanup)
					if ok then
						print("[MAIN] cleanup: " .. name)
					else
						warn("[MAIN] cleanup " .. name .. " упал: " .. tostring(err))
					end
				end
			end
		end

		-- отключаем общие коннекты
		if oldHub.Connections then
			for _, c in ipairs(oldHub.Connections) do
				pcall(function() c:Disconnect() end)
			end
			oldHub.Connections = {}
		end

		-- выключаем все тоглы
		if oldHub.Toggles then
			for _, sw in pairs(oldHub.Toggles) do
				if type(sw) == "table" and sw.set then
					pcall(function() sw.set(false) end)
				end
			end
			oldHub.Toggles = {}
		end
	end
	getgenv().Hub = nil

	-- 2. Удаляем старые ScreenGui
	local removeNames = {
		MenuUI = true,
		HubNotifications = true,
		EntityNotifier = true,
	}
	for _, obj in ipairs(playerGui:GetChildren()) do
		if obj:IsA("ScreenGui") and removeNames[obj.Name] then
			obj:Destroy()
			print("[MAIN] Удалён старый GUI: " .. obj.Name)
		end
	end

	print("[MAIN] PRE-CLEANUP завершён")
end
-- ============================================================

-- ============================================================
-- ============  ЗАГРУЗЧИК  ===================================
-- ============================================================
local function load(path, addTimestamp)
	local url = BASE .. path
	if addTimestamp then
		url = url .. "?t=" .. tostring(os.time())
	end

	local ok, result = pcall(function()
		return loadstring(game:HttpGet(url))()
	end)

	if not ok then
		warn("[MAIN] Ошибка загрузки " .. path .. ": " .. tostring(result))
		return nil
	end
	return result
end

-- ============================================================
-- ============  CONFIG  ======================================
-- ============================================================
local Config = load("config.lua", false)
if not Config then
	warn("[MAIN] Config не загружен — выход")
	return
end
print("[MAIN] Config загружен")

-- ============================================================
-- ============  HUB  =========================================
-- ============================================================
local Hub = {}
Hub.Config = Config
Hub.Toggles = {}
Hub.Connections = {}
Hub.Modules = {}
Hub.Objects = {
	ESP = {},
	ToolESP = {},
	PromptESP = {},
	MonsterESP = {},
}

getgenv().Hub = Hub

-- ============================================================
-- ============  ЗАГРУЗКА UI  =================================
-- ============================================================
-- ui.lua сам подтянет esp / movement / library / bypass / notify / misc
local UI = load("features/ui.lua", true)  -- true = добавить ?t= для обхода кэша
if UI and type(UI) == "table" and UI.init then
	local ok, err = pcall(UI.init, Hub)
	if ok then
		print("[MAIN] UI загружен, модули подключены")
	else
		warn("[MAIN] UI упал: " .. tostring(err))
	end
else
	warn("[MAIN] ui.lua не вернул init()")
end

print("[MAIN] Готово")
