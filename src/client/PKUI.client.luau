-- PKUI.client.luau
-- 顯示 PK 通知、分數、勝負結果

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local gameRemote = ReplicatedStorage:WaitForChild("GameRemote")

-- 通用通知 helper
local function showNotice(text, color, duration)
	local pg = player.PlayerGui
	local g = pg:FindFirstChild("PKNoticeGui") or Instance.new("ScreenGui")
	g.Name = "PKNoticeGui"; g.ResetOnSpawn = false; g.Parent = pg
	g:ClearAllChildren()

	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.new(0, 380, 0, 60)
	lbl.Position = UDim2.new(0.5, -190, 0.15, 0)
	lbl.BackgroundColor3 = color or Color3.fromRGB(30,30,30)
	lbl.BackgroundTransparency = 0.1
	lbl.Text = text
	lbl.Font = Enum.Font.GothamBold
	lbl.TextSize = 20
	lbl.TextColor3 = Color3.new(1,1,1)
	lbl.TextWrapped = true
	lbl.Parent = g
	local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0,10); c.Parent = lbl

	task.delay(duration or 4, function()
		if lbl.Parent then
			TweenService:Create(lbl, TweenInfo.new(0.5), {BackgroundTransparency=1, TextTransparency=1}):Play()
			task.wait(0.5); g:ClearAllChildren()
		end
	end)
end

-- 分數 HUD
local scoreGui = Instance.new("ScreenGui")
scoreGui.Name = "PKScoreGui"
scoreGui.ResetOnSpawn = false
scoreGui.Enabled = false
scoreGui.Parent = player.PlayerGui

local scoreFrame = Instance.new("Frame")
scoreFrame.Size = UDim2.new(0, 360, 0, 70)
scoreFrame.Position = UDim2.new(0.5, -180, 0, 20)
scoreFrame.BackgroundColor3 = Color3.fromRGB(20,10,10)
scoreFrame.BackgroundTransparency = 0.15
scoreFrame.BorderSizePixel = 0
scoreFrame.Parent = scoreGui
local sfc = Instance.new("UICorner"); sfc.CornerRadius = UDim.new(0,12); sfc.Parent = scoreFrame

local scoreLabel = Instance.new("TextLabel")
scoreLabel.Size = UDim2.new(1,0,1,0)
scoreLabel.BackgroundTransparency = 1
scoreLabel.Text = "⚔️ PK"
scoreLabel.Font = Enum.Font.GothamBlack
scoreLabel.TextSize = 26
scoreLabel.TextColor3 = Color3.fromRGB(255,100,100)
scoreLabel.Parent = scoreFrame

-- 聆聽 GameRemote 事件
gameRemote.OnClientEvent:Connect(function(action, a, b, c, d)
	if action == "PKNotice" then
		showNotice("⚔️ " .. tostring(a), Color3.fromRGB(180,30,30), 4)

	elseif action == "PKStart" then
		-- a = p1Name, b = p2Name
		scoreGui.Enabled = true
		scoreLabel.Text = a .. " 0 ⚔️ 0 " .. b
		showNotice("⚔️ PK 開始！" .. a .. " vs " .. b, Color3.fromRGB(180,30,30), 3)

	elseif action == "PKScore" then
		-- a=score1, b=score2, c=p1Name, d=p2Name
		scoreLabel.Text = tostring(c) .. " " .. tostring(a) .. " ⚔️ " .. tostring(b) .. " " .. tostring(d)
		-- 分數低時變紅色警告
		local myScore = (player.Name == c) and a or b
		if myScore <= -3 then
			scoreLabel.TextColor3 = Color3.fromRGB(255,50,50)
		else
			scoreLabel.TextColor3 = Color3.fromRGB(255,200,100)
		end

	elseif action == "PKEnd" then
		-- a=isWinner, b=myScore, c=opponentScore
		scoreGui.Enabled = false
		if a then
			showNotice("🏆 你贏了！最終比分 " .. tostring(b) .. " vs " .. tostring(c),
				Color3.fromRGB(0,150,0), 5)
		else
			showNotice("💀 你輸了！最終比分 " .. tostring(b) .. " vs " .. tostring(c),
				Color3.fromRGB(150,0,0), 5)
		end
	end
end)
