-- MapSetup.server.luau
-- 大廳場景已靜態放置於 Studio Workspace，此腳本只負責：
-- 1. 建立 TeacherRig（動態，需要 Players API）
-- 2. 建立 RemoteEvent / RemoteFunction
-- 3. 通知其他腳本初始化完成

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

-- 確保 Shared 資料夾存在
local Shared = ReplicatedStorage:FindFirstChild("Shared")
if not Shared then
	Shared = Instance.new("Folder")
	Shared.Name = "Shared"
	Shared.Parent = ReplicatedStorage
end

-- TeacherRig（動態生成，需要 HumanoidDescription API）
local function createTeacherRig()
	local existing = Shared:FindFirstChild("TeacherRig")
	if existing then existing:Destroy() end

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
			if part:IsA("BasePart") then part.Anchored = true end
		end
		rig.Parent = Shared
		print("✅ [SERVER] TeacherRig 生成完成")
	else
		warn("⚠️ [SERVER] TeacherRig 生成失敗")
	end
end

-- Remotes
local function ensureRemote(className, name)
	local existing = ReplicatedStorage:FindFirstChild(name)
	if not existing then
		existing = Instance.new(className)
		existing.Name = name
		existing.Parent = ReplicatedStorage
		print(">>> [SERVER] 創建 " .. name)
	end
	return existing
end

createTeacherRig()
ensureRemote("RemoteEvent", "GameRemote")
ensureRemote("RemoteFunction", "GetWordList")

-- 通知其他腳本
ServerScriptService:SetAttribute("MapSetupComplete", true)
print("✅ [SERVER] MapSetup 完成")
