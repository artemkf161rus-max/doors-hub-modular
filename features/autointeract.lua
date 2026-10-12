-- ============================================================
-- ============  MODULE: AUTO INTERACT (DEBUG)  ===============
-- ============================================================
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer

local AutoInteract = {}

local Config, Toggles, Hub, Elements, page
local connections = {}

local aiState = {
	enabled = false,
	loop = nil,
	distance = 12,
	cooldown = {},
	lastFire = 0,
}

local DEBUG = true  -- ← выключи когда всё заработает

-- ============================================================
-- НАСТРОЙКИ ИГНОРА
-- ============================================================

local IGNORE_PREFIXES = {
	"Regal",
	"Wardrobe",
	"Backdoor_Wardrobe",
	"RetroWardrobe",
	"Rooms_Locker",
	"Locker_Large",
	"CircularVent",
	"Dumpster",
	"Bed",
	"Double_Bed",
	"Painting",
	"Paintings",
	"PaintingsContainer",
	"PaintingFrame",
	"FakeDoor",
	"DoorFake",
	"SideroomSpace",
	"Hide",
	"Climb",
	"Rift",
	"Star",
	"Donate",
	"Dialogue",
	"Animate",
	"ToolEvent",
	"PropPrompt",
}

local IGNORE_SUBSTRINGS = {
	"painting",
	"paintings",
	"paint",
	"regal",
	"wardrobe",
	"hideprompt",
	"climbprompt",
	"fakedoor",
	"doorfake",
	"fireplace",
	"movingdoor",
	"wax_door",
}

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
	PropPrompt = true,
}

-- ============================================================
-- DEBUG LOGGER
-- ============================================================
local function dbg(msg)
	if DEBUG then
		print("[AI] " .. msg)
	end
end

-- ============================================================
-- ХЕЛПЕРЫ
-- ============================================================
local function getChain(obj, depth)
	depth = depth or 5
	local chain = {}
	local c = obj
	local d = 0
	while c and d < depth do
		table.insert(chain, c.Name)
		c = c.Parent
		d = d + 1
	end
	return table.concat(chain, " > ")
end

local function containsSubstring(name, substrings)
	if not name then return false end
	local lowerName = string.lower(name)
	for _, s in ipairs(substrings) do
		if string.find(lowerName, s, 1, true) then
			return true
		end
	end
	return false
end

local function startsWithPrefix(name, prefixes)
	if not name then return false end
	local lowerName = string.lower(name)
	for _, prefix in ipairs(prefixes) do
		if string.sub(lowerName, 1, #prefix) == string.lower(prefix) then
			return true
		end
	end
	return false
end

local function isIgnored(prompt)
	-- 1. по имени prompt'а (точное)
	if IGNORE_PROMPT_NAMES[prompt.Name] then return true, "prompt.Name в списке" end

	-- 2. fake prompt
	if prompt:GetAttribute("FakePrompt") then return true, "FakePrompt attribute" end

	-- 3. имя самого prompt'а содержит подстроку
	if containsSubstring(prompt.Name, IGNORE_SUBSTRINGS) then
		return true, "prompt.Name содержит подстроку"
	end

	-- 4. по цепочке родителей
	local current = prompt.Parent
	local depth = 0
	while current and depth < 15 do
		local name = current.Name

		if IGNORE_PROMPT_NAMES[name] then
			return true, "родитель '" .. name .. "' в IGNORE_PROMPT_NAMES"
		end

		if startsWithPrefix(name, IGNORE_PREFIXES) then
			return true, "родитель '" .. name .. "' начинается с префикса"
		end

		if containsSubstring(name, IGNORE_SUBSTRINGS) then
			return true, "родитель '" .. name .. "' содержит подстроку"
		end

		-- атрибуты
		for attrName in pairs(current:GetAttributes()) do
			if string.find(string.lower(attrName), "paint", 1, true) then
				return true, "родитель '" .. name .. "' имеет атрибут '" .. attrName .. "'"
			end
		end

		current = current.Parent
		depth = depth + 1
	end

	return false, nil
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

	if now - aiState.lastFire < 0.05 then return end

	-- собираем все prompts в радиусе, с инфо
	local candidates = {}

	for _, prompt in ipairs(workspace:GetDescendants()) do
		if prompt:IsA("ProximityPrompt") and prompt.Enabled then
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
						local ignored, reason = isIgnored(prompt)
						table.insert(candidates, {
							prompt = prompt,
							dist = dist,
							ignored = ignored,
							reason = reason,
						})
					end
				end
			end
		end
	end

	-- DEBUG: логируем ВСЕ prompts в радиусе
	if DEBUG and #candidates > 0 then
		dbg("=== Prompts в радиусе (" .. #candidates .. ") ===")
		for _, c in ipairs(candidates) do
			local status
			if c.ignored then
				status = "ИГНОР (" .. (c.reason or "?") .. ")"
			else
				status = "КАНДИДАТ"
			end
			dbg("  " .. status .. " | " .. c.prompt.Name .. 
				" | dist: " .. math.floor(c.dist) ..
				" | chain: " .. getChain(c.prompt.Parent, 4))
		end
	end

	-- активируем первый не-игнор
	for _, c in ipairs(candidates) do
		if not c.ignored then
			local lastUse = aiState.cooldown[c.prompt] or 0
			if now - lastUse > 0.5 then
				dbg(">>> АКТИВИРУЮ: " .. c.prompt.Name ..
					" | chain: " .. getChain(c.prompt.Parent, 5) ..
					" | dist: " .. math.floor(c.dist))

				aiState.cooldown[c.prompt] = now
				firePrompt(c.prompt)
				aiState.lastFire = now
				break
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
			print("[AUTO INTERACT] ON (dist=" .. aiState.distance .. ", DEBUG=" .. tostring(DEBUG) .. ")")
		else
			print("[AUTO INTERACT] OFF")
		end
	end)

	Elements.label(page, "DISTANCE (5-30)", 154)
	local distVal = Elements.label(page, "Distance: 12", 170,
		{ color = Color3.fromRGB(255, 255, 255), size = 10 })

	Elements.slider(page, 186, 5, 30, 12, function(v)
		aiState.distance = math.floor(v)
		distVal.Text = "Distance: " .. aiState.distance
	end)

	Elements.label(page,
		"DEBUG включён — смотри консоль",
		206,
		{ color = Color3.fromRGB(255, 200, 0), size = 9,
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
		warn("[autointeract] Elements не найдены")
		return
	end

	buildUI()

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

	print("[AUTOINTERACT] Модуль инициализирован (DEBUG=" .. tostring(DEBUG) .. ")")
	return AutoInteract
end

return AutoInteract
