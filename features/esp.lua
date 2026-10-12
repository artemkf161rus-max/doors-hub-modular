local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ProximityPromptService = game:GetService("ProximityPromptService")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer

local Misc = {}

-- ==================== STATE ====================
local Config
local Toggles
local Hub
local Elements
local page

local connections = {}

-- anti-lag
local lagState = {
	enabled = false,
	saved = {},
}

-- infinite items
local infState = {
	enabled = false,
}

-- fake prompts registry
local FakePrompts = {}  -- [fake] = original

-- контейнер для оригинальных prompt'ов
local PromptContainer = nil

-- список "замочных" prompt'ов — те, где важно НЕ потратить предмет
local LOCK_PROMPT_NAMES = {
	UnlockPrompt = true,
	SkullPrompt = true,
	LockPrompt = true,
	ThingToEnable = true,
	FusesPrompt = true,
}

-- предметы, которые можно дюпать
local ItemNames = {
	Lockpick = "Lockpicks",
	Shears = "Shears",
	SkeletonKey = "Skeleton Key",
	Multitool = "Multitool",
	Key = "Key",
	KeyBackdoor = "Backdoor Key",
	KeyElectrical = "Electrical Key",
	KeyIron = "Iron Key",
	GeneratorFuse = "Generator Fuse",
}

local function track(conn)
	table.insert(connections, conn)
	return conn
end

local function getPromptContainer()
	if PromptContainer and PromptContainer.Parent then return PromptContainer end

	if gethui then
		PromptContainer = Instance.new("Folder")
		PromptContainer.Name = "PromptContainer_" .. tostring(math.random(1, 99999))
		PromptContainer.Parent = gethui()
	else
		PromptContainer = Instance.new("Folder")
		PromptContainer.Name = "PromptContainer"
		PromptContainer.Parent = game:GetService("CoreGui")
	end

	return PromptContainer
end

------------------------------------------------------------
-- ANTI-LAG
------------------------------------------------------------
local function isScreechSound(obj)
	if not obj.Parent then return false end
	local pn = string.lower(obj.Parent.Name)
	return string.find(pn, "screech", 1, true) ~= nil
end

local function applyAntiLag()
	for _, obj in ipairs(workspace:GetDescendants()) do
		if obj:IsA("BasePart") then
			if not lagState.saved[obj] then
				lagState.saved[obj] = { Material = obj.Material }
			end
			obj.Material = Enum.Material.SmoothPlastic
			obj.Reflectance = 0
		elseif obj:IsA("Decal") or obj:IsA("Texture") then
			obj.Transparency = 1
		elseif obj:IsA("ParticleEmitter")
			or obj:IsA("Trail")
			or obj:IsA("Smoke")
			or obj:IsA("Fire")
			or obj:IsA("Sparkles")
			or obj:IsA("Beam") then
			obj.Enabled = false
		elseif obj:IsA("Sound") then
			if isScreechSound(obj) then
				obj.Volume = 1
			else
				obj.Volume = 0
			end
		end
	end
end

local function restoreAntiLag()
	for obj, data in pairs(lagState.saved) do
		if obj and obj.Parent and obj:IsA("BasePart") and data.Material then
			obj.Material = data.Material
		end
	end
	lagState.saved = {}
end

------------------------------------------------------------
-- FAKE PROMPTS
------------------------------------------------------------
local function isLockPrompt(prompt)
	if LOCK_PROMPT_NAMES[prompt.Name] then return true end
	if prompt.Parent and prompt.Parent:GetAttribute("Locked") == true then return true end
	if prompt.Parent and prompt.Parent.Parent
		and prompt.Parent.Parent.Name == "Locker_Small_Locked"
		and prompt.Name == "ActivateEventPrompt" then
		return true
	end
	return false
end

local function makeFakePrompt(originalPrompt)
	-- уже fake?
	if originalPrompt:GetAttribute("FakePrompt") then return end
	-- уже обработан?
	for fake in pairs(FakePrompts) do
		if FakePrompts[fake] == originalPrompt then return end
	end

	local fake = originalPrompt:Clone()
	fake:SetAttribute("FakePrompt", true)
	fake.Name = originalPrompt.Name
	fake.Parent = originalPrompt.Parent
	task.wait()
	fake.Enabled = originalPrompt.Enabled

	-- прячем оригинал
	originalPrompt.Parent = getPromptContainer()

	-- сохраняем связь
	FakePrompts[fake] = originalPrompt

	-- синхронизация Enabled
	local enabledConn = originalPrompt:GetPropertyChangedSignal("Enabled"):Connect(function()
		if fake and fake.Parent then
			fake.Enabled = originalPrompt.Enabled
		end
	end)
	track(enabledConn)

	-- очистка при уничтожении
	originalPrompt.Destroying:Once(function()
		if fake and fake.Parent then fake:Destroy() end
		FakePrompts[fake] = nil
	end)
	fake.Destroying:Once(function()
		FakePrompts[fake] = nil
	end)
end

local function scanPromptsForFake()
	for _, obj in ipairs(workspace:GetDescendants()) do
		if obj:IsA("ProximityPrompt") and not obj:GetAttribute("FakePrompt") then
			if isLockPrompt(obj) then
				makeFakePrompt(obj)
			end
		end
	end
end

local function onPromptAdded(obj)
	if not obj:IsA("ProximityPrompt") then return end
	if obj:GetAttribute("FakePrompt") then return end

	task.wait(0.1)
	if isLockPrompt(obj) then
		makeFakePrompt(obj)
	end
end

------------------------------------------------------------
-- FIRE PROMPT HELPER
------------------------------------------------------------
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

------------------------------------------------------------
-- INFINITE ITEMS
------------------------------------------------------------
local function onPromptTriggered(prompt)
	if not infState.enabled then return end
	if not prompt:GetAttribute("FakePrompt") then return end

	print("[INF] FakePrompt triggered:", prompt.Name)

	local char = player.Character
	if not char then return end

	local anyTool = char:FindFirstChildOfClass("Tool")
	if not anyTool then
		print("[INF] нет tool в руках")
		return
	end

	local toolData = ItemNames[anyTool.Name]
	if not toolData then
		print("[INF] tool не в списке:", anyTool.Name)
		-- просто активируем оригинал
		local realPrompt = FakePrompts[prompt]
		if realPrompt then firePrompt(realPrompt) end
		return
	end

	print("[INF] Tool:", anyTool.Name, "→", toolData)

	local drops = workspace:FindFirstChild("Drops")
	local rf = ReplicatedStorage:FindFirstChild("RemotesFolder")

	if not drops then warn("[INF] нет workspace.Drops") return end
	if not rf then warn("[INF] нет RemotesFolder") return end

	local dropRemote = rf:FindFirstChild("DropItem")
	if not dropRemote then warn("[INF] нет DropItem remote") return end

	-- ждём новый дроп
	local gotDrop = false
	local dropConn
	dropConn = drops.ChildAdded:Connect(function(newTool)
		if gotDrop then return end
		gotDrop = true
		if dropConn then dropConn:Disconnect() end

		print("[INF] Новый дроп:", newTool.Name)
		task.wait(0.15)

		local dropPrompt = newTool:FindFirstChild("ModulePrompt")
			or newTool:FindFirstChildWhichIsA("ProximityPrompt")

		if dropPrompt then
			print("[INF] Подбираю дроп")
			firePrompt(dropPrompt)
		end

		-- активируем оригинальный prompt (чтобы игра думала что всё ок)
		local realPrompt = FakePrompts[prompt]
		if realPrompt then
			firePrompt(realPrompt)
		end
	end)
	track(dropConn)

	-- страховка — если дроп не появился за 2 секунды
	task.delay(2, function()
		if not gotDrop and dropConn then
			dropConn:Disconnect()
			warn("[INF] Дроп не появился за 2 сек")
			local realPrompt = FakePrompts[prompt]
			if realPrompt then firePrompt(realPrompt) end
		end
	end)

	-- фаерим DropItem
	print("[INF] Фаерю DropItem")
	pcall(function() dropRemote:FireServer(anyTool) end)
end

------------------------------------------------------------
-- UI (page 3)
------------------------------------------------------------
local function buildUI()
	page = Hub.Page(3)
	if not page then
		warn("[misc] page 3 не найдена")
		return
	end

	-- ============ ANTI-LAG ============
	Elements.label(page, "ANTI-LAG", 74)
	Hub.Toggles.antiLag = Elements.switch(page, 72, function(on)
		lagState.enabled = on
		if on then
			applyAntiLag()
		else
			restoreAntiLag()
		end
	end)

	-- ============ INFINITE ITEMS ============
	Elements.label(page, "INFINITE ITEMS", 94)

	local infHint = Elements.label(page,
		"Lockpick, Skeleton Key, Shears, Multitool", 112,
		{ color = Color3.fromRGB(150, 150, 150), size = 9,
		  font = Enum.Font.Gotham })

	Hub.Toggles.infiniteItems = Elements.switch(page, 92, function(on)
		infState.enabled = on
		if on then
			print("[MISC] Infinite Items ON")
			scanPromptsForFake()
		else
			print("[MISC] Infinite Items OFF")
		end
	end)
end

------------------------------------------------------------
-- INIT
------------------------------------------------------------
function Misc.init(hub)
	Hub = hub
	Config = hub.Config
	Toggles = hub.Toggles
	Elements = hub.Elements or (hub.Objects and hub.Objects.Elements)

	if not Elements then
		warn("[misc] Elements не найдены — ui.lua должен грузиться первым")
		return
	end

	-- UI
	buildUI()

	-- сохраняем реестр в Hub
	Hub.Objects.FakePrompts = FakePrompts

	-- ============ FAKE PROMPTS SETUP ============
	-- сканируем существующие prompts
	task.spawn(scanPromptsForFake)

	-- следим за новыми
	track(workspace.DescendantAdded:Connect(onPromptAdded))

	-- ============ INFINITE ITEMS LISTENER ============
	track(ProximityPromptService.PromptTriggered:Connect(onPromptTriggered))

	-- ============ CLEANUP ============
	function Misc.cleanup()
		lagState.enabled = false
		infState.enabled = false

		restoreAntiLag()

		-- восстанавливаем оригинальные prompts
		for fake, original in pairs(FakePrompts) do
			if original and original.Parent == PromptContainer then
				if fake and fake.Parent then
					original.Parent = fake.Parent
				end
			end
			if fake and fake.Parent then
				fake:Destroy()
			end
		end
		FakePrompts = {}
		Hub.Objects.FakePrompts = FakePrompts

		if PromptContainer and PromptContainer.Parent then
			PromptContainer:Destroy()
		end
		PromptContainer = nil

		for _, conn in ipairs(connections) do
			pcall(function() conn:Disconnect() end)
		end
		connections = {}
	end

	print("[MISC] Модуль инициализирован")
	return Misc
end

return Misc
