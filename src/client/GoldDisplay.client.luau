local Players = game:GetService("Players")
local player = Players.LocalPlayer

-- 等待 PlayerGui 載入
local playerGui = player:WaitForChild("PlayerGui")

-- 1. 建立 ScreenGui (介面容器)
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "StatsGui"
screenGui.ResetOnSpawn = false -- 重生時不重置，保持顯示
screenGui.Parent = playerGui

-- 2. 建立顯示文字標籤 (TextLabel)
local label = Instance.new("TextLabel")
label.Name = "GoldDisplay"
label.AnchorPoint = Vector2.new(1, 1) -- 設定錨點在右下
label.Position = UDim2.new(1, -20, 1, -20) -- 畫面右下角，留一點邊距
label.Size = UDim2.new(0, 200, 0, 50)
label.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
label.BackgroundTransparency = 0.3
label.BorderSizePixel = 0
label.TextColor3 = Color3.fromRGB(255, 215, 0) -- 金色文字
label.Font = Enum.Font.GothamBold
label.TextSize = 24
label.Text = "Gold: ..."
label.Parent = screenGui

-- 3. 監聽金幣數值變化
local function setupLeaderstats()
	local leaderstats = player:WaitForChild("leaderstats", 10)
	if not leaderstats then return end

	local gold = leaderstats:WaitForChild("Gold", 10)
	if not gold then return end

	local function update()
		label.Text = "💰 Gold: " .. gold.Value
	end

	update()
	gold.Changed:Connect(update)
end

task.spawn(setupLeaderstats)