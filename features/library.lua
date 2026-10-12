local Players = game:GetService("Players")
local player = Players.LocalPlayer

local Library = {}

local Hub
local Elements
local page

local connections = {}

local function track(conn)
	table.insert(connections, conn)
	return conn
end

------------------------------------------------------------
-- GET CODE
------------------------------------------------------------
local function getLibraryCode()
	local char = player.Character
	if not char then return "_____" end

	local paper = char:FindFirstChild("LibraryHintPaper")
		or char:FindFirstChild("LibraryHintPaperHard")
		or (player.Backpack and player.Backpack:FindFirstChild("LibraryHintPaper"))
		or (player.Backpack and player.Backpack:FindFirstChild("LibraryHintPaperHard"))

	if not paper or not paper:FindFirstChild("UI") then
		return "_____"
	end

	local code = { "_", "_", "_", "_", "_" }
	local playerGui = player:FindFirstChild("PlayerGui")
	local permUI = playerGui and playerGui:FindFirstChild("PermUI")
	local hints = permUI and permUI:FindFirstChild("Hints")

	if hints then
		local hintChildren = hints:GetChildren()
		local uiChildren = paper.UI:GetChildren()

		for _, hint in ipairs(hintChildren) do
			for _, uiChild in ipairs(uiChildren) do
				if hint:IsA("ImageLabel") and uiChild:IsA("ImageLabel")
				and hint.ImageRectOffset == uiChild.ImageRectOffset
				and code[tonumber(uiChild.Name)] then
					code[tonumber(uiChild.Name)] = hint.TextLabel.Text
				end
			end
		end
	end

	return table.concat(code)
end

------------------------------------------------------------
-- UI
------------------------------------------------------------
local function buildUI()
	-- кладём на page 1 (или на любую другую — поменяй Hub.Page(n))
	page = Hub.Page(1)
	if not page then
		warn("[library] page не найдена")
		return
	end

	local codeBtn = Elements.button(page, "Показать код библиотеки", 1,
		Color3.fromRGB(90, 0, 160), 240)
	codeBtn.Position = UDim2.new(0, 10, 0, 170)
	codeBtn.Size = UDim2.new(1, -20, 0, 26)
	codeBtn.TextSize = 11

	codeBtn.MouseButton1Click:Connect(function()
		local code = getLibraryCode()
		print("[LIBRARY CODE]", code)
		codeBtn.Text = "Код: " .. code
		task.delay(5, function()
			codeBtn.Text = "Показать код библиотеки"
		end)
	end)
end

------------------------------------------------------------
-- INIT
------------------------------------------------------------
function Library.init(hub)
	Hub = hub
	Elements = hub.Elements or (hub.Objects and hub.Objects.Elements)

	if not Elements then
		warn("[library] Elements не найдены — ui.lua должен грузиться первым")
		return
	end

	buildUI()

	function Library.cleanup()
		for _, conn in ipairs(connections) do
			pcall(function() conn:Disconnect() end)
		end
		connections = {}
	end

	print("[LIBRARY] Модуль инициализирован")
	return Library
end

return Library
