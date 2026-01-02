local Workspace = game:GetService("Workspace")
local ServerStorage = game:GetService("ServerStorage")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Merged AssetProvider logic to resolve require() issue
local function createTeacherRig()
	local Shared = ReplicatedStorage:WaitForChild("Shared")

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

-- 6. 生成所有必要的資源
createTeacherRig()

print("✅ [SERVER] MapSetup 完成，場景物件已建立。")