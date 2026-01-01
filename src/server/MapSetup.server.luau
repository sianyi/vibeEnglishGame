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