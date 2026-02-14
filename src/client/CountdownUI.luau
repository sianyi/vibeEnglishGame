--!strict
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")

local CountdownUI = {}
CountdownUI.__index = CountdownUI

export type CountdownUI = typeof(setmetatable({}, CountdownUI))

function CountdownUI.new(): CountdownUI
	local self = setmetatable({}, CountdownUI)
	
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")
	warn("[CountdownUI] Initializing UI for", player.Name)
	
	-- 建立 ScreenGui
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "GameCountdownUI"
	screenGui.IgnoreGuiInset = true
	screenGui.ResetOnSpawn = false
	screenGui.DisplayOrder = 100 -- 確保顯示在最上層
	screenGui.Enabled = false
	screenGui.Parent = playerGui
	
	-- 建立文字標籤
	local label = Instance.new("TextLabel")
	label.Name = "NumberLabel"
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromScale(0.5, 0.5)
	label.Size = UDim2.fromScale(0.2, 0.2)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.Text = ""
	label.TextColor3 = Color3.fromRGB(255, 255, 100) -- 黃色
	label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	label.TextStrokeTransparency = 0
	label.TextScaled = true
	label.ZIndex = 10 -- 確保在最上層
	label.Parent = screenGui
	warn("[CountdownUI] ScreenGui created and parented to PlayerGui:", screenGui.Parent)
	
	self.instance = screenGui
	self.label = label
	
	return self
end

function CountdownUI:Play(seconds: number)
	warn("[CountdownUI] Play requested for", seconds, "seconds")
	if not self.instance then 
		warn("[CountdownUI] Instance is missing!")
		return 
	end
	warn("[CountdownUI] UI Parent is:", self.instance.Parent, "| Enabled:", self.instance.Enabled)
	self.instance.Enabled = true
	
	for i = seconds, 1, -1 do
		print("[CountdownUI] Ticking:", i)
		self.label.Text = tostring(i)
		self.label.Rotation = -15
		self.label.Size = UDim2.fromScale(0.1, 0.1)
		self.label.TextTransparency = 0
		
		-- 彈跳動畫
		local tweenInfo = TweenInfo.new(0.5, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out)
		TweenService:Create(self.label, tweenInfo, {
			Size = UDim2.fromScale(0.3, 0.3),
			Rotation = 0
		}):Play()
		
		task.wait(1)
	end
	
	-- GO!
	warn("[CountdownUI] GO!")
	self.label.Text = "GO!"
	self.label.TextColor3 = Color3.fromRGB(100, 255, 100) -- 綠色
	
	local goTween = TweenService:Create(self.label, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Size = UDim2.fromScale(0.5, 0.5),
		TextTransparency = 1
	})
	goTween:Play()
	
	task.wait(0.5)
	self.instance.Enabled = false
	
	warn("[CountdownUI] Animation finished")
	-- 重置樣式
	self.label.TextColor3 = Color3.fromRGB(255, 255, 100)
	self.label.TextTransparency = 0
end

function CountdownUI:Destroy()
	if self.instance then
		self.instance:Destroy()
	end
end

return CountdownUI