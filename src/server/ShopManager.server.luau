-- ShopManager.server.luau
-- 道具商店：建立攤販實體 + 處理購買請求

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ShopData = require(Shared:WaitForChild("ShopData"))
local gameRemote = ReplicatedStorage:WaitForChild("GameRemote")

-- 建立 ShopEvent RemoteFunction（購買請求）
local shopEvent = Instance.new("RemoteFunction")
shopEvent.Name = "ShopEvent"
shopEvent.Parent = ReplicatedStorage

-- 建立攤販實體（放在地圖中央）
local function createShopStand()
	local shopPos = Vector3.new(0, 0, 8)

	local stand = Instance.new("Model")
	stand.Name = "ShopStand"

	-- 攤販桌
	local counter = Instance.new("Part")
	counter.Name = "Counter"
	counter.Size = Vector3.new(10, 3, 5)
	counter.Position = shopPos + Vector3.new(0, 1.5, 0)
	counter.BrickColor = BrickColor.new("Bright orange")
	counter.Material = Enum.Material.SmoothPlastic
	counter.Anchored = true
	counter.Parent = stand

	-- 招牌柱
	local pole = Instance.new("Part")
	pole.Size = Vector3.new(0.5, 5, 0.5)
	pole.Position = shopPos + Vector3.new(0, 5.5, -2)
	pole.BrickColor = BrickColor.new("Dark orange")
	pole.Material = Enum.Material.SmoothPlastic
	pole.Anchored = true
	pole.Parent = stand

	-- 招牌板
	local sign = Instance.new("Part")
	sign.Size = Vector3.new(10, 3, 0.4)
	sign.Position = shopPos + Vector3.new(0, 8, -2)
	sign.BrickColor = BrickColor.new("Bright yellow")
	sign.Material = Enum.Material.Neon
	sign.Anchored = true
	sign.Parent = stand

	local signGui = Instance.new("SurfaceGui")
	signGui.Face = Enum.NormalId.Front
	signGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	signGui.PixelsPerStud = 20
	signGui.Parent = sign

	local signLabel = Instance.new("TextLabel")
	signLabel.Size = UDim2.new(1, 0, 1, 0)
	signLabel.BackgroundTransparency = 1
	signLabel.Text = "🏪 道具商店"
	signLabel.TextScaled = true
	signLabel.Font = Enum.Font.GothamBlack
	signLabel.TextColor3 = Color3.fromRGB(50, 10, 0)
	signLabel.Parent = signGui

	-- ProximityPrompt
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "ShopPrompt"
	prompt.ActionText = "開啟商店"
	prompt.ObjectText = "🏪 道具商店"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 10
	prompt.Parent = counter

	stand.Parent = Workspace
	print("✅ [SHOP] 攤販建立完成")
	return prompt
end

local prompt = createShopStand()

-- ProximityPrompt 觸發 → 通知該玩家開啟 UI
prompt.Triggered:Connect(function(player)
	gameRemote:FireClient(player, "OpenShop")
end)

-- 處理購買請求
shopEvent.OnServerInvoke = function(player, itemId)
	-- 找道具資料
	local item = nil
	for _, i in ipairs(ShopData) do
		if i.Id == itemId then item = i; break end
	end
	if not item then return false, "道具不存在" end

	-- 檢查金幣
	local ls = player:FindFirstChild("leaderstats")
	if not ls or not ls:FindFirstChild("Gold") then return false, "找不到金幣資料" end
	if ls.Gold.Value < item.Price then
		return false, "金幣不足！需要 " .. item.Price .. " 金幣"
	end

	-- 扣金幣、加道具使用次數（存在 player attribute）
	ls.Gold.Value -= item.Price
	local attrKey = "Item_" .. itemId
	local current = player:GetAttribute(attrKey) or 0
	player:SetAttribute(attrKey, current + item.Uses)

	print("[SHOP] " .. player.Name .. " 購買 " .. item.Name .. "，剩餘金幣: " .. ls.Gold.Value)
	return true, item.Name .. " 購買成功！剩餘 " .. ls.Gold.Value .. " 金幣"
end
