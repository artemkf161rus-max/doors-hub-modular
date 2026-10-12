local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local UI = {}

local Hub
local Config
local Toggles
local Connections = {}

local gui
local menu
local buttonHolder
local pages = {}
local currentPage = 1
local totalPages = 3
local isLocked = false

local function track(conn)
	table.insert(Connections, conn)
	return conn
end

local function makeDraggable(frame, dragTarget, canDrag)
	local dragging, dragStart, startPos, dragInput
	local target = dragTarget or frame
	track(target.InputBegan:Connect(function(input)
		if canDrag and not canDrag() then return end
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			dragStart = input.Position
			startPos = frame.Position
			input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then dragging = false end
			end)
		end
	end))
	track(target.InputChanged:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
			dragInput = input
		end
	end))
	track(UserInputService.InputChanged:Connect(function(input)
		if not dragging then return end
		if canDrag and not canDrag() then dragging = false return end
		if input == dragInput and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			local delta = input.Position - dragStart
			frame.Position = UDim2.new(
				startPos.X.Scale, startPos.X.Offset + delta.X,
				startPos.Y.Scale, startPos.Y.Offset + delta.Y
			)
		end
	end))
end

local function sOn(bg, knob)
	TweenService:Create(bg, TweenInfo.new(0.2), { BackgroundColor3 = Color3.fromRGB(120, 0, 200) }):Play()
	TweenService:Create(knob, TweenInfo.new(0.2), { Position = UDim2.new(0, 23, 0.5, -7) }):Play()
end

local function sOff(bg, knob)
	TweenService:Create(bg, TweenInfo.new(0.2), { BackgroundColor3 = Color3.fromRGB(60, 60, 60) }):Play()
	TweenService:Create(knob, TweenInfo.new(0.2), { Position = UDim2.new(0, 3, 0.5, -7) }):Play()
end

local function makeBtn(text, order, color, width)
	local b = Instance.new("TextButton")
	b.Size = UDim2.new(0, width or 80, 0, 40)
	b.BackgroundColor3 = color
	b.BorderSizePixel = 0
	b.Text = text
	b.TextColor3 = Color3.fromRGB(255, 255, 255)
	b.Font = Enum.Font.GothamBold
	b.TextSize = 13
	b.LayoutOrder = order
	b.AutoButtonColor = false
	b.Active = true
	b.Parent = buttonHolder
	local c = Instance.new("UICorner") c.CornerRadius = UDim.new(0, 8) c.Parent = b
	local s = Instance.new("UIStroke") s.Color = Color3.fromRGB(200, 150, 255) s.Thickness = 2 s.Parent = b
	return b
end

local function makeLabel(parent, text, y)
	local l = Instance.new("TextLabel")
	l.Size = UDim2.new(1, -20, 0, 16)
	l.Position = UDim2.new(0, 10, 0, y)
	l.BackgroundTransparency = 1
	l.Text = text
	l.TextColor3 = Color3.fromRGB(220, 200, 255)
	l.Font = Enum.Font.GothamBold
	l.TextSize = 11
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.Parent = parent
	return l
end

local function makeSwitch(parent, y)
	local bg = Instance.new("TextButton")
	bg.Size = UDim2.new(0, 40, 0, 20)
	bg.Position = UDim2.new(1, -50, 0, y - 2)
	bg.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
	bg.BorderSizePixel = 0
	bg.Text = ""
	bg.AutoButtonColor = false
	bg.Parent = parent
	local c = Instance.new("UICorner") c.CornerRadius = UDim.new(1, 0) c.Parent = bg
	local knob = Instance.new("Frame")
	knob.Size = UDim2.new(0, 14, 0, 14)
	knob.Position = UDim2.new(0, 3, 0.5, -7)
	knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	knob.BorderSizePixel = 0
	knob.Parent = bg
	local kc = Instance.new("UICorner") kc.CornerRadius = UDim.new(1, 0) kc.Parent = knob
	return bg, knob
end

local function makeSlider(parent, y, min, max, def, onChange)
	local sb = Instance.new("Frame")
	sb.Size = UDim2.new(1, -20, 0, 8)
	sb.Position = UDim2.new(0, 10, 0, y)
	sb.BackgroundColor3 = Color3.fromRGB(30, 0, 55)
	sb.BorderSizePixel = 0
	sb.Active = true
	sb.Parent = parent
	local sc = Instance.new("UICorner") sc.CornerRadius = UDim.new(1, 0) sc.Parent = sb
	local fill = Instance.new("Frame")
	fill.Size = UDim2.new((def - min) / (max - min), 0, 1, 0)
	fill.BackgroundColor3 = Color3.fromRGB(180, 100, 255)
	fill.BorderSizePixel = 0
	fill.Parent = sb
	local fc = Instance.new("UICorner") fc.CornerRadius = UDim.new(1, 0) fc.Parent = fill
	local knob = Instance.new("Frame")
	knob.Size = UDim2.new(0, 14, 0, 14)
	knob.Position = UDim2.new((def - min) / (max - min), 0, 0.5, 0)
	knob.AnchorPoint = Vector2.new(0, 0.5)
	knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	knob.BorderSizePixel = 0
	knob.ZIndex = 2
	knob.Parent = sb
	local kc = Instance.new("UICorner") kc.CornerRadius = UDim.new(1, 0) kc.Parent = knob
	local dragging = false
	local function setV(v)
		v = math.clamp(v, min, max)
		local a = (v - min) / (max - min)
		fill.Size = UDim2.new(a, 0, 1, 0)
		knob.Position = UDim2.new(a, 0, 0.5, 0)
		if onChange then onChange(v) end
	end
	track(sb.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			local p = input.Position.X - sb.AbsolutePosition.X
			setV(min + math.clamp(p / sb.AbsoluteSize.X, 0, 1) * (max - min))
		end
	end))
	track(UserInputService.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			local p = input.Position.X - sb.AbsolutePosition.X
			setV(min + math.clamp(p / sb.AbsoluteSize.X, 0, 1) * (max - min))
		end
	end))
	track(UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then dragging = false end
	end))
	return setV
end

------------------------------------------------------------
-- BUILD GUI
------------------------------------------------------------
local function buildGui()
	gui = Instance.new("ScreenGui")
	gui.Name = "MenuUI"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 999
	gui.Parent = playerGui

	-- Кнопки сверху
	buttonHolder = Instance.new("Frame")
	buttonHolder.Size = UDim2.new(0, 320, 0, 40)
	buttonHolder.Position = UDim2.new(0, 20, 0, 20)
	buttonHolder.BackgroundTransparency = 1
	buttonHolder.Active = true
	buttonHolder.Parent = gui

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.Padding = UDim.new(0, 10)
	layout.Parent = buttonHolder

	local toggleButton = makeBtn("Toggle", 1, Color3.fromRGB(75, 0, 130), 80)
	local lockButton = makeBtn("Locked", 2, Color3.fromRGB(75, 0, 130), 90)
	local unloadButton = makeBtn("Выгрузить", 3, Color3.fromRGB(150, 0, 0), 100)

	-- Меню
	menu = Instance.new("Frame")
	menu.Size = UDim2.new(0, 280, 0, 300)
	menu.Position = UDim2.new(0, 20, 0, 80)
	menu.BackgroundColor3 = Color3.fromRGB(45, 0, 80)
	menu.BorderSizePixel = 0
	menu.Visible = false
	menu.Active = true
	menu.Parent = gui
	local mc = Instance.new("UICorner") mc.CornerRadius = UDim.new(0, 10) mc.Parent = menu
	local mst = Instance.new("UIStroke") mst.Color = Color3.fromRGB(180, 100, 255) mst.Thickness = 2 mst.Parent = menu

	-- Страницы
	for i = 1, totalPages do
		local p = Instance.new("Frame")
		p.Size = UDim2.new(1, 0, 1, -40)
		p.BackgroundTransparency = 1
		p.Visible = false
		p.Parent = menu
		pages[i] = p
	end

	-- Навигация
	local pageNav = Instance.new("Frame")
	pageNav.Size = UDim2.new(1, -20, 0, 30)
	pageNav.Position = UDim2.new(0, 10, 1, -35)
	pageNav.BackgroundTransparency = 1
	pageNav.Parent = menu

	local prevBtn = Instance.new("TextButton")
	prevBtn.Size = UDim2.new(0, 60, 1, 0)
	prevBtn.BackgroundColor3 = Color3.fromRGB(90, 0, 160)
	prevBtn.BorderSizePixel = 0
	prevBtn.Text = "◀"
	prevBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	prevBtn.Font = Enum.Font.GothamBold
	prevBtn.TextSize = 18
	prevBtn.AutoButtonColor = false
	prevBtn.Parent = pageNav
	local pc = Instance.new("UICorner") pc.CornerRadius = UDim.new(0, 6) pc.Parent = prevBtn

	local nextBtn = Instance.new("TextButton")
	nextBtn.Size = UDim2.new(0, 60, 1, 0)
	nextBtn.Position = UDim2.new(1, -60, 0, 0)
	nextBtn.BackgroundColor3 = Color3.fromRGB(90, 0, 160)
	nextBtn.BorderSizePixel = 0
	nextBtn.Text = "▶"
	nextBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	nextBtn.Font = Enum.Font.GothamBold
	nextBtn.TextSize = 18
	nextBtn.AutoButtonColor = false
	nextBtn.Parent = pageNav
	local nc = Instance.new("UICorner") nc.CornerRadius = UDim.new(0, 6) nc.Parent = nextBtn

	local pageLabel = Instance.new("TextLabel")
	pageLabel.Size = UDim2.new(1, -140, 1, 0)
	pageLabel.Position = UDim2.new(0, 70, 0, 0)
	pageLabel.BackgroundTransparency = 1
	pageLabel.Text = "1 / " .. totalPages
	pageLabel.TextColor3 = Color3.fromRGB(220, 200, 255)
	pageLabel.Font = Enum.Font.GothamBold
	pageLabel.TextSize = 14
	pageLabel.Parent = pageNav

	local function showPage(n)
		if n < 1 then n = totalPages end
		if n > totalPages then n = 1 end
		currentPage = n
		for i, p in ipairs(pages) do p.Visible = (i == n) end
		pageLabel.Text = n .. " / " .. totalPages
	end

	track(prevBtn.MouseButton1Click:Connect(function() showPage(currentPage - 1) end))
	track(nextBtn.MouseButton1Click:Connect(function() showPage(currentPage + 1) end))

	------------------------------------------------------------
	-- PAGE 1: WALKSPEED / FOV / FULLBRIGHT
	------------------------------------------------------------
	makeLabel(pages[1], "WALKSPEED (16-150)", 2)
	local wsVal = Instance.new("TextLabel")
	wsVal.Size = UDim2.new(1, -20, 0, 14)
	wsVal.Position = UDim2.new(0, 10, 0, 18)
	wsVal.BackgroundTransparency = 1
	wsVal.Text = "REAL 16 / FAKE 15"
	wsVal.TextColor3 = Color3.fromRGB(255, 255, 255)
	wsVal.Font = Enum.Font.GothamBold
	wsVal.TextSize = 10
	wsVal.TextXAlignment = Enum.TextXAlignment.Left
	wsVal.Parent = pages[1]

	local speedSlider = makeSlider(pages[1], 36, 16, 150, 16, function(v)
		local s = math.floor(v + 0.5)
		wsVal.Text = "REAL " .. s .. " / FAKE 15"
		if Hub.Functions.Movement and Hub.Functions.Movement.setSpeed then
			Hub.Functions.Movement.setSpeed(s)
		end
	end)

	local spSt = Instance.new("TextLabel")
	spSt.Size = UDim2.new(1, -20, 0, 12)
	spSt.Position = UDim2.new(0, 10, 0, 50)
	spSt.BackgroundTransparency = 1
	spSt.Text = "Spoof: READY"
	spSt.TextColor3 = Color3.fromRGB(100, 255, 100)
	spSt.Font = Enum.Font.GothamBold
	spSt.TextSize = 9
	spSt.TextXAlignment = Enum.TextXAlignment.Left
	spSt.Parent = pages[1]

	makeLabel(pages[1], "ENABLE SPEED", 66)
	local sBg, sKnob = makeSwitch(pages[1], 64)
	track(sBg.MouseButton1Click:Connect(function()
		local state = not Toggles.speed
		if Hub.Functions.Movement and Hub.Functions.Movement.toggleSpeed then
			Hub.Functions.Movement.toggleSpeed(state)
			if state then sOn(sBg, sKnob) else sOff(sBg, sKnob) end
		end
	end))

	makeLabel(pages[1], "FOV ENABLE", 86)
	local fovBg, fovKnob = makeSwitch(pages[1], 84)
	track(fovBg.MouseButton1Click:Connect(function()
		local state = not Toggles.fov
		if Hub.Functions.Movement and Hub.Functions.Movement.toggleFOV then
			Hub.Functions.Movement.toggleFOV(state)
			if state then sOn(fovBg, fovKnob) else sOff(fovBg, fovKnob) end
		end
	end))

	local fovVal = Instance.new("TextLabel")
	fovVal.Size = UDim2.new(1, -20, 0, 12)
	fovVal.Position = UDim2.new(0, 10, 0, 104)
	fovVal.BackgroundTransparency = 1
	fovVal.Text = "FOV: 70"
	fovVal.TextColor3 = Color3.fromRGB(255, 255, 255)
	fovVal.Font = Enum.Font.GothamBold
	fovVal.TextSize = 10
	fovVal.TextXAlignment = Enum.TextXAlignment.Left
	fovVal.Parent = pages[1]

	makeSlider(pages[1], 120, 1, 120, 70, function(v)
		local f = math.floor(v)
		fovVal.Text = "FOV: " .. f
		if Hub.Functions.Movement and Hub.Functions.Movement.setFOV then
			Hub.Functions.Movement.setFOV(f)
		end
	end)

	makeLabel(pages[1], "FULLBRIGHT", 138)
	local fbBg, fbKnob = makeSwitch(pages[1], 136)
	track(fbBg.MouseButton1Click:Connect(function()
		local state = not Toggles.fullbright
		if Hub.Functions.Movement and Hub.Functions.Movement.toggleFullbright then
			Hub.Functions.Movement.toggleFullbright(state)
			if state then sOn(fbBg, fbKnob) else sOff(fbBg, fbKnob) end
		end
	end))

	------------------------------------------------------------
	-- PAGE 2: ESP
	------------------------------------------------------------
	makeLabel(pages[2], "ESP PLAYERS", 2)
	local espBg, espKnob = makeSwitch(pages[2], 0)
	track(espBg.MouseButton1Click:Connect(function()
		local state = not Toggles.espPlayers
		if Hub.Functions.ESP then
			Hub.Functions.ESP.togglePlayers(state)
			if state then sOn(espBg, espKnob) else sOff(espBg, espKnob) end
		end
	end))

	makeLabel(pages[2], "ESP TOOLS", 22)
	local toolBg, toolKnob = makeSwitch(pages[2], 20)
	track(toolBg.MouseButton1Click:Connect(function()
		local state = not Toggles.espTools
		if Hub.Functions.ESP then
			Hub.Functions.ESP.toggleTools(state)
			if state then sOn(toolBg, toolKnob) else sOff(toolBg, toolKnob) end
		end
	end))

	makeLabel(pages[2], "ESP PROMPTS", 42)
	local promptBg, promptKnob = makeSwitch(pages[2], 40)
	track(promptBg.MouseButton1Click:Connect(function()
		local state = not Toggles.espPrompts
		if Hub.Functions.ESP then
			Hub.Functions.ESP.togglePrompts(state)
			if state then sOn(promptBg, promptKnob) else sOff(promptBg, promptKnob) end
		end
	end))

	makeLabel(pages[2], "ESP MONSTERS", 62)
	local monBg, monKnob = makeSwitch(pages[2], 60)
	track(monBg.MouseButton1Click:Connect(function()
		local state = not Toggles.espMonsters
		if Hub.Functions.ESP then
			Hub.Functions.ESP.toggleMonsters(state)
			if state then sOn(monBg, monKnob) else sOff(monBg, monKnob) end
		end
	end))

	makeLabel(pages[2], "INSTANT PROMPT", 82)
	local instBg, instKnob = makeSwitch(pages[2], 80)
	track(instBg.MouseButton1Click:Connect(function()
		local state = not Toggles.instantPrompt
		if Hub.Functions.Misc and Hub.Functions.Misc.toggleInstantPrompt then
			Hub.Functions.Misc.toggleInstantPrompt(state)
			if state then sOn(instBg, instKnob) else sOff(instBg, instKnob) end
		end
	end))

	------------------------------------------------------------
	-- PAGE 3: EXPLOITS
	------------------------------------------------------------
	makeLabel(pages[3], "ANTICHEAT BYPASS", 2)
	local bypBg, bypKnob = makeSwitch(pages[3], 0)
	track(bypBg.MouseButton1Click:Connect(function()
		local state = not Toggles.anticheat
		if Hub.Functions.Bypass and Hub.Functions.Bypass.toggleAnticheat then
			Hub.Functions.Bypass.toggleAnticheat(state)
			if state then sOn(bypBg, bypKnob) else sOff(bypBg, bypKnob) end
		end
	end))

	local bypHint = Instance.new("TextLabel")
	bypHint.Size = UDim2.new(1, -20, 0, 12)
	bypHint.Position = UDim2.new(0, 10, 0, 18)
	bypHint.BackgroundTransparency = 1
	bypHint.Text = "Климб лестницу"
	bypHint.TextColor3 = Color3.fromRGB(180, 180, 180)
	bypHint.Font = Enum.Font.Gotham
	bypHint.TextSize = 9
	bypHint.TextXAlignment = Enum.TextXAlignment.Left
	bypHint.Parent = pages[3]

	makeLabel(pages[3], "DOOR REACH", 34)
	local doorBg, doorKnob = makeSwitch(pages[3], 32)
	track(doorBg.MouseButton1Click:Connect(function()
		local state = not Toggles.doorReach
		if Hub.Functions.Bypass and Hub.Functions.Bypass.toggleDoorReach then
			Hub.Functions.Bypass.toggleDoorReach(state)
			if state then sOn(doorBg, doorKnob) else sOff(doorBg, doorKnob) end
		end
	end))

	makeLabel(pages[3], "ENTITY NOTIFY", 54)
	local notifyBg, notifyKnob = makeSwitch(pages[3], 52)
	track(notifyBg.MouseButton1Click:Connect(function()
		local state = not Toggles.entityNotify
		if Hub.Functions.Notify and Hub.Functions.Notify.toggle then
			Hub.Functions.Notify.toggle(state)
			if state then sOn(notifyBg, notifyKnob) else sOff(notifyBg, notifyKnob) end
		end
	end))

	makeLabel(pages[3], "ANTI-LAG", 74)
	local lagBg, lagKnob = makeSwitch(pages[3], 72)
	track(lagBg.MouseButton1Click:Connect(function()
		local state = not Toggles.antiLag
		if Hub.Functions.Misc and Hub.Functions.Misc.toggleAntiLag then
			Hub.Functions.Misc.toggleAntiLag(state)
			if state then sOn(lagBg, lagKnob) else sOff(lagBg, lagKnob) end
		end
	end))

	makeLabel(pages[3], "INFINITE ITEMS", 94)
	local infBg, infKnob = makeSwitch(pages[3], 92)
	track(infBg.MouseButton1Click:Connect(function()
		local state = not Toggles.infiniteItems
		if Hub.Functions.Bypass and Hub.Functions.Bypass.toggleInfiniteItems then
			Hub.Functions.Bypass.toggleInfiniteItems(state)
			if state then sOn(infBg, infKnob) else sOff(infBg, infKnob) end
		end
	end))

	local infHint = Instance.new("TextLabel")
	infHint.Size = UDim2.new(1, -20, 0, 12)
	infHint.Position = UDim2.new(0, 10, 0, 112)
	infHint.BackgroundTransparency = 1
	infHint.Text = "Lockpick, Skeleton Key, Shears, Multitool"
	infHint.TextColor3 = Color3.fromRGB(150, 150, 150)
	infHint.Font = Enum.Font.Gotham
	infHint.TextSize = 9
	infHint.TextXAlignment = Enum.TextXAlignment.Left
	infHint.Parent = pages[3]

	showPage(1)

	------------------------------------------------------------
	-- TOGGLE / LOCK / UNLOAD
	------------------------------------------------------------
	local menuOpen = false
	track(toggleButton.MouseButton1Click:Connect(function()
		menuOpen = not menuOpen
		menu.Visible = menuOpen
		if menuOpen then
			menu.Position = UDim2.new(
				buttonHolder.Position.X.Scale,
				buttonHolder.Position.X.Offset,
				buttonHolder.Position.Y.Scale,
				buttonHolder.Position.Y.Offset + 50
			)
		end
	end))

	track(lockButton.MouseButton1Click:Connect(function()
		isLocked = not isLocked
		if isLocked then
			lockButton.Text = "Locked"
			lockButton.BackgroundColor3 = Color3.fromRGB(75, 0, 130)
		else
			lockButton.Text = "Unlocked"
			lockButton.BackgroundColor3 = Color3.fromRGB(120, 0, 200)
		end
	end))

	track(unloadButton.MouseButton1Click:Connect(function()
		if Hub.Functions.ESP then Hub.Functions.ESP.cleanup() end
		if Hub.Functions.Movement and Hub.Functions.Movement.cleanup then Hub.Functions.Movement.cleanup() end
		if Hub.Functions.Bypass and Hub.Functions.Bypass.cleanup then Hub.Functions.Bypass.cleanup() end
		if Hub.Functions.Notify and Hub.Functions.Notify.cleanup then Hub.Functions.Notify.cleanup() end
		if Hub.Functions.Misc and Hub.Functions.Misc.cleanup then Hub.Functions.Misc.cleanup() end
		for _, conn in ipairs(Connections) do
			pcall(function() conn:Disconnect() end)
		end
		Connections = {}
		if gui and gui.Parent then gui:Destroy() end
	end))

	-- Перетаскивание
	makeDraggable(buttonHolder, toggleButton, function() return not isLocked end)
	makeDraggable(buttonHolder, lockButton, function() return not isLocked end)
	makeDraggable(buttonHolder, unloadButton, function() return not isLocked end)
	makeDraggable(menu, menu, function() return not isLocked end)
end

------------------------------------------------------------
-- INIT
------------------------------------------------------------
function UI.init(hub)
	Hub = hub
	Config = hub.Config
	Toggles = hub.Toggles

	buildGui()

	function UI.cleanup()
		for _, conn in ipairs(Connections) do
			pcall(function() conn:Disconnect() end)
		end
		Connections = {}
		if gui and gui.Parent then gui:Destroy() end
	end

	print("[UI] Модуль инициализирован")
end

return UI
