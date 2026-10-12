-- ============================================================
-- ============  MODULE: AUTO INTERACT  =======================
-- ============  (Abysall-style, all prompts)  ================
-- ============================================================
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local player = Players.LocalPlayer

local AutoInteract = {}

local Config, Toggles, Hub, Elements, page
local connections = {}

local aiState = {
	enabled = false,
	loop = nil,
	lastFire = 0,
}

-- ============================================================
-- BLACKLIST (промпты которые НЕ трогаем)
-- ============================================================
local AutoInteractBlacklist = {
	HidePrompt = true,
	RiftPrompt = true,
	StarRiftPrompt = true,
	InteractPrompt = true,
	ClimbPrompt = true,
	DonatePrompt = true,
	DialoguePrompt = true,
	RevivePrompt = true,
	EnterPrompt = true,
	AnimatePrompt = true,
	ToolEventPrompt = true,
	Prompt = true,
	PropPrompt = true,
}

-- ============================================================
-- ХЕЛПЕРЫ (как в Abysall)
-- ============================================================
local function HasItem(name, onlyCharacter)
	local char = player.Character
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not onlyCharacter and backpack and backpack:FindFirstChild(name) then
		return backpack:FindFirstChild(name)
	elseif char and char:FindFirstChild(name) then
		return char:FindFirstChild(name)
	end
	return nil
end

local function FirePrompt(prompt)
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
-- ГЛАВНАЯ ФУНКЦИЯ (порт из Abysall)
-- ============================================================
local TriggerDebounce = false

local function TriggerPrompt(Prompt)
	if not Prompt or not Prompt.Parent then return end
	if AutoInteractBlacklist[Prompt.Name] then return end
	if TriggerDebounce then return end

	-- fake prompt — не наш (для Infinite Items)
	if Prompt:GetAttribute("FakePrompt") then return end

	local char = player.Character
	local humanoid = char and char:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end

	-- если у игрока уже есть предмет с полной прочностью — не тратим
	local ParentItem = HasItem(Prompt.Parent.Name)
	if ParentItem and ParentItem:GetAttribute("Durability") and ParentItem:GetAttribute("DurabilityMax")
		and ParentItem:GetAttribute("Durability") >= ParentItem:GetAttribute("DurabilityMax")
	then return end

	-- ============ LOCK PROMPTS ============
	local LockPromptNames = {
		UnlockPrompt = true, SkullPrompt = true, LockPrompt = true,
		ThingToEnable = true, FusesPrompt = true,
	}
	local IsLockPrompt = LockPromptNames[Prompt.Name]
		or (Prompt.Parent and Prompt.Parent:GetAttribute("Locked") == true)
		or (Prompt.Parent and Prompt.Parent.Parent
			and Prompt.Parent.Parent.Name == "Locker_Small_Locked"
			and Prompt.Name == "ActivateEventPrompt")

	if IsLockPrompt then
		-- проверка что есть ключ
		local KeyItems = {
			"Key", "GeneratorFuse", "KeyBackdoor", "KeyElectrical",
			"KeyIron", "Lockpick", "SkeletonKey", "Shears", "Multitool",
		}
		local OffhandKeyItems = { "Key", "GeneratorFuse", "KeyElectrical", "KeyIron" }
		local HasKey = false
		for _, K in ipairs(KeyItems) do
			if HasItem(K, true) then HasKey = true break end
		end
		for _, K in ipairs(OffhandKeyItems) do
			if HasItem(K) then HasKey = true break end
		end
		if not HasKey then return end
	end

	-- ============ СПЕЦИФИЧНЫЕ ПРОВЕРКИ ============
	-- Vines/Cellar — нужны ножницы или мультитул
	if Prompt.Parent.Name == "CuttableVines"
		and not HasItem("Shears", true)
		and not HasItem("Multitool", true) then return end
	if Prompt.Parent.Name == "Chest_Vine"
		and not HasItem("Shears", true)
		and not HasItem("Multitool", true) then return end
	if Prompt.Parent.Name == "Cellar"
		and not HasItem("Shears", true)
		and not HasItem("Multitool", true) then return end

	-- SkullLock — нужен SkeletonKey
	if Prompt.Parent.Name == "SkullLock" and not HasItem("SkeletonKey", true) then return end

	-- Lock1/Lock2 — нужен Lockpick или Multitool
	if Prompt.Parent.Name == "Lock1"
		and not HasItem("Lockpick", true)
		and not HasItem("Multitool", true) then return end
	if Prompt.Parent.Name == "Lock2"
		and not HasItem("Lockpick", true)
		and not HasItem("Multitool", true) then return end

	-- если держим Shears — не используем на замках (кроме vine)
	if HasItem("Shears", true) and IsLockPrompt
		and Prompt.Parent.Name ~= "CuttableVines"
		and Prompt.Parent.Name ~= "Chest_Vine"
		and Prompt.Parent.Name ~= "Cellar" then return end

	-- ============ ОБЩИЕ ПРОВЕРКИ ============
	-- уже есть ключ — не подбираем второй
	if Prompt.Parent.Name == "KeyObtain" and (HasItem("Key") or HasItem("KeyBackdoor")) then return end
	if Prompt.Parent.Name == "ElectricalKeyObtain" and HasItem("KeyElectrical") then return end

	-- Lever закрытия — не трогаем
	if Prompt.Parent.Name == "LeverForGate" and Prompt:GetAttribute("Interactions") then return end

	-- фейковые двери — не трогаем
	if Prompt.Parent.Parent and (Prompt.Parent.Parent.Name == "DoorFake"
		or Prompt.Parent.Parent.Name == "FakeDoor") then return end

	-- ============ АКТИВИРУЕМ ============
	FirePrompt(Prompt)

	TriggerDebounce = true
	task.wait()
	TriggerDebounce = false
end

-- ============================================================
-- ОСНОВНОЙ ЦИКЛ (как в Abysall)
-- ============================================================
local function runLoop()
	local char = player.Character
	if not char then return end

	local humanoid = char:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end

	local now = tick()
	if now - aiState.lastFire < 1/60 then return end

	-- перебираем ВСЕ ProximityPrompt в workspace
	for _, prompt in ipairs(workspace:GetDescendants()) do
		if prompt:IsA("ProximityPrompt") and prompt.Enabled then
			-- получаем позицию родителя
			local parent = prompt.Parent
			if parent and (parent:IsA("BasePart") or parent:IsA("Model")) then
				local distance
				if parent:IsA("BasePart") then
					distance = player:DistanceFromCharacter(parent.Position)
				else
					distance = player:DistanceFromCharacter(parent:GetPivot().Position)
				end

				-- проверяем дистанцию
				if distance <= prompt.MaxActivationDistance then
					task.spawn(TriggerPrompt, prompt)
				end
			end
		end
	end

	aiState.lastFire = now
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
			print("[AUTO INTERACT] ON")
		else
			print("[AUTO INTERACT] OFF")
		end
	end)

	Elements.label(page,
		"Активирует все prompts в радиусе",
		154,
		{ color = Color3.fromRGB(150, 255, 150), size = 9,
		  font = Enum.Font.Gotham })

	Elements.label(page,
		"Blacklist: Hide/Climb/Rift/Donate/Dialogue...",
		170,
		{ color = Color3.fromRGB(150, 150, 150), size = 9,
		  font = Enum.Font.Gotham })

	Elements.label(page,
		"Проверки: ключи, прочность, lock prompts",
		186,
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
