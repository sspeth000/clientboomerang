-- Boomerang.client.lua
-- Place this LocalScript in StarterPlayer > StarterPlayerScripts.
-- Recreates the original gear's Handle mesh, texture, grip, attachment, and sound.
-- Throwing is a local visual animation only. No projectile physics, hit detection,
-- damage, touch effects, remote calls, or server-side changes are performed.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
if not player then
    return
end

local backpack = player:WaitForChild("Backpack")

local TOOL_NAME = "Local Boomerang"
local MESH_ID = "rbxassetid://13425802"
local TEXTURE_ID = "rbxassetid://13425822"
local TOOL_TEXTURE_ID = "rbxassetid://13426134"
local FLYING_SOUND_ID = "rbxassetid://18478970"

-- Tuned from the original launcher/controller timing and target distances.
local LAUNCH_OFFSET = 10
local OUTBOUND_DISTANCE = 100
local OUTBOUND_DURATION = 0.9
local RETURN_DELAY = 0.5
local RETURN_DURATION = 0.85
local COOLDOWN = 1
local ARC_HEIGHT = 3
local SPIN_RATE = 10 -- Original controller used RotVelocity = Vector3.new(0, 10, 0).

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
tool.ToolTip = "Classic boomerang (local visual throw)"
tool.TextureId = TOOL_TEXTURE_ID
tool.RequiresHandle = true
tool.CanBeDropped = false

-- Original Tool Grip values from gear/src/init.meta.json.
tool.Grip = CFrame.new(
    0.5, 0, 0,
    0, 0, 1,
    1, 0, 0,
    0, 1, 0
)

tool:SetAttribute("ClientOnly", true)
tool:SetAttribute("DecorativeOnly", true)

-- Original Handle dimensions, color, and material from the uploaded gear files.
local handle = Instance.new("Part")
handle.Name = "Handle"
handle.Size = Vector3.new(3, 1.6, 1)
handle.Color = Color3.new(0.3882353, 0.372549, 0.384314)
handle.Material = Enum.Material.Plastic
handle.TopSurface = Enum.SurfaceType.Smooth
handle.BottomSurface = Enum.SurfaceType.Smooth
handle.CanCollide = false
handle.CanTouch = false
handle.CanQuery = false
handle.Massless = true
handle.Anchored = false
handle.Parent = tool

-- Original FileMesh and texture references from Handle/Mesh.model.json.
local mesh = Instance.new("SpecialMesh")
mesh.Name = "Mesh"
mesh.MeshType = Enum.MeshType.FileMesh
mesh.MeshId = MESH_ID
mesh.TextureId = TEXTURE_ID
mesh.Scale = Vector3.new(1, 1, 1)
mesh.Parent = handle

-- Original attachment position from Handle/RightGripAttachment.model.json.
local gripAttachment = Instance.new("Attachment")
gripAttachment.Name = "RightGripAttachment"
gripAttachment.CFrame = CFrame.new(1.5, 0, 0)
gripAttachment.Parent = handle

-- Original flying sound asset. It is only played on the local visual copy.
local flyingSound = Instance.new("Sound")
flyingSound.Name = "FlyingSound"
flyingSound.SoundId = FLYING_SOUND_ID
flyingSound.Volume = 1
flyingSound.Parent = handle

local busy = false
local lastActivation = 0
local activeVisual = nil
local equippedMouse = nil
local cursorReady = false

local NORMAL_CURSOR = "rbxasset://textures\\GunCursor.png"
local WAIT_CURSOR = "rbxasset://textures\\GunWaitCursor.png"

local function getCharacter()
    local currentCharacter = player.Character
    if not currentCharacter then
        return nil, nil
    end

    local humanoid = currentCharacter:FindFirstChildOfClass("Humanoid")
    local currentHandle = currentCharacter:FindFirstChild(TOOL_NAME)
    if not humanoid or not currentHandle or not currentHandle:IsA("Tool") then
        return nil, nil
    end

    local visualHandle = currentHandle:FindFirstChild("Handle")
    if not visualHandle or not visualHandle:IsA("BasePart") then
        return nil, nil
    end

    return currentCharacter, visualHandle
end

local function animateArc(visual, startCFrame, getEndCFrame, duration, spinSign, arcHeight)
    local elapsed = 0
    local startRotation = startCFrame - startCFrame.Position

    while elapsed < duration and visual.Parent do
        local deltaTime = RunService.RenderStepped:Wait()
        elapsed += deltaTime

        local alpha = math.clamp(elapsed / duration, 0, 1)
        local endCFrame = getEndCFrame()
        if not endCFrame then
            break
        end

        local startPosition = startCFrame.Position
        local endPosition = endCFrame.Position
        local position = startPosition:Lerp(endPosition, alpha)
        position += Vector3.new(0, math.sin(alpha * math.pi) * arcHeight, 0)

        local endRotation = endCFrame - endCFrame.Position
        local baseRotation = startRotation:Lerp(endRotation, alpha)
        local spin = CFrame.Angles(0, SPIN_RATE * elapsed * spinSign, 0)

        visual.CFrame = CFrame.new(position) * baseRotation * spin
    end
end

local function performLocalThrow()
    if busy or (os.clock() - lastActivation) < COOLDOWN then
        return
    end

    local currentCharacter, currentHandle = getCharacter()
    if not currentCharacter or not currentHandle then
        return
    end

    local head = currentCharacter:FindFirstChild("Head")
    local root = currentCharacter:FindFirstChild("HumanoidRootPart") or currentCharacter.PrimaryPart
    if not head or not root then
        return
    end

    busy = true
    lastActivation = os.clock()

    -- Match the original Local Gui cursor feedback and one-second cooldown.
    if equippedMouse then
        equippedMouse.Icon = WAIT_CURSOR
        cursorReady = false
        task.delay(COOLDOWN, function()
            if equippedMouse then
                equippedMouse.Icon = NORMAL_CURSOR
                cursorReady = true
            end
        end)
    end

    local camera = workspace.CurrentCamera
    local aimPosition
    if equippedMouse then
        local ok, hit = pcall(function()
            return equippedMouse.Hit.Position
        end)
        if ok and hit then
            aimPosition = hit
        end
    end

    if not aimPosition then
        aimPosition = head.Position + (camera and camera.CFrame.LookVector or root.CFrame.LookVector) * 100
    end

    local direction = aimPosition - head.Position
    if direction.Magnitude < 0.001 then
        direction = root.CFrame.LookVector
    else
        direction = direction.Unit
    end

    -- The original launcher starts roughly ten studs ahead and aims another
    -- hundred studs forward. This is a visual path only, not a physics launch.
    local startCFrame = currentHandle.CFrame
    local outboundPosition = root.Position + direction * (LAUNCH_OFFSET + OUTBOUND_DISTANCE)
    local outboundCFrame = CFrame.lookAt(outboundPosition, outboundPosition + direction)

    -- Anchored, non-colliding clone: it cannot touch or affect anything.
    local visual = currentHandle:Clone()
    visual.Name = "LocalBoomerangVisual"
    visual.Anchored = true
    visual.CanCollide = false
    visual.CanTouch = false
    visual.CanQuery = false
    visual.Massless = true
    visual.CFrame = startCFrame
    visual.Parent = workspace
    activeVisual = visual

    currentHandle.LocalTransparencyModifier = 1

    local sound = visual:FindFirstChild("FlyingSound")
    if sound and sound:IsA("Sound") then
        sound.Looped = true
        sound:Play()
    end

    animateArc(
        visual,
        startCFrame,
        function()
            return outboundCFrame
        end,
        OUTBOUND_DURATION,
        1,
        ARC_HEIGHT
    )

    -- The original controller pauses briefly near the far target before
    -- redirecting the boomerang toward the thrower's Head.
    if visual.Parent then
        task.wait(RETURN_DELAY)
    end

    animateArc(
        visual,
        visual.CFrame,
        function()
            if not head.Parent then
                return nil
            end
            return CFrame.lookAt(head.Position, head.Position + direction)
        end,
        RETURN_DURATION,
        -1,
        ARC_HEIGHT * 0.5
    )

    if visual and visual.Parent then
        visual:Destroy()
    end

    activeVisual = nil
    if currentHandle and currentHandle.Parent then
        currentHandle.LocalTransparencyModifier = 0
    end

    busy = false
end

tool.Equipped:Connect(function(mouse)
    equippedMouse = mouse
    cursorReady = true
    if equippedMouse then
        equippedMouse.Icon = NORMAL_CURSOR
    end
end)

tool.Activated:Connect(performLocalThrow)

tool.Unequipped:Connect(function()
    equippedMouse = nil
    cursorReady = false

    -- Do not leave the real Handle hidden if the player switches tools mid-animation.
    local _, currentHandle = getCharacter()
    if currentHandle then
        currentHandle.LocalTransparencyModifier = 0
    end
end)

player.CharacterRemoving:Connect(function()
    if activeVisual then
        activeVisual:Destroy()
        activeVisual = nil
    end
    busy = false
end)

tool.Parent = backpack
