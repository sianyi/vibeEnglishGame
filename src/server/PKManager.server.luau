-- PKManager.server.luau
-- 1v1 PK 模式：兩人同場答題，答對+1，答錯-1+擊倒，先到-5分者輸

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

-- 等待依賴
local Shared = ReplicatedStorage:WaitForChild("Shared")
local QuestionData = require(Shared:WaitForChild("QuestionData"))
local gameRemote = ReplicatedStorage:WaitForChild("GameRemote")

local PK_LOSE_SCORE = -5   -- 達到此分數者輸
local ROUND_TIME    = 12   -- 每題秒數
local PK_OFFSET     = Vector3.new(20000, 2000, 10000)  -- PK 教室位置（遠離主遊戲）

local pkQueue  = {}
local pkActive = false

-- ============================================================
-- 輔助：建立 Part
-- ============================================================
local function makePart(name, props, parent)
	local p = Instance.new("Part")
	p.Name = name; p.Anchored = true
	for k, v in pairs(props) do p[k] = v end
	p.Parent = parent; return p
end

local function makeSurfaceLabel(part, face, text, size, color)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 20; gui.Parent = part
	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.new(1,0,1,0)
	lbl.BackgroundTransparency = 1
	lbl.Text = text
	lbl.TextColor3 = color or Color3.new(1,1,1)
	lbl.TextScaled = false; lbl.TextSize = size or 50
	lbl.Font = Enum.Font.GothamBlack; lbl.TextWrapped = true
	lbl.Parent = gui; return lbl
end

-- ============================================================
-- 建立 PK 教室
-- ============================================================
local function createPKClassroom(offset)
	local model = Instance.new("Model")
	model.Name = "PKClassroom"

	-- 地板
	makePart("Floor", {Position=offset, Size=Vector3.new(60,2,60),
		Color=Color3.fromRGB(120,40,40), Material=Enum.Material.SmoothPlastic}, model)

	-- 作答區
	local padYes = makePart("PadYes", {
		Position=offset+Vector3.new(-15,1.1,-15), Size=Vector3.new(14,0.2,14),
		Color=Color3.fromRGB(46,204,113), Material=Enum.Material.Neon}, model)
	makeSurfaceLabel(padYes, Enum.NormalId.Top, "YES", 80)

	local padNo = makePart("PadNo", {
		Position=offset+Vector3.new(15,1.1,-15), Size=Vector3.new(14,0.2,14),
		Color=Color3.fromRGB(231,76,60), Material=Enum.Material.Neon}, model)
	makeSurfaceLabel(padNo, Enum.NormalId.Top, "NO", 80)

	-- 牆壁
	makePart("WallBack",  {Position=offset+Vector3.new(0,8,-30),  Size=Vector3.new(60,16,1),  Color=Color3.fromRGB(80,20,20)}, model)
	makePart("WallFront", {Position=offset+Vector3.new(0,8,30),   Size=Vector3.new(60,16,1),  Color=Color3.fromRGB(80,20,20)}, model)
	makePart("WallLeft",  {Position=offset+Vector3.new(-30,8,0),  Size=Vector3.new(1,16,60),  Color=Color3.fromRGB(80,20,20)}, model)
	makePart("WallRight", {Position=offset+Vector3.new(30,8,0),   Size=Vector3.new(1,16,60),  Color=Color3.fromRGB(80,20,20)}, model)

	-- 天花板
	makePart("Ceiling", {Position=offset+Vector3.new(0,16,0), Size=Vector3.new(60,1,60),
		Color=Color3.fromRGB(60,20,20)}, model)
	local lightPart = makePart("Light", {Position=offset+Vector3.new(0,15,0),
		Size=Vector3.new(15,1,15), Material=Enum.Material.Neon}, model)
	local light = Instance.new("SurfaceLight")
	light.Face=Enum.NormalId.Bottom; light.Range=40; light.Brightness=2; light.Parent=lightPart

	-- 黑板（題目顯示）
	local qLabels = {}
	local boardCfgs = {
		{pos=offset+Vector3.new(0,12,-28),  size=Vector3.new(30,10,1),  face=Enum.NormalId.Back},
		{pos=offset+Vector3.new(0,12,28),   size=Vector3.new(30,10,1),  face=Enum.NormalId.Front},
		{pos=offset+Vector3.new(-28,12,0),  size=Vector3.new(1,10,30),  face=Enum.NormalId.Right},
		{pos=offset+Vector3.new(28,12,0),   size=Vector3.new(1,10,30),  face=Enum.NormalId.Left},
	}
	for i, cfg in ipairs(boardCfgs) do
		local board = makePart("Board"..i, {Position=cfg.pos, Size=cfg.size,
			Color=Color3.fromRGB(20,20,20), Material=Enum.Material.Slate}, model)
		table.insert(qLabels, makeSurfaceLabel(board, cfg.face, "等待開始...", 28, Color3.fromRGB(255,220,0)))
	end

	-- 分數牌（中央懸掛）
	local scorePart = makePart("ScoreBoard", {
		Position=offset+Vector3.new(0,14,0), Size=Vector3.new(20,4,1),
		Color=Color3.fromRGB(10,10,10), Material=Enum.Material.Neon}, model)
	local scoreLabel = makeSurfaceLabel(scorePart, Enum.NormalId.Front, "⚔️ PK", 32, Color3.fromRGB(255,100,100))

	model.Parent = Workspace
	return model, padYes, padNo, qLabels, scoreLabel
end

-- ============================================================
-- PK 遊戲主邏輯
-- ============================================================
local function startPKGame(p1, p2)
	pkActive = true
	print("[PK] 開始！" .. p1.Name .. " vs " .. p2.Name)

	local scores = {[p1] = 0, [p2] = 0}
	local classroom, padYes, padNo, qLabels, scoreLabel = createPKClassroom(PK_OFFSET)

	-- 傳送玩家
	for i, p in ipairs({p1, p2}) do
		if p.Character then
			p.Character:PivotTo(CFrame.new(PK_OFFSET + Vector3.new((i==1 and -10 or 10), 5, 10)))
		end
	end

	gameRemote:FireClient(p1, "PKStart", p1.Name, p2.Name)
	gameRemote:FireClient(p2, "PKStart", p1.Name, p2.Name)

	-- 更新分數牌
	local function updateScore()
		local s1, s2 = scores[p1], scores[p2]
		scoreLabel.Text = p1.Name .. " " .. s1 .. " ⚔️ " .. s2 .. " " .. p2.Name
		gameRemote:FireClient(p1, "PKScore", s1, s2, p1.Name, p2.Name)
		gameRemote:FireClient(p2, "PKScore", s1, s2, p1.Name, p2.Name)
	end
	updateScore()

	-- 擊倒
	local function knockdown(player)
		if player.Character then
			local hum = player.Character:FindFirstChild("Humanoid")
			if hum then
				-- 🛡️ Shield 保護
				local shield = player:GetAttribute("Item_Shield") or 0
				if shield > 0 then
					player:SetAttribute("Item_Shield", shield - 1)
					return
				end
				hum.Sit = true; hum.PlatformStand = true
				local root = player.Character:FindFirstChild("HumanoidRootPart")
				if root then root.AssemblyLinearVelocity = Vector3.new(0, 50, 0) end
				task.delay(3, function() if hum then hum.Sit=false; hum.PlatformStand=false end end)
			end
		end
	end

	-- 確認遊戲是否結束
	local gameRunning = true
	local function checkEnd()
		if scores[p1] <= PK_LOSE_SCORE then return p2, p1 end
		if scores[p2] <= PK_LOSE_SCORE then return p1, p2 end
		return nil, nil
	end

	-- 每題的作答狀態
	local roundActive = false
	local currentQ = nil

	local function onPadTouched(hit, isYes)
		if not roundActive or not currentQ then return end
		local char = hit.Parent
		local player = Players:GetPlayerFromCharacter(char)
		if player ~= p1 and player ~= p2 then return end
		local hum = char:FindFirstChild("Humanoid")
		if not (hum and hum.Health > 0 and not hum.Sit) then return end

		local correct = (isYes == currentQ.isCorrect)
		if correct then
			scores[player] += 1
			roundActive = false
			for _, lbl in ipairs(qLabels) do lbl.Text = player.Name .. " 答對！+1" end
		else
			scores[player] -= 1
			knockdown(player)
			for _, lbl in ipairs(qLabels) do lbl.Text = player.Name .. " 答錯！-1" end
		end

		updateScore()
		local winner, loser = checkEnd()
		if winner then
			gameRunning = false
			roundActive = false
		end
	end

	padYes.Touched:Connect(function(hit) onPadTouched(hit, true) end)
	padNo.Touched:Connect(function(hit) onPadTouched(hit, false) end)

	-- 問題迴圈
	local round = 0
	while gameRunning do
		round += 1
		currentQ = QuestionData.GetRandomQuestion(nil, 1000)
		local qText = string.format("第 %d 題\n%s\n= %s ?", round, currentQ.Word, currentQ.Definition)
		for _, lbl in ipairs(qLabels) do lbl.Text = qText end

		-- 📖 作弊器
		for _, p in ipairs({p1, p2}) do
			local cheat = p:GetAttribute("Item_Cheat") or 0
			if cheat > 0 then
				p:SetAttribute("Item_Cheat", cheat - 1)
				gameRemote:FireClient(p, "CheatHint", currentQ.IsCorrect)
			end
		end

		roundActive = true
		local t = ROUND_TIME
		while t > 0 and roundActive and gameRunning do
			task.wait(1)
			t -= 1
		end
		roundActive = false

		if not gameRunning then break end
		task.wait(2)
	end

	-- 遊戲結束
	local winner, loser = checkEnd()
	local winnerName = winner and winner.Name or "平手"
	for _, lbl in ipairs(qLabels) do
		lbl.Text = "🏆 " .. winnerName .. " 獲勝！"
	end
	updateScore()

	if winner then
		gameRemote:FireClient(winner, "PKEnd", true,  scores[winner], scores[loser])
		gameRemote:FireClient(loser,  "PKEnd", false, scores[loser],  scores[winner])
		-- 更新勝場
		local ls = winner:FindFirstChild("leaderstats")
		if ls and ls:FindFirstChild("Wins") then ls.Wins.Value += 1 end
	end

	task.wait(4)

	-- 傳送回大廳
	for _, p in ipairs({p1, p2}) do
		if p.Character then
			p.Character:PivotTo(CFrame.new(0, 10, 0))
		end
	end

	task.wait(1)
	classroom:Destroy()
	pkActive = false
	print("[PK] 結束，教室已清理")
end

-- ============================================================
-- 建立 PK 入場區
-- ============================================================
local function createPKZone()
	-- 等 Workspace 準備好
	local base = makePart("PKZone_Base", {
		Position = Vector3.new(0, 1, -62),
		Size = Vector3.new(14, 2, 14),
		Color = Color3.fromRGB(200, 30, 30),
		Material = Enum.Material.Neon,
	}, Workspace)

	local sign = makePart("PKZone_Sign", {
		Position = Vector3.new(0, 7, -62),
		Size = Vector3.new(14, 4, 0.5),
		Color = Color3.fromRGB(20,20,20),
	}, Workspace)

	makeSurfaceLabel(sign, Enum.NormalId.Front, "⚔️ 1v1 PK", 40, Color3.fromRGB(255, 80, 80))
	makeSurfaceLabel(sign, Enum.NormalId.Back,  "⚔️ 1v1 PK", 40, Color3.fromRGB(255, 80, 80))

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "加入 PK 佇列"
	prompt.ObjectText  = "⚔️ 1v1 挑戰"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 10
	prompt.Parent = base

	-- 佇列狀態顯示
	local statusPart = makePart("PKZone_Status", {
		Position = Vector3.new(0, 4, -62),
		Size = Vector3.new(14, 1.5, 0.4),
		Color = Color3.fromRGB(10,10,10),
	}, Workspace)
	local statusLabel = makeSurfaceLabel(statusPart, Enum.NormalId.Front, "等待玩家（0/2）", 24, Color3.fromRGB(200,200,200))

	print("✅ [PK] PK Zone 建立完成")
	return prompt, statusLabel
end

local pkPrompt, pkStatusLabel = createPKZone()

-- ============================================================
-- 佇列邏輯
-- ============================================================
pkPrompt.Triggered:Connect(function(player)
	if pkActive then
		gameRemote:FireClient(player, "PKNotice", "目前有場 PK 進行中，請稍後再試！")
		return
	end
	if table.find(pkQueue, player) then
		gameRemote:FireClient(player, "PKNotice", "你已在佇列中，等待對手...")
		return
	end

	table.insert(pkQueue, player)
	local count = #pkQueue
	pkStatusLabel.Text = "等待玩家（" .. count .. "/2）"
	gameRemote:FireClient(player, "PKNotice", "已加入佇列（" .. count .. "/2），等待對手...")
	print("[PK] " .. player.Name .. " 加入佇列，共 " .. count .. " 人")

	if count >= 2 then
		local p1 = table.remove(pkQueue, 1)
		local p2 = table.remove(pkQueue, 1)
		pkStatusLabel.Text = "等待玩家（0/2）"
		task.spawn(startPKGame, p1, p2)
	end
end)

-- 玩家離線時從佇列移除
Players.PlayerRemoving:Connect(function(player)
	local idx = table.find(pkQueue, player)
	if idx then
		table.remove(pkQueue, idx)
		pkStatusLabel.Text = "等待玩家（" .. #pkQueue .. "/2）"
	end
end)

print("✅ [PK] PKManager 啟動完成")
