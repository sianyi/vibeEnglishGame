--!strict
-- LevelSelectionUI.luau
-- 單字級別選擇 UI

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local LevelSelectionUI = {}
LevelSelectionUI.__index = LevelSelectionUI

export type LevelSelectionUI = typeof(setmetatable({}, LevelSelectionUI))

-- 單字級別配置
local LEVELS = {
	{ level = 1000, name = "基礎", desc = "最常見的 1000 個單字", color = Color3.fromRGB(46, 204, 113) },
	{ level = 2000, name = "進階", desc = "2000 個常用單字", color = Color3.fromRGB(52, 152, 219) },
	{ level = 3000, name = "中級", desc = "3000 個中等難度單字", color = Color3.fromRGB(155, 89, 182) },
	{ level = 4000, name = "高級", desc = "4000 個較難單字", color = Color3.fromRGB(241, 196, 15) },
	{ level = 5000, name = "專業", desc = "5000 個專業術語", color = Color3.fromRGB(231, 76, 60) },
}

function LevelSelectionUI.new(): LevelSelectionUI
	local self = setmetatable({}, LevelSelectionUI)
	
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")
	
	-- 建立 ScreenGui
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "LevelSelectionUI"
	screenGui.IgnoreGuiInset = true
	screenGui.ResetOnSpawn = false
	screenGui.Enabled = true
	screenGui.DisplayOrder = 50
	screenGui.Parent = playerGui
	
	-- 背景遮罩
	local bg = Instance.new("Frame")
	bg.Name = "Background"
	bg.Size = UDim2.fromScale(1, 1)
	bg.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	bg.BackgroundTransparency = 0.7
	bg.Parent = screenGui
	
	-- 主容器
	local container = Instance.new("Frame")
	container.Name = "Container"
	container.Size = UDim2.fromOffset(600, 500)
	container.Position = UDim2.fromScale(0.5, 0.5)
	container.AnchorPoint = Vector2.new(0.5, 0.5)
	container.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
	container.BorderSizePixel = 0
	container.Parent = screenGui
	
	-- 標題
	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.fromScale(1, 0.15)
	title.Position = UDim2.fromScale(0, 0)
	title.BackgroundTransparency = 1
	title.Text = "選擇單字級別"
	title.TextColor3 = Color3.new(1, 1, 1)
	title.TextScaled = true
	title.Font = Enum.Font.GothamBold
	title.Parent = container
	
	-- 說明文字
	local desc = Instance.new("TextLabel")
	desc.Name = "Description"
	desc.Size = UDim2.fromScale(1, 0.1)
	desc.Position = UDim2.fromScale(0, 0.15)
	desc.BackgroundTransparency = 1
	desc.Text = "選擇你要挑戰的單字範圍"
	desc.TextColor3 = Color3.fromRGB(180, 180, 180)
	desc.TextScaled = true
	desc.Font = Enum.Font.Gotham
	desc.Parent = container
	
	-- 按鈕容器
	local buttonsFrame = Instance.new("Frame")
	buttonsFrame.Name = "ButtonsFrame"
	buttonsFrame.Size = UDim2.fromScale(1, 0.6)
	buttonsFrame.Position = UDim2.fromScale(0, 0.28)
	buttonsFrame.BackgroundTransparency = 1
	buttonsFrame.Parent = container
	
	local grid = Instance.new("UIListLayout")
	grid.FillDirection = Enum.FillDirection.Horizontal
	grid.HorizontalAlignment = Enum.HorizontalAlignment.Center
	grid.VerticalAlignment = Enum.VerticalAlignment.Center
	grid.Padding = UDim.new(0.05, 0)
	grid.Parent = buttonsFrame
	
	-- 建立每個級別的按鈕
	local remoteEvent = ReplicatedStorage:WaitForChild("GameRemote")
	
	for _, levelInfo in ipairs(LEVELS) do
		local button = Instance.new("TextButton")
		button.Name = "LevelButton_" .. levelInfo.level
		button.Size = UDim2.fromScale(0.18, 0.9)
		button.BackgroundColor3 = levelInfo.color
		button.BorderSizePixel = 0
		button.Text = ""
		button.Parent = buttonsFrame
		
		-- 按鈕內的文字
		local btnContent = Instance.new("Frame")
		btnContent.Size = UDim2.fromScale(1, 1)
		btnContent.BackgroundTransparency = 1
		btnContent.Parent = button
		
		local levelNum = Instance.new("TextLabel")
		levelNum.Size = UDim2.fromScale(1, 0.5)
		levelNum.Position = UDim2.fromScale(0, 0.1)
		levelNum.BackgroundTransparency = 1
		levelNum.Text = "Level\n" .. levelInfo.level
		levelNum.TextColor3 = Color3.new(1, 1, 1)
		levelNum.TextScaled = true
		levelNum.Font = Enum.Font.GothamBold
		levelNum.Parent = btnContent
		
		local levelName = Instance.new("TextLabel")
		levelName.Size = UDim2.fromScale(1, 0.25)
		levelName.Position = UDim2.fromScale(0, 0.55)
		levelName.BackgroundTransparency = 1
		levelName.Text = levelInfo.name
		levelName.TextColor3 = Color3.new(1, 1, 1)
		levelName.TextScaled = true
		levelName.Font = Enum.Font.Gotham
		levelName.Parent = btnContent
		
		-- 按鈕互動效果
		button.MouseEnter:Connect(function()
			local tween = TweenService:Create(button, TweenInfo.new(0.2), {
				Size = UDim2.fromScale(0.2, 0.95)
			})
			tween:Play()
		end)
		
		button.MouseLeave:Connect(function()
			local tween = TweenService:Create(button, TweenInfo.new(0.2), {
				Size = UDim2.fromScale(0.18, 0.9)
			})
			tween:Play()
		end)
		
		button.MouseButton1Click:Connect(function()
			-- 發送選擇的級別到伺服器
			remoteEvent:FireServer("SetWordLevel", levelInfo.level)
			
			-- 隱藏 UI
			local tween = TweenService:Create(container, TweenInfo.new(0.3), {
				Size = UDim2.fromOffset(0, 0),
				Position = UDim2.fromScale(0.5, 0.5)
			})
			tween:Play()
			
			task.delay(0.3, function()
				screenGui:Destroy()
			end)
		end)
	end
	
	-- 關閉按鈕
	local closeBtn = Instance.new("TextButton")
	closeBtn.Name = "CloseButton"
	closeBtn.Size = UDim2.fromOffset(40, 40)
	closeBtn.Position = UDim2.fromScale(1, 0)
	closeBtn.AnchorPoint = Vector2.new(1, 0)
	closeBtn.BackgroundTransparency = 1
	closeBtn.Text = "✕"
	closeBtn.TextColor3 = Color3.new(1, 1, 1)
	closeBtn.TextScaled = true
	closeBtn.Font = Enum.Font.GothamBold
	closeBtn.Parent = container
	
	closeBtn.MouseButton1Click:Connect(function()
		screenGui:Destroy()
	end)
	
	self.screenGui = screenGui
	self.container = container
	
	return self
end

function LevelSelectionUI:Destroy()
	if self.screenGui then
		self.screenGui:Destroy()
	end
end

return LevelSelectionUI
