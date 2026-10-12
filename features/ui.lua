local UI = {}

function UI.init(Hub)
	local Players = game:GetService("Players")
	local TweenService = game:GetService("TweenService")
	local UserInputService = game:GetService("UserInputService")
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")

	-- ==================== ЦВЕТА ====================
	local COLORS = {
		Background  = Color3.fromRGB(45, 0, 80),
		Background2 = Color3.fromRGB(30, 0, 55),
		Accent      = Color3.fromRGB(180, 100, 255),
		AccentDark  = Color3.fromRGB(90, 0, 160),
		Stroke      = Color3.fromRGB(200, 150, 255),
		Text        = Color3.fromRGB(220, 200, 255),
		TextBright  = Color3.fromRGB(255, 255, 255),
		Danger      = Color3.fromRGB(150, 0, 0),
		SwitchOff   = Color3.fromRGB(60, 60, 60),
		SwitchOn    = Color3.fromRGB(120, 0, 200),
	}
	local FONT_BOLD = Enum.Font.GothamBold

	-- ==================== ROOT ====================
	local gui = Instance.new("ScreenGui")
	gui.Name = "MenuUI"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 999
	gui.Parent = playerGui
	Hub.Objects.MainGui = gui

	local isLocked = false
	Hub.IsLocked = function() return isLocked end

	-- ==================== ХЕЛПЕРЫ ====================
	local function corner(parent, r)
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0, r or 8)
		c.Parent = parent
		return c
	end

	local function stroke(parent, color, thickness)
		local s = Instance.new("UIStroke")
		s.Color = color or COLORS.Stroke
		s.Thickness = thickness or 2
		s.Parent = parent
		return s
	end

	local function makeDraggable(frame, dragTarget)
		local dragging, dragStart, startPos, dragInput
		local target = dragTarget or frame
		target.InputBegan:Connect(function(input)
			if isLocked then return end
			if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then
				dragging = true
				dragStart = input.Position
				startPos = frame.Position
				input.Changed:Connect(function()
					if input.UserInputState == Enum.UserInputState.End then
						dragging = false
					end
				end)
			end
		end)
		target.InputChanged:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseMovement
			or input.UserInputType == Enum.UserInputType.Touch then
				dragInput = input
			end
		end)
		UserInputService.InputChanged:Connect(function(input)
			if not dragging then return end
			if isLocked then dragging = false return end
			if input == dragInput then
				local delta = input.Position - dragStart
				frame.Position = UDim2.new(
					startPos.X.Scale, startPos.X.Offset + delta.X,
					startPos.Y.Scale, startPos.Y.Offset + delta.Y
				)
			end
		end)
	end

	-- ==================== ЭЛЕМЕНТЫ ====================
	local Elements = {}

	function Elements.label(parent, text, y, cfg)
		cfg = cfg or {}
		local l = Instance.new("TextLabel")
		l.Size = UDim2.new(1, -20, 0, 16)
		l.Position = UDim2.new(0, 10, 0, y)
		l.BackgroundTransparency = 1
		l.Text = text
		l.TextColor3 = cfg.color or COLORS.Text
		l.Font = cfg.font or FONT_BOLD
		l.TextSize = cfg.size or 11
		l.TextXAlignment = Enum.TextXAlignment.Left
		l.Parent = parent
		return l
	end

	function Elements.switch(parent, y, callback)
		local bg = Instance.new("TextButton")
		bg.Size = UDim2.new(0, 40, 0, 20)
		bg.Position = UDim2.new(1, -50, 0, y - 2)
		bg.BackgroundColor3 = COLORS.SwitchOff
		bg.BorderSizePixel = 0
		bg.Text = ""
		bg.AutoButtonColor = false
		bg.Parent = parent
		corner(bg, 999)

		local knob = Instance.new("Frame")
		knob.Size = UDim2.new(0, 14, 0, 14)
		knob.Position = UDim2.new(0, 3, 0.5, -7)
		knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		knob.BorderSizePixel = 0
		knob.Parent = bg
		corner(knob, 999)

		local state = false
		local function update()
			TweenService:Create(bg, TweenInfo.new(0.2),
				{BackgroundColor3 = state and COLORS.SwitchOn or COLORS.SwitchOff}):Play()
			TweenService:Create(knob, TweenInfo.new(0.2),
				{Position = state and UDim2.new(0, 23, 0.5, -7) or UDim2.new(0, 3, 0.5, -7)}):Play()
			if callback then callback(state) end
		end

		bg.MouseButton1Click:Connect(function()
			state = not state
			update()
		end)

		return {
			instance = bg,
			knob = knob,
			get = function() return state end,
			set = function(v) state = v update() end,
		}
	end

	function Elements.slider(parent, y, min, max, default, callback)
		local sb = Instance.new("Frame")
		sb.Size = UDim2.new(1, -20, 0, 8)
		sb.Position = UDim2.new(0, 10, 0, y)
		sb.BackgroundColor3 = COLORS.Background2
		sb.BorderSizePixel = 0
		sb.Active = true
		sb.Parent = parent
		corner(sb, 999)

		local fill = Instance.new("Frame")
		fill.Size = UDim2.new((default - min) / (max - min), 0, 1, 0)
		fill.BackgroundColor3 = COLORS.Accent
		fill.BorderSizePixel = 0
		fill.Parent = sb
		corner(fill, 999)

		local knob = Instance.new("Frame")
		knob.Size = UDim2.new(0, 14, 0, 14)
		knob.Position = UDim2.new((default - min) / (max - min), 0, 0.5, 0)
		knob.AnchorPoint = Vector2.new(0, 0.5)
		knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		knob.BorderSizePixel = 0
		knob.ZIndex = 2
		knob.Parent = sb
		corner(knob, 999)

		local dragging = false
		local value = default
		local function setV(v)
			v = math.clamp(v, min, max)
			value = v
			local a = (v - min) / (max - min)
			fill.Size = UDim2.new(a, 0, 1, 0)
			knob.Position = UDim2.new(a, 0, 0.5, 0)
			if callback then callback(v) end
		end

		sb.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then
				dragging = true
				local p = input.Position.X - sb.AbsolutePosition.X
				setV(min + math.clamp(p / sb.AbsoluteSize.X, 0, 1) * (max - min))
			end
		end)
		UserInputService.InputChanged:Connect(function(input)
			if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
			or input.UserInputType == Enum.UserInputType.Touch) then
				local p = input.Position.X - sb.AbsolutePosition.X
				setV(min + math.clamp(p / sb.AbsoluteSize.X, 0, 1) * (max - min))
			end
		end)
		UserInputService.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then
				dragging = false
			end
		end)

		return {
			instance = sb,
			get = function() return value end,
			set = setV,
		}
	end

	function Elements.button(parent, text, order, color, width, callback)
		local b = Instance.new("TextButton")
		b.Size = UDim2.new(0, width or 80, 0, 40)
		b.BackgroundColor3 = color or COLORS.AccentDark
		b.BorderSizePixel = 0
		b.Text = text
		b.TextColor3 = COLORS.TextBright
		b.Font = FONT_BOLD
		b.TextSize = 13
		b.LayoutOrder = order or 0
		b.AutoButtonColor = false
		b.Active = true
		b.Parent = parent
		corner(b)
		stroke(b)
		if callback then b.MouseButton1Click:Connect(callback) end
		return b
	end

	Hub.Objects.Elements = Elements

	-- ==================== HOLDER ====================
	local holder = Instance.new("Frame")
	holder.Size = UDim2.new(0, 320, 0, 40)
	holder.Position = UDim2.new(0, 20, 0, 20)
	holder.BackgroundTransparency = 1
	holder.Active = true
	holder.Parent = gui
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.Padding = UDim.new(0, 10)
	layout.Parent = holder

	local toggleBtn = Elements.button(holder, "Toggle", 1, Color3.fromRGB(75, 0, 130), 80)
	local lockBtn   = Elements.button(holder, "Locked", 2, Color3.fromRGB(75, 0, 130), 90)
	local unloadBtn = Elements.button(holder, "Выгрузить", 3, COLORS.Danger, 100)

	-- ==================== MENU ====================
	local menu = Instance.new("Frame")
	menu.Size = UDim2.new(0, 280, 0, 300)
	menu.Position = UDim2.new(0, 20, 0, 80)
	menu.BackgroundColor3 = COLORS.Background
	menu.BorderSizePixel = 0
	menu.Visible = false
	menu.Active = true
	menu.Parent = gui
	corner(menu, 10)
	stroke(menu, COLORS.Accent, 2)

	-- ==================== PAGES ====================
	local pages = {}
	local pagesCount = 3
	for i = 1, pagesCount do
		local p = Instance.new("Frame")
		p.Size = UDim2.new(1, 0, 1, -40)
		p.BackgroundTransparency = 1
		p.Visible = false
		p.Parent = menu
		pages[i] = p
	end

	local nav = Instance.new("Frame")
	nav.Size = UDim2.new(1, -20, 0, 30)
	nav.Position = UDim2.new(0, 10, 1, -35)
	nav.BackgroundTransparency = 1
	nav.Parent = menu

	local prev = Instance.new("TextButton")
	prev.Size = UDim2.new(0, 60, 1, 0)
	prev.BackgroundColor3 = COLORS.AccentDark
	prev.BorderSizePixel = 0
	prev.Text = "◀"
	prev.TextColor3 = COLORS.TextBright
	prev.Font = FONT_BOLD
	prev.TextSize = 18
	prev.AutoButtonColor = false
	prev.Parent = nav
	corner(prev, 6)

	local next_ = Instance.new("TextButton")
	next_.Size = UDim2.new(0, 60, 1, 0)
	next_.Position = UDim2.new(1, -60, 0, 0)
	next_.BackgroundColor3 = COLORS.AccentDark
	next_.BorderSizePixel = 0
	next_.Text = "▶"
	next_.TextColor3 = COLORS.TextBright
	next_.Font = FONT_BOLD
	next_.TextSize = 18
	next_.AutoButtonColor = false
	next_.Parent = nav
	corner(next_, 6)

	local pageLabel = Instance.new("TextLabel")
	pageLabel.Size = UDim2.new(1, -140, 1, 0)
	pageLabel.Position = UDim2.new(0, 70, 0, 0)
	pageLabel.BackgroundTransparency = 1
	pageLabel.TextColor3 = COLORS.Text
	pageLabel.Font = FONT_BOLD
	pageLabel.TextSize = 14
	pageLabel.Parent = nav

	local currentPage = 1
	local function showPage(n)
		if n < 1 then n = pagesCount end
		if n > pagesCount then n = 1 end
		currentPage = n
		for i, p in ipairs(pages) do p.Visible = (i == n) end
		pageLabel.Text = n .. " / " .. pagesCount
	end
	prev.MouseButton1Click:Connect(function() showPage(currentPage - 1) end)
	next_.MouseButton1Click:Connect(function() showPage(currentPage + 1) end)
	showPage(1)

	-- ==================== DRAG & BUTTONS ====================
	makeDraggable(holder, toggleBtn)
	makeDraggable(holder, lockBtn)
	makeDraggable(holder, unloadBtn)
	makeDraggable(menu, menu)

	local open = false
	toggleBtn.MouseButton1Click:Connect(function()
		open = not open
		menu.Visible = open
		if open then
			menu.Position = UDim2.new(
				holder.Position.X.Scale, holder.Position.X.Offset,
				holder.Position.Y.Scale, holder.Position.Y.Offset + 50
			)
		end
	end)

	lockBtn.MouseButton1Click:Connect(function()
		isLocked = not isLocked
		lockBtn.Text = isLocked and "Locked" or "Unlocked"
		lockBtn.BackgroundColor3 = isLocked and Color3.fromRGB(75, 0, 130) or Color3.fromRGB(120, 0, 200)
	end)

	-- ==================== PUBLIC API ====================
	Hub.Page = function(n) return pages[n] end
	Hub.Elements = Elements
	Hub.MenuGui = gui

	-- ============================================================
	-- ================  ЗАГРУЗКА МОДУЛЕЙ  ========================
	-- ============================================================
	local BASE = "https://raw.githubusercontent.com/artemkf161rus-max/doors-hub-modular/refs/heads/main/"

	local function loadModule(path)
		local ok, result = pcall(function()
			return loadstring(game:HttpGet(BASE .. path))()
		end)
		if not ok then
			warn("[UI] Ошибка загрузки " .. path .. ": " .. tostring(result))
			return nil
		end
		return result
	end

	-- порядок важен: сначала ui уже создан, потом фичи
	local modules = {
		"features/esp.lua",
		"features/movement.lua",
		"features/library.lua",
		"features/bypass.lua",
		"features/notify.lua",
		"features/misc.lua",
	}

	for _, path in ipairs(modules) do
		local mod = loadModule(path)
		if mod and type(mod) == "table" and mod.init then
			local ok, err = pcall(mod.init, Hub)
			if ok then
				print("[UI] Модуль загружен: " .. path)
			else
				warn("[UI] Модуль " .. path .. " упал: " .. tostring(err))
			end
		else
			warn("[UI] Модуль " .. path .. " не вернул init()")
		end
	end

	-- ==================== UNLOAD ====================
	unloadBtn.MouseButton1Click:Connect(function()
		-- вызываем cleanup у ESP-модуля
		if Hub.Modules and Hub.Modules.esp and Hub.Modules.esp.cleanup then
			pcall(Hub.Modules.esp.cleanup)
		end

		-- выключаем все тоглы
		for _, sw in pairs(Hub.Toggles) do
			pcall(function() sw.set(false) end)
		end

		-- отключаем общие коннекты
		for _, c in pairs(Hub.Connections) do
			pcall(function() c:Disconnect() end)
		end
		Hub.Connections = {}

		-- удаляем GUI
		if gui and gui.Parent then gui:Destroy() end
		print("[HUB] Unloaded")
	end)

	return Hub
end

return UI
