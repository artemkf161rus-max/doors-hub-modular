-- ============================================================
-- ============  MODULE: JUMP ENABLE  =========================
-- ============================================================
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local player = Players.LocalPlayer

local JumpEnable = {}

local Config, Toggles, Hub, Elements, page
local connections = {}

local jumpState = {
	enabled = false,
	jumpPower = 50,
	loop = nil,
}

local function track(c)
	table.insert(connections, c)
	return c
end

-- ============================================================
-- ПРИМЕНЕНИЕ ПРЫЖКА
-- ============================================================
local function applyJump()
	local char = player.Character
	if not char then return end

	-- ставим атрибут игры
	char:SetAttribute("CanJump", true)

	local hum = char:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.UseJumpPower = true
		hum.JumpPower = jumpState.jumpPower
	end
end

-- ============================================================
-- ХУК НА SetAttribute — блокируем CanJump = false
-- ============================================================
if hookmetamethod and newcclosure and getnamecallmethod then
	local ok, err = pcall(function()
		local oldNamecall
		oldNamecall = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
			if getnamecallmethod() == "SetAttribute" then
				local args = {...}
				if args[1] == "CanJump" and args[2] == false then
					return oldNamecall(self, "CanJump", true)
				end
			end
			return oldNamecall(self, ...)
		end))
	end)
	if not ok then
		warn("[JUMP] Hook не установлен: " .. tostring(err))
	end
end

-- ============================================================
-- ХУК НА JumpPower — всегда не меньше заданного
-- ============================================================
if hookmetamethod and newcclosure then
	pcall(function()
		local oldIndex
		oldIndex = hookmetamethod(game, "__index", newcclosure(function(self, key)
			if key == "JumpPower" then
				local real = oldIndex(self, key)
				if real and real < jumpState.jumpPower then
					return jumpState.jumpPower
				end
				return real
			end
			return oldIndex(self, key)
		end))
	end)
end

-- ============================================================
-- LOOP — каждую секунду переприменяет
-- ============================================================
local function startLoop()
	if jumpState.loop then return end

	jumpState.loop = RunService.Heartbeat:Connect(function()
		if not jumpState.enabled then return end

		local char = player.Character
		if not char then return end

		if char:GetAttribute("CanJump") ~= true then
			char:SetAttribute("CanJump", true)
		end

		local hum = char:FindFirstChildOfClass("Humanoid")
		if hum and hum.JumpPower < jumpState.jumpPower then
			hum.JumpPower = jumpState.jumpPower
		end
	end)

	track(jumpState.loop)
end

local function stopLoop()
	if jumpState.loop then
		jumpState.loop:Disconnect()
		jumpState.loop = nil
	end
end

-- ============================================================
-- ПРЯМОЙ ПРЫЖОК ПО SPACE
-- ============================================================
track(UserInputService.InputBegan:Connect(function(input, gpe)
	if gpe then return end
	if not jumpState.enabled then return end
	if input.KeyCode == Enum.KeyCode.Space then
		local char = player.Character
		if not char then return end
		local hum = char:FindFirstChildOfClass("Humanoid")
		if hum and hum.Health > 0 then
			pcall(function()
				hum:ChangeState(Enum.HumanoidStateType.Jumping)
			end)
		end
	end
end))

-- ============================================================
-- UI (page 1)
-- ============================================================
local function buildUI()
	page = Hub.Page(1)
	if not page then
		warn("[jump] page 1 не найдена")
		return
	end

	-- ============ ENABLE JUMP ============
	Elements.label(page, "ENABLE JUMP", 300)
	Hub.Toggles.jump = Elements.switch(page, 298, function(on)
		jumpState.enabled = on

		if on then
			applyJump()
			startLoop()
			print("[JUMP] Enabled")
		else
			stopLoop()
			print("[JUMP] Disabled")
		end
	end)

	-- ============ JUMP POWER ============
	Elements.label(page, "JUMP POWER (50-500)", 322)
	local jumpVal = Elements.label(page, "Value: 50", 338,
		{ color = Color3.fromRGB(255, 255, 255), size = 10 })

	Elements.slider(page, 354, 50, 500, 50, function(v)
		jumpState.jumpPower = math.floor(v)
		jumpVal.Text = "Value: " .. jumpState.jumpPower

		-- применяем сразу если включено
		if jumpState.enabled then
			local char = player.Character
			if char then
				local hum = char:FindFirstChildOfClass("Humanoid")
				if hum then hum.JumpPower = jumpState.jumpPower end
			end
		end
	end)

	-- ============ INFINITE JUMPS ============
	Elements.label(page, "INFINITE JUMPS", 376)
	Hub.Toggles.infiniteJumps = Elements.switch(page, 374, function(on)
		if on then
			-- включаем бесконечные прыжки
			track(UserInputService.InputBegan:Connect(function(input, gpe)
				if gpe then return end
				if Hub.Toggles.infiniteJumps and Hub.Toggles.infiniteJumps.get() then
					if input.KeyCode == Enum.KeyCode.Space then
						local char = player.Character
						if not char then return end
						local hum = char:FindFirstChildOfClass("Humanoid")
						if hum then
							hum:ChangeState(Enum.HumanoidStateType.Jumping)
						end
					end
				end
			end))
		end
	end)

	-- ============ HINT ============
	Elements.label(page, "Прыжок в Doors отключён — включаем через хук", 396,
		{ color = Color3.fromRGB(150, 150, 150), size = 9,
		  font = Enum.Font.Gotham })
end

-- ============================================================
-- INIT
-- ============================================================
function JumpEnable.init(hub)
	Hub = hub
	Config = hub.Config
	Toggles = hub.Toggles
	Elements = hub.Elements or (hub.Objects and hub.Objects.Elements)

	if not Elements then
		warn("[jump] Elements не найдены")
		return
	end

	buildUI()

	-- при респавне — переприменяем
	track(player.CharacterAdded:Connect(function()
		task.wait(1)
		if jumpState.enabled then
			applyJump()
		end
	end))

	-- следим за атрибутом CanJump
	track(player.CharacterAdded:Connect(function(char)
		task.wait(0.5)
		track(char:GetAttributeChangedSignal("CanJump"):Connect(function()
			if jumpState.enabled and char:GetAttribute("CanJump") ~= true then
				char:SetAttribute("CanJump", true)
			end
		end))
	end))

	function JumpEnable.cleanup()
		jumpState.enabled = false
		stopLoop()

		for _, c in ipairs(connections) do
			pcall(function() c:Disconnect() end)
		end
		connections = {}
	end

	print("[JUMP] Модуль инициализирован")
	return JumpEnable
end

return JumpEnable
