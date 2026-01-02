local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

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

	-- NPC 相關
	self.teacherNPC = nil
	self.aiConnection = nil
	self.teacherTouchConnection = nil

	-- 建立場景
	self.roomOffset = Vector3.new(math.random(-100000, 100000), 500, math.random(-100000, 100000))
	self.classroom = self:_createLocalClassroom(self.roomOffset)
	self.ui.surfaceGui.Parent = self.classroom.blackboard

	-- 初始化 UI 列表，並為主黑板加上除錯編號
	self.titleLabels = {self.ui.titleLabel}
	self.questionLabels = {self.ui.questionLabel}
	self.timerLabels = {self.ui.timerLabel}

	-- 複製 UI 到其他牆面的黑板
	local function setupExtraBoard(part, face)
		local clone = self.ui.surfaceGui:Clone()
		if face then clone.Face = face end
		clone.Parent = part
		
		local t = clone:WaitForChild("TitleLabel", 5)
		local q = clone:WaitForChild("QuestionLabel", 5)
		local tm = clone:WaitForChild("TimerLabel", 5)
		
		if t then table.insert(self.titleLabels, t) end
		if q then table.insert(self.questionLabels, q) end
		if tm then table.insert(self.timerLabels, tm) end
	end

	if self.classroom.blackboardFront then setupExtraBoard(self.classroom.blackboardFront, Enum.NormalId.Front) end
	if self.classroom.blackboardLeft then setupExtraBoard(self.classroom.blackboardLeft, Enum.NormalId.Right) end
	if self.classroom.blackboardRight then setupExtraBoard(self.classroom.blackboardRight, Enum.NormalId.Left) end

	-- 建立老師 NPC
	self.teacherNPC = self:_createTeacherNPC(self.roomOffset)

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
	
	-- 異步獲取題目，防止阻塞
	task.spawn(function()
		self.wordList = self.getWordListFunc:InvokeServer()
		self:nextQuestion()
	end)

	-- 啟動老師 AI (可以立即啟動，不需要等待題目)
	self.aiConnection = RunService.Heartbeat:Connect(function()
		local playerChar = player.Character
		local teacherHumanoid = self.teacherNPC and self.teacherNPC:FindFirstChildOfClass("Humanoid")

		if not playerChar or not teacherHumanoid or teacherHumanoid.Health <= 0 then
			return
		end
		
		local playerRoot = playerChar.PrimaryPart
		local playerPos = playerRoot.Position
		
		-- 使用 Move 代替 MoveTo 以獲得更平滑的追逐效果
		local npcRoot = self.teacherNPC.PrimaryPart
		local direction = (playerPos - npcRoot.Position).Unit
		teacherHumanoid:Move(direction)
	end)

	-- 老師速度變化
	task.spawn(function()
		local teacherHumanoid = self.teacherNPC and self.teacherNPC:FindFirstChildOfClass("Humanoid")
		if not teacherHumanoid then return end

		while self.teacherNPC and self.teacherNPC.Parent do
			local newSpeed = math.random(8, 16) -- 玩家速度的 1/2 到 1 倍 (8-16)
			teacherHumanoid.WalkSpeed = newSpeed
			task.wait(math.random(2, 4)) -- 每 2-4 秒變換一次速度
		end
	end)
end

function GameSession:Destroy()
	logger:debug("Session:Destroy() called")
	if self.padCorrectConnection then self.padCorrectConnection:Disconnect() end
	if self.padWrongConnection then self.padWrongConnection:Disconnect() end
	if self.struggleConnection then self.struggleConnection:Disconnect() end
	if self.struggleButtonConnection then self.struggleButtonConnection:Disconnect() end
	if self.aiConnection then self.aiConnection:Disconnect() end
	if self.teacherTouchConnection then self.teacherTouchConnection:Disconnect() end

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
			elseif k == "CFrame" then
				part[k] = v + offset
			else
				part[k] = v
			end
		end
		part.Parent = classroom
		return part
	end

	-- 建立地板
	local floor = createPart("Floor", { Position = Vector3.new(0, 20, -100), Size = Vector3.new(100, 2, 100), Color = Color3.fromRGB(75, 151, 75), Material = Enum.Material.Grass })
	-- 建立黑板
	local blackboard = createPart("Blackboard", { Position = Vector3.new(0, 28.5, -148), Size = Vector3.new(32, 16, 1), Color = Color3.fromRGB(27, 27, 27), Material = Enum.Material.Slate })
	-- 建立其他牆面的黑板 (旋轉以面向房間中心)
	local blackboardFront = createPart("BlackboardFront", { Position = Vector3.new(0, 28.5, -52), Size = Vector3.new(32, 16, 1), Color = Color3.fromRGB(27, 27, 27), Material = Enum.Material.Slate })
	local blackboardLeft = createPart("BlackboardLeft", { Position = Vector3.new(-48, 28.5, -100), Size = Vector3.new(1, 16, 32), Color = Color3.fromRGB(27, 27, 27), Material = Enum.Material.Slate })
	local blackboardRight = createPart("BlackboardRight", { Position = Vector3.new(48, 28.5, -100), Size = Vector3.new(1, 16, 32), Color = Color3.fromRGB(27, 27, 27), Material = Enum.Material.Slate })

	-- 建立作答區
	local padCorrect = createPart("AnswerPadCorrect", { Position = Vector3.new(-25, 21.1, -80), Size = Vector3.new(20, 0.2, 20), Color = Color3.fromRGB(46, 204, 113), Material = Enum.Material.Neon })
	local padWrong = createPart("AnswerPadWrong", { Position = Vector3.new(25, 21.1, -80), Size = Vector3.new(20, 0.2, 20), Color = Color3.fromRGB(231, 76, 60), Material = Enum.Material.Neon })
	-- 建立牆壁與天花板
	createPart("WallBack", { Position = Vector3.new(0, 31, -150), Size = Vector3.new(100, 20, 1), Color = Color3.fromRGB(204, 191, 153), Material = Enum.Material.SmoothPlastic })
	createPart("WallFront", { Position = Vector3.new(0, 31, -50), Size = Vector3.new(100, 20, 1), Color = Color3.fromRGB(204, 191, 153), Material = Enum.Material.SmoothPlastic })
	createPart("WallLeft", { Position = Vector3.new(-50, 31, -100), Size = Vector3.new(1, 20, 100), Color = Color3.fromRGB(204, 191, 153), Material = Enum.Material.SmoothPlastic })
	createPart("WallRight", { Position = Vector3.new(50, 31, -100), Size = Vector3.new(1, 20, 100), Color = Color3.fromRGB(204, 191, 153), Material = Enum.Material.SmoothPlastic })
	createPart("Ceiling", { Position = Vector3.new(0, 41.5, -100), Size = Vector3.new(100, 1, 100), Color = Color3.fromRGB(204, 204, 204), Material = Enum.Material.Concrete })
	
	-- 改用 SurfaceLight 提供均勻照明
	local ceilingLightPart = createPart("CeilingLight", { Position = Vector3.new(0, 41, -100), Size = Vector3.new(20, 0.5, 20), Color = Color3.fromRGB(255, 255, 255), Material = Enum.Material.Neon })
	local surfaceLight = Instance.new("SurfaceLight")
	surfaceLight.Face = Enum.NormalId.Bottom
	surfaceLight.Range = 60 -- 足夠照到地板
	surfaceLight.Brightness = 2
	surfaceLight.Angle = 180 -- 廣角照明
	surfaceLight.Parent = ceilingLightPart

	-- 新增地板文字 (Yes/No)
	local function addLabel(part, text)
		local sg = Instance.new("SurfaceGui")
		sg.Face = Enum.NormalId.Top
		sg.PixelsPerStud = 20
		sg.Parent = part
		local tl = Instance.new("TextLabel")
		tl.Size = UDim2.new(1, 0, 1, 0)
		tl.BackgroundTransparency = 1
		tl.Text = text
		tl.TextColor3 = Color3.new(1, 1, 1)
		tl.TextScaled = true
		tl.Font = Enum.Font.GothamBlack
		tl.Parent = sg
	end
	addLabel(padCorrect, "YES")
	addLabel(padWrong, "NO")

	classroom.Parent = Workspace
	
	return { 
		model = classroom, 
		blackboard = blackboard, 
		blackboardFront = blackboardFront,
		blackboardLeft = blackboardLeft,
		blackboardRight = blackboardRight,
		padCorrect = padCorrect, 
		padWrong = padWrong, 
		floor = floor 
	}
end

function GameSession:_createTeacherNPC(offset)
	local teacherRig = Shared:FindFirstChild("TeacherRig")
	local npc

	if teacherRig then
		npc = teacherRig:Clone()
		npc.Name = "Teacher"
		
		-- 確保所有部件都未錨定，以便 Humanoid 控制
		for _, part in ipairs(npc:GetDescendants()) do
			if part:IsA("BasePart") then
				part.Anchored = false
			end
		end
		
		npc:SetPrimaryPartCFrame(CFrame.new(offset + Vector3.new(0, 25, -60)))
	else
		logger:warn("找不到 'TeacherRig'，使用預設方塊人作為替代。")
		-- Fallback: 建立簡單的方塊人
		npc = Instance.new("Model")
		npc.Name = "Teacher"
		
		local humanoid = Instance.new("Humanoid")
		humanoid.Parent = npc
		
		local hrp = Instance.new("Part")
		hrp.Name = "HumanoidRootPart"
		hrp.Size = Vector3.new(4, 4, 2)
		hrp.Transparency = 1
		hrp.Parent = npc
		npc.PrimaryPart = hrp
		
		local torso = Instance.new("Part")
		torso.Name = "Torso"
		torso.Size = Vector3.new(4, 4, 2)
		torso.CanCollide = false
		torso.Color = Color3.fromRGB(50, 50, 50)
		torso.Parent = npc
		
		local head = Instance.new("Part")
		head.Name = "Head"
		head.Size = Vector3.new(2.5, 2.5, 2.5)
		head.Shape = Enum.PartType.Ball
		head.CanCollide = false
		head.Color = Color3.fromRGB(200, 200, 200)
		head.Parent = npc
		
		-- 設定位置與焊接
		npc:SetPrimaryPartCFrame(CFrame.new(offset + Vector3.new(0, 25, -60)))
		torso.CFrame = hrp.CFrame
		head.CFrame = torso.CFrame * CFrame.new(0, 3.5, 0)
		
		local torsoWeld = Instance.new("WeldConstraint", hrp); torsoWeld.Part0 = hrp; torsoWeld.Part1 = torso
		local headWeld = Instance.new("WeldConstraint", torso); headWeld.Part0 = torso; headWeld.Part1 = head
	end

	local humanoid = npc:FindFirstChild("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = 8 -- 初始速度
		humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOn
	end

	local hrp = npc.PrimaryPart
	if not hrp then
		logger:warn("TeacherRig 模型缺少 PrimaryPart (應為 HumanoidRootPart)！")
		if npc then npc:Destroy() end
		return nil
	end

	logger:debug("Teacher NPC created at: " .. tostring(hrp.Position))
	npc.Parent = self.classroom.model

	-- 綁定觸碰事件 (傷害與擊飛)
	local debounce = false
	self.teacherTouchConnection = hrp.Touched:Connect(function(hit)
		if debounce then return end
		
		local char = player.Character
		if char and hit:IsDescendantOf(char) then
			local hum = char:FindFirstChild("Humanoid")
			local root = char:FindFirstChild("HumanoidRootPart")
			
			if hum and root then
				-- Debug Log: 印出碰撞時的位置資訊
				local dist = (root.Position - hrp.Position).Magnitude
				logger:debug(string.format("Teacher Hit! PlayerPos: %.1f, %.1f, %.1f | TeacherPos: %.1f, %.1f, %.1f | Dist: %.2f", root.Position.X, root.Position.Y, root.Position.Z, hrp.Position.X, hrp.Position.Y, hrp.Position.Z, dist))

				debounce = true
				
				-- 1. 擊飛效果：計算從老師指向玩家的方向
				local pushDirection = (root.Position - hrp.Position).Unit
				-- 加上一點向上的力，讓玩家飛起來
				local velocity = (pushDirection * 50) + Vector3.new(0, 30, 0)
				root.AssemblyLinearVelocity = velocity
				
				-- 2. 觸發跌倒與掙扎機制
				self:triggerStruggle()
				
				task.wait(1.5) -- 冷卻時間
				debounce = false
			end
		end
	end)

	return npc
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
	local titleText = "第 " .. self.currentRound .. " / " .. self.maxRounds .. " 題"
	for _, label in ipairs(self.titleLabels) do label.Text = titleText end
	
	self.answerChosen = false
	
	local data = self.wordList[self.currentRound]
	if not data then return end
	
	self.currentAnswerIsMatch = data.isCorrect
	local qText = data.en .. "\n=\n" .. data.displayCn .. " ?"
	for _, label in ipairs(self.questionLabels) do label.Text = qText end
	
	local timeLeft = 10
	for _, label in ipairs(self.timerLabels) do label.Text = "剩餘時間: " .. timeLeft end
	
	task.spawn(function()
		local thisRound = self.currentRound
		for i = 1, 10 do
			if self.answerChosen or self.currentRound ~= thisRound then return end
			task.wait(1)
			timeLeft -= 1
			for _, label in ipairs(self.timerLabels) do label.Text = "剩餘時間: " .. timeLeft end
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
		for _, label in ipairs(self.questionLabels) do label.Text = "時間到！" end
		self.currentStreak = 0
		soundWrong:Play()
	elseif playerChoice == self.currentAnswerIsMatch then
		self.currentStreak += 1
		local winText = self.currentStreak >= 3 and "答對了！ (+20 連勝!)" or "答對了！ (+10)"
		for _, label in ipairs(self.questionLabels) do label.Text = winText end
		
		if self.currentStreak >= 3 then
			local tweenInfo = TweenInfo.new(0.2, Enum.EasingStyle.Bounce, Enum.EasingDirection.Out, 0, true)
			local largeSize = self.ui.questionLabel.TextSize * 1.2 -- 動態計算放大尺寸
			for _, label in ipairs(self.questionLabels) do
				TweenService:Create(label, tweenInfo, {TextSize = largeSize}):Play()
			end
		end
		isWin = true
		soundCorrect:Play()
	else
		for _, label in ipairs(self.questionLabels) do label.Text = "答錯了！ (-10)" end
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