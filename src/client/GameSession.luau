local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Logger = require(Shared:WaitForChild("Logger"))
local logger = Logger.new("GameSession")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- 音效與資源
local soundCorrect = Instance.new("Sound")
soundCorrect.SoundId = "rbxassetid://131886985"
soundCorrect.Parent = playerGui

local soundWrong = Instance.new("Sound")
soundWrong.SoundId = "rbxassetid://130972023"
soundWrong.Parent = playerGui

local soundFling = Instance.new("Sound")
soundFling.SoundId = "rbxassetid://12222084"
soundFling.Parent = playerGui

local GameSession = {}
GameSession.__index = GameSession

-- 視覺回饋：讓地板發光閃爍
local function flashPad(pad)
	local tweenInfo = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, true)
	local tween = TweenService:Create(pad, tweenInfo, {Color = Color3.new(1, 1, 1)})
	tween:Play()
end

function GameSession.new(remote, getWordListFunc, uiElements, onGameOverCallback)
	local self = setmetatable({}, GameSession)

	self.remote = remote
	self.getWordListFunc = getWordListFunc
	self.ui = uiElements
	self.onGameOverCallback = onGameOverCallback

	-- 遊戲狀態
	self.currentRound = 0
	self.maxRounds = 10
	self.currentAnswerIsMatch = false
	self.answerChosen = false
	self.currentStreak = 0
	self.wordList = {}

	-- 建立場景
	self.roomOffset = Vector3.new(math.random(-100000, 100000), 500, math.random(-100000, 100000))
	self.classroom = self:_createLocalClassroom(self.roomOffset)
	self.ui.surfaceGui.Parent = self.classroom.blackboard

	-- 綁定事件
	self.padCorrectConnection = self.classroom.padCorrect.Touched:Connect(function(hit) self:onPadTouch(hit, true) end)
	self.padWrongConnection = self.classroom.padWrong.Touched:Connect(function(hit) self:onPadTouch(hit, false) end)

	return self
end

function GameSession:Start()
	-- 傳送玩家
	if player.Character then
		player.Character:PivotTo(CFrame.new(self.roomOffset) * CFrame.new(0, 25, -100) * CFrame.Angles(0, math.rad(180), 0))
	end

	-- 通知伺服器遊戲開始
	self.remote:FireServer("StartGame")
	
	-- 獲取題目
	self.wordList = self.getWordListFunc:InvokeServer()
	
	self:nextQuestion()
end

function GameSession:Destroy()
	logger:debug("Session:Destroy() called")
	if self.padCorrectConnection then self.padCorrectConnection:Disconnect() end
	if self.padWrongConnection then self.padWrongConnection:Disconnect() end
	if self.struggleConnection then self.struggleConnection:Disconnect() end
	if self.struggleButtonConnection then self.struggleButtonConnection:Disconnect() end

	if self.classroom and self.classroom.model then
		self.classroom.model:Destroy()
	end
	
	-- 注意：UI 不銷毀，只是解除 Parent，以便下次重用 (由主腳本管理 UI 生命週期)
	if self.ui then
		if self.ui.surfaceGui then self.ui.surfaceGui.Parent = nil end
		if self.ui.struggleLabel then self.ui.struggleLabel.Visible = false end
		if self.ui.struggleButton then self.ui.struggleButton.Visible = false end
	end
end

function GameSession:_createLocalClassroom(offset)
	local classroom = Instance.new("Model")
	classroom.Name = "LocalClassroom"
	
	local function createPart(name, props)
		local part = Instance.new("Part")
		part.Name = name
		part.Anchored = true
		for k, v in pairs(props) do
			if k == "Position" then
				part[k] = v + offset
			else
				part[k] = v
			end
		end
		part.Parent = classroom
		return part
	end

	-- 建立地板
	local floor = createPart("Floor", { Position = Vector3.new(0, 20, -100), Size = Vector3.new(50, 2, 50), Color = Color3.fromRGB(75, 151, 75), Material = Enum.Material.Grass })
	-- 建立黑板
	local blackboard = createPart("Blackboard", { Position = Vector3.new(0, 28.5, -118), Size = Vector3.new(16, 8, 1), Color = Color3.fromRGB(27, 27, 27), Material = Enum.Material.Slate })
	-- 建立作答區
	local padCorrect = createPart("AnswerPadCorrect", { Position = Vector3.new(-10, 21.1, -105), Size = Vector3.new(10, 0.2, 10), Color = Color3.fromRGB(46, 204, 113), Material = Enum.Material.Neon })
	local padWrong = createPart("AnswerPadWrong", { Position = Vector3.new(10, 21.1, -105), Size = Vector3.new(10, 0.2, 10), Color = Color3.fromRGB(231, 76, 60), Material = Enum.Material.Neon })
	-- 建立牆壁與天花板
	createPart("WallBack", { Position = Vector3.new(0, 31, -120), Size = Vector3.new(40, 20, 1), Color = Color3.fromRGB(204, 191, 153), Material = Enum.Material.SmoothPlastic })
	createPart("WallFront", { Position = Vector3.new(0, 31, -80), Size = Vector3.new(40, 20, 1), Color = Color3.fromRGB(204, 191, 153), Material = Enum.Material.SmoothPlastic })
	createPart("WallLeft", { Position = Vector3.new(-20, 31, -100), Size = Vector3.new(1, 20, 40), Color = Color3.fromRGB(204, 191, 153), Material = Enum.Material.SmoothPlastic })
	createPart("WallRight", { Position = Vector3.new(20, 31, -100), Size = Vector3.new(1, 20, 40), Color = Color3.fromRGB(204, 191, 153), Material = Enum.Material.SmoothPlastic })
	createPart("Ceiling", { Position = Vector3.new(0, 41.5, -100), Size = Vector3.new(40, 1, 40), Color = Color3.fromRGB(204, 204, 204), Material = Enum.Material.Concrete })
	
	local lightPart = createPart("ClassroomLight", { Position = Vector3.new(0, 41, -100), Size = Vector3.new(4, 0.5, 8), Color = Color3.fromRGB(255, 255, 255), Material = Enum.Material.Neon })
	local light = Instance.new("PointLight"); light.Range = 30; light.Brightness = 1.5; light.Parent = lightPart

	classroom.Parent = Workspace
	
	return { model = classroom, blackboard = blackboard, padCorrect = padCorrect, padWrong = padWrong, floor = floor }
end

function GameSession:onPadTouch(hit, isCorrectPad)
	if self.answerChosen then return end
	local char = player.Character
	if char and hit:IsDescendantOf(char) then
		local pad = isCorrectPad and self.classroom.padCorrect or self.classroom.padWrong
		flashPad(pad)
		self:handleAnswer(isCorrectPad)
	end
end

function GameSession:nextQuestion()
	if self.currentRound >= self.maxRounds then
		self.onGameOverCallback()
		return
	end
	
	self.currentRound += 1
	self.ui.titleLabel.Text = "第 " .. self.currentRound .. " / " .. self.maxRounds .. " 題"
	self.answerChosen = false
	
	local data = self.wordList[self.currentRound]
	if not data then return end
	
	self.currentAnswerIsMatch = data.isCorrect
	self.ui.questionLabel.Text = data.en .. "\n=\n" .. data.displayCn .. " ?"
	
	local timeLeft = 10
	self.ui.timerLabel.Text = "剩餘時間: " .. timeLeft
	
	task.spawn(function()
		local thisRound = self.currentRound
		for i = 1, 10 do
			if self.answerChosen or self.currentRound ~= thisRound then return end
			task.wait(1)
			timeLeft -= 1
			self.ui.timerLabel.Text = "剩餘時間: " .. timeLeft
		end
		if not self.answerChosen and self.currentRound == thisRound then
			self:handleAnswer(nil)
		end
	end)
end

function GameSession:handleAnswer(playerChoice)
	if self.answerChosen then return end
	self.answerChosen = true
	
	local isWin = false
	if playerChoice == nil then
		self.ui.questionLabel.Text = "時間到！"
		self.currentStreak = 0
		soundWrong:Play()
	elseif playerChoice == self.currentAnswerIsMatch then
		self.currentStreak += 1
		self.ui.questionLabel.Text = self.currentStreak >= 3 and "答對了！ (+20 連勝!)" or "答對了！ (+10)"
		if self.currentStreak >= 3 then
			local tweenInfo = TweenInfo.new(0.2, Enum.EasingStyle.Bounce, Enum.EasingDirection.Out, 0, true)
			TweenService:Create(self.ui.questionLabel, tweenInfo, {TextSize = 80}):Play()
		end
		isWin = true
		soundCorrect:Play()
	else
		self.ui.questionLabel.Text = "答錯了！ (-10)"
		self.currentStreak = 0
		soundWrong:Play()
	end
	
	if not isWin then
		self:triggerStruggle()
	end

	self.remote:FireServer("AnswerResult", isWin)
	task.wait(1.5)
	self:nextQuestion()
end

function GameSession:triggerStruggle()
	local char = player.Character
	if not char then return end
	local hum = char:FindFirstChild("Humanoid")
	local hrp = char:FindFirstChild("HumanoidRootPart")
	
	if hrp and hum then
		soundFling:Play()
		hum.Sit = true
		hrp.AssemblyLinearVelocity = Vector3.new(math.random(-25, 25), 50, math.random(-25, 25))
		hum:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
		
		-- 恢復掙扎機制：連按空白鍵站起來
		local requiredPresses = 5
		local presses = 0

		self.ui.struggleLabel.Visible = true
		self.ui.struggleLabel.Text = "連按按鈕站起來！"
		self.ui.struggleButton.Visible = true
		
		if self.struggleConnection then self.struggleConnection:Disconnect() end
		if self.struggleButtonConnection then self.struggleButtonConnection:Disconnect() end
		
		local lastAttempt = 0
		local function attemptStandUp()
			local now = os.clock()
			if now - lastAttempt < 0.15 then return end -- 防止按住跳躍鍵瞬間完成
			lastAttempt = now

			presses += 1
			
			-- 文字震動效果
			self.ui.struggleLabel.Position = UDim2.new(0.5, -200 + math.random(-5, 5), 0.65, math.random(-5, 5))
			
			if presses >= requiredPresses then
				if self.struggleConnection then self.struggleConnection:Disconnect() end
				if self.struggleButtonConnection then self.struggleButtonConnection:Disconnect() end
				self.struggleConnection = nil
				self.struggleButtonConnection = nil
				
				if hum and hum.Parent then
					hum:SetStateEnabled(Enum.HumanoidStateType.Jumping, true) -- 恢復跳躍能力
					hum.Sit = false -- 站起來
				end
				self.ui.struggleLabel.Visible = false
				self.ui.struggleButton.Visible = false
				self.ui.struggleLabel.Position = UDim2.new(0.5, -200, 0.65, 0) -- 重置位置
			end
		end
		
		-- 改用 JumpRequest，這樣手機的跳躍按鈕也能觸發掙扎
		self.struggleConnection = UserInputService.JumpRequest:Connect(attemptStandUp)
		self.struggleButtonConnection = self.ui.struggleButton.MouseButton1Click:Connect(attemptStandUp)
	end
end

return GameSession