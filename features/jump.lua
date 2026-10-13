-- ============================================================
-- ============  MODULE: JUMP ENABLE (Page 4)  ================
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
	infiniteLoop = nil,
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
	pcall(function()
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
end

-- ============================================================
-- ХУК НА JumpPower
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
-- LOOP — переприменяет CanJump
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
-- UI (PAGE 4)
-- ============================================================
local function buildUI()
	page = Hub.Page(4)  -- ← Page 4!
	if not page then
		warn("[jump] page 4 не найдена")
		return
	end

	-- ============ ENABLE JUMP ============
	Elements.label(page, "JUMP — ENABLE", 2)
	Hub.Toggles.jump = Elements.switch(page, 0, function(on)
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
	Elements.label(page, "JUMP POWER (50-500)", 26)
	local jumpVal = Elements.label(page, "Value: 50", 42,
		{ color = Color3.fromRGB(255, 255, 255), size = 10 })

	Elements.slider(page, 58, 50, 500, 50, function(v)
		jumpState.jumpPower = math.floor(v)
		jumpVal.Text = "Value: " .. jumpState.jumpPower

		if jumpState.enabled then
			local char = player.Character
			if char then
				local hum = char:FindFirstChildOfClass("Humanoid")
				if hum then hum.JumpPower = jumpState.jumpPower end
			end
		end
	end)

	-- ============ INFINITE JUMPS ============
	Elements.label(page, "INFINITE JUMPS", 82)
	Hub.Toggles.infiniteJumps = Elements.switch(page, 80, function(on)
		if on then
			if not jumpState.infiniteLoop then
				jumpState.infiniteLoop = RunService.Heartbeat:Connect(function()
					if not Hub.Toggles.infiniteJumps.get() then return end
					if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
						local char = player.Character
						if not char then return end
						local hum = char:FindFirstChildOfClass("Humanoid")
						if hum then
							hum:ChangeState(Enum.HumanoidStateType.Jumping)
						end
					end
				end)
				track(jumpState.infiniteLoop)
			end
		else
			if jumpState.infiniteLoop then
				jumpState.infiniteLoop:Disconnect()
				jumpState.infiniteLoop = nil
			end
		end
	end)

	-- ============ HINT ============
	Elements.label(page, "Прыжок отключён в Doors — включаем через хук", 106,
		{ color = Color3.fromRGB(150, 150, 150), size = 9,
		  font = Enum.Font.Gotham })

	Elements.label(page, "Слайдер 50 = обычный, 200 = высокий, 500 = крыша", 124,
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

	track(player.CharacterAdded:Connect(function()
		task.wait(1)
		if jumpState.enabled then
			applyJump()
		end
	end))

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

		if jumpState.infiniteLoop then
			jumpState.infiniteLoop:Disconnect()
			jumpState.infiniteLoop = nil
		end

		for _, c in ipairs(connections) do
			pcall(function() c:Disconnect() end)
		end
		connections = {}
	end

	print("[JUMP] Модуль инициализирован")
	return JumpEnable
end

return JumpEnable
