-- ============================================================
-- ================  MAIN.LUA  ================================
-- ============================================================
local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

local BASE = "https://raw.githubusercontent.com/artemkf161rus-max/doors-hub-modular/refs/heads/main/"

-- ⏱ Старт замера времени
local LoadStart = tick()

-- ============================================================
-- ============  PRE-CLEANUP (важно!)  ========================
-- ============================================================
do
	print("[MAIN] PRE-CLEANUP запущен")

	local oldHub = getgenv().Hub
	if oldHub then
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

		if oldHub.Connections then
			for _, c in ipairs(oldHub.Connections) do
				pcall(function() c:Disconnect() end)
			end
			oldHub.Connections = {}
		end

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
-- ============  ХЕЛПЕР — Roblox Notification  ================
-- ============================================================
local function SendNotification(title, text, duration)
	task.spawn(function()
		local ok, err = pcall(function()
			StarterGui:SetCore("SendNotification", {
				Title = title or "Hub",
				Text = text or "",
				Duration = duration or 5,
				Icon = "rbxassetid://6023426923",
			})
		end)
		if not ok then
			warn("[MAIN] SendNotification failed: " .. tostring(err))
		end
	end)
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
local UI = load("features/ui.lua", true)
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

-- ============================================================
-- ============  ВРЕМЯ ЗАГРУЗКИ + УВЕДОМЛЕНИЕ  ================
-- ============================================================
local LoadTime = tick() - LoadStart
local LoadTimeMs = math.floor(LoadTime * 1000) / 1000

-- выводим в консоль
print("[MAIN] Загружено за " .. LoadTimeMs .. " сек")

-- показываем встроенное уведомление Roblox
task.wait(0.5)  -- ждём чтобы Core успел инициализироваться
SendNotification(
	"✦ Doors Hub ✦",
	"Загружено за " .. LoadTimeMs .. " сек",
	5
)

print("[MAIN] Готово")
