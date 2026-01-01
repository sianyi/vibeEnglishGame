local Workspace = game:GetService("Workspace")
local ServerStorage = game:GetService("ServerStorage")

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

-- 1. 建立教室資料夾
local classroom = Workspace:FindFirstChild("Classroom")
if not classroom then
	classroom = Instance.new("Folder")
	classroom.Name = "Classroom"
	classroom.Parent = Workspace
end

-- 2. 建立教室物件
ensurePart("Floor", classroom, {
	Position = Vector3.new(0, 20, -100),
	Size = Vector3.new(50, 2, 50),
	Color = Color3.fromRGB(75, 151, 75),
	Material = Enum.Material.Grass
})

ensurePart("Blackboard", classroom, {
	Position = Vector3.new(0, 28.5, -118),
	Size = Vector3.new(16, 8, 1),
	Color = Color3.fromRGB(27, 27, 27),
	Material = Enum.Material.Slate
})

ensurePart("AnswerPadCorrect", classroom, {
	Position = Vector3.new(-10, 21.1, -105),
	Size = Vector3.new(10, 0.2, 10),
	Color = Color3.fromRGB(46, 204, 113),
	Material = Enum.Material.Neon
})

ensurePart("AnswerPadWrong", classroom, {
	Position = Vector3.new(10, 21.1, -105),
	Size = Vector3.new(10, 0.2, 10),
	Color = Color3.fromRGB(231, 76, 60),
	Material = Enum.Material.Neon
})

-- 2.1 建立教室牆壁與天花板
ensurePart("WallBack", classroom, {
	Position = Vector3.new(0, 31, -120),
	Size = Vector3.new(40, 20, 1),
	Color = Color3.fromRGB(204, 191, 153),
	Material = Enum.Material.SmoothPlastic
})

ensurePart("WallFront", classroom, {
	Position = Vector3.new(0, 31, -80),
	Size = Vector3.new(40, 20, 1),
	Color = Color3.fromRGB(204, 191, 153),
	Material = Enum.Material.SmoothPlastic
})

ensurePart("WallLeft", classroom, {
	Position = Vector3.new(-20, 31, -100),
	Size = Vector3.new(1, 20, 40),
	Color = Color3.fromRGB(204, 191, 153),
	Material = Enum.Material.SmoothPlastic
})

ensurePart("WallRight", classroom, {
	Position = Vector3.new(20, 31, -100),
	Size = Vector3.new(1, 20, 40),
	Color = Color3.fromRGB(204, 191, 153),
	Material = Enum.Material.SmoothPlastic
})

ensurePart("Ceiling", classroom, {
	Position = Vector3.new(0, 41.5, -100),
	Size = Vector3.new(40, 1, 40),
	Color = Color3.fromRGB(204, 204, 204),
	Material = Enum.Material.Concrete
})

ensurePart("ClassroomLight", classroom, {
	Position = Vector3.new(0, 41, -100),
	Size = Vector3.new(4, 0.5, 8),
	Color = Color3.fromRGB(255, 255, 255),
	Material = Enum.Material.Neon
}, {
	{ ClassName = "PointLight", Name = "Light", Properties = { Range = 30, Brightness = 1.5 } }
})

-- 3. 建立排行榜看板
ensurePart("WordGameRank", Workspace, {
	Position = Vector3.new(0, 45, 60),
	Size = Vector3.new(48, 30, 1),
	Color = Color3.fromRGB(27, 27, 27),
	Material = Enum.Material.Metal
})

-- 4. 建立遊戲開始區域 (含 ProximityPrompt)
ensurePart("WordGameZone", Workspace, {
	Position = Vector3.new(0, 0.6, 15),
	Size = Vector3.new(12, 1, 12),
	Color = Color3.fromRGB(0, 153, 255),
	Material = Enum.Material.Neon,
	CanCollide = false
}, {
	{
		ClassName = "ProximityPrompt",
		Name = "InteractPrompt",
		Properties = {
			ActionText = "開始挑戰",
			ObjectText = "單字遊戲",
			KeyboardKeyCode = Enum.KeyCode.E,
			RequiresLineOfSight = false,
			HoldDuration = 0.5,
			MaxActivationDistance = 15
		}
	}
})

-- 5. 建立告示牌 (含 SurfaceGui)
local sign = ensurePart("WordGameSign", Workspace, {
	Position = Vector3.new(8, 3, 15),
	Size = Vector3.new(1, 6, 6),
	Color = Color3.fromRGB(153, 102, 51),
	Material = Enum.Material.Wood
})

if not sign:FindFirstChild("SignGui") then
	local gui = Instance.new("SurfaceGui")
	gui.Name = "SignGui"
	gui.Face = Enum.NormalId.Left
	gui.PixelsPerStud = 50
	gui.Parent = sign
	
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.Text = "1000單字\n測試遊戲"
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextScaled = true
	label.Font = Enum.Font.GothamBlack
	label.Parent = gui
end

-- 6. 建立 ClickPart
ensurePart("ClickPart", Workspace, {
	Position = Vector3.new(10, 5, 0),
	Size = Vector3.new(4, 4, 4),
	Color = Color3.fromRGB(255, 204, 0),
	Anchored = true
})

print("✅ [SERVER] MapSetup 完成，場景物件已建立。")