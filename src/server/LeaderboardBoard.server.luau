local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local BOARD_PART_NAME = "WordGameRank"
local boardPart = Workspace:WaitForChild(BOARD_PART_NAME)
print("✅ [SERVER] 排行榜看板已載入:", boardPart.Name)

-- 1. 建立 SurfaceGui (顯示介面)
local surfaceGui = Instance.new("SurfaceGui")
surfaceGui.Face = Enum.NormalId.Front -- 顯示在正面
surfaceGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
surfaceGui.PixelsPerStud = 20 -- 解析度設定 (降低數值讓文字看起來更大)
surfaceGui.Parent = boardPart

-- 背景
local bg = Instance.new("Frame")
bg.Size = UDim2.new(1, 0, 1, 0)
bg.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
bg.BorderSizePixel = 0
bg.Parent = surfaceGui

-- 標題
local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0.15, 0)
title.BackgroundColor3 = Color3.fromRGB(20, 20, 20) -- 改為深色背景以凸顯霓虹效果
title.Text = "🏆 勝率排行榜 🏆"
title.TextColor3 = Color3.fromRGB(255, 255, 255)
title.Font = Enum.Font.GothamBlack
title.TextScaled = true
title.Parent = bg

-- 霓虹燈閃爍效果
task.spawn(function()
	local colors = {
		Color3.fromRGB(255, 0, 0),   -- 紅
		Color3.fromRGB(255, 170, 0), -- 橙
		Color3.fromRGB(255, 255, 0), -- 黃
		Color3.fromRGB(0, 255, 0),   -- 綠
		Color3.fromRGB(0, 255, 255), -- 青
		Color3.fromRGB(0, 0, 255),   -- 藍
		Color3.fromRGB(255, 0, 255), -- 紫
	}
	local index = 1
	while title.Parent do
		local tween = TweenService:Create(title, TweenInfo.new(0.5, Enum.EasingStyle.Linear), {TextColor3 = colors[index]})
		tween:Play()
		tween.Completed:Wait()
		index = (index % #colors) + 1
	end
end)

-- 列表容器
local listContainer = Instance.new("ScrollingFrame")
listContainer.Size = UDim2.new(1, -20, 0.8, -20)
listContainer.Position = UDim2.new(0, 10, 0.18, 10)
listContainer.BackgroundTransparency = 1
listContainer.ScrollBarThickness = 6
listContainer.Parent = bg

local uiListLayout = Instance.new("UIListLayout")
uiListLayout.SortOrder = Enum.SortOrder.LayoutOrder
uiListLayout.Padding = UDim.new(0, 5)
uiListLayout.Parent = listContainer

-- 輔助函數：建立一行資料
local function createRow(rank, name, wins, winRate, gold)
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, 0, 0, 50)
	row.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
	row.BorderSizePixel = 0

	local text = string.format("%d. %s | 🏆 %d勝 | %.1f%% | 💰 %d", rank, name, wins, winRate, gold)

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, -20, 1, 0)
	label.Position = UDim2.new(0, 10, 0, 0)
	label.BackgroundTransparency = 1
	label.Text = text

	if rank == 1 then
		label.TextColor3 = Color3.fromRGB(255, 215, 0) -- 金色
	elseif rank == 2 then
		label.TextColor3 = Color3.fromRGB(192, 192, 192) -- 銀色
	elseif rank == 3 then
		label.TextColor3 = Color3.fromRGB(205, 127, 50) -- 銅色
	else
		label.TextColor3 = Color3.new(1, 1, 1)
	end

	label.Font = Enum.Font.GothamBold
	label.TextSize = 24
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = row
	
	return row
end

-- 更新排行榜函數
local function updateBoard()
	-- 清空舊資料
	for _, child in ipairs(listContainer:GetChildren()) do
		if child:IsA("Frame") then child:Destroy() end
	end

	local data = {}
	for _, player in ipairs(Players:GetPlayers()) do
		local ls = player:FindFirstChild("leaderstats")
		if ls then
			local gold = ls:FindFirstChild("Gold") and ls.Gold.Value or 0
			local wins = ls:FindFirstChild("Wins") and ls.Wins.Value or 0
			local totalCorrect = ls:FindFirstChild("TotalCorrect") and ls.TotalCorrect.Value or 0
			local totalAnswered = ls:FindFirstChild("TotalAnswered") and ls.TotalAnswered.Value or 0

			local winRate = 0
			if totalAnswered > 0 then
				winRate = (totalCorrect / totalAnswered) * 100
			end

			table.insert(data, {name = player.Name, wins = wins, winRate = winRate, gold = gold})
		end
	end

	-- 排序：勝場多者優先，勝場相同比勝率，再比金幣
	table.sort(data, function(a, b)
		if a.wins ~= b.wins then return a.wins > b.wins end
		if math.abs(a.winRate - b.winRate) > 0.1 then return a.winRate > b.winRate end
		return a.gold > b.gold
	end)

	-- 顯示
	for i, entry in ipairs(data) do
		local row = createRow(i, entry.name, entry.wins, entry.winRate, entry.gold)
		row.Parent = listContainer
	end
end

-- 每 5 秒更新一次
while true do
	updateBoard()
	task.wait(5)
end