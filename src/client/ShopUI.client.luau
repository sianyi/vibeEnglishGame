-- ShopUI.client.luau
-- 道具商店 UI + 作弊提示顯示

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local Shared = ReplicatedStorage:WaitForChild("Shared")
local ShopData = require(Shared:WaitForChild("ShopData"))
local shopEvent = ReplicatedStorage:WaitForChild("ShopEvent")
local gameRemote = ReplicatedStorage:WaitForChild("GameRemote")

-- ==================== 作弊提示 UI ====================
local function showCheatHint(isYesCorrect)
	local hintGui = player.PlayerGui:FindFirstChild("CheatHintGui")
	if not hintGui then
		hintGui = Instance.new("ScreenGui")
		hintGui.Name = "CheatHintGui"
		hintGui.ResetOnSpawn = false
		hintGui.Parent = player.PlayerGui
	end
	hintGui:ClearAllChildren()

	local hint = Instance.new("TextLabel")
	hint.Size = UDim2.new(0, 240, 0, 55)
	hint.Position = UDim2.new(0.5, -120, 0.08, 0)
	hint.BackgroundColor3 = Color3.fromRGB(0, 120, 0)
	hint.BackgroundTransparency = 0.15
	hint.Text = "📖 答案：" .. (isYesCorrect and "YES ✅" or "NO ✅")
	hint.Font = Enum.Font.GothamBlack
	hint.TextSize = 22
	hint.TextColor3 = Color3.fromRGB(200, 255, 200)
	hint.Parent = hintGui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = hint

	task.delay(9, function()
		if hint.Parent then hintGui:ClearAllChildren() end
	end)
end

-- ==================== 商店 UI ====================
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "ShopGui"
screenGui.ResetOnSpawn = false
screenGui.Enabled = false
screenGui.Parent = player.PlayerGui

-- 半透明遮罩
local overlay = Instance.new("Frame")
overlay.Size = UDim2.new(1, 0, 1, 0)
overlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
overlay.BackgroundTransparency = 0.45
overlay.Parent = screenGui

-- 主面板
local panel = Instance.new("Frame")
panel.Size = UDim2.new(0, 480, 0, 430)
panel.Position = UDim2.new(0.5, -240, 0.5, -215)
panel.BackgroundColor3 = Color3.fromRGB(28, 18, 8)
panel.BorderSizePixel = 0
panel.Parent = overlay

local panelCorner = Instance.new("UICorner")
panelCorner.CornerRadius = UDim.new(0, 14)
panelCorner.Parent = panel

-- 標題列
local titleBar = Instance.new("Frame")
titleBar.Size = UDim2.new(1, 0, 0, 52)
titleBar.BackgroundColor3 = Color3.fromRGB(200, 130, 0)
titleBar.BorderSizePixel = 0
titleBar.Parent = panel

local titleCorner = Instance.new("UICorner")
titleCorner.CornerRadius = UDim.new(0, 14)
titleCorner.Parent = titleBar

local titleLabel = Instance.new("TextLabel")
titleLabel.Size = UDim2.new(1, -60, 1, 0)
titleLabel.Position = UDim2.new(0, 10, 0, 0)
titleLabel.BackgroundTransparency = 1
titleLabel.Text = "🏪 道具商店"
titleLabel.Font = Enum.Font.GothamBlack
titleLabel.TextSize = 26
titleLabel.TextColor3 = Color3.new(1, 1, 1)
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.Parent = titleBar

-- 關閉按鈕
local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 38, 0, 38)
closeBtn.Position = UDim2.new(1, -44, 0, 7)
closeBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
closeBtn.Text = "✕"
closeBtn.Font = Enum.Font.GothamBlack
closeBtn.TextSize = 18
closeBtn.TextColor3 = Color3.new(1, 1, 1)
closeBtn.Parent = titleBar

local closeBtnCorner = Instance.new("UICorner")
closeBtnCorner.CornerRadius = UDim.new(0, 8)
closeBtnCorner.Parent = closeBtn

closeBtn.MouseButton1Click:Connect(function()
	screenGui.Enabled = false
end)

-- 金幣顯示
local goldLabel = Instance.new("TextLabel")
goldLabel.Size = UDim2.new(1, -20, 0, 28)
goldLabel.Position = UDim2.new(0, 10, 0, 57)
goldLabel.BackgroundTransparency = 1
goldLabel.TextColor3 = Color3.fromRGB(255, 215, 50)
goldLabel.Font = Enum.Font.GothamBold
goldLabel.TextSize = 18
goldLabel.Text = "💰 金幣: 0"
goldLabel.TextXAlignment = Enum.TextXAlignment.Left
goldLabel.Parent = panel

-- 更新顯示函數
local function updateGold()
	local ls = player:FindFirstChild("leaderstats")
	goldLabel.Text = "💰 金幣: " .. (ls and ls:FindFirstChild("Gold") and ls.Gold.Value or 0)
end

local inventoryLabels = {}
local function updateInventory()
	for _, item in ipairs(ShopData) do
		local count = player:GetAttribute("Item_" .. item.Id) or 0
		if inventoryLabels[item.Id] then
			inventoryLabels[item.Id].Text = "持有 " .. count .. " 次"
			inventoryLabels[item.Id].TextColor3 = count > 0
				and Color3.fromRGB(100, 255, 100)
				or Color3.fromRGB(150, 150, 150)
		end
	end
end

-- 道具列表
for i, item in ipairs(ShopData) do
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, -20, 0, 82)
	row.Position = UDim2.new(0, 10, 0, 90 + (i - 1) * 88)
	row.BackgroundColor3 = Color3.fromRGB(50, 35, 15)
	row.BorderSizePixel = 0
	row.Parent = panel

	local rowCorner = Instance.new("UICorner")
	rowCorner.CornerRadius = UDim.new(0, 9)
	rowCorner.Parent = row

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size = UDim2.new(0.55, 0, 0.48, 0)
	nameLabel.Position = UDim2.new(0, 12, 0, 6)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = item.Name
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.TextSize = 17
	nameLabel.TextColor3 = Color3.new(1, 1, 1)
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.Parent = row

	local descLabel = Instance.new("TextLabel")
	descLabel.Size = UDim2.new(0.55, 0, 0.45, 0)
	descLabel.Position = UDim2.new(0, 12, 0.5, 2)
	descLabel.BackgroundTransparency = 1
	descLabel.Text = item.Desc
	descLabel.Font = Enum.Font.Gotham
	descLabel.TextSize = 12
	descLabel.TextColor3 = Color3.fromRGB(190, 190, 190)
	descLabel.TextXAlignment = Enum.TextXAlignment.Left
	descLabel.TextWrapped = true
	descLabel.Parent = row

	local invLabel = Instance.new("TextLabel")
	invLabel.Size = UDim2.new(0.22, 0, 1, 0)
	invLabel.Position = UDim2.new(0.56, 0, 0, 0)
	invLabel.BackgroundTransparency = 1
	invLabel.Text = "持有 0 次"
	invLabel.Font = Enum.Font.GothamBold
	invLabel.TextSize = 14
	invLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
	invLabel.Parent = row
	inventoryLabels[item.Id] = invLabel

	local buyBtn = Instance.new("TextButton")
	buyBtn.Size = UDim2.new(0.2, -4, 0.56, 0)
	buyBtn.Position = UDim2.new(0.8, 0, 0.22, 0)
	buyBtn.BackgroundColor3 = Color3.fromRGB(240, 170, 0)
	buyBtn.Text = "💰 " .. item.Price
	buyBtn.Font = Enum.Font.GothamBold
	buyBtn.TextSize = 15
	buyBtn.TextColor3 = Color3.fromRGB(40, 10, 0)
	buyBtn.Parent = row

	local buyCorner = Instance.new("UICorner")
	buyCorner.CornerRadius = UDim.new(0, 7)
	buyCorner.Parent = buyBtn

	local itemId = item.Id
	local itemPrice = item.Price
	buyBtn.MouseButton1Click:Connect(function()
		buyBtn.Text = "..."
		buyBtn.BackgroundColor3 = Color3.fromRGB(130, 130, 130)
		local ok, msg = shopEvent:InvokeServer(itemId)
		task.wait(0.3)
		if ok then
			buyBtn.BackgroundColor3 = Color3.fromRGB(0, 180, 80)
			buyBtn.Text = "✅"
		else
			buyBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
			buyBtn.Text = "❌"
		end
		task.delay(1.2, function()
			buyBtn.BackgroundColor3 = Color3.fromRGB(240, 170, 0)
			buyBtn.Text = "💰 " .. itemPrice
		end)
		updateGold()
		updateInventory()
	end)
end

-- 監聽 GameRemote 事件
gameRemote.OnClientEvent:Connect(function(action, data)
	if action == "OpenShop" then
		updateGold()
		updateInventory()
		screenGui.Enabled = true
	elseif action == "CheatHint" then
		showCheatHint(data) -- data = isYesCorrect (boolean)
	elseif action == "ItemUsed" then
		updateInventory()
	end
end)

-- 金幣變動時更新（如果商店開著）
local function watchGold()
	local ls = player:WaitForChild("leaderstats")
	ls:WaitForChild("Gold"):GetPropertyChangedSignal("Value"):Connect(function()
		if screenGui.Enabled then updateGold() end
	end)
end
task.spawn(watchGold)
