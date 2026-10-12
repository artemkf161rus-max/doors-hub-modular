-- ============================================================
-- ============  UI (OBSIDIAN LIBRARY)  =======================
-- ============================================================
local UI = {}

function UI.init(Hub)
	local Players = game:GetService("Players")
	local player = Players.LocalPlayer

	-- ============================================================
	-- ЗАГРУЗКА OBSIDIAN
	-- ============================================================
	local BASE_OBSIDIAN = "https://raw.githubusercontent.com/deividcomsono/Obsidian/refs/heads/main/"

	local Library = loadstring(game:HttpGet(BASE_OBSIDIAN .. "Library.lua"))()
	local SaveManager = loadstring(game:HttpGet(BASE_OBSIDIAN .. "addons/SaveManager.lua"))()
	local ThemeManager = loadstring(game:HttpGet(BASE_OBSIDIAN .. "addons/ThemeManager.lua"))()

	local Options = Library.Options
	local Toggles = Library.Toggles

	-- ============================================================
	-- СОЗДАНИЕ ОКНА
	-- ============================================================
	local Window = Library:CreateWindow({
		Title = Hub.Config.HUB_NAME or "Doors Hub",
		Footer = "v" .. (Hub.Config.HUB_VERSION or "1.0.0"),
		NotifySide = "Right",
		ShowCustomCursor = false,
		AutoShow = true,
		Center = true,
		TabPadding = 3,
		MenuFadeTime = 0,
		CornerRadius = 4,
	})

	-- ============================================================
	-- ТАБЫ
	-- ============================================================
	local Tabs = {
		Main     = Window:AddTab("Main", "house"),
		ESP      = Window:AddTab("ESP", "eye"),
		Exploits = Window:AddTab("Exploits", "shield"),
		Misc     = Window:AddTab("Misc", "settings"),
		Settings = Window:AddTab("Settings", "cog"),
	}

	-- ============================================================
	-- СОХРАНЯЕМ В HUB
	-- ============================================================
	Hub.Library = Library
	Hub.SaveManager = SaveManager
	Hub.ThemeManager = ThemeManager
	Hub.Options = Options
	Hub.Toggles = Toggles
	Hub.Tabs = Tabs
	Hub.Window = Window

	-- ============================================================
	-- SAVE MANAGER
	-- ============================================================
	SaveManager:SetLibrary(Library)
	SaveManager:IgnoreThemeSettings()
	SaveManager:SetIgnoreIndexes({})
	SaveManager:BuildConfigSection(Tabs.Settings)

	-- ============================================================
	-- THEME MANAGER
	-- ============================================================
	ThemeManager:SetLibrary(Library)
	ThemeManager:ApplyToTab(Tabs.Settings)

	-- ============================================================
	-- ЗАГРУЗКА МОДУЛЕЙ
	-- ============================================================
	local BASE = "https://raw.githubusercontent.com/artemkf161rus-max/doors-hub-modular/refs/heads/main/"

	local function loadModule(path)
		local url = BASE .. path .. "?t=" .. tostring(os.time())
		local ok, result = pcall(function()
			return loadstring(game:HttpGet(url))()
		end)
		if not ok then
			warn("[UI] ❌ " .. path .. ": " .. tostring(result))
			return nil
		end
		return result
	end

	local modules = {
		"features/movement.lua",
		"features/esp.lua",
		"features/library.lua",
		"features/bypass.lua",
		"features/notify.lua",
		"features/misc.lua",
	}

	print("[UI] ========== ЗАГРУЗКА МОДУЛЕЙ ==========")

	for _, path in ipairs(modules) do
		local mod = loadModule(path)
		if not mod or type(mod) ~= "table" or not mod.init then
			warn("[UI] ❌ " .. path)
			continue
		end

		local name = path:match("features/(%w+)%.lua")
		Hub.Modules[name] = mod

		local ok, err = pcall(mod.init, Hub)
		if ok then
			print("[UI] ✅ " .. name)
		else
			warn("[UI] ❌ " .. name .. ": " .. tostring(err))
		end
	end

	print("[UI] =========================================")

	-- ============================================================
	-- UNLOAD
	-- ============================================================
	Library:OnUnload(function()
		print("[UI] Unloading...")

		for name, mod in pairs(Hub.Modules) do
			if type(mod) == "table" and mod.cleanup then
				pcall(mod.cleanup)
			end
		end

		for _, sw in pairs(Hub.Toggles) do
			if type(sw) == "table" and sw.set then
				pcall(function() sw.set(false) end)
			end
		end

		for _, c in pairs(Hub.Connections) do
			pcall(function() c:Disconnect() end)
		end
		Hub.Connections = {}

		getgenv().Hub = nil
		print("[HUB] Unloaded")
	end)

	print("[UI] Obsidian UI загружен")
	return Hub
end

return UI
