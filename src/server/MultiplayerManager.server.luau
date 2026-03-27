local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local RunService = game:GetService("RunService")
local WordService = require(script.Parent:WaitForChild("WordService"))

-- 等待 MapSetup 完成
print(">>> [SERVER] 等待 MapSetup 完成...")
local maxWait = 10
local waited = 0
while not ServerScriptService:GetAttribute("MapSetupComplete") and waited < maxWait do
	task.wait(1)
	waited += 1
	print(">>> [SERVER] 等待中... (" .. waited .. "/" .. maxWait .. ")")
end

if not ServerScriptService:GetAttribute("MapSetupComplete") then
	warn(">>> [SERVER] 警告: MapSetup 未完成，但繼續執行...")
end

print(">>> [SERVER] MapSetup 已完成，開始初始化...")

-- 確保 Shared 資料夾存在
local Shared = ReplicatedStorage:FindFirstChild("Shared")
if not Shared then
	Shared = Instance.new("Folder")
	Shared.Name = "Shared"
	Shared.Parent = ReplicatedStorage
	warn(">>> [SERVER] 警告: Shared 資料夾不存在，已創建")
end

-- 載入日誌系統
local GameLogger
local logger = nil
local function initLogger()
	local success, err = pcall(function()
		GameLogger = require(Shared:WaitForChild("GameLogger"))
	end)
	if success and GameLogger then
		logger = GameLogger.new("MultiplayerManager")
		logger:info("=== 日誌系統初始化成功 ===")
		logger:info("Session ID: " .. GameLogger.getSessionId())
	else
		warn(">>> [SERVER] 無法載入 GameLogger: " .. tostring(err))
		-- 創建一個簡單的 logger 後備
		logger = {
			info = function(self, msg) print("[INFO] " .. msg) end,
			warn = function(self, msg) warn("[WARN] " .. msg) end,
			error = function(self, msg) warn("[ERROR] " .. msg) end,
			debug = function(self, msg) print("[DEBUG] " .. msg) end,
			logAction = function(self, action, details) print("[ACTION] " .. action .. " | " .. details) end
		}
	end
end
initLogger()

-- Singleton Check: 防止腳本重複執行
if ServerScriptService:GetAttribute("MultiplayerManagerRunning") then
	logger:warn("MultiplayerManager 已經在運行中，停止此副本。")
	return
end
ServerScriptService:SetAttribute("MultiplayerManagerRunning", true)

logger:info("========================================")
logger:info("MultiplayerManager 正在啟動...")
logger:info("========================================")

-- 狀態變數
local lobbyPlayers = {}
local isGameRunning = false
local countdownActive = false
local startingGame = false -- New flag to prevent double start
local currentClassroom = nil
local currentTeacher = nil

-- 遊戲邏輯變數
local currentWordData = nil
local questionLabels = {} -- 儲存所有黑板的 TextLabel
local gameLoopActive = false

-- 設定
local MIN_PLAYERS = 1 -- 測試用設為 1，正式可改為 2
local INTERMISSION_TIME = 3 -- 縮短倒數時間

-- 老師動畫 ID (可以使用 Roblox 提供的動畫或自行上傳)
local TEACHER_ANIMS = {
	Angry = "rbxassetid://507770453", -- 、生氣動畫
	Happy = "rbxassetid://507770240", -- 開心/勝利動畫
	Idle = "rbxassetid://507765644", -- 待機動畫
	Walk = "rbxassetid://507777826", -- 走路動畫
}

-- 新增：單字級別與難度設定
local currentWordLevel = 1000 -- 預設 Level 1000
local currentDifficulty = nil -- nil 代表不限制難度

-- 參照
-- 尋找所有等級區域 (使用 WaitForChild 確保區域已創建)
local levelZones = {}
local function findLevelZones()
	logger:info("開始搜尋等級區域...")
	
	for i = 1000, 5000, 1000 do
		local zoneName = "LevelZone_" .. i
		-- 使用 WaitForChild 等待區域創建，最多等 10 秒
		logger:info("嘗試尋找區域: " .. zoneName)
		
		local zone = Workspace:FindFirstChild(zoneName)
		if zone then
			table.insert(levelZones, zone)
			logger:info("✅ 找到區域: " .. zoneName .. " | WordLevel=" .. tostring(zone:GetAttribute("WordLevel")))
		else
			logger:warn("❌ 找不到區域: " .. zoneName)
		end
	end
	
	logger:info("搜尋完成！找到 " .. #levelZones .. " 個等級區域")
end

-- 嘗試尋找等級區域，如果找不到則創建它們
logger:info("啟動任務來搜尋等級區域...")
task.spawn(function()
	findLevelZones()
end)

local multiplayerZone = nil
-- 嘗試找舊的多人區域
task.spawn(function()
	multiplayerZone = Workspace:FindFirstChild("MultiplayerZone")
	if multiplayerZone then
		logger:info("✅ 找到舊的多人區域: MultiplayerZone")
	else
		logger:warn("❌ 沒有找到舊的多人區域")
	end
end)

-- 建立倒數 RemoteEvent (如果不存在)
local countdownRemote = ReplicatedStorage:FindFirstChild("GameRemote")
if not countdownRemote then
	countdownRemote = Instance.new("RemoteEvent")
	countdownRemote.Name = "GameRemote"
	countdownRemote.Parent = ReplicatedStorage
	logger:warn("GameRemote 不存在，已創建")
else
	logger:info("GameRemote 已存在")
end

-- 載入 QuestionData
local QuestionData
local success, err = pcall(function()
	QuestionData = require(Shared:WaitForChild("QuestionData"))
end)

if not success or not QuestionData then
	warn(">>> [SERVER] 無法載入 QuestionData，使用 WordService 作為後備:", err)
	QuestionData = nil
else
	logger:info("QuestionData 載入成功！")
end

-- 輔助函數：建立零件
local function createPart(name, props, parent)
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	for k, v in pairs(props) do
		part[k] = v
	end
	part.Parent = parent
	return part
end

-- 輔助函數：建立文字 UI
local function createSurfaceUI(part, face, text, textSize, color)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.PixelsPerStud = 20
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.Parent = part
	
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = color or Color3.new(1, 1, 1)
	label.TextScaled = false
	label.TextSize = textSize or 60
	label.Font = Enum.Font.GothamBlack
	label.TextWrapped = true
	label.Parent = gui
	return label
end

-- 取得題目 (使用 QuestionData)
local function getNewQuestion()
	-- 優先使用 QuestionData
	if QuestionData then
		local q = QuestionData.GetRandomQuestion(currentDifficulty, currentWordLevel)
		return {
			en = q.Word,
			displayCn = q.Definition,
			isCorrect = q.IsCorrect,
			difficulty = q.Difficulty,
			level = q.Level
		}
	end
	
	-- 後備使用 WordService
	local list = WordService.generateQuestions(1)
	if list and #list > 0 then
		return list[1]
	end
	return {en = "Error", displayCn = "錯誤", isCorrect = true}
end

-- 建立伺服器端教室 (縮小版)
local function createClassroom(offset)
	local model = Instance.new("Model")
	model.Name = "MultiplayerClassroom"
	
	-- 縮小地板 (從 100x100 改為 60x60)
	local floor = createPart("Floor", {Position = offset, Size = Vector3.new(60, 2, 60), Color = Color3.fromRGB(75, 151, 75), Material = Enum.Material.Grass}, model)
	
	-- 縮小作答區 (含 UI) (從 20x20 改為 14x14)
	local padYes = createPart("PadYes", {Position = offset + Vector3.new(-15, 1.1, -15), Size = Vector3.new(14, 0.2, 14), Color = Color3.fromRGB(46, 204, 113), Material = Enum.Material.Neon}, model)
	padYes.Name = "PadYes"
	createSurfaceUI(padYes, Enum.NormalId.Top, "YES", 80)
	
	local padNo = createPart("PadNo", {Position = offset + Vector3.new(15, 1.1, -15), Size = Vector3.new(14, 0.2, 14), Color = Color3.fromRGB(231, 76, 60), Material = Enum.Material.Neon}, model)
	padNo.Name = "PadNo"
	createSurfaceUI(padNo, Enum.NormalId.Top, "NO", 80)
	
	-- 縮小牆壁 (從 100 改為 60)
	local wallBack = createPart("WallBack", {Position = offset + Vector3.new(0, 8, -30), Size = Vector3.new(60, 16, 1), Color = Color3.fromRGB(204, 191, 153)}, model)
	createPart("WallFront", {Position = offset + Vector3.new(0, 8, 30), Size = Vector3.new(60, 16, 1), Color = Color3.fromRGB(204, 191, 153)}, model)
	createPart("WallLeft", {Position = offset + Vector3.new(-30, 8, 0), Size = Vector3.new(1, 16, 60), Color = Color3.fromRGB(204, 191, 153)}, model)
	createPart("WallRight", {Position = offset + Vector3.new(30, 8, 0), Size = Vector3.new(1, 16, 60), Color = Color3.fromRGB(204, 191, 153)}, model)
	
	-- 建立四面牆的黑板與 UI (縮小)
	questionLabels = {} -- 重置列表
	local boardConfigs = {
		{pos = offset + Vector3.new(0, 12, -28), size = Vector3.new(24, 12, 1), face = Enum.NormalId.Back}, -- 後
		{pos = offset + Vector3.new(0, 12, 28), size = Vector3.new(24, 12, 1), face = Enum.NormalId.Front}, -- 前
		{pos = offset + Vector3.new(-28, 12, 0), size = Vector3.new(1, 12, 24), face = Enum.NormalId.Right}, -- 左
		{pos = offset + Vector3.new(28, 12, 0), size = Vector3.new(1, 12, 24), face = Enum.NormalId.Left}, -- 右
	}
	
	for i, cfg in ipairs(boardConfigs) do
		local board = createPart("Blackboard"..i, {Position = cfg.pos, Size = cfg.size, Color = Color3.fromRGB(27, 27, 27), Material = Enum.Material.Slate}, model)
		local label = createSurfaceUI(board, cfg.face, "等待題目...", 30, Color3.fromRGB(255, 220, 0))
		table.insert(questionLabels, label)
	end
	
	-- 天花板與燈光 (縮小)
	createPart("Ceiling", {Position = offset + Vector3.new(0, 16, 0), Size = Vector3.new(60, 1, 60), Color = Color3.fromRGB(200, 200, 200)}, model)
	local lightPart = createPart("Light", {Position = offset + Vector3.new(0, 15, 0), Size = Vector3.new(15, 1, 15), Material = Enum.Material.Neon}, model)
	local light = Instance.new("SurfaceLight")
	light.Face = Enum.NormalId.Bottom
	light.Range = 40
	light.Brightness = 2
	light.Parent = lightPart
	
	model.Parent = Workspace
	return model
end

-- 生成老師 NPC
local function spawnTeacher(position, parent)
	local teacherRig = Shared:FindFirstChild("TeacherRig")
	if not teacherRig then
		warn("TeacherRig not found in Shared!")
		return nil
	end
	
	local npc = teacherRig:Clone()
	npc.Name = "TeacherNPC"
	local humanoid = npc:WaitForChild("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = 4 -- 設定為玩家速度的 1/4 (16/4 = 4)
		
		-- 載入動畫
		local anims = {}
		for emotion, animId in pairs(TEACHER_ANIMS) do
			local anim = Instance.new("Animation")
			anim.AnimationId = animId
			anims[emotion] = humanoid:LoadAnimation(anim)
		end
		
		-- 儲存動畫到 NPC 上
		npc:SetAttribute("TeacherAnims", true)
		
		-- 儲存動畫引用
		humanoid:SetAttribute("Anims", true)
		
		-- 等待一小段時間確保動畫載入完成
		task.wait(0.1)
		
		-- 播放待機動畫
		if anims.Idle then
			anims.Idle:Play()
		end
		
		-- 儲存動畫引用到 NPC 上
		local animsFolder = Instance.new("Folder")
		animsFolder.Name = "TeacherAnims"
		animsFolder.Parent = npc
		
		for emotion, animTrack in pairs(anims) do
			local track = Instance.new("ObjectValue")
			track.Name = emotion
			track.Value = animTrack
			track.Parent = animsFolder
		end
	end
	npc:PivotTo(CFrame.new(position))
	
	-- 確保老師可以移動 (解除錨定)
	for _, part in ipairs(npc:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Anchored = false
		end
	end

	-- 老師外觀：正裝配色（藍色上衣、黑色褲子、膚色頭手）
	for _, part in ipairs(npc:GetDescendants()) do
		if part:IsA("BasePart") then
			local n = part.Name
			if n == "Head" then
				part.BrickColor = BrickColor.new("Light orange")
			elseif n == "Torso" or n == "UpperTorso" then
				part.BrickColor = BrickColor.new("Bright blue")
			elseif n:find("Arm") or n:find("Hand") then
				part.BrickColor = BrickColor.new("Light orange")
			elseif n:find("Leg") or n:find("Foot") then
				part.BrickColor = BrickColor.new("Black")
			end
		end
	end

	npc.Parent = parent
	return npc
end

-- 老師情緒動畫
local function playTeacherEmotion(teacher, emotion)
	if not teacher then return end
	
	local animsFolder = teacher:FindFirstChild("TeacherAnims")
	if not animsFolder then return end
	
	local animTrack = animsFolder:FindFirstChild(emotion)
	if not animTrack or not animTrack.Value then return end
	
	-- 停止當前動畫，播放新動畫
	local track = animTrack.Value
	
	-- 停止所有動畫
	local humanoid = teacher:FindFirstChild("Humanoid")
	if humanoid then
		for _, t in ipairs(humanoid:GetPlayingAnimationTracks()) do
			t:Stop()
		end
	end
	
	-- 播放新動畫
	track:Play()
	
	-- 如果是情緒動畫，播放後回到待機 (走路動畫持續播放)
	if emotion == "Angry" or emotion == "Happy" then
		task.delay(2, function()
			if teacher and teacher.Parent then
				local idleTrack = animsFolder:FindFirstChild("Idle")
				if idleTrack and idleTrack.Value then
					track:Stop()
					idleTrack.Value:Play()
				end
			end
		end)
	elseif emotion == "Walk" then
		-- 走路動畫會持續播放直到被其他動畫覆蓋
	end
end

-- 處理玩家跌倒與自動起身
local function handlePlayerFall(player)
	if player.Character then
		local hum = player.Character:FindFirstChild("Humanoid")
		if hum then
			hum.Sit = true
			-- 增加 PlatformStand 確保跌倒效果明顯
			hum.PlatformStand = true
			-- 3秒後自動站起
			task.delay(3, function()
				if hum then 
					hum.Sit = false 
					hum.PlatformStand = false
				end
			end)
		end
	end
end

-- 播放音效 helper
local function playSound(soundId, parent)
	local sound = Instance.new("Sound")
	sound.SoundId = soundId
	sound.Volume = 2 -- Increase volume to be clearly audible
	sound.RollOffMaxDistance = 10000 -- Ensure it's heard everywhere
	sound.Parent = parent
	sound:Play()
	game:GetService("Debris"):AddItem(sound, 2)
end

local function startGame()
	logger:info("========== startGame 被呼叫 ==========")
	logger:info("isGameRunning=" .. tostring(isGameRunning) .. " | startingGame=" .. tostring(startingGame))
	
	if isGameRunning or startingGame then 
		logger:warn("遊戲已在進行中，跳過")
		return 
	end
	
	startingGame = true
	isGameRunning = true
	
	logger:info("Lobby 人數: " .. #lobbyPlayers)
	
	-- 禁用所有等級區域的 prompt
	for _, zone in ipairs(levelZones) do
		local prompt = zone:FindFirstChild("InteractPrompt")
		if prompt then 
			prompt.Enabled = false
			logger:debug("禁用區域: " .. zone.Name)
		end
	end
	if multiplayerZone then
		local prompt = multiplayerZone:FindFirstChild("InteractPrompt")
		if prompt then 
			prompt.Enabled = false
			logger:debug("禁用區域: MultiplayerZone")
		end
	end
	
	logger:info("遊戲開始！等級: " .. currentWordLevel .. " | 人數: " .. #lobbyPlayers)
	
	-- 1. 建立地圖 (根據不同等級放在不同位置，避免重疊)
	local levelOffset = (currentWordLevel - 1000) / 1000 -- 0 for 1000, 1 for 2000, etc.
	local gameOffset = Vector3.new(
		10000 + (levelOffset * 500), -- X 軸根據等級偏移
		2000, 
		10000
	)
	currentClassroom = createClassroom(gameOffset)
	
		-- 2. 傳送玩家 (範圍縮小)
	for i, player in ipairs(lobbyPlayers) do
		if player.Character then
			-- 隨機分散傳送 (範圍從 20 改為 25)
			local spawnPos = gameOffset + Vector3.new(math.random(-25, 25), 5, math.random(-25, 25))
			player.Character:PivotTo(CFrame.new(spawnPos))
		end
	end
	
	-- 2.5 綁定地板答題事件
	local function onPadTouched(hit, isYesPad)
		if not gameLoopActive or not currentWordData then return end
		
		local char = hit.Parent
		local player = Players:GetPlayerFromCharacter(char)
		if player and table.find(lobbyPlayers, player) then
			local hum = char:FindFirstChild("Humanoid")
			if hum and hum.Health > 0 and not hum.Sit then
				-- 判斷答案
				local isCorrect = (isYesPad == currentWordData.isCorrect)
				
				if isCorrect then
					-- 答對：獲勝！
					print(">>> [SERVER] 玩家 " .. player.Name .. " 答對獲勝！")
					playSound("rbxassetid://131886985", player)
					playTeacherEmotion(currentTeacher, "Happy")
					gameLoopActive = false

					for _, lbl in ipairs(questionLabels) do lbl.Text = player.Name .. " 獲勝！" end

					-- 更新 leaderstats
					local ls = player:FindFirstChild("leaderstats")
					if ls then
						if ls:FindFirstChild("Gold") then ls.Gold.Value += 50 end
						if ls:FindFirstChild("Wins") then ls.Wins.Value += 1 end
						if ls:FindFirstChild("TotalCorrect") then ls.TotalCorrect.Value += 1 end
						if ls:FindFirstChild("TotalAnswered") then ls.TotalAnswered.Value += 1 end
					end

					-- 其他玩家跌倒
					for _, otherP in ipairs(lobbyPlayers) do
						if otherP ~= player and otherP.Character then
							handlePlayerFall(otherP)
						end
					end
				else
					-- 答錯：自己跌倒
					handlePlayerFall(player)
					playTeacherEmotion(currentTeacher, "Angry")

					local root = char:FindFirstChild("HumanoidRootPart")
					if root then root.AssemblyLinearVelocity = Vector3.new(0, 50, 0) end

					playSound("rbxassetid://130972023", player)

					-- 答錯也記錄 TotalAnswered
					local ls = player:FindFirstChild("leaderstats")
					if ls and ls:FindFirstChild("TotalAnswered") then
						ls.TotalAnswered.Value += 1
					end
				end
			end
		end
	end
	
	local padYes = currentClassroom:FindFirstChild("PadYes")
	local padNo = currentClassroom:FindFirstChild("PadNo")
	if padYes then padYes.Touched:Connect(function(hit) onPadTouched(hit, true) end) end
	if padNo then padNo.Touched:Connect(function(hit) onPadTouched(hit, false) end) end

	-- 3. 生成老師 (位置調整為 smaller classroom)
	currentTeacher = spawnTeacher(gameOffset + Vector3.new(0, 5, -25), currentClassroom)
	
	-- 4. 啟動老師 AI (追逐最近玩家 + Idle 徘徊)
	task.spawn(function()
		local humanoid = currentTeacher:WaitForChild("Humanoid")
		local root = currentTeacher:WaitForChild("HumanoidRootPart")

		local podiumPos = gameOffset + Vector3.new(0, 5, -25)
		local isChasing = false
		local CHASE_DISTANCE = 65 -- 教室 60x60，讓老師在整個教室內都能追到玩家
		local IDLE_WANDER_RANGE = 10
		local wanderTimer = 0 -- 倒數計時器，到 0 時才換下一個徘徊目標

		-- 攻擊判定
		root.Touched:Connect(function(hit)
			local char = hit.Parent
			local player = Players:GetPlayerFromCharacter(char)
			if player and table.find(lobbyPlayers, player) then
				local hum = char:FindFirstChild("Humanoid")
				local pRoot = char:FindFirstChild("HumanoidRootPart")
				if hum and pRoot and not hum.Sit then
					handlePlayerFall(player)
					playTeacherEmotion(currentTeacher, "Angry")
					local dir = (pRoot.Position - root.Position).Unit
					pRoot.AssemblyLinearVelocity = dir * 60 + Vector3.new(0, 30, 0)
				end
			end
		end)

		while isGameRunning and currentTeacher and currentTeacher.Parent do
			local target = nil
			local minDist = math.huge

			-- 尋找最近的玩家
			for _, player in ipairs(lobbyPlayers) do
				if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
					local pRoot = player.Character.HumanoidRootPart
					local dist = (pRoot.Position - root.Position).Magnitude
					if dist < minDist then
						minDist = dist
						target = pRoot
					end
				end
			end

			if target and minDist < CHASE_DISTANCE then
				-- 追逐模式
				if not isChasing then
					isChasing = true
					playTeacherEmotion(currentTeacher, "Walk")
				end
				humanoid:MoveTo(target.Position)
			else
				-- 徘徊模式（每隔 wanderTimer 換目標，不阻塞主迴圈）
				if isChasing then
					isChasing = false
					playTeacherEmotion(currentTeacher, "Idle")
					wanderTimer = 0 -- 立即換一個徘徊目標
				end
				wanderTimer -= 0.2
				if wanderTimer <= 0 then
					local wanderX = podiumPos.X + math.random(-IDLE_WANDER_RANGE, IDLE_WANDER_RANGE)
					local wanderZ = podiumPos.Z + math.random(-IDLE_WANDER_RANGE, IDLE_WANDER_RANGE)
					humanoid:MoveTo(Vector3.new(wanderX, podiumPos.Y, wanderZ))
					wanderTimer = math.random(3, 6)
				end
			end

			task.wait(0.2)
		end
	end)
	
	-- 5. 遊戲主迴圈 (出題 -> 等待 -> 結算)
	for round = 1, 10 do
		if #lobbyPlayers == 0 then break end
		
		-- 出題
		currentWordData = getNewQuestion()
		local qText = string.format("第 %d 題\n%s\n=\n%s ?", round, currentWordData.en, currentWordData.displayCn)
		for _, lbl in ipairs(questionLabels) do lbl.Text = qText end
		
		gameLoopActive = true
		
		-- 等待有人答對或時間到 (例如 10 秒)
		local waitTime = 10
		while waitTime > 0 and gameLoopActive do
			task.wait(1)
			waitTime -= 1
		end
		
		gameLoopActive = false
		task.wait(2) -- 回合間隔
	end
	
	-- 遊戲結束清理
	isGameRunning = false
	startingGame = false
	
	logger:info("========== 遊戲結束，清理中... ==========")
	
	-- 先治療所有玩家，確保他們活著
	for _, player in ipairs(lobbyPlayers) do
		if player.Character then
			local hum = player.Character:FindFirstChild("Humanoid")
			if hum then
				hum.Health = hum.MaxHealth
				hum.Sit = false
				hum.PlatformStand = false
			end
		end
	end
	
	-- 找到玩家應該回去的區域
	local targetZone = nil
	for _, zone in ipairs(levelZones) do
		if zone:GetAttribute("WordLevel") == currentWordLevel then
			targetZone = zone
			break
		end
	end
	
	-- 如果沒有找到對應的區域，嘗試找任意一個等級區域
	if not targetZone and #levelZones > 0 then
		targetZone = levelZones[1]
		logger:warn("找不到對應等級區域，使用第一個可用的區域")
	end
	
	-- 傳送所有玩家
	for _, player in ipairs(lobbyPlayers) do
		if player.Character then
			if targetZone then
				player.Character:PivotTo(targetZone.CFrame * CFrame.new(0, 5, 0))
				logger:info("玩家 " .. player.Name .. " 傳送回: " .. targetZone.Name)
			elseif multiplayerZone then
				player.Character:PivotTo(multiplayerZone.CFrame * CFrame.new(0, 5, 0))
				logger:info("玩家 " .. player.Name .. " 傳送回 MultiplayerZone")
			else
				-- 最後手段：回到大廳原點上方
				player.Character:PivotTo(CFrame.new(0, 50, 0))
				warn(">>> [SERVER] 找不到任何區域，回到原點")
			end
		end
	end
	
	-- 等待玩家傳送完成
	task.wait(1)
	
	-- 銷毀教室
	if currentClassroom then 
		currentClassroom:Destroy() 
		currentClassroom = nil
		logger:info("教室已銷毀")
	end
	
	lobbyPlayers = {} -- 清空大廳
	logger:info("Lobby 已清空")
	
	-- 重新啟用所有等級區域的 prompt
	for _, zone in ipairs(levelZones) do
		local p = zone:FindFirstChild("InteractPrompt")
		if p then 
			p.Enabled = true
			logger:debug("啟用區域: " .. zone.Name)
		end
	end
	if multiplayerZone then
		local p = multiplayerZone:FindFirstChild("InteractPrompt")
		if p then 
			p.Enabled = true
			logger:debug("啟用區域: MultiplayerZone")
		end
	end
	
	logger:info("========== 遊戲結束，大廳已重置 ==========")
end

local function startIntermission()
	if countdownActive then return end
	countdownActive = true
	
	print(">>> [SERVER] 倒數計時開始...")
	
	-- 發送倒數事件給所有大廳玩家
	for i = INTERMISSION_TIME, 1, -1 do
		-- 再次檢查人數與遊戲狀態，防止重複觸發
		if #lobbyPlayers < MIN_PLAYERS or isGameRunning then
			print(">>> [SERVER] 人數不足，倒數取消。")
			countdownActive = false
			-- 通知玩家倒數取消
			countdownRemote:FireAllClients("Countdown", 0)
			return
		end
		
		-- 發送倒數給客戶端顯示
		countdownRemote:FireAllClients("Countdown", i)
		print(">>> [SERVER] 多人遊戲即將開始: " .. i)
		task.wait(1)
	end
	
	if not isGameRunning and not startingGame and #lobbyPlayers >= MIN_PLAYERS then
		countdownActive = false
		-- 發送遊戲開始訊號
		countdownRemote:FireAllClients("Countdown", -1) -- -1 表示開始
		startGame()
	end
end

local function onPromptTriggered(player, selectedLevel: number?)
	logger:info("========== onPromptTriggered 被呼叫 ==========")
	logger:info("玩家: " .. tostring(player) .. " | 選擇等級: " .. tostring(selectedLevel))
	
	-- 如果有指定等級，使用該等級
	if selectedLevel then
		currentWordLevel = selectedLevel
		logger:info("設定 currentWordLevel = " .. tostring(selectedLevel))
	end
	
	logger:info("isGameRunning = " .. tostring(isGameRunning) .. " | startingGame = " .. tostring(startingGame))
	
	if isGameRunning or startingGame then 
		logger:warn("遊戲正在進行中，拒絕加入")
		return 
	end
	
	-- 避免重複加入
	if table.find(lobbyPlayers, player) then 
		logger:warn("玩家已在 Lobby 中: " .. player.Name)
		return 
	end
	
	table.insert(lobbyPlayers, player)
	logger:info("玩家加入 Lobby: " .. player.Name .. " | 等級: " .. tostring(currentWordLevel) .. " | 人數: " .. #lobbyPlayers .. "/" .. MIN_PLAYERS)
	
	-- 將玩家傳送到等待區 (區域上方)，作為視覺回饋
	if player.Character then
		-- 找到觸發的區域位置
		local triggerZone = nil
		for _, zone in ipairs(levelZones) do
			if zone:GetAttribute("WordLevel") == currentWordLevel then
				triggerZone = zone
				break
			end
		end
		
		if triggerZone then
			logger:info("傳送到區域: " .. triggerZone.Name)
			player.Character:PivotTo(triggerZone.CFrame * CFrame.new(0, 3, 0))
		elseif multiplayerZone then
			logger:info("傳送到舊多人區域")
			player.Character:PivotTo(multiplayerZone.CFrame * CFrame.new(0, 3, 0))
		else
			logger:warn("找不到任何區域來傳送玩家！")
		end
	else
		logger:warn("玩家沒有 Character，無法傳送")
	end
	
	-- 嘗試開始倒數
	logger:info("檢查是否開始倒數: #lobbyPlayers=" .. #lobbyPlayers .. " | countdownActive=" .. tostring(countdownActive))
	
	if #lobbyPlayers >= MIN_PLAYERS and not countdownActive then
		logger:info("✅ 條件滿足，開始倒數！")
		startIntermission()
	else
		logger:info("等待更多玩家... 需要 " .. MIN_PLAYERS .. " 人，目前 " .. #lobbyPlayers .. " 人")
	end
	
	logger:info("========== onPromptTriggered 結束 ==========")
end

local function onPlayerRemoving(player)
	local idx = table.find(lobbyPlayers, player)
	if idx then
		table.remove(lobbyPlayers, idx)
		print(">>> [SERVER] " .. player.Name .. " 離開了大廳。")
	end
end

-- 綁定所有等級區域的觸發事件
local function bindZonePrompts()
	logger:info("========== 開始綁定區域 ==========")
	
	-- 等待區域準備好 (最多等 15 秒)
	logger:info("等待等級區域創建... (最多等 15 秒)")
	
	local maxWait = 15
	local waited = 0
	while #levelZones < 5 and waited < maxWait do
		task.wait(1)
		waited += 1
		logger:debug("第 " .. waited .. " 秒檢查: 已找到 " .. #levelZones .. " 個區域")
		
		-- 嘗試再次尋找
		for i = 1000, 5000, 1000 do
			local zoneName = "LevelZone_" .. i
			local exists = false
			for _, z in ipairs(levelZones) do
				if z.Name == zoneName then
					exists = true
					break
				end
			end
			if not exists then
				local zone = Workspace:FindFirstChild(zoneName)
				if zone then
					table.insert(levelZones, zone)
					logger:info("✅ [延遲找到] 區域: " .. zoneName .. " | WordLevel=" .. tostring(zone:GetAttribute("WordLevel")))
				end
			end
		end
	end
	
	logger:info("========== 綁定結果 ==========")
	logger:info("最終找到 " .. #levelZones .. " 個等級區域")
	
	-- 列出所有找到的區域
	for idx, zone in ipairs(levelZones) do
		local level = zone:GetAttribute("WordLevel") or "nil"
		local prompt = zone:FindFirstChild("InteractPrompt")
		local hasPrompt = prompt ~= nil
		logger:info("  [" .. idx .. "] " .. zone.Name .. " | Level=" .. tostring(level) .. " | HasPrompt=" .. tostring(hasPrompt))
	end
	
	-- 綁定新的等級區域
	logger:info("開始綁定 Prompt 事件...")
	
	if #levelZones == 0 then
		logger:error("❌ 沒有找到任何等級區域！請檢查 MapSetup.server.luau 是否正確執行")
	end
	
	for _, zone in ipairs(levelZones) do
		local prompt = zone:FindFirstChild("InteractPrompt")
		if prompt then
			local level = zone:GetAttribute("WordLevel") or 1000
			logger:info("  → 嘗試綁定: " .. zone.Name .. " (Level " .. level .. ")")
			
			prompt.Triggered:Connect(function(player)
				logger:logAction("ZONE_TRIGGERED", player.Name .. " triggered " .. zone.Name .. " (Level " .. level .. ")")
				onPromptTriggered(player, level)
			end)
			logger:info("  ✅ 綁定成功: " .. zone.Name)
		else
			logger:warn("  ❌ 找不到 InteractPrompt: " .. zone.Name)
		end
	end
	
	-- 如果有舊的多人區域，也綁定
	if multiplayerZone then
		logger:info("→ 嘗試綁定舊的多人區域: MultiplayerZone")
		local prompt = multiplayerZone:FindFirstChild("InteractPrompt")
		if prompt then
			prompt.Triggered:Connect(function(player)
				logger:logAction("ZONE_TRIGGERED", player.Name .. " triggered MultiplayerZone")
				onPromptTriggered(player, currentWordLevel)
			end)
			logger:info("  ✅ 綁定成功: MultiplayerZone")
		else
			logger:warn("  ❌ 找不到 InteractPrompt: MultiplayerZone")
		end
	else
		logger:warn("沒有舊的多人區域需要綁定 (這是正常的)")
	end
	
	-- DevTest hook（BindableEvent，fire-and-forget 非阻塞）
	local devTrigger = Instance.new("BindableEvent")
	devTrigger.Name = "DevTriggerGame"
	devTrigger.Event:Connect(function(player, level) task.spawn(onPromptTriggered, player, level) end)
	devTrigger.Parent = ServerScriptService
	logger:info("✅ DevTriggerGame BindableEvent 已建立")

	logger:info("========== 綁定完成 ==========")
end

bindZonePrompts()

Players.PlayerRemoving:Connect(function(player)
	local idx = table.find(lobbyPlayers, player)
	if idx then
		table.remove(lobbyPlayers, idx)
		logger:info("玩家離開 Lobby: " .. player.Name .. " | 剩餘人數: " .. #lobbyPlayers)
	end
end)

-- 處理玩家選擇單字級別
countdownRemote.OnServerEvent:Connect(function(player, action, data)
	logger:debug("收到 RemoteEvent: " .. action .. " | " .. tostring(data))
	
	if action == "SetWordLevel" then
		local level = tonumber(data)
		if level and (level == 1000 or level == 2000 or level == 3000 or level == 4000 or level == 5000) then
			currentWordLevel = level
			logger:info("玩家設定等級: " .. player.Name .. " → Level " .. level)
		end
	elseif action == "SetDifficulty" then
		local diff = tonumber(data)
		if diff == nil or diff == 1 or diff == 2 or diff == 3 then
			currentDifficulty = diff
			local diffName = diff == 1 and "Easy" or diff == 2 and "Medium" or diff == 3 and "Hard" or "全部"
			logger:info("玩家設定難度: " .. player.Name .. " → " .. diffName)
		end
	end
end)

logger:info("========================================")
logger:info("✅ MultiplayerManager 啟動完成！")
logger:info("等待玩家進入各等級區域...")
logger:info("========================================")