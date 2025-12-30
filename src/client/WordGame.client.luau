local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- 等待伺服器建立 RemoteEvent
local REMOTE_NAME = "WordGameEvent"
local remote = ReplicatedStorage:WaitForChild(REMOTE_NAME)

-- 1. 單字庫 (改為動態獲取)
local getWordListFunc = ReplicatedStorage:WaitForChild("GetWordList")
local wordList = {} -- 初始為空，按下開始後才載入

-- 2. 建立 UI
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "WordGameGui"
screenGui.ResetOnSpawn = false -- 防止玩家重生後音樂與介面消失
screenGui.Parent = playerGui

-- 開始按鈕
local startButton = Instance.new("TextButton")
startButton.Size = UDim2.new(0, 150, 0, 50)
startButton.Position = UDim2.new(0.5, -75, 0.85, 0) -- 畫面下方
startButton.BackgroundColor3 = Color3.fromRGB(0, 120, 215)
startButton.TextColor3 = Color3.new(1, 1, 1)
startButton.Font = Enum.Font.GothamBold
startButton.TextSize = 20
startButton.Text = "開始單字挑戰"
startButton.Parent = screenGui

-- 尋找黑板零件
local classroom = Workspace:WaitForChild("Classroom")
local blackboardPart = classroom:WaitForChild("Blackboard")
local padCorrect = classroom:WaitForChild("AnswerPadCorrect")
local padWrong = classroom:WaitForChild("AnswerPadWrong")
local floor = classroom:WaitForChild("Floor") -- 關鍵修正：確保地板存在才開始

-- 建立黑板介面 (SurfaceGui)
local surfaceGui = Instance.new("SurfaceGui")
surfaceGui.Face = Enum.NormalId.Back -- 修正朝向，讓玩家看得到
surfaceGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
surfaceGui.LightInfluence = 0 -- 讓文字自體發光，不受光影影響
surfaceGui.PixelsPerStud = 50
surfaceGui.Parent = blackboardPart

local titleLabel = Instance.new("TextLabel")
titleLabel.Size = UDim2.new(1, 0, 0.15, 0)
titleLabel.BackgroundTransparency = 1
titleLabel.TextColor3 = Color3.new(1, 1, 1)
titleLabel.Font = Enum.Font.GothamBold
titleLabel.TextSize = 40
titleLabel.Text = "第 1/10 題"
titleLabel.Parent = surfaceGui

local questionLabel = Instance.new("TextLabel")
questionLabel.Size = UDim2.new(1, 0, 0.6, 0)
questionLabel.Position = UDim2.new(0, 0, 0.2, 0)
questionLabel.BackgroundTransparency = 1
questionLabel.TextColor3 = Color3.fromRGB(255, 220, 0)
questionLabel.Font = Enum.Font.GothamBlack
questionLabel.TextSize = 60
questionLabel.TextWrapped = true
questionLabel.Text = "Apple\n=\n蘋果 ?"
questionLabel.Parent = surfaceGui

local timerLabel = Instance.new("TextLabel")
timerLabel.Size = UDim2.new(1, 0, 0.15, 0)
timerLabel.Position = UDim2.new(0, 0, 0.85, 0)
timerLabel.BackgroundTransparency = 1
timerLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
timerLabel.Font = Enum.Font.Gotham
timerLabel.TextSize = 40
timerLabel.Text = "剩餘時間: 10"
timerLabel.Parent = surfaceGui

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

-- 音效設定
local soundCorrect = Instance.new("Sound")
soundCorrect.SoundId = "rbxassetid://4612375233" -- 正確音效
soundCorrect.Parent = screenGui

local soundWrong = Instance.new("Sound")
soundWrong.SoundId = "rbxassetid://4612377476" -- 錯誤音效
soundWrong.Parent = screenGui

-- 彈飛音效
local soundFling = Instance.new("Sound")
soundFling.SoundId = "rbxassetid://12222084" -- 卡通彈跳音效
soundFling.Parent = screenGui

-- 背景音樂
local bgm = Instance.new("Sound")
bgm.SoundId = "rbxassetid://1835386694" -- 輕快背景音樂
bgm.Looped = true
bgm.Volume = 0.5
bgm.Parent = screenGui
-- bgm:Play() -- 改到開始遊戲時播放

-- 3. 遊戲邏輯
local currentRound = 0
local maxRounds = 10
local currentAnswerIsMatch = false -- 題目是否正確匹配
local answerChosen = false
local currentStreak = 0 -- 本地端記錄連勝 (用於 UI 顯示)
local savedJumpPower = 50 -- 儲存原本的跳躍力
local savedJumpHeight = 7.2
local struggleConnection = nil -- 追蹤按鍵事件，防止重複綁定

local gameRunning = false
local safetyConnection = nil

-- 持續的安全檢查：防止玩家掉出教室
local function startSafetyCheck()
	if safetyConnection then safetyConnection:Disconnect() end
	safetyConnection = RunService.Heartbeat:Connect(function()
		if not gameRunning then 
			if safetyConnection then safetyConnection:Disconnect() end
			return 
		end
		
		local char = player.Character
		if char then
			local hrp = char:FindFirstChild("HumanoidRootPart")
			
			-- 動態安全檢查：依據地板位置判斷
			local floorPos = floor.Position
			local center2D = Vector3.new(floorPos.X, 0, floorPos.Z)
			local player2D = Vector3.new(hrp.Position.X, 0, hrp.Position.Z)
			
			-- 如果高度低於地板 10 格，或水平距離超過 35 格，視為掉出
			if hrp and (hrp.Position.Y < (floorPos.Y - 10) or (player2D - center2D).Magnitude > 35) then
				char:PivotTo(CFrame.new(floorPos.X, floorPos.Y + 5, floorPos.Z) * CFrame.Angles(0, math.rad(180), 0))
				hrp.AssemblyLinearVelocity = Vector3.zero -- 重置速度
			end
		end
	end)
end

local function endGame()
	gameRunning = false
	if safetyConnection then safetyConnection:Disconnect() end
	if struggleConnection then 
		struggleConnection:Disconnect() 
		struggleConnection = nil
	end
	struggleLabel.Visible = false
	
	surfaceGui.Enabled = false -- 隱藏黑板內容
	startButton.Visible = true
	startButton.Text = "遊戲結束！再玩一次"
	remote:FireServer("EndGame")
end

local function handleAnswer(playerChoice) -- playerChoice: true=選正確, false=選錯誤, nil=超時
	if answerChosen then return end
	answerChosen = true
	
	local isWin = false
	if playerChoice == nil then
		questionLabel.Text = "時間到！"
		isWin = false
		currentStreak = 0
		soundWrong:Play()
	elseif playerChoice == currentAnswerIsMatch then
		currentStreak += 1
		if currentStreak >= 3 then
			questionLabel.Text = "答對了！ (+20 連勝!)"
			
			-- 連勝文字縮放動畫 (變大再變回)
			local tweenInfo = TweenInfo.new(0.2, Enum.EasingStyle.Bounce, Enum.EasingDirection.Out, 0, true)
			TweenService:Create(questionLabel, tweenInfo, {TextSize = 80}):Play()
		else
			questionLabel.Text = "答對了！ (+10)"
		end
		isWin = true
		soundCorrect:Play()
	else
		questionLabel.Text = "答錯了！ (-10)"
		isWin = false
		currentStreak = 0
		soundWrong:Play()
	end
	
	if not isWin then
		local char = player.Character
		if char then
			local hrp = char:FindFirstChild("HumanoidRootPart")
			local hum = char:FindFirstChild("Humanoid")
			if hrp and hum then
				-- 如果當前跳躍力正常 (>0)，才更新儲存值；否則沿用之前的紀錄 (避免存到 0)
				if hum.JumpPower > 0 then
					savedJumpPower = hum.JumpPower
					savedJumpHeight = hum.JumpHeight
				end

				soundFling:Play()
				hum.Sit = true -- 強制坐下 (跌倒效果)
				-- 給予隨機方向的瞬間速度 (彈飛效果)
				hrp.AssemblyLinearVelocity = Vector3.new(math.random(-25, 25), 50, math.random(-25, 25))
				
				-- 掙扎機制：連按空白鍵站起來
				local requiredPresses = 5
				local presses = 0
				
				-- 暫時禁用跳躍 (防止按一下就站起來)
				hum.JumpPower = 0
				hum.JumpHeight = 0
				
				struggleLabel.Visible = true
				struggleLabel.Text = "連按空白鍵站起來！"
				
				-- 清除舊的連線，防止多重觸發
				if struggleConnection then struggleConnection:Disconnect() end
				
				struggleConnection = UserInputService.InputBegan:Connect(function(input, processed)
					if input.KeyCode == Enum.KeyCode.Space and not processed then
						presses += 1
						
						-- 文字震動效果
						struggleLabel.Position = UDim2.new(0.5, -200 + math.random(-5, 5), 0.65, math.random(-5, 5))
						
						if presses >= requiredPresses then
							if struggleConnection then struggleConnection:Disconnect() end
							struggleConnection = nil
							if hum and hum.Parent then
								hum.Sit = false -- 站起來
								hum.JumpPower = savedJumpPower -- 恢復正確的跳躍力
								hum.JumpHeight = savedJumpHeight
							end
							struggleLabel.Visible = false
							struggleLabel.Position = UDim2.new(0.5, -200, 0.65, 0) -- 重置位置
						end
					end
				end)
			end
		end
	end

	remote:FireServer("AnswerResult", isWin)
	task.wait(1.5)
	nextQuestion()
end

function nextQuestion()
	if currentRound >= maxRounds then
		endGame()
		return
	end
	
	currentRound += 1
	titleLabel.Text = "第 " .. currentRound .. " / " .. maxRounds .. " 題"
	answerChosen = false
	
	-- 取出伺服器預先生成的題目 (依序出題)
	local data = wordList[currentRound]
	if not data then return end
	
	currentAnswerIsMatch = data.isCorrect
	questionLabel.Text = data.en .. "\n=\n" .. data.displayCn .. " ?"
	
	-- 倒數計時
	local timeLeft = 10
	timerLabel.Text = "剩餘時間: " .. timeLeft
	
	task.spawn(function()
		local thisRound = currentRound
		for i = 1, 10 do
			if answerChosen or currentRound ~= thisRound then return end
			task.wait(1)
			timeLeft -= 1
			timerLabel.Text = "剩餘時間: " .. timeLeft
		end
		
		if not answerChosen and currentRound == thisRound then
			handleAnswer(nil) -- 超時
		end
	end)
end

-- 視覺回饋：讓地板發光閃爍
local function flashPad(pad)
	local tweenInfo = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, true)
	local tween = TweenService:Create(pad, tweenInfo, {Color = Color3.new(1, 1, 1)})
	tween:Play()
end

-- 踩踏事件偵測
local function onPadTouch(hit, isCorrectPad)
	if answerChosen then return end
	local char = player.Character
	if char and hit:IsDescendantOf(char) then
		local pad = isCorrectPad and padCorrect or padWrong
		flashPad(pad)
		handleAnswer(isCorrectPad)
	end
end

padCorrect.Touched:Connect(function(hit) onPadTouch(hit, true) end)
padWrong.Touched:Connect(function(hit) onPadTouch(hit, false) end)

startButton.MouseButton1Click:Connect(function()
	startButton.Text = "載入題目中..."
	task.wait() -- 強制更新 UI 顯示
	
	task.wait(0.5) -- 稍微等待伺服器準備
	gameRunning = true
	startSafetyCheck()
	
	-- 通知伺服器遊戲開始 (重置單局分數)
	remote:FireServer("StartGame")
	
	-- 向伺服器請求 10 個隨機翻譯好的單字
	wordList = getWordListFunc:InvokeServer()
	
	if not bgm.Playing then
		bgm:Play()
	end

	startButton.Visible = false
	surfaceGui.Enabled = true
	currentRound = 0
	currentStreak = 0 -- 重置連勝
	nextQuestion()
end)