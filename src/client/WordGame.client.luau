local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local REMOTE_NAME = "WordGameEvent"
local remote = ReplicatedStorage:WaitForChild(REMOTE_NAME)

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Logger = require(Shared:WaitForChild("Logger"))
local logger = Logger.new("WordGame")

local getWordListFunc = ReplicatedStorage:WaitForChild("GetWordList")
local GameSession = require(script.Parent:WaitForChild("GameSession"))

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "WordGameGui"
screenGui.ResetOnSpawn = false
screenGui.Parent = playerGui

local startButton = Instance.new("TextButton")
startButton.Size = UDim2.new(0, 200, 0, 60)
startButton.Position = UDim2.new(0.5, -100, 0.8, 0)
startButton.BackgroundColor3 = Color3.fromRGB(0, 120, 215)
startButton.TextColor3 = Color3.new(1, 1, 1)
startButton.Font = Enum.Font.GothamBold
startButton.TextSize = 24
startButton.Text = "開始遊戲"
startButton.Visible = false
startButton.Parent = screenGui

local startZone = Workspace:WaitForChild("WordGameZone")
local startPrompt = startZone:WaitForChild("InteractPrompt", 10)
if not startPrompt then
	logger:warn("⚠️ 警告: 在 WordGameZone 中找不到 InteractPrompt！請檢查 MapSetup。")
end

-- 遊戲 UI (預先建立，以便傳遞給 GameSession)
local surfaceGui = Instance.new("SurfaceGui")
local titleLabel = Instance.new("TextLabel")
local questionLabel = Instance.new("TextLabel")
local timerLabel = Instance.new("TextLabel")

local function setupGameUI()
	surfaceGui.Name = "BlackboardGui"
	surfaceGui.Face = Enum.NormalId.Back
	surfaceGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	surfaceGui.LightInfluence = 0
	surfaceGui.PixelsPerStud = 50

	titleLabel.Size = UDim2.new(1, 0, 0.15, 0); titleLabel.BackgroundTransparency = 1; titleLabel.TextColor3 = Color3.new(1, 1, 1); titleLabel.Font = Enum.Font.GothamBold; titleLabel.TextSize = 40; titleLabel.Parent = surfaceGui
	questionLabel.Size = UDim2.new(1, 0, 0.6, 0); questionLabel.Position = UDim2.new(0, 0, 0.2, 0); questionLabel.BackgroundTransparency = 1; questionLabel.TextColor3 = Color3.fromRGB(255, 220, 0); questionLabel.Font = Enum.Font.GothamBlack; questionLabel.TextSize = 60; questionLabel.TextWrapped = true; questionLabel.Parent = surfaceGui
	timerLabel.Size = UDim2.new(1, 0, 0.15, 0); timerLabel.Position = UDim2.new(0, 0, 0.85, 0); timerLabel.BackgroundTransparency = 1; timerLabel.TextColor3 = Color3.fromRGB(255, 100, 100); timerLabel.Font = Enum.Font.Gotham; timerLabel.TextSize = 40; timerLabel.Parent = surfaceGui
end

setupGameUI()

-- 掙扎提示 UI
local struggleLabel = Instance.new("TextLabel")
struggleLabel.Size = UDim2.new(0, 400, 0, 60)
struggleLabel.Position = UDim2.new(0.5, -200, 0.65, 0)
struggleLabel.BackgroundTransparency = 1
struggleLabel.TextColor3 = Color3.fromRGB(255, 80, 80)
struggleLabel.TextStrokeTransparency = 0
struggleLabel.Font = Enum.Font.GothamBlack
struggleLabel.TextSize = 32
struggleLabel.Text = "連按空白鍵站起來！"
struggleLabel.Visible = false
struggleLabel.Parent = screenGui

-- 掙扎按鈕 (手機版/滑鼠點擊用)
local struggleButton = Instance.new("TextButton")
struggleButton.Size = UDim2.new(0, 200, 0, 60)
struggleButton.Position = UDim2.new(0.5, -100, 0.75, 0) -- 位於提示文字下方
struggleButton.BackgroundColor3 = Color3.fromRGB(255, 80, 80)
struggleButton.TextColor3 = Color3.new(1, 1, 1)
struggleButton.Font = Enum.Font.GothamBold
struggleButton.TextSize = 24
struggleButton.Text = "點擊掙扎！"
struggleButton.ZIndex = 10 -- 確保按鈕在最上層
struggleButton.Visible = false
struggleButton.Parent = screenGui

local activeSession = nil -- 儲存當前的遊戲會話
local safetyConnection = nil
local isTeleporting = false

-- 本地隱藏/顯示其他玩家
local function toggleOtherPlayers(visible)
	for _, otherPlayer in ipairs(Players:GetPlayers()) do
		if otherPlayer ~= player then
			local char = otherPlayer.Character
			if char then
				-- 遞迴設定所有零件透明度
				for _, part in ipairs(char:GetDescendants()) do
					if part:IsA("BasePart") or part:IsA("Decal") then
						part.Transparency = visible and 0 or 1
					elseif part:IsA("BillboardGui") or part:IsA("SurfaceGui") then
						-- 隱藏名字標籤等 UI
						part.Enabled = visible
					end
				end
			end
		end
	end
end

-- 持續的安全檢查：防止玩家掉出教室
-- (This function is now managed within the GameSession)

local function endGame()
	logger:debug("endGame: 開始執行...")
	if safetyConnection then safetyConnection:Disconnect() end

	if activeSession then
		activeSession:Destroy()
		activeSession = nil
	end

	-- 強制解除掙扎狀態 (修復遊戲結束時卡在跌倒狀態的 Bug)
	local char = player.Character
	if char then
		local hum = char:FindFirstChild("Humanoid")
		if hum then
			hum.Sit = false -- 站起來
			hum:SetStateEnabled(Enum.HumanoidStateType.Jumping, true) -- 恢復跳躍能力
		end
	end

	-- 恢復顯示其他玩家
	toggleOtherPlayers(true)

	if startPrompt then
		startPrompt.Enabled = true
	end

	isTeleporting = true
	logger:debug("endGame: 準備發送 EndGame 事件到伺服器...")
	remote:FireServer("EndGame")
	logger:debug("endGame: EndGame 事件已發送。")
end

local function startGameSession()
	if activeSession then return end
	
	if startPrompt then startPrompt.Enabled = false end

	-- 隱藏其他玩家，營造絕對獨立空間
	toggleOtherPlayers(false)

	-- 建立新的遊戲會話
	local uiElements = {
		surfaceGui = surfaceGui,
		titleLabel = titleLabel,
		questionLabel = questionLabel,
		timerLabel = timerLabel,
		struggleLabel = struggleLabel,
		struggleButton = struggleButton
	}
	activeSession = GameSession.new(remote, getWordListFunc, uiElements, endGame)
	activeSession:Start()
	-- startSafetyCheck() -- Safety check is now internal to the session
end

startButton.MouseButton1Click:Connect(startGameSession)

-- 支援按 E 觸發
if startPrompt then
	startPrompt.Triggered:Connect(startGameSession)
end

local lastDebugTime = 0

-- 區域偵測：控制開始按鈕的顯示
RunService.Heartbeat:Connect(function()
	if activeSession or isTeleporting then
		startButton.Visible = false
		return
	end

	local char = player.Character
	if char then
		local hrp = char:FindFirstChild("HumanoidRootPart")
		if hrp then
			local playerPos = Vector3.new(hrp.Position.X, 0, hrp.Position.Z)
			local zonePos = Vector3.new(startZone.Position.X, 0, startZone.Position.Z)
			local dist = (playerPos - zonePos).Magnitude
			
			-- 如果距離突然變得很小 (回到大廳)，則結束傳送狀態
			if isTeleporting and dist < 100 then
				isTeleporting = false
				logger:debug("傳送完成，恢復距離偵測")
			end

			if os.clock() - lastDebugTime > 1 then
				lastDebugTime = os.clock()
				logger:debug(string.format("距離開始區: %.2f | 顯示按鈕: %s", dist, tostring(dist <= 8)))
			end
			
			startButton.Visible = (dist <= 8) -- 距離 8 單位內顯示按鈕
		end
	end
end)
