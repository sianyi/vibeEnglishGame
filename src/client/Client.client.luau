--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

warn("[Client] 核心腳本啟動中... (v2.0 Debug)")

-- 0. 除錯：列出 ReplicatedStorage 的內容，協助確認 RemoteEvent 的真實位置
task.spawn(function()
	warn("=== 🔍 ReplicatedStorage 內容掃描 ===")
	for _, child in ipairs(ReplicatedStorage:GetChildren()) do
		warn("📁 " .. child.Name .. " [" .. child.ClassName .. "]")
		if child:IsA("Folder") then
			for _, grandChild in ipairs(child:GetChildren()) do
				warn("   └─ " .. grandChild.Name .. " [" .. grandChild.ClassName .. "]")
			end
		end
	end
	warn("=====================================")
end)

-- 1. 取得必要的資源與模組 (遞迴搜尋)
local function findObjectRecursive(parent, name, className, maxDepth)
	maxDepth = maxDepth or 3
	if maxDepth <= 0 then return nil end
	
	local target = parent:FindFirstChild(name)
	if target and (not className or target:IsA(className)) then
		return target
	end
	
	for _, child in ipairs(parent:GetChildren()) do
		if child:IsA("Folder") then
			local result = findObjectRecursive(child, name, className, maxDepth - 1)
			if result then return result end
		end
	end
	return nil
end

local function waitForObject(name, className)
	local obj = findObjectRecursive(ReplicatedStorage, name, className)
	if obj then 
		warn("[Client] ✅ 立即找到: " .. obj:GetFullName())
		return obj 
	end
	
	warn("[Client] ⚠️ 尚未找到 " .. name .. "，正在全域搜尋...")
	return ReplicatedStorage:WaitForChild(name, 15) -- 嘗試等待根目錄，如果失敗會報錯
end

-- 注意：GetWordList 應該是 RemoteFunction，GameRemote 是 RemoteEvent
local GameRemote = findObjectRecursive(ReplicatedStorage, "GameRemote", "RemoteEvent") or ReplicatedStorage:WaitForChild("GameRemote", 10)
local GetWordList = findObjectRecursive(ReplicatedStorage, "GetWordList", "RemoteFunction") or ReplicatedStorage:WaitForChild("GetWordList", 10)

if not GameRemote or not GetWordList then
	warn("[Client] ❌ 嚴重錯誤：找不到必要的 Remotes！請查看上方的內容掃描，確認伺服器將它們放在哪裡。")
	return
else
	warn("[Client] ✅ 成功連結 Remotes，準備啟動遊戲 Session")
end

local GameSession = require(script.Parent:WaitForChild("GameSession"))
local CountdownUI = require(script.Parent:WaitForChild("CountdownUI"))
-- LevelSelectionUI 不再需要，因為改用區域觸發

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- 用於追蹤當前選擇的單字級別
local selectedWordLevel = 1000

-- 2. 準備 UI 容器
-- 這些 UI 元素會被傳入 GameSession 中使用
local function createGameUI()
	-- A. 黑板 UI (SurfaceGui)
	local surfaceGui = Instance.new("SurfaceGui")
	surfaceGui.Name = "BoardUI"
	surfaceGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	surfaceGui.PixelsPerStud = 20
	
	local bg = Instance.new("Frame", surfaceGui)
	bg.Size = UDim2.fromScale(1, 1)
	bg.BackgroundTransparency = 1
	
	local title = Instance.new("TextLabel", bg)
	title.Name = "TitleLabel"
	title.Size = UDim2.new(1, 0, 0.2, 0)
	title.Position = UDim2.new(0, 0, 0, 0)
	title.BackgroundTransparency = 1
	title.TextColor3 = Color3.new(1, 1, 1)
	title.TextScaled = true
	title.Text = "等待遊戲開始..."
	
	local question = Instance.new("TextLabel", bg)
	question.Name = "QuestionLabel"
	question.Size = UDim2.new(1, 0, 0.6, 0)
	question.Position = UDim2.new(0, 0, 0.2, 0)
	question.BackgroundTransparency = 1
	question.TextColor3 = Color3.new(1, 1, 0.5)
	question.TextScaled = true
	question.Text = "題目載入中..."
	
	local timer = Instance.new("TextLabel", bg)
	timer.Name = "TimerLabel"
	timer.Size = UDim2.new(1, 0, 0.2, 0)
	timer.Position = UDim2.new(0, 0, 0.8, 0)
	timer.BackgroundTransparency = 1
	timer.TextColor3 = Color3.new(1, 0.5, 0.5)
	timer.TextScaled = true
	timer.Text = ""

	-- B. 掙扎 UI (ScreenGui)
	local struggleScreen = Instance.new("ScreenGui", playerGui)
	struggleScreen.Name = "StruggleUI"
	
	local struggleLabel = Instance.new("TextLabel", struggleScreen)
	struggleLabel.Size = UDim2.new(0, 400, 0, 100)
	struggleLabel.Position = UDim2.new(0.5, -200, 0.65, 0)
	struggleLabel.BackgroundTransparency = 1
	struggleLabel.TextColor3 = Color3.new(1, 0, 0)
	struggleLabel.TextScaled = true
	struggleLabel.Text = "連按空白鍵！"
	struggleLabel.Visible = false
	
	local struggleButton = Instance.new("TextButton", struggleScreen)
	struggleButton.Size = UDim2.fromScale(1, 1)
	struggleButton.BackgroundTransparency = 1
	struggleButton.Text = ""
	struggleButton.Visible = false

	return {
		surfaceGui = surfaceGui,
		titleLabel = title,
		questionLabel = question,
		timerLabel = timer,
		struggleLabel = struggleLabel,
		struggleButton = struggleButton
	}
end

local uiElements = createGameUI()
local currentSession = nil
local currentCountdownUI = nil

-- 3. 監聽伺服器的開始訊號
GameRemote.OnClientEvent:Connect(function(action, ...)
	warn("[Client] 收到事件:", action)
	
	if action == "Countdown" then
		-- 多人遊戲倒數
		local count = ...
		if count == 0 then
			-- 倒數取消
			warn("[Client] 倒數取消")
			if currentCountdownUI and currentCountdownUI.instance then
				currentCountdownUI.instance.Enabled = false
			end
		elseif count == -1 then
			-- 遊戲開始
			warn("[Client] 遊戲開始！")
			if currentCountdownUI and currentCountdownUI.instance then
				currentCountdownUI.instance.Enabled = false
			end
		else
			-- 顯示倒數
			warn("[Client] 倒數:", count)
			
			-- 如果還沒有倒數 UI，就創建一個
			if not currentCountdownUI then
				currentCountdownUI = CountdownUI.new()
			end
			
			-- 啟用並顯示倒數
			currentCountdownUI.instance.Enabled = true
			currentCountdownUI.label.Text = tostring(count)
			currentCountdownUI.label.TextColor3 = Color3.fromRGB(255, 255, 100)
			currentCountdownUI.label.Rotation = -15
			currentCountdownUI.label.Size = UDim2.fromScale(0.1, 0.1)
			
			-- 彈跳動畫
			local tweenInfo = TweenInfo.new(0.5, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out)
			TweenService:Create(currentCountdownUI.label, tweenInfo, {
				Size = UDim2.fromScale(0.3, 0.3),
				Rotation = 0
			}):Play()
		end
		return
	end
	
	if action == "StartGame" then
		-- 如果已有舊的 Session，先銷毀
		if currentSession then 
			currentSession:Destroy() 
		end
		
		warn("[Client] 正在建立 GameSession...")
		-- 建立並啟動新的遊戲 Session
		currentSession = GameSession.new(GameRemote, GetWordList, uiElements, function()
			warn("遊戲結束！")
			-- 這裡可以處理遊戲結束後的邏輯，例如顯示結算畫面
		end)
		
		currentSession:Start()
	end
end)

-- 按 L 鍵顯示目前等級資訊 (可選功能)
-- UserInputService.InputBegan:Connect(function(input, gameProcessed)
-- 	if gameProcessed then return end
-- 	
-- 	if input.KeyCode == Enum.KeyCode.L then
-- 		if currentLevelSelectionUI then
-- 			currentLevelSelectionUI:Destroy()
-- 		end
-- 		currentLevelSelectionUI = LevelSelectionUI.new()
-- 		print("[Client] 打開單字級別選擇 UI")
-- 	end
-- end)

print("[Client] 客戶端腳本初始化完成")