-- Boomerang.client.lua
-- Place this LocalScript in StarterPlayer > StarterPlayerScripts.
-- Creates a decorative, client-only classic-style boomerang Tool.
-- It has no projectile, hit detection, damage, remotes, or server effects.

local Players = game:GetService("Players")

local player = Players.LocalPlayer
if not player then
    return
end

local backpack = player:WaitForChild("Backpack")
local TOOL_NAME = "Local Boomerang"

-- Remove an older copy so rerunning the LocalScript stays clean.
local existing = backpack:FindFirstChild(TOOL_NAME)
if existing then
    existing:Destroy()
end

local character = player.Character
if character then
    local equippedCopy = character:FindFirstChild(TOOL_NAME)
    if equippedCopy then
        equippedCopy:Destroy()
    end
end

local tool = Instance.new("Tool")
tool.Name = TOOL_NAME
tool.ToolTip = "Decorative classic-style boomerang"
tool.RequiresHandle = true
tool.CanBeDropped = false
tool.Grip = CFrame.new(0, -0.12, -0.28) * CFrame.Angles(math.rad(-8), 0, math.rad(-18))
tool:SetAttribute("ClientOnly", true)
tool:SetAttribute("DecorativeOnly", true)

-- The central section is the Tool's required Handle.
local handle = Instance.new("Part")
handle.Name = "Handle"
handle.Size = Vector3.new(0.22, 0.18, 0.72)
handle.Material = Enum.Material.Wood
handle.Color = Color3.fromRGB(151, 91, 48)
handle.TopSurface = Enum.SurfaceType.Smooth
handle.BottomSurface = Enum.SurfaceType.Smooth
handle.CanCollide = false
handle.CanTouch = false
handle.CanQuery = false
handle.Massless = true
handle.Anchored = false
handle.Parent = tool

local function makePiece(name, size, color, relativeCFrame, shape)
    local piece
    if shape == "wedge" then
        piece = Instance.new("WedgePart")
    else
        piece = Instance.new("Part")
    end

    piece.Name = name
    piece.Size = size
    piece.Material = Enum.Material.Wood
    piece.Color = color
    piece.TopSurface = Enum.SurfaceType.Smooth
    piece.BottomSurface = Enum.SurfaceType.Smooth
    piece.CanCollide = false
    piece.CanTouch = false
    piece.CanQuery = false
    piece.Massless = true
    piece.Anchored = false
    piece.CFrame = relativeCFrame
    piece.Parent = tool

    local weld = Instance.new("WeldConstraint")
    weld.Part0 = handle
    weld.Part1 = piece
    weld.Parent = handle

    return piece
end

-- Short overlapping wooden sections form a curved V silhouette.
local base = handle.CFrame
local darkWood = Color3.fromRGB(151, 91, 48)
local warmWood = Color3.fromRGB(177, 116, 65)

local pieces = {
    { "LeftInner",  Vector3.new(0.22, 0.18, 0.72), darkWood, CFrame.new(-0.20, 0, -0.48) * CFrame.Angles(0, math.rad(-27), 0) },
    { "LeftOuter",  Vector3.new(0.20, 0.16, 0.62), warmWood, CFrame.new(-0.56, 0, -0.88) * CFrame.Angles(0, math.rad(-48), 0) },
    { "RightInner", Vector3.new(0.22, 0.18, 0.72), darkWood, CFrame.new(0.20, 0, -0.48) * CFrame.Angles(0, math.rad(27), 0) },
    { "RightOuter", Vector3.new(0.20, 0.16, 0.62), warmWood, CFrame.new(0.56, 0, -0.88) * CFrame.Angles(0, math.rad(48), 0) },
}

for _, data in ipairs(pieces) do
    makePiece(data[1], data[2], data[3], base * data[4])
end

-- Small tapered tips finish the ends of the decorative prop.
makePiece(
    "LeftTip",
    Vector3.new(0.20, 0.16, 0.34),
    darkWood,
    base * CFrame.new(-0.82, 0, -1.13) * CFrame.Angles(0, math.rad(-58), 0),
    "wedge"
)

makePiece(
    "RightTip",
    Vector3.new(0.20, 0.16, 0.34),
    darkWood,
    base * CFrame.new(0.82, 0, -1.13) * CFrame.Angles(0, math.rad(58), 0),
    "wedge"
)

tool.Parent = backpack
