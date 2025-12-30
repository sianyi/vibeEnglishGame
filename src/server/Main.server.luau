local Players = game:GetService("Players")

local function onPlayerAdded(player)
	-- 防止重複建立
	if player:FindFirstChild("leaderstats") then return end

	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	leaderstats.Parent = player

	local gold = Instance.new("IntValue")
	gold.Name = "Gold"
	gold.Value = 0
	gold.Parent = leaderstats

	local highScore = Instance.new("IntValue")
	highScore.Name = "HighScore"
	highScore.Value = 0
	highScore.Parent = leaderstats

	local totalCorrect = Instance.new("IntValue")
	totalCorrect.Name = "TotalCorrect"
	totalCorrect.Value = 0
	totalCorrect.Parent = leaderstats

	local totalAnswered = Instance.new("IntValue")
	totalAnswered.Name = "TotalAnswered"
	totalAnswered.Value = 0
	totalAnswered.Parent = leaderstats
end

Players.PlayerAdded:Connect(onPlayerAdded)

for _, player in ipairs(Players:GetPlayers()) do
	onPlayerAdded(player)
end