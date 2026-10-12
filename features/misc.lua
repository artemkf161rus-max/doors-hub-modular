local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ProximityPromptService = game:GetService("ProximityPromptService")
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
	saved = {}, -- [Instance] = {Material = ...}
}

-- infinite items
local infState = {
	enabled = false,
}

local function track(conn)
	table.insert(connections, conn)
	return conn
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
-- INFINITE ITEMS
------------------------------------------------------------
local function firePrompt(prompt)
	if not prompt then return end
	pcall(function() fireproximityprompt(prompt) end)
end

local function onPromptTriggered(prompt)
	if not infState.enabled then return end

	local remotes = ReplicatedStorage:FindFirstChild("RemotesFolder")
	if not remotes then return end
	local drops = workspace:FindFirstChild("Drops")
	if not drops then return end
	local dropRemote = remotes:FindFirstChild("DropItem")
	if not dropRemote then return end

	local char = player.Character
	if not char then return end

	local anyTool = char:FindFirstChildOfClass("Tool")
	if not anyTool then return end

	local toolData = Config.ITEM_NAMES[anyTool.Name]
	if not toolData then return end

	-- ждём появления дропа
	drops.ChildAdded:Once(function(newTool)
		local dropPrompt = newTool:FindFirstChild("ModulePrompt")
		if dropPrompt then
			firePrompt(dropPrompt)
		end
	end)

	-- фаерим дроп
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

	-- ============ INFINITE ITEMS LISTENER ============
	track(ProximityPromptService.PromptTriggered:Connect(onPromptTriggered))

	-- ============ CLEANUP ============
	function Misc.cleanup()
		lagState.enabled = false
		infState.enabled = false

		restoreAntiLag()

		for _, conn in ipairs(connections) do
			pcall(function() conn:Disconnect() end)
		end
		connections = {}
	end

	print("[MISC] Модуль инициализирован")
	return Misc
end

return Misc
