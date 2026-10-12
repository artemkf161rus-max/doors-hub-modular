local BASE = "https://raw.githubusercontent.com/artemkf161rus-max/doors-hub-modular/refs/heads/main/"

local function load(path)
	local ok, result = pcall(function()
		return loadstring(game:HttpGet(BASE .. path))()
	end)
	if not ok then
		warn("[HUB] Ошибка загрузки " .. path .. ": " .. tostring(result))
		return nil
	end
	return result
end

local Config = load("config.lua")
if not Config then
	warn("[HUB] Config не загружен — выход")
	return
end
print("[HUB] Config загружен")

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

-- грузим ТОЛЬКО ui, он сам подтянет остальные
local UI = load("features/ui.lua")
if UI and UI.init then
	local ok, err = pcall(UI.init, Hub)
	if ok then
		print("[HUB] UI загружен, модули подключены")
	else
		warn("[HUB] UI упал: " .. tostring(err))
	end
else
	warn("[HUB] ui.lua не вернул init()")
end

print("[HUB] Готово")
