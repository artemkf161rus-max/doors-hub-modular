local BASE = "https://raw.githubusercontent.com/ТВОЙ_НИК/doors-hub-modular/main/"

local function load(path)
	local ok, result = pcall(function()
		return loadstring(game:HttpGet(BASE .. path .. "?t=" .. tick()))()
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
Hub.Functions = {}
Hub.Objects = {
	ESP = {},
	ToolESP = {},
	PromptESP = {},
	MonsterESP = {},
}

getgenv().Hub = Hub

local featureList = {
	"esp",
	"movement",
	"bypass",
	"notify",
	"misc",
	"ui",
}

for _, name in ipairs(featureList) do
	local mod = load("features/" .. name .. ".lua")
	if mod and type(mod) == "table" and mod.init then
		local ok, err = pcall(mod.init, Hub)
		if ok then
			print("[HUB] Модуль загружен: " .. name)
		else
			warn("[HUB] Модуль " .. name .. " упал: " .. tostring(err))
		end
	else
		warn("[HUB] Модуль " .. name .. " не вернул init()")
	end
end

print("[HUB] Все модули загружены")
