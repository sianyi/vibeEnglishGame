local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")

-- 設定目標 Part 名稱與音效 ID
local PART_NAME = "ClickPart"
local SOUND_ID = "rbxassetid://12221967" -- 範例音效 ID (Coin sound)，你可以換成你喜歡的
local REWARD_AMOUNT = 50

local clickPart = Workspace:WaitForChild(PART_NAME, 5) -- 等待最多 5 秒

if not clickPart then
	warn("警告: 找不到 ClickPart！")
	return
end

local debounce = false

local function onPartTouch(hit)
	if debounce then return end

	local player = Players:GetPlayerFromCharacter(hit.Parent)
	if not player then return end

	debounce = true

	-- 視覺效果: 隱藏磚塊 (假裝被吃掉了)
	clickPart.Transparency = 1
	clickPart.CanCollide = false

	-- 1. 增加金幣
	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats then
		local gold = leaderstats:FindFirstChild("Gold")
		if gold then
			gold.Value += REWARD_AMOUNT
			print("💰 金幣已增加！目前金幣:", gold.Value)
		end
	end

	-- 2. 播放音效 (播放完畢後自動銷毀 Sound 實例)
	local sound = Instance.new("Sound")
	sound.SoundId = SOUND_ID
	sound.Parent = clickPart
	sound.Ended:Connect(function()
		sound:Destroy()
	end)
	sound:Play()

	task.wait(3) -- 等待 3 秒後重生
	
	-- 重生
	clickPart.Transparency = 0
	clickPart.CanCollide = true
	debounce = false
end

clickPart.Touched:Connect(onPartTouch)