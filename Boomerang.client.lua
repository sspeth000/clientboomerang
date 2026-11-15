-- Boomerang.client.lua
-- Place this LocalScript in StarterPlayer > StarterPlayerScripts.
-- Creates a visual-only Boomerang Tool in the local player's Backpack.
-- No remotes are used and no server inventory is modified.

local Players = game:GetService("Players")

local player = Players.LocalPlayer
if not player then
    return
end

local backpack = player:WaitForChild("Backpack")

local TOOL_NAME = "Local Boomerang"

-- Make rerunning the script safe: keep only one copy.
local existing = backpack:FindFirstChild(TOOL_NAME)
if existing then
    existing:Destroy()
end

local character = player.Character
if character then
    local equipped = character:FindFirstChild(TOOL_NAME)
    if equipped then
        equipped:Destroy()
    end
end

local tool = Instance.new("Tool")
tool.Name = TOOL_NAME
tool.ToolTip = "A locally-created boomerang"
tool.RequiresHandle = true
tool.CanBeDropped = false
tool.Grip = CFrame.new(0, -0.15, -0.35) * CFrame.Angles(0, 0, math.rad(-12))
tool:SetAttribute("ClientOnly", true)

local handle = Instance.new("Part")
handle.Name = "Handle"
handle.Size = Vector3.new(0.28, 0.42, 2.1)
handle.Material = Enum.Material.Wood
handle.Color = Color3.fromRGB(145, 83, 43)
handle.TopSurface = Enum.SurfaceType.Smooth
handle.BottomSurface = Enum.SurfaceType.Smooth
handle.CanCollide = false
handle.CanTouch = false
handle.CanQuery = false
handle.Massless = true
handle.Parent = tool

-- A second angled arm gives the tool a recognizable boomerang silhouette.
local wing = Instance.new("Part")
wing.Name = "Wing"
wing.Size = Vector3.new(0.28, 0.42, 1.85)
wing.Material = Enum.Material.Wood
wing.Color = Color3.fromRGB(177, 111, 59)
wing.TopSurface = Enum.SurfaceType.Smooth
wing.BottomSurface = Enum.SurfaceType.Smooth
wing.CanCollide = false
wing.CanTouch = false
wing.CanQuery = false
wing.Massless = true
wing.CFrame = handle.CFrame * CFrame.new(0, 0, -0.78) * CFrame.Angles(0, math.rad(105), 0)
wing.Parent = tool

local weld = Instance.new("WeldConstraint")
weld.Part0 = handle
weld.Part1 = wing
weld.Parent = handle

tool.Parent = backpack
