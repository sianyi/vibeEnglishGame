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

-- 開始按鈕 (進入區域後顯示)
local startButton = Instance.new("TextButton")
startButton.Size = UDim2.new(0, 200, 0, 60)
startButton.Position = UDim2.new(0.5, -100, 0.8, 0) -- 畫面下方
startButton.BackgroundColor3 = Color3.fromRGB(0, 120, 215)
startButton.TextColor3 = Color3.new(1, 1, 1)
startButton.Font = Enum.Font.GothamBold
startButton.TextSize = 24
startButton.Text = "開始遊戲"
startButton.Visible = false
startButton.Parent = screenGui

-- [DEBUG] 列出 Workspace 所有物件，確認同步狀態
print(">>> [DEBUG] Workspace Children List:")
for _, child in ipairs(Workspace:GetChildren()) do
	print(" - " .. child.Name .. " (" .. child.ClassName .. ")")
end

local startZone = Workspace:WaitForChild("WordGameZone")
local leaderboardPart = Workspace:WaitForChild("WordGameRank")
local gameSign = Workspace:WaitForChild("WordGameSign", 5)

-- [DEBUG] 初始位置檢查 (確認物件狀態)
print("--------------------------------------------------")
print(string.format(">>> [DEBUG] WordGameZone: %s | Size: %s | Transparency: %.1f | Parent: %s", tostring(startZone.Position), tostring(startZone.Size), startZone.Transparency, tostring(startZone.Parent)))
print(string.format(">>> [DEBUG] WordGameRank: %s | Size: %s | Transparency: %.1f | Parent: %s", tostring(leaderboardPart.Position), tostring(leaderboardPart.Size), leaderboardPart.Transparency, tostring(leaderboardPart.Parent)))

local baseplate = Workspace:FindFirstChild("Baseplate")
if baseplate then
	print(string.format(">>> [DEBUG] Baseplate Position: %s | Size: %s", tostring(baseplate.Position), tostring(baseplate.Size)))
end

if gameSign then
	print(string.format(">>> [DEBUG] WordGameSign: %s | Parent: %s", tostring(gameSign.Position), tostring(gameSign.Parent)))
	local gui = gameSign:FindFirstChild("SignGui")
	if gui then
		print(string.format(">>> [DEBUG] SignGui found. Face: %s, Enabled: %s", tostring(gui.Face), tostring(gui.Enabled)))
		local label = gui:FindFirstChild("TextLabel")
		if label then
			print(string.format(">>> [DEBUG] TextLabel found. Text: '%s', Visible: %s, Transparency: %.1f, Size: %s", label.Text, tostring(label.Visible), label.TextTransparency, tostring(label.Size)))
		else
			warn(">>> [DEBUG] 警告: SignGui 裡面找不到 TextLabel")
		end
	else
		warn(">>> [DEBUG] 警告: WordGameSign 裡面找不到 SignGui")
	end
else
	warn(">>> [DEBUG] 警告: 找不到 WordGameSign (告示牌)！")
end
print("--------------------------------------------------")

local startPrompt = startZone:WaitForChild("InteractPrompt")

-- 遊戲 UI (預先建立，遊戲開始時再指定 Parent)
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

	titleLabel.Size = UDim2.new(1, 0, 0.15, 0)
	titleLabel.BackgroundTransparency = 1
	titleLabel.TextColor3 = Color3.new(1, 1, 1)
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.TextSize = 40
	titleLabel.Text = "第 1/10 題"
	titleLabel.Parent = surfaceGui

	questionLabel.Size = UDim2.new(1, 0, 0.6, 0)
	questionLabel.Position = UDim2.new(0, 0, 0.2, 0)
	questionLabel.BackgroundTransparency = 1
	questionLabel.TextColor3 = Color3.fromRGB(255, 220, 0)
	questionLabel.Font = Enum.Font.GothamBlack
	questionLabel.TextSize = 60
	questionLabel.TextWrapped = true
	questionLabel.Text = "Apple\n=\n蘋果 ?"
	questionLabel.Parent = surfaceGui

	timerLabel.Size = UDim2.new(1, 0, 0.15, 0)
	timerLabel.Position = UDim2.new(0, 0, 0.85, 0)
	timerLabel.BackgroundTransparency = 1
	timerLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
	timerLabel.Font = Enum.Font.Gotham
	timerLabel.TextSize = 40
	timerLabel.Text = "剩餘時間: 10"
	timerLabel.Parent = surfaceGui
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

-- 音效設定
local soundCorrect = Instance.new("Sound")
soundCorrect.SoundId = "rbxassetid://131886985" -- 正確音效 (Coin)
soundCorrect.Parent = screenGui

local soundWrong = Instance.new("Sound")
soundWrong.SoundId = "rbxassetid://130972023" -- 錯誤音效 (Error)
soundWrong.Parent = screenGui

-- 彈飛音效
local soundFling = Instance.new("Sound")
soundFling.SoundId = "rbxassetid://12222084" -- 卡通彈跳音效
soundFling.Parent = screenGui

-- 3. 遊戲邏輯
local currentRound = 0
local maxRounds = 10
local currentAnswerIsMatch = false -- 題目是否正確匹配
local answerChosen = false
local currentStreak = 0 -- 本地端記錄連勝 (用於 UI 顯示)
local struggleConnection = nil -- 追蹤按鍵事件，防止重複綁定
local struggleButtonConnection = nil -- 追蹤按鈕事件

local localClassroom = nil -- 儲存本地教室模型

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
			-- 安全檢查：如果玩家掉出教室範圍，將其傳送回教室中心
			local hrp = char:FindFirstChild("HumanoidRootPart")
			if hrp and hrp.Position.Y < 10 then
				char:PivotTo(CFrame.new(0, 25, -100))
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
	if struggleButtonConnection then
		struggleButtonConnection:Disconnect()
		struggleButtonConnection = nil
	end
	struggleLabel.Visible = false
	struggleButton.Visible = false
	
	-- [DEBUG] 增加日誌來檢查 endGame 流程
	print(">>> [DEBUG] endGame: 開始執行...")

	-- 強制解除掙扎狀態 (修復遊戲結束時卡在跌倒狀態的 Bug)
	local char = player.Character
	if char then
		local hum = char:FindFirstChild("Humanoid")
		if hum then
			hum.Sit = false -- 站起來
			hum:SetStateEnabled(Enum.HumanoidStateType.Jumping, true) -- 恢復跳躍能力
		end
	end

	-- 使用 pcall 來安全地銷毀教室，防止錯誤中斷整個函數
	if localClassroom then
		print(">>> [DEBUG] endGame: 準備銷毀教室...")
		local success, err = pcall(function()
			-- 保護 UI 不被銷毀，以便下一局重複使用
			surfaceGui.Parent = nil
			
			-- 正確的銷毀方式是銷毀 table 中的 model 物件
			print(">>> [DEBUG] endGame: 正在嘗試 localClassroom.model:Destroy()")
			localClassroom.model:Destroy()
			print(">>> [DEBUG] endGame: 教室銷毀成功。")
		end)

		if not success then
			warn(">>> [CRITICAL ERROR] 銷毀教室失敗:", err)
		end

		localClassroom = nil
	end

	if startPrompt then
		startPrompt.Enabled = true -- 重新啟用提示
	end
	print(">>> [DEBUG] endGame: 準備發送 EndGame 事件到伺服器...")
	remote:FireServer("EndGame")
	print(">>> [DEBUG] endGame: EndGame 事件已發送。")
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
				soundFling:Play()
				hum.Sit = true -- 強制坐下 (跌倒效果)
				-- 給予隨機方向的瞬間速度 (彈飛效果)
				hrp.AssemblyLinearVelocity = Vector3.new(math.random(-25, 25), 50, math.random(-25, 25))
				
				-- 掙扎機制：連按空白鍵站起來
				local requiredPresses = 5
				local presses = 0

				-- 暫時禁用跳躍狀態 (這會隱藏手機原生跳躍鈕，所以我們顯示自訂按鈕)
				hum:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
				
				struggleLabel.Visible = true
				struggleLabel.Text = "連按按鈕站起來！"
				print(">>> [DEBUG] 顯示掙扎按鈕")
				struggleButton.Visible = true
				
				-- 清除舊的連線，防止多重觸發
				if struggleConnection then struggleConnection:Disconnect() end
				if struggleButtonConnection then struggleButtonConnection:Disconnect() end
				
				local lastAttempt = 0
				local function attemptStandUp()
					local now = os.clock()
					if now - lastAttempt < 0.15 then return end -- 防止按住跳躍鍵瞬間完成
					lastAttempt = now

					presses += 1
					
					-- 文字震動效果
					struggleLabel.Position = UDim2.new(0.5, -200 + math.random(-5, 5), 0.65, math.random(-5, 5))
					
					if presses >= requiredPresses then
						if struggleConnection then struggleConnection:Disconnect() end
						if struggleButtonConnection then struggleButtonConnection:Disconnect() end
						struggleConnection = nil
						struggleButtonConnection = nil
						
						if hum and hum.Parent then
							hum:SetStateEnabled(Enum.HumanoidStateType.Jumping, true) -- 恢復跳躍能力
							hum.Sit = false -- 站起來
						end
						struggleLabel.Visible = false
						struggleButton.Visible = false
						struggleLabel.Position = UDim2.new(0.5, -200, 0.65, 0) -- 重置位置
					end
				end
				
				-- 改用 JumpRequest，這樣手機的跳躍按鈕也能觸發掙扎
				struggleConnection = UserInputService.JumpRequest:Connect(attemptStandUp)
				
				struggleButtonConnection = struggleButton.MouseButton1Click:Connect(attemptStandUp)
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

-- 建立本地獨立教室
local function createLocalClassroom()
	local classroom = Instance.new("Model")
	classroom.Name = "LocalClassroom"
	
	local function createPart(name, props)
		local part = Instance.new("Part")
		part.Name = name
		part.Anchored = true
		for k, v in pairs(props) do
			part[k] = v
		end
		part.Parent = classroom
		return part
	end

	-- 建立地板
	local floor = createPart("Floor", {
		Position = Vector3.new(0, 20, -100),
		Size = Vector3.new(50, 2, 50),
		Color = Color3.fromRGB(75, 151, 75),
		Material = Enum.Material.Grass
	})

	-- 建立黑板
	local blackboard = createPart("Blackboard", {
		Position = Vector3.new(0, 28.5, -118),
		Size = Vector3.new(16, 8, 1),
		Color = Color3.fromRGB(27, 27, 27),
		Material = Enum.Material.Slate
	})

	-- 建立作答區
	local padCorrect = createPart("AnswerPadCorrect", {
		Position = Vector3.new(-10, 21.1, -105),
		Size = Vector3.new(10, 0.2, 10),
		Color = Color3.fromRGB(46, 204, 113),
		Material = Enum.Material.Neon
	})

	local padWrong = createPart("AnswerPadWrong", {
		Position = Vector3.new(10, 21.1, -105),
		Size = Vector3.new(10, 0.2, 10),
		Color = Color3.fromRGB(231, 76, 60),
		Material = Enum.Material.Neon
	})

	-- 建立牆壁與天花板
	createPart("WallBack", { Position = Vector3.new(0, 31, -120), Size = Vector3.new(40, 20, 1), Color = Color3.fromRGB(204, 191, 153), Material = Enum.Material.SmoothPlastic })
	createPart("WallFront", { Position = Vector3.new(0, 31, -80), Size = Vector3.new(40, 20, 1), Color = Color3.fromRGB(204, 191, 153), Material = Enum.Material.SmoothPlastic })
	createPart("WallLeft", { Position = Vector3.new(-20, 31, -100), Size = Vector3.new(1, 20, 40), Color = Color3.fromRGB(204, 191, 153), Material = Enum.Material.SmoothPlastic })
	createPart("WallRight", { Position = Vector3.new(20, 31, -100), Size = Vector3.new(1, 20, 40), Color = Color3.fromRGB(204, 191, 153), Material = Enum.Material.SmoothPlastic })
	createPart("Ceiling", { Position = Vector3.new(0, 41.5, -100), Size = Vector3.new(40, 1, 40), Color = Color3.fromRGB(204, 204, 204), Material = Enum.Material.Concrete })
	
	local lightPart = createPart("ClassroomLight", { Position = Vector3.new(0, 41, -100), Size = Vector3.new(4, 0.5, 8), Color = Color3.fromRGB(255, 255, 255), Material = Enum.Material.Neon })
	local light = Instance.new("PointLight")
	light.Range = 30
	light.Brightness = 1.5
	light.Parent = lightPart

	classroom.Parent = Workspace
	
	return {
		model = classroom,
		blackboard = blackboard,
		padCorrect = padCorrect,
		padWrong = padWrong,
		floor = floor
	}
end

-- 踩踏事件偵測
local function onPadTouch(hit, isCorrectPad)
	if answerChosen then return end
	local char = player.Character
	if char and hit:IsDescendantOf(char) then
		local pad = isCorrectPad and localClassroom.padCorrect or localClassroom.padWrong
		flashPad(pad)
		handleAnswer(isCorrectPad)
	end
end

local function startGameSession()
	if gameRunning then return end
	
	if startPrompt then startPrompt.Enabled = false end

	-- 建立獨立教室
	localClassroom = createLocalClassroom()
	surfaceGui.Parent = localClassroom.blackboard

	-- 綁定新的踩踏事件
	localClassroom.padCorrect.Touched:Connect(function(hit) onPadTouch(hit, true) end)
	localClassroom.padWrong.Touched:Connect(function(hit) onPadTouch(hit, false) end)

	-- 傳送玩家
	if player.Character then
		player.Character:PivotTo(CFrame.new(0, 25, -100) * CFrame.Angles(0, math.rad(180), 0))
	end

	task.wait(0.5) -- 稍微等待伺服器準備
	gameRunning = true
	startSafetyCheck()
	
	-- 通知伺服器遊戲開始 (重置單局分數)
	remote:FireServer("StartGame")
	
	-- 向伺服器請求 10 個隨機翻譯好的單字
	wordList = getWordListFunc:InvokeServer()
	
	currentRound = 0
	currentStreak = 0 -- 重置連勝
	nextQuestion()
end

startButton.MouseButton1Click:Connect(startGameSession)

-- 支援按 E 觸發
if startPrompt then
	startPrompt.Triggered:Connect(startGameSession)
end

local lastDebugTime = 0

-- 區域偵測：控制開始按鈕的顯示
RunService.Heartbeat:Connect(function()
	if gameRunning then
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
			
			if os.clock() - lastDebugTime > 1 then
				lastDebugTime = os.clock()
				print(string.format(">>> [DEBUG] 距離開始區: %.2f | 顯示按鈕: %s", dist, tostring(dist <= 8)))
			end
			
			startButton.Visible = (dist <= 8) -- 距離 8 單位內顯示按鈕
		end
	end
end)
