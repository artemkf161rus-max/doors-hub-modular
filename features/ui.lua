-- ============================================================
-- ============  MODULE: UI (COMPACT)  ========================
-- ============================================================
local UI = {}

function UI.init(Hub)
	local Players = game:GetService("Players")
	local TweenService = game:GetService("TweenService")
	local UserInputService = game:GetService("UserInputService")
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")

	local BASE = "https://raw.githubusercontent.com/artemkf161rus-max/doors-hub-modular/refs/heads/main/"

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

	local function corner(parent, r)
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0, r or 6)
		c.Parent = parent
		return c
	end

	local function stroke(parent, color, thickness)
		local s = Instance.new("UIStroke")
		s.Color = color or COLORS.Stroke
		s.Thickness = thickness or 1
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

	-- ============================================================
	-- ELEMENTS
	-- ============================================================
	local Elements = {}

	function Elements.label(parent, text, y, cfg)
		cfg = cfg or {}
		local l = Instance.new("TextLabel")
		l.Size = UDim2.new(1, -16, 0, 14)
		l.Position = UDim2.new(0, 8, 0, y)
		l.BackgroundTransparency = 1
		l.Text = text
		l.TextColor3 = cfg.color or COLORS.Text
		l.Font = cfg.font or FONT_BOLD
		l.TextSize = cfg.size or 10
		l.TextXAlignment = Enum.TextXAlignment.Left
		l.Parent = parent
		return l
	end

	function Elements.switch(parent, y, callback)
		local bg = Instance.new("TextButton")
		bg.Size = UDim2.new(0, 34, 0, 16)
		bg.Position = UDim2.new(1, -42, 0, y - 1)
		bg.BackgroundColor3 = COLORS.SwitchOff
		bg.BorderSizePixel = 0
		bg.Text = ""
		bg.AutoButtonColor = false
		bg.Parent = parent
		corner(bg, 999)

		local knob = Instance.new("Frame")
		knob.Size = UDim2.new(0, 12, 0, 12)
		knob.Position = UDim2.new(0, 2, 0.5, -6)
		knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		knob.BorderSizePixel = 0
		knob.Parent = bg
		corner(knob, 999)

		local state = false
		local function update()
			TweenService:Create(bg, TweenInfo.new(0.15),
				{BackgroundColor3 = state and COLORS.SwitchOn or COLORS.SwitchOff}):Play()
			TweenService:Create(knob, TweenInfo.new(0.15),
				{Position = state and UDim2.new(0, 18, 0.5, -6) or UDim2.new(0, 2, 0.5, -6)}):Play()
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
		sb.Size = UDim2.new(1, -16, 0, 6)
		sb.Position = UDim2.new(0, 8, 0, y)
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
		knob.Size = UDim2.new(0, 10, 0, 10)
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
		for _, child in ipairs(parent:GetChildren()) do
			if child:IsA("TextButton") and child.Text == text then
				return child
			end
		end

		local b = Instance.new("TextButton")
		b.Size = UDim2.new(0, width or 70, 0, 32)
		b.BackgroundColor3 = color or COLORS.AccentDark
		b.BorderSizePixel = 0
		b.Text = text
		b.TextColor3 = COLORS.TextBright
		b.Font = FONT_BOLD
		b.TextSize = 12
		b.LayoutOrder = order or 0
		b.AutoButtonColor = false
		b.Active = true
		b.Parent = parent
		corner(b, 6)
		stroke(b, COLORS.Stroke, 1)
		if callback then b.MouseButton1Click:Connect(callback) end
		return b
	end

	-- ============================================================
	-- BUTTON HOLDER
	-- ============================================================
	local holder = Instance.new("Frame")
	holder.Size = UDim2.new(0, 260, 0, 32)
	holder.Position = UDim2.new(0, 15, 0, 15)
	holder.BackgroundTransparency = 1
	holder.Active = true
	holder.Parent = gui
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.Padding = UDim.new(0, 6)
	layout.Parent = holder

	local toggleBtn = Elements.button(holder, "Toggle", 1, Color3.fromRGB(75, 0, 130), 70)
	local lockBtn   = Elements.button(holder, "Lock", 2, Color3.fromRGB(75, 0, 130), 70)
	local unloadBtn = Elements.button(holder, "Unload", 3, COLORS.Danger, 80)

	-- ============================================================
	-- MENU
	-- ============================================================
	local menu = Instance.new("Frame")
	menu.Size = UDim2.new(0, 250, 0, 260)
	menu.Position = UDim2.new(0, 15, 0, 60)
	menu.BackgroundColor3 = COLORS.Background
	menu.BorderSizePixel = 0
	menu.Visible = false
	menu.Active = true
	menu.Parent = gui
	corner(menu, 8)
	stroke(menu, COLORS.Accent, 1)

	-- ============================================================
	-- PAGES
	-- ============================================================
	local pages = {}
	local pagesCount = 3
	for i = 1, pagesCount do
		local p = Instance.new("Frame")
		p.Name = "Page" .. i
		p.Size = UDim2.new(1, 0, 1, -32)
		p.BackgroundTransparency = 1
		p.Visible = false
		p.Parent = menu
		pages[i] = p
	end

	local nav = Instance.new("Frame")
	nav.Size = UDim2.new(1, -16, 0, 24)
	nav.Position = UDim2.new(0, 8, 1, -28)
	nav.BackgroundTransparency = 1
	nav.Parent = menu

	local prev = Instance.new("TextButton")
	prev.Size = UDim2.new(0, 50, 1, 0)
	prev.BackgroundColor3 = COLORS.AccentDark
	prev.BorderSizePixel = 0
	prev.Text = "◀"
	prev.TextColor3 = COLORS.TextBright
	prev.Font = FONT_BOLD
	prev.TextSize = 14
	prev.AutoButtonColor = false
	prev.Parent = nav
	corner(prev, 4)

	local next_ = Instance.new("TextButton")
	next_.Size = UDim2.new(0, 50, 1, 0)
	next_.Position = UDim2.new(1, -50, 0, 0)
	next_.BackgroundColor3 = COLORS.AccentDark
	next_.BorderSizePixel = 0
	next_.Text = "▶"
	next_.TextColor3 = COLORS.TextBright
	next_.Font = FONT_BOLD
	next_.TextSize = 14
	next_.AutoButtonColor = false
	next_.Parent = nav
	corner(next_, 4)

	local pageLabel = Instance.new("TextLabel")
	pageLabel.Size = UDim2.new(1, -120, 1, 0)
	pageLabel.Position = UDim2.new(0, 60, 0, 0)
	pageLabel.BackgroundTransparency = 1
	pageLabel.TextColor3 = COLORS.Text
	pageLabel.Font = FONT_BOLD
	pageLabel.TextSize = 12
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

	-- ============================================================
	-- ПУБЛИЧНОЕ API
	-- ============================================================
	Hub.Page = function(n) return pages[n] end
	Hub.Elements = Elements
	Hub.Objects.Elements = Elements
	Hub.MenuGui = gui
	Hub.MenuFrame = menu
	Hub.Pages = pages

	-- DRAG
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
				holder.Position.Y.Scale, holder.Position.Y.Offset + 40
			)
		end
	end)

	lockBtn.MouseButton1Click:Connect(function()
		isLocked = not isLocked
		lockBtn.Text = isLocked and "Lock" or "Unlk"
		lockBtn.BackgroundColor3 = isLocked and Color3.fromRGB(75, 0, 130) or Color3.fromRGB(120, 0, 200)
	end)

	-- ============================================================
	-- ЗАГРУЗКА МОДУЛЕЙ
	-- ============================================================
	local function loadModule(path)
		local url = BASE .. path .. "?t=" .. tostring(os.time())
		local ok, result = pcall(function()
			return loadstring(game:HttpGet(url))()
		end)
		if not ok then
			warn("[UI] Ошибка загрузки " .. path .. ": " .. tostring(result))
			return nil
		end
		return result
	end

	local modules = {
		"features/esp.lua",
		"features/movement.lua",
		"features/library.lua",
		"features/bypass.lua",
		"features/notify.lua",
		"features/misc.lua",
		"features/jump.lua",
		"features/save.lua",
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
			warn("[UI] ❌ " .. name .. " упал: " .. tostring(err))
		end
	end

	print("[UI] =========================================")

	-- ============================================================
	-- UNLOAD
	-- ============================================================
	unloadBtn.MouseButton1Click:Connect(function()
		if Hub.Modules.save and Hub.Modules.save.cleanup then
			pcall(Hub.Modules.save.cleanup)
		end
		for name, mod in pairs(Hub.Modules) do
			if name ~= "save" and type(mod) == "table" and mod.cleanup then
				pcall(mod.cleanup)
			end
		end
		for _, sw in pairs(Hub.Toggles) do
			pcall(function() sw.set(false) end)
		end
		for _, c in pairs(Hub.Connections) do
			pcall(function() c:Disconnect() end)
		end
		Hub.Connections = {}
		if gui and gui.Parent then gui:Destroy() end
		print("[HUB] Unloaded")
	end)

	return Hub
end

return UI
