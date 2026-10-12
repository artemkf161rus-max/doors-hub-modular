local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local Notify = {}

-- ==================== STATE ====================
local Config
local Toggles
local Hub
local Elements
local page

local connections = {}

local notifyGui = nil
local notifyState = { enabled = false }
local notified = {} -- [Instance] = true, защита от спама

local function track(conn)
	table.insert(connections, conn)
	return conn
end

------------------------------------------------------------
-- GUI
------------------------------------------------------------
local function ensureGui()
	if notifyGui and notifyGui.Parent then return notifyGui end

	notifyGui = Instance.new("ScreenGui")
	notifyGui.Name = "HubNotifications"
	notifyGui.ResetOnSpawn = false
	notifyGui.IgnoreGuiInset = true
	notifyGui.DisplayOrder = 998
	notifyGui.Parent = playerGui

	return notifyGui
end

------------------------------------------------------------
-- SHOW NOTIFICATION
------------------------------------------------------------
local function showNotification(name)
	local gui = ensureGui()

	local frame = Instance.new("Frame")
	frame.Size = UDim2.new(0, 320, 0, 70)
	frame.Position = UDim2.new(0.5, -160, 0, -100)
	frame.BackgroundColor3 = Color3.fromRGB(150, 0, 0)
	frame.BorderSizePixel = 0
	frame.Parent = gui

	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 12)
	c.Parent = frame

	local st = Instance.new("UIStroke")
	st.Color = Color3.fromRGB(255, 100, 100)
	st.Thickness = 3
	st.Parent = frame

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0, 26)
	title.Position = UDim2.new(0, 0, 0, 8)
	title.BackgroundTransparency = 1
	title.Text = "⚠ МОНСТР ⚠"
	title.TextColor3 = Color3.fromRGB(255, 255, 255)
	title.Font = Enum.Font.GothamBold
	title.TextSize = 18
	title.Parent = frame

	local nl = Instance.new("TextLabel")
	nl.Size = UDim2.new(1, 0, 0, 24)
	nl.Position = UDim2.new(0, 0, 0, 36)
	nl.BackgroundTransparency = 1
	nl.Text = name
	nl.TextColor3 = Color3.fromRGB(255, 220, 100)
	nl.Font = Enum.Font.GothamBold
	nl.TextSize = 20
	nl.Parent = frame

	-- звук
	local s = Instance.new("Sound")
	s.SoundId = "rbxassetid://4896323111"
	s.Volume = 2
	s.Parent = frame
	s:Play()

	-- появление
	TweenService:Create(frame,
		TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{Position = UDim2.new(0.5, -160, 0, 40)}):Play()

	-- исчезновение
	task.delay(3, function()
		local t = TweenService:Create(frame,
			TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{Position = UDim2.new(0.5, -160, 0, -100), BackgroundTransparency = 1})
		t:Play()

		for _, obj in ipairs(frame:GetDescendants()) do
			if obj:IsA("TextLabel") then
				TweenService:Create(obj, TweenInfo.new(0.4), {TextTransparency = 1}):Play()
			elseif obj:IsA("UIStroke") then
				TweenService:Create(obj, TweenInfo.new(0.4), {Transparency = 1}):Play()
			end
		end

		t.Completed:Connect(function()
			if frame and frame.Parent then frame:Destroy() end
		end)
	end)
end

------------------------------------------------------------
-- DETECT MONSTERS
------------------------------------------------------------
local function onDescendantAdded(obj)
	if not notifyState.enabled then return end
	if notified[obj] then return end

	local alias = Config.ENTITY_LIST[obj.Name]
	if not alias then return end

	notified[obj] = true
	showNotification(alias)

	-- сброс флага через 15 сек
	task.delay(15, function()
		notified[obj] = nil
	end)
end

------------------------------------------------------------
-- UI (page 3)
------------------------------------------------------------
local function buildUI()
	page = Hub.Page(3)
	if not page then
		warn("[notify] page 3 не найдена")
		return
	end

	Elements.label(page, "ENTITY NOTIFY", 54)
	Hub.Toggles.entityNotify = Elements.switch(page, 52, function(on)
		notifyState.enabled = on
		if not on then
			notified = {}
		end
	end)
end

------------------------------------------------------------
-- INIT
------------------------------------------------------------
function Notify.init(hub)
	Hub = hub
	Config = hub.Config
	Toggles = hub.Toggles
	Elements = hub.Elements or (hub.Objects and hub.Objects.Elements)

	if not Elements then
		warn("[notify] Elements не найдены — ui.lua должен грузиться первым")
		return
	end

	-- UI
	buildUI()

	-- подписка на новые объекты в workspace
	track(workspace.DescendantAdded:Connect(onDescendantAdded))

	-- ============ CLEANUP ============
	function Notify.cleanup()
		notifyState.enabled = false
		notified = {}

		for _, conn in ipairs(connections) do
			pcall(function() conn:Disconnect() end)
		end
		connections = {}

		if notifyGui and notifyGui.Parent then
			notifyGui:Destroy()
		end
		notifyGui = nil
	end

	print("[NOTIFY] Модуль инициализирован")
	return Notify
end

return Notify
