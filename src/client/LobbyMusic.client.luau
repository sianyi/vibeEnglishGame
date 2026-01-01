local Players = game:GetService("Players")
local player = Players.LocalPlayer

local playerGui = player:WaitForChild("PlayerGui")

local bgm = Instance.new("Sound")
bgm.SoundId = "rbxassetid://1843404009" -- Upbeat background music
bgm.Looped = true
bgm.Volume = 0.4
bgm.Parent = playerGui
bgm:Play()