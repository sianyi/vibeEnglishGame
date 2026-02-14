local Workspace = game:GetService("Workspace")
local ServerStorage = game:GetService("ServerStorage")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

-- 等待其他腳本完成初始化 (給 3 秒讓其他腳本準備好)
task.wait(3)

-- 確保 Shared 資料夾存在
local Shared = ReplicatedStorage:FindFirstChild("Shared")
if not Shared then
	Shared = Instance.new("Folder")
	Shared.Name = "Shared"
	Shared.Parent = ReplicatedStorage
	print(">>> [SERVER] 創建 Shared 資料夾")
else
	print(">>> [SERVER] Shared 資料夾已存在")
end

-- 通知其他腳本可以開始了
ServerScriptService:SetAttribute("MapSetupComplete", true)
print(">>> [SERVER] MapSetup 準備完成，通知其他腳本...")

-- Merged AssetProvider logic to resolve require() issue
local function createTeacherRig()
	local existingRig = Shared:FindFirstChild("TeacherRig")
	if existingRig then existingRig:Destroy() end

	local success, rig = pcall(function()
		local desc = Instance.new("HumanoidDescription")
		desc.HeightScale = 1.5
		desc.WidthScale = 1.5
		desc.DepthScale = 1.5
		desc.HeadScale = 1.5
		desc.Shirt = 144076358
		desc.Pants = 144076468
		desc.HairAccessory = "16630147"
		desc.FaceAccessory = "118279773"
		return Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R15)
	end)

	if success and rig then
		rig.Name = "TeacherRig"
		for _, part in ipairs(rig:GetDescendants()) do
			if part:IsA("BasePart") then
				part.Anchored = true
			end
		end
		rig.Parent = Shared
		print("✅ [SERVER] 已自動生成 R15 TeacherRig。")
	else
		warn("⚠️ [SERVER] 生成 TeacherRig 失敗。")
	end
end

local function ensurePart(name, parent, properties, children)
	local part = parent:FindFirstChild(name)
	if not part then
		part = Instance.new("Part")
		part.Name = name
		part.Parent = parent
	end
	
	part.Anchored = true
	for prop, val in pairs(properties) do
		part[prop] = val
	end
	
	if children then
		for _, childDef in ipairs(children) do
			local className = childDef.ClassName
			local childName = childDef.Name
			local childProps = childDef.Properties or {}
			
			local child = part:FindFirstChild(childName)
			if not child then
				child = Instance.new(className)
				child.Name = childName
				child.Parent = part
			end
			
			for cProp, cVal in pairs(childProps) do
				child[cProp] = cVal
			end
		end
	end
	
	return part
end

-- 建立可愛的等級區域
local function createLevelZone(level: number, position: Vector3, color: Color3, name: string, desc: string)
	local zoneName = "LevelZone_" .. level
	
	-- 建立發光底座 (更可愛的設計)
	local base = ensurePart(zoneName .. "_Base", Workspace, {
		Position = position - Vector3.new(0, 0.5, 0),
		Size = Vector3.new(14, 1, 14),
		Color = color,
		Material = Enum.Material.Neon,
		CanCollide = true
	})
	
	-- 頂部的觸發區域 (半透明發光)
	local zone = ensurePart(zoneName, Workspace, {
		Position = position,
		Size = Vector3.new(8, 0.5, 8),
		Color = color,
		Material = Enum.Material.Neon,
		Transparency = 0.3,
		CanCollide = false
	}, {
		{
			ClassName = "ProximityPrompt",
			Name = "InteractPrompt",
			Properties = {
				ActionText = "點我\n玩遊戲",
				ObjectText = name,
				KeyboardKeyCode = Enum.KeyCode.E,
				RequiresLineOfSight = false,
				HoldDuration = 0.3,
				MaxActivationDistance = 20
			}
		}
	})
	
	-- 設定等級屬性
	zone:SetAttribute("WordLevel", level)
	
	-- 建立可愛的提示看板 (浮動效果)
	local hintPart = ensurePart(zoneName .. "_Hint", Workspace, {
		Position = position + Vector3.new(0, 6, 0),
		Size = Vector3.new(10, 4, 0.5),
		Color = color,
		Material = Enum.Material.Wood,
		CanCollide = false
	})
	
	-- BillboardGui (永遠面向玩家)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "LevelHint"
	billboard.Size = UDim2.fromOffset(200, 80)
	billboard.StudsOffset = Vector3.new(0, 0, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = hintPart
	
	-- 背景框架
	local bg = Instance.new("Frame")
	bg.Size = UDim2.fromScale(1, 1)
	bg.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	bg.BackgroundTransparency = 0.3
	bg.BorderSizePixel = 0
	bg.Parent = billboard
	
	-- 等級文字
	local levelText = Instance.new("TextLabel")
	levelText.Size = UDim2.fromScale(1, 0.5)
	levelText.Position = UDim2.fromScale(0, 0)
	levelText.BackgroundTransparency = 1
	levelText.Text = "⭐ Level " .. level .. " ⭐"
	levelText.TextColor3 = color
	levelText.TextScaled = true
	levelText.Font = Enum.Font.FredokaOne
	levelText.Parent = bg
	
	-- 名稱文字
	local nameText = Instance.new("TextLabel")
	nameText.Size = UDim2.fromScale(1, 0.5)
	nameText.Position = UDim2.fromScale(0, 0.5)
	nameText.BackgroundTransparency = 1
	nameText.Text = name
	nameText.TextColor3 = Color3.new(1, 1, 1)
	nameText.TextScaled = true
	nameText.Font = Enum.Font.GothamBold
	nameText.Parent = bg
	
	-- 裝飾：可愛的柱子
	for i = 1, 4 do
		local angle = (i - 1) * math.pi / 2
		local pillarPos = position + Vector3.new(math.cos(angle) * 6, 2.5, math.sin(angle) * 6)
		local pillar = ensurePart(zoneName .. "_Pillar" .. i, Workspace, {
			Position = pillarPos,
			Size = Vector3.new(1, 5, 1),
			Color = color,
			Material = Enum.Material.Wood,
			CanCollide = true
		})
	end
	
	return zone
end

-- 建立排行榜看板 (降低高度)
ensurePart("WordGameRank", Workspace, {
	Position = Vector3.new(0, 12, 55), -- 降低高度
	Size = Vector3.new(40, 25, 1),
	Color = Color3.fromRGB(27, 27, 27),
	Material = Enum.Material.Metal
})

-- 建立各等級區域 (排列成一排)
local levels = {
	{ level = 1000, pos = Vector3.new(-50, 1.5, 15), color = Color3.fromRGB(46, 204, 113), name = "🌱 基礎", desc = "最常見1000字" },
	{ level = 2000, pos = Vector3.new(-25, 1.5, 15), color = Color3.fromRGB(52, 152, 219), name = "🌿 進階", desc = "2000常用字" },
	{ level = 3000, pos = Vector3.new(0, 1.5, 15), color = Color3.fromRGB(155, 89, 182), name = "🌳 中級", desc = "3000中等字" },
	{ level = 4000, pos = Vector3.new(25, 1.5, 15), color = Color3.fromRGB(241, 196, 15), name = "🍂 高級", desc = "4000難度字" },
	{ level = 5000, pos = Vector3.new(50, 1.5, 15), color = Color3.fromRGB(231, 76, 60), name = "🔥 專業", desc = "5000專業術語" },
}

for _, info in ipairs(levels) do
	createLevelZone(info.level, info.pos, info.color, info.name, info.desc)
end

-- 建立單人練習區域 (更可愛)
local function createSinglePlayerZone()
	local position = Vector3.new(0, 1.5, 35)
	
	-- 底座
	ensurePart("WordGameZone_Base", Workspace, {
		Position = position - Vector3.new(0, 0.5, 0),
		Size = Vector3.new(14, 1, 14),
		Color = Color3.fromRGB(0, 153, 255),
		Material = Enum.Material.Neon,
		CanCollide = true
	})
	
	-- 觸發區域
	ensurePart("WordGameZone", Workspace, {
		Position = position,
		Size = Vector3.new(8, 0.5, 8),
		Color = Color3.fromRGB(0, 153, 255),
		Material = Enum.Material.Neon,
		Transparency = 0.3,
		CanCollide = false
	}, {
		{
			ClassName = "ProximityPrompt",
			Name = "InteractPrompt",
			Properties = {
				ActionText = "點我\n練習",
				ObjectText = "🎮 單人練習",
				KeyboardKeyCode = Enum.KeyCode.E,
				RequiresLineOfSight = false,
				HoldDuration = 0.3,
				MaxActivationDistance = 20
			}
		}
	})
	
	-- 提示看板
	local hintPart = ensurePart("WordGameZone_Hint", Workspace, {
		Position = position + Vector3.new(0, 6, 0),
		Size = Vector3.new(10, 4, 0.5),
		Color = Color3.fromRGB(0, 153, 255),
		Material = Enum.Material.Wood,
		CanCollide = false
	})
	
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(200, 80)
	billboard.StudsOffset = Vector3.new(0, 0, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = hintPart
	
	local bg = Instance.new("Frame")
	bg.Size = UDim2.fromScale(1, 1)
	bg.BackgroundColor3 = Color3.fromRGB(0, 153, 255)
	bg.BackgroundTransparency = 0.3
	bg.BorderSizePixel = 0
	bg.Parent = billboard
	
	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.Text = "🎮 單人練習"
	text.TextColor3 = Color3.new(1, 1, 1)
	text.TextScaled = true
	text.Font = Enum.Font.FredokaOne
	text.Parent = bg
	
	-- 裝飾柱子
	for i = 1, 4 do
		local angle = (i - 1) * math.pi / 2
		local pillarPos = position + Vector3.new(math.cos(angle) * 6, 2.5, math.sin(angle) * 6)
		ensurePart("SingleZone_Pillar" .. i, Workspace, {
			Position = pillarPos,
			Size = Vector3.new(1, 5, 1),
			Color = Color3.fromRGB(0, 153, 255),
			Material = Enum.Material.Wood,
			CanCollide = true
		})
	end
end

createSinglePlayerZone()

-- 6. 生成所有必要的資源
createTeacherRig()

-- 確保 RemoteEvent 存在
local gameRemote = ReplicatedStorage:FindFirstChild("GameRemote")
if not gameRemote then
	gameRemote = Instance.new("RemoteEvent")
	gameRemote.Name = "GameRemote"
	gameRemote.Parent = ReplicatedStorage
	print(">>> [SERVER] 創建 GameRemote")
end

local getWordList = ReplicatedStorage:FindFirstChild("GetWordList")
if not getWordList then
	getWordList = Instance.new("RemoteFunction")
	getWordList.Name = "GetWordList"
	getWordList.Parent = ReplicatedStorage
	print(">>> [SERVER] 創建 GetWordList")
end

print("✅ [SERVER] MapSetup 完成，場景物件已建立。")
print(">>> 等級區域: Level 1000, 2000, 3000, 4000, 5000 已建立")
