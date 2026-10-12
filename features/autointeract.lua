-- ============================================================
-- ============  MODULE: AUTO INTERACT  =======================
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

-- ============================================================
-- ЖЁСТКИЙ ИГНОР ПО НАЧАЛУ ИМЕНИ (case-insensitive)
-- ============================================================
local IGNORE_STARTS_WITH = {
	"painting",       -- Painting_1, Painting_2, PaintingABC, PaintingWhatever
	"paintings",      -- PaintingsContainer, PaintingsFolder
	"regal",          -- Regal, RegalDoor
	"wardrobe",       -- Wardrobe, Wardrobe-FOOLS26
	"backdoor_wardrobe",
	"retro_wardrobe",
	"rooms_locker",
	"locker_large",
	"circularvent",
	"dumpster",
	"bed",            -- Bed, Beds
	"double_bed",
	"fakedoor",
	"doorfake",
	"sideroomspace",
	"hide",           -- HidePrompt, HidingSpot
	"climb",
	"rift",
	"star",
	"donate",
	"dialogue",
	"animate",
	"toolevent",
	"propprompt",
	"fireplace",
	"movingdoor",
	"wax_door",
}

-- Точные имена prompt'ов
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
-- ХЕЛПЕРЫ
-- ============================================================
local function startsWithIgnore(name)
	if not name then return false end
	local lower = string.lower(name)
	for _, prefix in ipairs(IGNORE_STARTS_WITH) do
		if string.sub(lower, 1, #prefix) == prefix then
			return true
		end
	end
	return false
end

local function isIgnored(prompt)
	-- 1. точное имя prompt'а
	if IGNORE_PROMPT_NAMES[prompt.Name] then return true end

	-- 2. fake prompt (для Infinite Items)
	if prompt:GetAttribute("FakePrompt") then return true end

	-- 3. имя самого prompt'а начинается с игнора
	if startsWithIgnore(prompt.Name) then return true end

	-- 4. вся цепочка родителей вверх — если ЛЮБОЙ начинается на игнор
	local current = prompt.Parent
	local depth = 0
	while current and depth < 20 do
		if startsWithIgnore(current.Name) then return true end
		if IGNORE_PROMPT_NAMES[current.Name] then return true end

		current = current.Parent
		depth = depth + 1
	end

	return false
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

	for _, prompt in ipairs(workspace:GetDescendants()) do
		if prompt:IsA("ProximityPrompt") and prompt.Enabled then
			if not isIgnored(prompt) then
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
							local lastUse = aiState.cooldown[prompt] or 0
							if now - lastUse > 0.5 then
								aiState.cooldown[prompt] = now
								firePrompt(prompt)
								aiState.lastFire = now
								break  -- один prompt за тик
							end
						end
					end
				end
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
			print("[AUTO INTERACT] ON (dist=" .. aiState.distance .. ")")
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
		"Ignores: Painting*, Regal*, Wardrobe*, Hide...",
		206,
		{ color = Color3.fromRGB(150, 150, 150), size = 9,
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

	print("[AUTOINTERACT] Модуль инициализирован")
	return AutoInteract
end

return AutoInteract
