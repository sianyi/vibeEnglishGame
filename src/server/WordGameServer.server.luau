local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

-- 建立 RemoteEvent 用於前後端通訊
local REMOTE_NAME = "WordGameEvent"
local remote = ReplicatedStorage:FindFirstChild(REMOTE_NAME)
if not remote then
	remote = Instance.new("RemoteEvent")
	remote.Name = REMOTE_NAME
	remote.Parent = ReplicatedStorage
end

-- 建立 RemoteFunction 用於讓客戶端請求單字表
local FUNC_NAME = "GetWordList"
local getWordListFunc = ReplicatedStorage:FindFirstChild(FUNC_NAME)
if not getWordListFunc then
	getWordListFunc = Instance.new("RemoteFunction")
	getWordListFunc.Name = FUNC_NAME
	getWordListFunc.Parent = ReplicatedStorage
end

-- 載入單字庫 (純英文列表)
local Shared = ReplicatedStorage:WaitForChild("Shared")
local fullWordList = require(Shared:WaitForChild("WordList"))

-- 翻譯函數 (使用 Google Translate 非官方 API)
local function translateText(text)
	local encoded = HttpService:UrlEncode(text)
	local url = "https://translate.googleapis.com/translate_a/single?client=gtx&sl=en&tl=zh-TW&dt=t&q=" .. encoded
	
	local success, result = pcall(function()
		return HttpService:GetAsync(url)
	end)

	if success then
		local data = HttpService:JSONDecode(result)
		-- Google API 回傳結構: [[[ "翻譯結果", "原文", ... ]], ...]
		if data and data[1] and data[1][1] and data[1][1][1] then
			return data[1][1][1]
		end
	end
	return nil
end

-- 隨機挑選單字並翻譯
function getWordListFunc.OnServerInvoke(player)
	local validPairs = {}
	local pool = table.clone(fullWordList)
	
	-- 1. & 2. 隨機挑選 10 個不重複的單字並翻譯
	for i = 1, 10 do
		if #pool == 0 then break end
		local idx = math.random(1, #pool)
		local word = table.remove(pool, idx)
		
		-- 呼叫翻譯 API
		local cn = translateText(word)
		if not cn then cn = "翻譯失敗" end
		
		table.insert(validPairs, {en = word, cn = cn})
		task.wait(0.1) -- 稍微延遲，避免瞬間發送太多請求被 Google 阻擋
	end
	
	-- 3. & 4. 配對出正確與錯誤的結果
	local gameData = {}
	for i, pair in ipairs(validPairs) do
		local isCorrect = math.random() > 0.5
		local displayCn = pair.cn
		
		if not isCorrect and #validPairs > 1 then
			-- 從其他 9 個單字的中文抽取錯誤答案
			local wrongIdx = math.random(1, #validPairs)
			while wrongIdx == i do
				wrongIdx = math.random(1, #validPairs)
			end
			displayCn = validPairs[wrongIdx].cn
		end
		
		table.insert(gameData, {
			en = pair.en,
			displayCn = displayCn,
			isCorrect = isCorrect
		})
	end
	
	return gameData
end

-- 記錄玩家連勝次數
local playerStreaks = {}
-- 記錄玩家單局答對題數
local playerSessionScores = {}

-- 處理連勝特效 (粒子系統)
local function toggleStreakParticles(player, enable)
	local char = player.Character
	if not char then return end
	local root = char:FindFirstChild("HumanoidRootPart")
	if not root then return end
	
	local existing = root:FindFirstChild("StreakParticles")
	
	if enable then
		if not existing then
			local particles = Instance.new("ParticleEmitter")
			particles.Name = "StreakParticles"
			particles.Texture = "rbxassetid://243660364" -- 星星/閃光貼圖
			particles.Color = ColorSequence.new(Color3.fromRGB(255, 215, 0)) -- 金色
			particles.Size = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.5),
				NumberSequenceKeypoint.new(1, 0)
			})
			particles.LightEmission = 0.8
			particles.Rate = 30
			particles.Lifetime = NumberRange.new(0.5, 1)
			particles.Speed = NumberRange.new(2, 5)
			particles.SpreadAngle = Vector2.new(180, 180)
			particles.Parent = root
		end
	else
		if existing then
			existing:Destroy()
		end
	end
end

local function onClientEvent(player, action, data)
	-- 遊戲開始，重置單局分數
	if action == "StartGame" then
		playerSessionScores[player] = 0
		playerStreaks[player] = 0
		toggleStreakParticles(player, false)
	elseif action == "EndGame" then
		print(string.format(">>> [SERVER] 收到來自 %s 的 EndGame 事件，準備傳送回大廳。", player.Name))
		-- 遊戲結束，傳送回重生點
		toggleStreakParticles(player, false)
		if player.Character then
			player.Character:PivotTo(CFrame.new(0, 10, 0))
			print(string.format(">>> [SERVER] %s 已被傳送回大廳。", player.Name))
		end
	-- 接收客戶端傳來的結果
	elseif action == "AnswerResult" then
		local isCorrect = data -- true 代表答對，false 代表答錯
		
		local leaderstats = player:FindFirstChild("leaderstats")
		if leaderstats then
			local totalAnswered = leaderstats:FindFirstChild("TotalAnswered")
			if totalAnswered then totalAnswered.Value += 1 end

			local totalCorrect = leaderstats:FindFirstChild("TotalCorrect")

			local gold = leaderstats:FindFirstChild("Gold")
			if gold then
				if isCorrect then
					if totalCorrect then totalCorrect.Value += 1 end

					-- 增加連勝
					local streak = playerStreaks[player] or 0
					streak += 1
					playerStreaks[player] = streak
					
					-- 連勝 5 題以上顯示特效
					if streak >= 5 then
						toggleStreakParticles(player, true)
					end

					-- 計算獎勵 (連勝 3 次以上加倍)
					local reward = 10
					if streak >= 3 then
						reward = 20
					end
					gold.Value += reward

					-- 更新單局分數與最高分
					local currentScore = (playerSessionScores[player] or 0) + 1
					playerSessionScores[player] = currentScore

					local highScore = leaderstats:FindFirstChild("HighScore")
					if highScore and currentScore > highScore.Value then
						highScore.Value = currentScore
					end
				else
					-- 答錯重置連勝
					playerStreaks[player] = 0
					toggleStreakParticles(player, false)
					gold.Value -= 10
				end
			end
		end
	end
end

remote.OnServerEvent:Connect(onClientEvent)

-- 玩家離開時清除資料
Players.PlayerRemoving:Connect(function(player)
	playerStreaks[player] = nil
	playerSessionScores[player] = nil
end)