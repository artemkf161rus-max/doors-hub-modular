-- ============================================================
-- ============  MODULE: ANTI-AFK  ============================
-- ============================================================
local Players = game:GetService("Players")
local VirtualUser = game:GetService("VirtualUser")
local player = Players.LocalPlayer

local AntiAFK = {}

local Config, Toggles, Hub, Elements, page
local connections = {}

local afkState = {
	enabled = false,
	lastPing = 0,
}

local function track(c)
	table.insert(connections, c)
	return c
end

-- ============================================================
-- ANTI-AFK LOOP
-- ============================================================
local function setupAntiAfk()
	track(player.Idled:Connect(function()
		if not afkState.enabled then return end

		-- Roblox думает что игрок AFK
		-- Клиент должен "нажать" кнопку чтобы продлить сессию
		VirtualUser:CaptureController()
		VirtualUser:ClickButton2(Vector2.new())

		afkState.lastPing = tick()
		print("[ANTI-AFK] Сработал — продлил сессию")
	end))
end

-- ============================================================
-- UI (page 4)
-- ============================================================
local function buildUI()
	page = Hub.Page(4)
	if not page then
		warn("[antiafk] page 4 не найдена")
		return
	end

	Elements.label(page, "═══ ANTI-AFK ═══", 150,
		{ color = Color3.fromRGB(255, 200, 0), size = 11,
		  font = Enum.Font.GothamBold })

	Elements.label(page, "Anti-AFK", 172)
	Hub.Toggles.antiAfk = Elements.switch(page, 170, function(on)
		afkState.enabled = on

		if on then
			print("[ANTI-AFK] Включён")
		else
			print("[ANTI-AFK] Выключен")
		end
	end)

	Elements.label(page, "Не даёт кикнуть за 20 мин AFK", 192,
		{ color = Color3.fromRGB(150, 150, 150), size = 9,
		  font = Enum.Font.Gotham })

	-- Статус
	local statusLabel = Elements.label(page, "Status: idle", 212,
		{ color = Color3.fromRGB(120, 120, 120), size = 9,
		  font = Enum.Font.Gotham })

	-- Обновление статуса
	task.spawn(function()
		while page and page.Parent do
			task.wait(1)
			if afkState.lastPing > 0 then
				local ago = math.floor(tick() - afkState.lastPing)
				statusLabel.Text = "Последний пинг: " .. ago .. " сек назад"
				statusLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
			else
				statusLabel.Text = "Status: idle"
				statusLabel.TextColor3 = Color3.fromRGB(120, 120, 120)
			end
		end
	end)
end

-- ============================================================
-- INIT
-- ============================================================
function AntiAFK.init(hub)
	Hub = hub
	Config = hub.Config
	Toggles = hub.Toggles
	Elements = hub.Elements or (hub.Objects and hub.Objects.Elements)

	if not Elements then
		warn("[antiafk] Elements не найдены")
		return
	end

	buildUI()
	setupAntiAfk()

	function AntiAFK.cleanup()
		afkState.enabled = false

		for _, c in ipairs(connections) do
			pcall(function() c:Disconnect() end)
		end
		connections = {}
	end

	print("[ANTI-AFK] Модуль инициализирован")
	return AntiAFK
end

return AntiAFK
