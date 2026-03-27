-- DevTest.server.luau
-- 自動測試腳本：測試多人遊戲系統（不需手動操作）
-- 僅在 Studio 模式執行

-- ============================================================
-- 模式切換：
--   "OFF"    = 停用（正常玩家測試，不干擾）
--   "PLAYER" = Studio 手動玩家測試（停用自動答題，但印出提示）
--   "MCP"    = MCP 自動測試模式（自動觸發關卡＋自動答題）
local DEV_MODE = "OFF"
-- ============================================================

local RunService = game:GetService("RunService")
if not RunService:IsStudio() then return end

if DEV_MODE == "OFF" then
	return
elseif DEV_MODE == "PLAYER" then
	print("[DEV TEST] 手動玩家測試模式（PLAYER）— 自動答題已停用，請自行操作")
	return
elseif DEV_MODE ~= "MCP" then
	warn("[DEV TEST] 未知模式: " .. tostring(DEV_MODE) .. "，請設為 OFF / PLAYER / MCP")
	return
end

-- 以下為 MCP 自動測試模式

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ServerScriptService = game:GetService("ServerScriptService")

local DEV_ROUNDS = 3  -- 要測試幾場
local DEV_LEVEL = 1000  -- 使用哪個等級
local ANSWER_DELAY = 4  -- 遊戲開始後幾秒自動答題

print("========================================")
print("[DEV TEST] 腳本已載入，等待遊戲初始化...")
print("========================================")

-- 等待 MultiplayerManager 完成 dev hook 設置
local devTrigger = ServerScriptService:WaitForChild("DevTriggerGame", 15)
if not devTrigger then
	warn("[DEV TEST] ❌ 找不到 DevTriggerGame，請確認 MultiplayerManager 已載入")
	return
end
print("[DEV TEST] ✅ DevTriggerGame 就緒")

local function getPlayer()
	local p = Players:GetPlayers()[1]
	if p then return p end
	return Players.PlayerAdded:Wait()
end

local function waitForClassroom(timeout)
	local t = 0
	while t < timeout do
		local c = Workspace:FindFirstChild("MultiplayerClassroom")
		if c then return c end
		task.wait(0.5)
		t += 0.5
	end
	return nil
end

local function runTest()
	local player = getPlayer()

	if not player.Character then
		player.CharacterAdded:Wait()
		task.wait(1)
	end

	print("")
	print("[DEV TEST] 開始測試玩家: " .. player.Name)
	print("[DEV TEST] 等級: " .. DEV_LEVEL .. " | 場數: " .. DEV_ROUNDS)
	print("========================================")

	local results = { wins = 0, errors = 0 }

	for round = 1, DEV_ROUNDS do
		print("")
		print("[DEV TEST] ===== 第 " .. round .. "/" .. DEV_ROUNDS .. " 場 =====")

		print("[DEV TEST] 觸發進入 LevelZone_" .. DEV_LEVEL .. "...")
		devTrigger:Fire(player, DEV_LEVEL)

		print("[DEV TEST] 等待遊戲開始（倒數 + 初始化）...")
		task.wait(5)

		local classroom = waitForClassroom(5)
		if not classroom then
			warn("[DEV TEST] ❌ 教室未出現，跳過本場")
			results.errors += 1
			task.wait(3)
			continue
		end
		print("[DEV TEST] ✅ 教室已建立")

		-- 讀取黑板題目
		task.wait(1)
		for _, child in ipairs(classroom:GetDescendants()) do
			if child:IsA("TextLabel") and child.Name == "QuestionLabel" and child.Text ~= "" then
				print("[DEV TEST] 📖 題目: " .. child.Text)
				break
			end
		end

		-- 找答題區
		local padYes = classroom:FindFirstChild("PadYes")
		local padNo = classroom:FindFirstChild("PadNo")

		if not padYes or not padNo then
			warn("[DEV TEST] ❌ 找不到答題區")
			results.errors += 1
			task.wait(10)
			continue
		end

		-- 等幾秒再答（模擬玩家思考）
		task.wait(ANSWER_DELAY)

		local chooseYes = (math.random(0, 1) == 1)
		local targetPad = chooseYes and padYes or padNo
		print("[DEV TEST] 🎯 自動選擇: " .. (chooseYes and "YES ✅" or "NO ❌"))

		if player.Character then
			local hrp = player.Character:FindFirstChild("HumanoidRootPart")
			if hrp then
				hrp.CFrame = CFrame.new(targetPad.Position + Vector3.new(0, 3, 0))
			end
		end

		-- 等待本場結束（教室被清理）
		print("[DEV TEST] 等待本場結束...")
		local waited = 0
		while Workspace:FindFirstChild("MultiplayerClassroom") and waited < 50 do
			task.wait(1)
			waited += 1
		end

		if not Workspace:FindFirstChild("MultiplayerClassroom") then
			print("[DEV TEST] ✅ 本場正常結束（教室已清理）")
			results.wins += 1
		else
			warn("[DEV TEST] ⚠️ 教室超時（3回合可能都還在跑）")
			results.errors += 1
		end

		task.wait(3)
	end

	print("")
	print("========================================")
	print("[DEV TEST] ===== 測試完成 =====")
	print("[DEV TEST] 正常結束: " .. results.wins .. " 場")
	print("[DEV TEST] 異常/跳過: " .. results.errors .. " 場")
	print("========================================")
end

task.wait(2)
runTest()
