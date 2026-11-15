-- Boomerang.client.lua
-- Place this LocalScript in StarterPlayer > StarterPlayerScripts.
-- Recreates the original gear's Handle mesh, texture, grip, attachment, and sound.
-- Throwing uses a client-created physics visual.
-- It collides with the world but has NoCollisionConstraints against player characters.
-- No damage, remote calls, or server changes.

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

-- Original launcher/controller values.
local LAUNCH_OFFSET = 10
local OUTBOUND_DISTANCE = 100
local INITIAL_VELOCITY = 150
local OUTBOUND_SWITCH_DISTANCE = 10
local RETURN_FINISH_DISTANCE = 5
local RETURN_DELAY = 0.5
local COOLDOWN = 1
local MAX_FLIGHT_TIME = 15 -- Cleanup guard if the character disappears or physics stalls.

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

-- Original launcher grip poses (gunUp and gunOut).
-- These are the exact axis vectors from BoomerangLauncher.server.luau.
local GUN_UP_GRIP = CFrame.fromMatrix(
    Vector3.new(0.5, 0, 0),
    Vector3.new(1, 0, 0),
    Vector3.new(0, 0.196, 0.981),
    Vector3.new(0, -0.981, 0.196)
)

local GUN_OUT_GRIP = CFrame.fromMatrix(
    Vector3.new(0.5, 0, 0),
    Vector3.new(1, 0, 0),
    Vector3.new(0, 0, 1),
    Vector3.new(0, -1, 0)
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
local cursorReady = true

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

-- Direct client-side translation of the original launcher/controller movement.
-- BodyPosition, initial velocity, rotation velocity, target distances, polling
-- intervals, and return timing follow the original source. The visual collides
-- with non-character world parts, while NoCollisionConstraints exclude players.
local function performLocalThrow()
    if busy or (os.clock() - lastActivation) < COOLDOWN then
        return
    end

    local currentCharacter, currentHandle = getCharacter()
    if not currentCharacter or not currentHandle then
        return
    end

    local head = currentCharacter:FindFirstChild("Head")
    local primaryPart = currentCharacter.PrimaryPart
    if not head or not primaryPart then
        return
    end

    busy = true
    lastActivation = os.clock()

    -- Original onActivated sequence: raise the grip, launch, then move
    -- into the follow-through pose after the original 0.1-second reload.
    tool.Grip = GUN_UP_GRIP
    task.delay(0.1, function()
        if tool and tool.Parent then
            tool.Grip = GUN_OUT_GRIP
        end
    end)

    if equippedMouse then
        equippedMouse.Icon = WAIT_CURSOR
        cursorReady = false
        task.delay(COOLDOWN, function()
            cursorReady = true
            if equippedMouse then
                equippedMouse.Icon = NORMAL_CURSOR
            end
        end)
    end

    local targetPosition
    if equippedMouse then
        local ok, mouseHit = pcall(function()
            return equippedMouse.Hit.Position
        end)
        if ok then
            targetPosition = mouseHit
        end
    end

    if not targetPosition then
        local camera = workspace.CurrentCamera
        local aimDirection = camera and camera.CFrame.LookVector or primaryPart.CFrame.LookVector
        targetPosition = head.Position + aimDirection * OUTBOUND_DISTANCE
    end

    -- Equivalent to the original (targetPos - character.Head.Position).Unit.
    local lookAt = targetPosition - head.Position
    if lookAt.Magnitude < 0.001 then
        lookAt = primaryPart.CFrame.LookVector
    else
        lookAt = lookAt.Unit
    end

    -- Equivalent to the original fire(v) spawn and target calculations.
    local spawnPosition = primaryPart.Position + lookAt * LAUNCH_OFFSET
    local outboundTarget = spawnPosition + lookAt * OUTBOUND_DISTANCE

    -- Clone only the Handle. It is created by this LocalScript and remains
    -- local to this client. It collides with world geometry, but not characters.
    local visual = currentHandle:Clone()
    visual.Name = "LocalBoomerangVisual"
    visual.Anchored = false
    visual.CanCollide = true
    visual.CanTouch = false
    visual.CanQuery = true
    visual.Massless = false
    -- Keep the equipped Handle's orientation so the mesh's flat face stays
    -- aligned with its grip instead of resetting it to world-axis alignment.
    -- Match the equipped Handle's orientation exactly. The held screenshot
    -- shows the correct plane already, so do not add an extra 90-degree turn.
    visual.CFrame = currentHandle.CFrame + (spawnPosition - currentHandle.Position)
    visual.Parent = workspace
    activeVisual = visual

    -- Prevent collisions with every player's character while preserving normal
    -- collision against the map and other non-character parts. Constraints are
    -- local to this visual and are also added for characters/parts that spawn
    -- while the boomerang is in flight.
    local collisionConnections = {}
    local function excludeCharacter(character)
        if not character then
            return
        end

        local function excludePart(descendant)
            if not descendant:IsA("BasePart") or not visual.Parent then
                return
            end

            local noCollision = Instance.new("NoCollisionConstraint")
            noCollision.Name = "ExcludePlayerCollision"
            noCollision.Part0 = visual
            noCollision.Part1 = descendant
            noCollision.Parent = visual
        end

        for _, descendant in ipairs(character:GetDescendants()) do
            excludePart(descendant)
        end

        table.insert(collisionConnections, character.DescendantAdded:Connect(excludePart))
    end

    for _, otherPlayer in ipairs(Players:GetPlayers()) do
        if otherPlayer.Character then
            excludeCharacter(otherPlayer.Character)
        end
        table.insert(collisionConnections, otherPlayer.CharacterAdded:Connect(excludeCharacter))
    end

    table.insert(collisionConnections, Players.PlayerAdded:Connect(function(otherPlayer)
        if otherPlayer.Character then
            excludeCharacter(otherPlayer.Character)
        end
        table.insert(collisionConnections, otherPlayer.CharacterAdded:Connect(excludeCharacter))
    end))

    currentHandle.LocalTransparencyModifier = 1

    -- Original launcher movement setup, adapted to the non-interactive clone.
    visual.Position = spawnPosition
    -- The boomerang mesh is broad across local X/Y, so spin around its local
    -- depth axis (local Z) to make it rotate flat like a propeller.
    local spinAxis = visual.CFrame.LookVector
    visual.RotVelocity = spinAxis * 10
    visual.Velocity = lookAt * INITIAL_VELOCITY

    local bodyPosition = Instance.new("BodyPosition")
    bodyPosition.MaxForce = Vector3.new(1e3, 1e3, 1e3)
    bodyPosition.D = 1.25e3
    bodyPosition.P = 1e3
    bodyPosition.Position = outboundTarget
    bodyPosition.Parent = visual

    -- Catch detection stays active for the entire flight, including the
    -- initial launch and outbound turn. The player's NoCollisionConstraints
    -- remain in place, so catching does not physically shove the character.
    local caught = false
    local overlapParams = OverlapParams.new()
    overlapParams.FilterType = Enum.RaycastFilterType.Include
    overlapParams.FilterDescendantsInstances = { currentCharacter }

    local catchConnection
    catchConnection = RunService.Heartbeat:Connect(function()
        if caught or not visual.Parent then
            return
        end

        local overlappingParts = workspace:GetPartsInPart(visual, overlapParams)
        if #overlappingParts > 0 then
            caught = true
            if bodyPosition.Parent then
                bodyPosition:Destroy()
            end
            if visual.Parent then
                visual:Destroy()
            end
        end
    end)

    local sound = visual:FindFirstChild("FlyingSound")
    if sound and sound:IsA("Sound") then
        sound.Looped = true
        sound:Play()
    end

    -- Original controller's outbound distance check, including its 0.1s polling.
    local flightStarted = os.clock()
    local validCharacter = true

    while visual.Parent and bodyPosition.Parent do
        task.wait(0.1)

        if os.clock() - flightStarted > MAX_FLIGHT_TIME then
            validCharacter = false
            break
        end

        if not head.Parent then
            validCharacter = false
            break
        end

        if (visual.Position - bodyPosition.Position).Magnitude < OUTBOUND_SWITCH_DISTANCE then
            -- Original creator lookup/return-target assignment, using the local
            -- player reference instead of a server-created creator ObjectValue.
            local creatorCharacter = player.Character
            local creatorHead = creatorCharacter and creatorCharacter:FindFirstChild("Head")
            if not creatorHead then
                validCharacter = false
                break
            end

            -- The boomerang has reached its outbound destination.
            -- Drop the guidance force so gravity takes over; it only returns
            -- to the player when the player physically overlaps it.
            bodyPosition:Destroy()
            break
        end
    end

    -- Remove any remaining guidance force (for example if the flight guard
    -- or character check ended the outbound loop early).
    if bodyPosition.Parent then
        bodyPosition:Destroy()
    end

    -- No automatic return: after reaching the outbound destination the
    -- boomerang falls under gravity and remains catchable on the ground.
    -- Keep the catch overlap check alive until the player actually touches it.
    while visual.Parent and not caught do
        task.wait(0.1)
    end

    if sound and sound.Parent then
        sound:Stop()
    end

    if catchConnection then
        catchConnection:Disconnect()
    end

    for _, connection in ipairs(collisionConnections) do
        connection:Disconnect()
    end

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

    -- Restore the real Handle even though the Tool has moved back to Backpack.
    local currentHandle = tool:FindFirstChild("Handle")
    if currentHandle and currentHandle:IsA("BasePart") then
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
