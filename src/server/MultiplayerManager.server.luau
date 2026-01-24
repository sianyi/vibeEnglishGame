local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local RunService = game:GetService("RunService")
local WordService = require(script.Parent:WaitForChild("WordService"))

-- Singleton Check: 防止腳本重複執行
if ServerScriptService:GetAttribute("MultiplayerManagerRunning") then
	warn(">>> [SERVER] MultiplayerManager 已經在運行中，停止此副本。")
	return
end
ServerScriptService:SetAttribute("MultiplayerManagerRunning", true)

print(">>> [SERVER] MultiplayerManager 正在啟動...")

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

-- 參照
local multiplayerZone = Workspace:WaitForChild("MultiplayerZone", 30)
if not multiplayerZone then
	warn(">>> [SERVER] 錯誤: 找不到 MultiplayerZone！請檢查 MapSetup 是否正確執行。")
	return
end

local prompt = multiplayerZone:WaitForChild("InteractPrompt", 10)
if not prompt then
	warn(">>> [SERVER] 錯誤: 找不到 InteractPrompt！")
	return
end

print(">>> [SERVER] MultiplayerManager 資源載入完成")

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

-- 取得題目 (直接呼叫 WordService)
local function getNewQuestion()
	local list = WordService.generateQuestions(1)
	if list and #list > 0 then
		return list[1]
	end
	return {en = "Error", displayCn = "錯誤", isCorrect = true}
end

-- 建立伺服器端教室
local function createClassroom(offset)
	local model = Instance.new("Model")
	model.Name = "MultiplayerClassroom"
	
	-- 地板
	local floor = createPart("Floor", {Position = offset, Size = Vector3.new(100, 2, 100), Color = Color3.fromRGB(75, 151, 75), Material = Enum.Material.Grass}, model)
	
	-- 作答區 (含 UI)
	local padYes = createPart("PadYes", {Position = offset + Vector3.new(-25, 1.1, -20), Size = Vector3.new(20, 0.2, 20), Color = Color3.fromRGB(46, 204, 113), Material = Enum.Material.Neon}, model)
	padYes.Name = "PadYes" -- 確保名稱正確以便識別
	createSurfaceUI(padYes, Enum.NormalId.Top, "YES", 100)
	
	local padNo = createPart("PadNo", {Position = offset + Vector3.new(25, 1.1, -20), Size = Vector3.new(20, 0.2, 20), Color = Color3.fromRGB(231, 76, 60), Material = Enum.Material.Neon}, model)
	padNo.Name = "PadNo"
	createSurfaceUI(padNo, Enum.NormalId.Top, "NO", 100)
	
	-- 牆壁
	local wallBack = createPart("WallBack", {Position = offset + Vector3.new(0, 11, -50), Size = Vector3.new(100, 20, 1), Color = Color3.fromRGB(204, 191, 153)}, model)
	createPart("WallFront", {Position = offset + Vector3.new(0, 11, 50), Size = Vector3.new(100, 20, 1), Color = Color3.fromRGB(204, 191, 153)}, model)
	createPart("WallLeft", {Position = offset + Vector3.new(-50, 11, 0), Size = Vector3.new(1, 20, 100), Color = Color3.fromRGB(204, 191, 153)}, model)
	createPart("WallRight", {Position = offset + Vector3.new(50, 11, 0), Size = Vector3.new(1, 20, 100), Color = Color3.fromRGB(204, 191, 153)}, model)
	
	-- 建立四面牆的黑板與 UI
	questionLabels = {} -- 重置列表
	local boardConfigs = {
		{pos = offset + Vector3.new(0, 15, -48), size = Vector3.new(32, 16, 1), face = Enum.NormalId.Back}, -- 後
		{pos = offset + Vector3.new(0, 15, 48), size = Vector3.new(32, 16, 1), face = Enum.NormalId.Front}, -- 前
		{pos = offset + Vector3.new(-48, 15, 0), size = Vector3.new(1, 16, 32), face = Enum.NormalId.Right}, -- 左
		{pos = offset + Vector3.new(48, 15, 0), size = Vector3.new(1, 16, 32), face = Enum.NormalId.Left}, -- 右
	}
	
	for i, cfg in ipairs(boardConfigs) do
		local board = createPart("Blackboard"..i, {Position = cfg.pos, Size = cfg.size, Color = Color3.fromRGB(27, 27, 27), Material = Enum.Material.Slate}, model)
		local label = createSurfaceUI(board, cfg.face, "等待題目...", 40, Color3.fromRGB(255, 220, 0))
		table.insert(questionLabels, label)
	end
	
	-- 天花板與燈光
	createPart("Ceiling", {Position = offset + Vector3.new(0, 21, 0), Size = Vector3.new(100, 1, 100), Color = Color3.fromRGB(200, 200, 200)}, model)
	local lightPart = createPart("Light", {Position = offset + Vector3.new(0, 20, 0), Size = Vector3.new(20, 1, 20), Material = Enum.Material.Neon}, model)
	local light = Instance.new("SurfaceLight")
	light.Face = Enum.NormalId.Bottom
	light.Range = 60
	light.Brightness = 2
	light.Parent = lightPart
	
	model.Parent = Workspace
	return model
end

-- 生成老師 NPC
local function spawnTeacher(position, parent)
	local teacherRig = ReplicatedStorage.Shared:FindFirstChild("TeacherRig")
	if not teacherRig then
		warn("TeacherRig not found in Shared!")
		return nil
	end
	
	local npc = teacherRig:Clone()
	npc.Name = "TeacherNPC"
	local humanoid = npc:WaitForChild("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = 4 -- 設定為玩家速度的 1/4 (16/4 = 4)
	end
	npc:PivotTo(CFrame.new(position))
	
	-- 確保老師可以移動 (解除錨定)
	for _, part in ipairs(npc:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Anchored = false
		end
	end
	
	npc.Parent = parent
	return npc
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
	if isGameRunning or startingGame then return end -- 防止重複執行
	startingGame = true
	isGameRunning = true
	prompt.Enabled = false -- 遊戲中禁止加入
	
	print(">>> [SERVER] 多人遊戲開始！玩家人數:", #lobbyPlayers)
	
	-- 1. 建立地圖 (位置設在遠處，避免與大廳重疊)
	local gameOffset = Vector3.new(10000, 2000, 10000) -- 移得更遠，避免干擾單人房 UI
	currentClassroom = createClassroom(gameOffset)
	
	-- 2. 傳送玩家
	for i, player in ipairs(lobbyPlayers) do
		if player.Character then
			-- 隨機分散傳送
			local spawnPos = gameOffset + Vector3.new(math.random(-20, 20), 5, math.random(-20, 20))
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
					playSound("rbxassetid://131886985", isYesPad and padYes or padNo) -- Correct sound
					
					gameLoopActive = false -- 停止本回合
					
					-- 更新 UI
					for _, lbl in ipairs(questionLabels) do lbl.Text = player.Name .. " 獲勝！" end
					
					-- 給予獎勵 (這裡簡單加 50 金幣)
					local ls = player:FindFirstChild("leaderstats")
					if ls and ls:FindFirstChild("Gold") then
						ls.Gold.Value += 50
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
					-- 增加擊飛效果
					local root = char:FindFirstChild("HumanoidRootPart")
					if root then root.AssemblyLinearVelocity = Vector3.new(0, 50, 0) end
					
					playSound("rbxassetid://130972023", isYesPad and padYes or padNo) -- Wrong sound
					-- 可以考慮扣分或擊飛
				end
			end
		end
	end
	
	local padYes = currentClassroom:FindFirstChild("PadYes")
	local padNo = currentClassroom:FindFirstChild("PadNo")
	if padYes then padYes.Touched:Connect(function(hit) onPadTouched(hit, true) end) end
	if padNo then padNo.Touched:Connect(function(hit) onPadTouched(hit, false) end) end

	-- 3. 生成老師
	currentTeacher = spawnTeacher(gameOffset + Vector3.new(0, 5, -40), currentClassroom)
	
	-- 4. 啟動老師 AI (追逐最近玩家)
	task.spawn(function()
		local humanoid = currentTeacher:WaitForChild("Humanoid")
		local root = currentTeacher:WaitForChild("HumanoidRootPart")
		
		-- 攻擊判定
		root.Touched:Connect(function(hit)
			local char = hit.Parent
			local player = Players:GetPlayerFromCharacter(char)
			if player and table.find(lobbyPlayers, player) then
				local hum = char:FindFirstChild("Humanoid")
				local pRoot = char:FindFirstChild("HumanoidRootPart")
				if hum and pRoot and not hum.Sit then
					handlePlayerFall(player) -- 跌倒並自動起身
					-- 擊飛效果
					local dir = (pRoot.Position - root.Position).Unit
					pRoot.AssemblyLinearVelocity = dir * 60 + Vector3.new(0, 30, 0)
				end
			end
		end)
		
		while isGameRunning and currentTeacher and currentTeacher.Parent do
			local target = nil
			local minDist = math.huge
			
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
			
			if target then
				humanoid:MoveTo(target.Position)
			end
			task.wait(0.2) -- 每 0.2 秒更新一次目標
		end
	end)
	
	-- 5. 遊戲主迴圈 (出題 -> 等待 -> 結算)
	-- 這裡示範 3 回合
	for round = 1, 3 do
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
	if currentClassroom then currentClassroom:Destroy() end
	
	-- 傳送回大廳
	for _, player in ipairs(lobbyPlayers) do
		if player.Character then
			player.Character:PivotTo(multiplayerZone.CFrame * CFrame.new(0, 3, 0))
		end
	end
	
	lobbyPlayers = {} -- 清空大廳
	prompt.Enabled = true
	print(">>> [SERVER] 多人遊戲結束，大廳已重置。")
end

local function startIntermission()
	if countdownActive then return end
	countdownActive = true
	
	print(">>> [SERVER] 倒數計時開始...")
	
	for i = INTERMISSION_TIME, 1, -1 do
		-- 再次檢查人數與遊戲狀態，防止重複觸發
		if #lobbyPlayers < MIN_PLAYERS or isGameRunning then
			print(">>> [SERVER] 人數不足，倒數取消。")
			countdownActive = false
			return
		end
		-- 這裡未來可以用 BillboardGui 或 Hint 顯示倒數給玩家看
		print(">>> [SERVER] 多人遊戲即將開始: " .. i)
		task.wait(1)
	end
	
	if not isGameRunning and not startingGame and #lobbyPlayers >= MIN_PLAYERS then
		countdownActive = false
		startGame()
	end
end

local function onPromptTriggered(player)
	print(">>> [SERVER] 收到加入請求: " .. player.Name)
	if isGameRunning or startingGame then 
		print(">>> [SERVER] 遊戲進行中，拒絕加入")
		return 
	end
	
	-- 避免重複加入
	if table.find(lobbyPlayers, player) then 
		print(">>> [SERVER] 玩家已在大廳中")
		return 
	end
	
	table.insert(lobbyPlayers, player)
	print(string.format(">>> [SERVER] %s 加入了多人大廳 (%d/%d)", player.Name, #lobbyPlayers, MIN_PLAYERS))
	
	-- 將玩家傳送到等待區 (紅色區域上方)，作為視覺回饋
	if player.Character then
		player.Character:PivotTo(multiplayerZone.CFrame * CFrame.new(0, 3, 0))
	end
	
	-- 嘗試開始倒數
	if #lobbyPlayers >= MIN_PLAYERS and not countdownActive then
		startIntermission()
	end
end

local function onPlayerRemoving(player)
	local idx = table.find(lobbyPlayers, player)
	if idx then
		table.remove(lobbyPlayers, idx)
		print(">>> [SERVER] " .. player.Name .. " 離開了大廳。")
	end
end

prompt.Triggered:Connect(onPromptTriggered)
Players.PlayerRemoving:Connect(onPlayerRemoving)

print("✅ [SERVER] MultiplayerManager 已啟動，等待玩家加入...")