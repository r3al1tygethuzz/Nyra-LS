--[[
    Nyra LS -- Complete Script
    Modern UI + Full Aimbot + Smooth Fly (BodyVelocity)
    Toggle fly: F key
    Toggle aimbot: via UI or Q key (hold mode)
]]

-- =============================================
--  SERVICES
-- =============================================
local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService     = game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer
local Mouse       = LocalPlayer:GetMouse()
local Camera      = workspace.CurrentCamera

-- =============================================
--  CONFIG
-- =============================================
local Config = {}

Config.Aim = {
    Enabled        = false,
    Smoothness     = 0.15,
    Prediction     = true,
    PredictionTime = 0.12,
    TargetPart     = "Head",
    AllowedParts   = { "Head", "UpperTorso", "HumanoidRootPart" },
    -- "camera" = lerp/mousemoverel from screen center (crosshair aim)
    -- "cursor" = FOV circle follows mouse, aim moves mouse toward target
    Mode           = "camera",
}
Config.FOV = {
    Enabled      = true,
    Radius       = 150,
    Visible      = true,
    Thickness    = 2,
    Transparency = 0.5,
}
Config.Targeting = {
    TeamCheck       = true,
    VisibilityCheck = true,
    MaxDistance     = 500,
    HealthFilter    = true,
    Whitelist       = {},
}
Config.Lock = {
    HoldToLock        = true,
    SwitchDelay       = 0.25,
    ReleaseOutsideFOV = true,
    Reacquire         = true,
}
Config.Input = {
    -- ActivationKey can be an Enum.KeyCode OR Enum.UserInputType (for mouse buttons)
    ActivationKey  = Enum.UserInputType.MouseButton2,
    HoldMode       = true,
    IsMouseButton  = true,   -- true when ActivationKey is a UserInputType
}
Config.Weapon = {
    ProjectileSpeed = 300,
    Gravity         = workspace.Gravity,
}
Config.Debug = { Enabled = false }

Config.ESP = {
    Enabled        = false,
    -- Boxes
    Boxes          = true,
    BoxColor       = Color3.fromRGB(255, 255, 255),
    BoxThickness   = 1,
    BoxFilled      = false,
    BoxFillTrans   = 0.85,
    -- Names
    Names          = true,
    NameColor      = Color3.fromRGB(255, 255, 255),
    NameSize       = 13,
    -- Health bar
    HealthBar      = true,
    HealthBarSide  = "left",   -- "left" or "right"
    -- Distance
    Distance       = true,
    DistanceColor  = Color3.fromRGB(200, 200, 200),
    MaxDistance    = 1000,
    -- Tracers
    Tracers        = false,
    TracerOrigin   = "bottom", -- "bottom" | "center" | "top"
    TracerColor    = Color3.fromRGB(255, 80, 80),
    TracerThick    = 1,
    -- Skeletons
    Skeletons      = false,
    SkeletonColor  = Color3.fromRGB(255, 255, 255),
    SkeletonThick  = 1,
    -- Chams (highlight)
    Chams          = false,
    ChamColor      = Color3.fromRGB(255, 80, 80),
    ChamTrans      = 0.5,
    -- Team filter (same as aimbot)
    TeamCheck      = true,
}

function Config.Save()
    if writefile then
        writefile("NyraConfig.json", game:GetService("HttpService"):JSONEncode(Config))
    end
end

function Config.Load()
    if readfile and isfile and isfile("NyraConfig.json") then
        local ok, data = pcall(function()
            return game:GetService("HttpService"):JSONDecode(readfile("NyraConfig.json"))
        end)
        if ok and data then
            for k, v in pairs(data) do
                if Config[k] then
                    for k2, v2 in pairs(v) do Config[k][k2] = v2 end
                end
            end
        end
    end
end

function Config.Reset()
    Config.Aim.Enabled               = false
    Config.Aim.Smoothness            = 0.15
    Config.FOV.Radius                = 150
    Config.Targeting.TeamCheck       = true
    Config.Targeting.VisibilityCheck = true
    Config.Lock.HoldToLock           = true
end

-- =============================================
--  MODULE: Visibility
-- =============================================
local Visibility = {}

function Visibility.Check(targetPosition)
    local origin    = Camera.CFrame.Position
    local direction = targetPosition - origin
    local params    = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    -- Bug fix: LocalPlayer.Character can be nil; guard it
    local filterList = {}
    if LocalPlayer.Character then
        table.insert(filterList, LocalPlayer.Character)
    end
    params.FilterDescendantsInstances = filterList
    local result = workspace:Raycast(origin, direction, params)
    if not result then return true end
    local hit = result.Instance
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            if hit:IsDescendantOf(player.Character) then return true end
        end
    end
    return false
end

-- =============================================
--  MODULE: FOV  (Drawing circle, guarded)
-- =============================================
local FOV = {}
do
    local circle = nil
    pcall(function()
        circle               = Drawing.new("Circle")
        circle.Color         = Color3.fromRGB(255, 255, 255)
        circle.Thickness     = Config.FOV.Thickness
        circle.Radius        = Config.FOV.Radius
        circle.Filled        = false
        circle.Visible       = Config.FOV.Visible and Config.FOV.Enabled
        circle.Transparency  = Config.FOV.Transparency
    end)
    FOV._circle = circle

    RunService.RenderStepped:Connect(function()
        if not circle then return end
        -- cursor mode: circle follows mouse
        -- camera mode: circle stays at screen center (crosshair)
        if Config.Aim.Mode == "cursor" then
            circle.Position = Vector2.new(Mouse.X, Mouse.Y)
        else
            local vp = Camera.ViewportSize
            circle.Position = Vector2.new(vp.X / 2, vp.Y / 2)
        end
        circle.Radius  = Config.FOV.Radius
        circle.Visible = Config.FOV.Visible and Config.FOV.Enabled
    end)
end

-- Returns the 2D reference point used for FOV checks (mouse or screen center)
local function getFOVOrigin()
    if Config.Aim.Mode == "cursor" then
        return Vector2.new(Mouse.X, Mouse.Y)
    else
        local vp = Camera.ViewportSize
        return Vector2.new(vp.X / 2, vp.Y / 2)
    end
end

function FOV.IsInsideFOV(worldPosition)
    local sp, onScreen = Camera:WorldToViewportPoint(worldPosition)
    if not onScreen then return false end
    return (Vector2.new(sp.X, sp.Y) - getFOVOrigin()).Magnitude <= Config.FOV.Radius
end

function FOV.DistanceToCursor(worldPosition)
    local sp, onScreen = Camera:WorldToViewportPoint(worldPosition)
    if not onScreen then return math.huge end
    return (Vector2.new(sp.X, sp.Y) - getFOVOrigin()).Magnitude
end

-- =============================================
--  MODULE: TargetManager
-- =============================================
local TargetManager = {}

local function GetPartPosition(character, partName)
    local part = character:FindFirstChild(partName)
    if part then return part.Position end
    for _, fb in ipairs(Config.Aim.AllowedParts) do
        local p = character:FindFirstChild(fb)
        if p then return p.Position end
    end
    return nil
end

function TargetManager.IsValid(player)
    if not player or player == LocalPlayer then return false end
    if #Config.Targeting.Whitelist > 0 then
        local found = false
        for _, name in ipairs(Config.Targeting.Whitelist) do
            if name == player.Name then found = true; break end
        end
        if not found then return false end
    end
    local char = player.Character
    if not char then return false end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 then return false end
    if Config.Targeting.TeamCheck then
        if LocalPlayer.Team and player.Team == LocalPlayer.Team then return false end
    end
    local root = char:FindFirstChild("HumanoidRootPart")
    if root then
        local myRoot = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        local origin = myRoot and myRoot.Position or Camera.CFrame.Position
        if (root.Position - origin).Magnitude > Config.Targeting.MaxDistance then return false end
    end
    return true
end

function TargetManager.GetClosest()
    local best, bestDist = nil, math.huge
    for _, player in ipairs(Players:GetPlayers()) do
        if TargetManager.IsValid(player) then
            local char = player.Character
            local pos  = GetPartPosition(char, Config.Aim.TargetPart)
            if not pos then continue end
            if Config.FOV.Enabled and not FOV.IsInsideFOV(pos) then continue end
            if Config.Targeting.VisibilityCheck and not Visibility.Check(pos) then continue end
            local d = FOV.DistanceToCursor(pos)
            if d < bestDist then bestDist = d; best = player end
        end
    end
    return best
end

-- =============================================
--  MODULE: Prediction
-- =============================================
local Prediction = {}

function Prediction.Calculate(character)
    local root = character:FindFirstChild("HumanoidRootPart")
    if not root then return nil end
    return root.Position + root.AssemblyLinearVelocity * Config.Aim.PredictionTime
end

-- =============================================
--  MODULE: AimController
-- =============================================
local AimController = {}
AimController.State         = "IDLE"
AimController.CurrentTarget = nil
AimController.IsLocked      = false

function AimController.Acquire()
    local t = TargetManager.GetClosest()
    if t then
        AimController.CurrentTarget = t
        AimController.State = "ACQUIRED"
    else
        AimController.State = "SEARCHING"
    end
    return t
end

function AimController.Lock()
    AimController.IsLocked = true
    AimController.State    = "LOCKED"
end

function AimController.Release()
    AimController.IsLocked      = false
    AimController.CurrentTarget = nil
    AimController.State         = "IDLE"
end

function AimController.Track()
    local target = AimController.CurrentTarget
    if not target or not TargetManager.IsValid(target) then
        AimController.State = "INVALID"
        if Config.Lock.Reacquire then AimController.Acquire()
        else AimController.Release() end
        return
    end
    AimController.State = "TRACKING"
    local char   = target.Character
    local aimPos = Config.Aim.Prediction and Prediction.Calculate(char) or nil
    if not aimPos then
        local part = char:FindFirstChild(Config.Aim.TargetPart)
                  or char:FindFirstChild("HumanoidRootPart")
        if not part then return end
        aimPos = part.Position
    end
    if Config.Lock.ReleaseOutsideFOV and Config.FOV.Enabled
        and not FOV.IsInsideFOV(aimPos) then
        AimController.Release(); return
    end

    local screenPos, onScreen = Camera:WorldToViewportPoint(aimPos)
    if not onScreen then return end

    -- Always use camera lerp for aiming, which works in all executors
    local targetCF = CFrame.new(Camera.CFrame.Position, aimPos)
    Camera.CFrame  = Camera.CFrame:Lerp(targetCF, Config.Aim.Smoothness)
end

-- =============================================
--  MODULE: Input
--  Input._active = key is currently held/toggled ON
--  The render loop runs when BOTH Config.Aim.Enabled
--  AND Input._active are true.
--  HOWEVER: the UI aimbot toggle sets Config.Aim.Enabled
--  and also forces Input._active = true so the loop
--  fires without needing a keypress.
-- =============================================
local Input = {}
Input._active = false

function Input.IsActive() return Input._active end

-- Called by the UI aimbot toggle to force-activate without a keypress
function Input.ForceActivate()
    Input._active = true
    AimController.Acquire()
    if AimController.CurrentTarget then AimController.Lock() end
end

function Input.ForceDeactivate()
    Input._active = false
    AimController.Release()
end

-- Helper: check if the input event matches the configured activation binding
local function inputMatchesActivation(input)
    if Config.Input.IsMouseButton then
        return input.UserInputType == Config.Input.ActivationKey
    else
        return input.KeyCode == Config.Input.ActivationKey
    end
end

UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end
    if not inputMatchesActivation(input) then return end
    if not Config.Aim.Enabled then return end

    if Config.Input.HoldMode then
        Input._active = true
    else
        Input._active = not Input._active
    end

    if Input._active then
        AimController.Acquire()
        if AimController.CurrentTarget then AimController.Lock() end
    else
        AimController.Release()
    end
end)

UserInputService.InputEnded:Connect(function(input, processed)
    if processed then return end
    if not Config.Input.HoldMode then return end
    if not inputMatchesActivation(input) then return end
    if Config.Aim.Enabled then
        Input._active = false
        AimController.Release()
    end
end)

-- =============================================
--  MAIN RENDER LOOP (aimbot)
-- =============================================
RunService.RenderStepped:Connect(function()
    -- Gate: aimbot must be enabled AND input must be active
    if not Config.Aim.Enabled or not Input.IsActive() then
        if AimController.IsLocked then AimController.Release() end
        return
    end

    local state = AimController.State
    if state == "IDLE" or state == "SEARCHING" then
        AimController.Acquire()
        if AimController.CurrentTarget then AimController.Lock() end
    elseif state == "LOCKED" or state == "TRACKING" then
        AimController.Track()
    elseif state == "INVALID" then
        if Config.Lock.Reacquire then AimController.Acquire()
        else AimController.Release() end
    end
end)

-- =============================================
--  FLY SYSTEM
--  Method: Anchored root + TweenService CFrame
--  Identical to the reference script approach.
--  No BodyVelocity, no physics constraints.
--  rootPart.Anchored = true kills gravity entirely.
--  TweenService tweens the CFrame each heartbeat
--  which looks like natural movement to anti-cheat.
-- =============================================
local FlyConfig = {
    Speed      = 1,    -- studs per heartbeat tick; 0.1 (creep) to 10 (very fast)
    SprintMult = 2,    -- multiplier when LeftShift held
    TweenTime  = 0.03, -- tween smoothness: lower = snappier, higher = smoother
    NoClip     = false, -- whether root CanCollide is kept off (phase through walls)
    Toggle     = Enum.KeyCode.F,
}

local flyActive = false
local flyConn   = nil

local function getRoot()
    local c = LocalPlayer.Character
    return c and c:FindFirstChild("HumanoidRootPart")
end

local function getHumanoid()
    local c = LocalPlayer.Character
    return c and c:FindFirstChildOfClass("Humanoid")
end

local function isValidChar()
    local c = LocalPlayer.Character
    return c and c.Parent
        and c:FindFirstChild("HumanoidRootPart")
        and c:FindFirstChildOfClass("Humanoid")
end

local function startFly()
    if not isValidChar() then return end
    local root = getRoot()
    local hum  = getHumanoid()

    -- Anchor stops gravity dead — no physics engine involvement at all
    root.Anchored    = true
    root.CanCollide  = false
    hum.PlatformStand = true

    flyConn = RunService.Heartbeat:Connect(function()
        if not flyActive or not isValidChar() then
            stopFly(); return
        end

        root = getRoot()
        if not root then return end

        local camCF = Camera.CFrame
        local speed = FlyConfig.Speed
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then
            speed = speed * FlyConfig.SprintMult
        end

        -- Horizontal movement in camera space (flattened look/right vectors)
        local horiz = Vector3.zero
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then
            horiz = horiz + camCF.LookVector * speed
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then
            horiz = horiz - camCF.LookVector * speed
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then
            horiz = horiz - camCF.RightVector * speed
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then
            horiz = horiz + camCF.RightVector * speed
        end

        -- Vertical
        local vert = Vector3.zero
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
            vert = Vector3.new(0, speed, 0)
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
            vert = Vector3.new(0, -speed, 0)
        end

        -- Target CFrame: new position, rotation aligned to camera (character faces where cam looks)
        local newPos     = root.Position + horiz + vert
        local targetCF   = CFrame.new(newPos) * camCF.Rotation

        -- TweenService tween looks exactly like a normal physics move to anti-cheat
        TweenService:Create(
            root,
            TweenInfo.new(FlyConfig.TweenTime, Enum.EasingStyle.Linear),
            { CFrame = targetCF }
        ):Play()
    end)
end

function stopFly()
    if flyConn then flyConn:Disconnect(); flyConn = nil end
    local root = getRoot()
    local hum  = getHumanoid()
    if root then
        root.Anchored   = false
        -- Only restore CanCollide if NoClip is off
        if not FlyConfig.NoClip then
            root.CanCollide = true
        end
    end
    if hum then
        hum.PlatformStand = false
    end
end

-- CharacterAdded: clean up fly state on respawn
LocalPlayer.CharacterAdded:Connect(function()
    flyActive = false
    if flyConn then flyConn:Disconnect(); flyConn = nil end
end)

-- =============================================
--  ESP ENGINE
--  Drawing-based per-player highlights.
--  All Drawing objects are pooled per player.
--  Runs on RenderStepped; cleans up on player leave.
-- =============================================
local ESP = {}
do
    -- Pool: { [player] = { box, boxFill, nameLabel, distLabel, healthBg, healthFill, tracer, skeleton[] } }
    local pool = {}

    -- Skeleton joint pairs for R15
    local SKELETON_PAIRS = {
        {"Head",       "UpperTorso"},
        {"UpperTorso", "LowerTorso"},
        {"UpperTorso", "LeftUpperArm"},
        {"LeftUpperArm","LeftLowerArm"},
        {"LeftLowerArm","LeftHand"},
        {"UpperTorso", "RightUpperArm"},
        {"RightUpperArm","RightLowerArm"},
        {"RightLowerArm","RightHand"},
        {"LowerTorso", "LeftUpperLeg"},
        {"LeftUpperLeg","LeftLowerLeg"},
        {"LeftLowerLeg","LeftFoot"},
        {"LowerTorso", "RightUpperLeg"},
        {"RightUpperLeg","RightLowerLeg"},
        {"RightLowerLeg","RightFoot"},
    }

    local function newDrawing(type, props)
        local ok, d = pcall(Drawing.new, type)
        if not ok then return nil end
        for k, v in pairs(props or {}) do
            pcall(function() d[k] = v end)
        end
        return d
    end

    local function createPool(player)
        local e = {}
        -- Bounding box outline
        e.box       = newDrawing("Square", { Filled = false, Color = Config.ESP.BoxColor,
                          Thickness = Config.ESP.BoxThickness, Visible = false })
        -- Box fill
        e.boxFill   = newDrawing("Square", { Filled = true, Color = Config.ESP.BoxColor,
                          Transparency = Config.ESP.BoxFillTrans, Visible = false })
        -- Name label
        e.name      = newDrawing("Text",   { Text = player.Name, Size = Config.ESP.NameSize,
                          Color = Config.ESP.NameColor, Center = true,
                          Outline = true, OutlineColor = Color3.new(0,0,0), Visible = false })
        -- Distance label
        e.dist      = newDrawing("Text",   { Text = "", Size = 11,
                          Color = Config.ESP.DistanceColor, Center = true,
                          Outline = true, OutlineColor = Color3.new(0,0,0), Visible = false })
        -- Health bar background (dark)
        e.healthBg  = newDrawing("Square", { Filled = true, Color = Color3.fromRGB(0,0,0),
                          Transparency = 0.4, Visible = false })
        -- Health bar fill (green→red based on health)
        e.healthFill= newDrawing("Square", { Filled = true, Color = Color3.fromRGB(0,255,0),
                          Visible = false })
        -- Tracer line
        e.tracer    = newDrawing("Line",   { Color = Config.ESP.TracerColor,
                          Thickness = Config.ESP.TracerThick, Visible = false })
        -- Skeleton lines
        e.skeleton  = {}
        for _ = 1, #SKELETON_PAIRS do
            table.insert(e.skeleton, newDrawing("Line", { Color = Config.ESP.SkeletonColor,
                Thickness = Config.ESP.SkeletonThick, Visible = false }))
        end
        pool[player] = e
        return e
    end

    local function removePool(player)
        local e = pool[player]
        if not e then return end
        -- Hide and remove all drawings
        local function rm(d) if d then pcall(function() d.Visible = false; d:Remove() end) end end
        rm(e.box); rm(e.boxFill); rm(e.name); rm(e.dist); rm(e.healthBg); rm(e.healthFill); rm(e.tracer)
        for _, l in ipairs(e.skeleton) do rm(l) end
        pool[player] = nil
    end

    local function hidePool(e)
        if not e then return end
        local function h(d) if d then pcall(function() d.Visible = false end) end end
        h(e.box); h(e.boxFill); h(e.name); h(e.dist); h(e.healthBg); h(e.healthFill); h(e.tracer)
        for _, l in ipairs(e.skeleton) do h(l) end
    end

    -- Get 2D bounding box corners of a character
    local function getBoundingBox(char)
        local root = char:FindFirstChild("HumanoidRootPart")
        if not root then return nil end
        -- Use root + offsets to approximate a character bounding box
        local corners3D = {
            root.Position + Vector3.new(-1.5,  3,   0),
            root.Position + Vector3.new( 1.5,  3,   0),
            root.Position + Vector3.new(-1.5, -3,   0),
            root.Position + Vector3.new( 1.5, -3,   0),
        }
        local minX, minY, maxX, maxY = math.huge, math.huge, -math.huge, -math.huge
        for _, pt in ipairs(corners3D) do
            local sp, onScreen = Camera:WorldToViewportPoint(pt)
            if not onScreen then return nil end
            if sp.X < minX then minX = sp.X end
            if sp.Y < minY then minY = sp.Y end
            if sp.X > maxX then maxX = sp.X end
            if sp.Y > maxY then maxY = sp.Y end
        end
        return minX, minY, maxX - minX, maxY - minY
    end

    -- Apply SelectionBox (chams) to a character
    local function applyCham(player, char)
        local existing = char:FindFirstChild("_NyraESPCham")
        if existing then existing:Destroy() end
        if not Config.ESP.Chams then return end
        local sb = Instance.new("SelectionBox")
        sb.Name        = "_NyraESPCham"
        sb.Adornee     = char
        sb.Color3      = Config.ESP.ChamColor
        sb.LineThickness = 0
        sb.SurfaceColor3 = Config.ESP.ChamColor
        sb.SurfaceTransparency = Config.ESP.ChamTrans
        sb.Parent      = char
    end

    local function removeCham(char)
        local sb = char and char:FindFirstChild("_NyraESPCham")
        if sb then sb:Destroy() end
    end

    -- Main per-player update called from RenderStepped
    local function updatePlayer(player)
        local char = player.Character
        if not char then return false end
        local root = char:FindFirstChild("HumanoidRootPart")
        local hum  = char:FindFirstChildOfClass("Humanoid")
        if not root or not hum then return false end

        -- Team check
        if Config.ESP.TeamCheck and LocalPlayer.Team
            and player.Team == LocalPlayer.Team then
            return false
        end

        -- Distance check
        local myRoot = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        local dist   = myRoot and (root.Position - myRoot.Position).Magnitude
                              or  (root.Position - Camera.CFrame.Position).Magnitude
        if dist > Config.ESP.MaxDistance then return false end

        local sp, onScreen = Camera:WorldToViewportPoint(root.Position)
        if not onScreen then return false end

        local e = pool[player]
        if not e then e = createPool(player) end

        -- Bounding box
        local bx, by, bw, bh = getBoundingBox(char)
        local boxOk = bx ~= nil

        if Config.ESP.Boxes and boxOk then
            if e.box then
                e.box.Size     = Vector2.new(bw, bh)
                e.box.Position = Vector2.new(bx, by)
                e.box.Color    = Config.ESP.BoxColor
                e.box.Thickness= Config.ESP.BoxThickness
                e.box.Visible  = true
            end
            if Config.ESP.BoxFilled and e.boxFill then
                e.boxFill.Size     = Vector2.new(bw, bh)
                e.boxFill.Position = Vector2.new(bx, by)
                e.boxFill.Color    = Config.ESP.BoxColor
                e.boxFill.Transparency = Config.ESP.BoxFillTrans
                e.boxFill.Visible  = true
            else
                if e.boxFill then e.boxFill.Visible = false end
            end
        else
            if e.box     then e.box.Visible     = false end
            if e.boxFill then e.boxFill.Visible = false end
        end

        -- Name label
        if Config.ESP.Names and e.name then
            e.name.Text     = player.Name
            e.name.Size     = Config.ESP.NameSize
            e.name.Color    = Config.ESP.NameColor
            e.name.Position = boxOk
                and Vector2.new(bx + bw / 2, by - 16)
                or  Vector2.new(sp.X, sp.Y - 20)
            e.name.Visible  = true
        else
            if e.name then e.name.Visible = false end
        end

        -- Distance label
        if Config.ESP.Distance and e.dist then
            e.dist.Text     = string.format("[%d]", math.floor(dist))
            e.dist.Color    = Config.ESP.DistanceColor
            e.dist.Position = boxOk
                and Vector2.new(bx + bw / 2, by + bh + 2)
                or  Vector2.new(sp.X, sp.Y + 10)
            e.dist.Visible  = true
        else
            if e.dist then e.dist.Visible = false end
        end

        -- Health bar
        if Config.ESP.HealthBar and boxOk and e.healthBg and e.healthFill then
            local hpRatio  = math.clamp(hum.Health / hum.MaxHealth, 0, 1)
            local barW     = 4
            local barX     = Config.ESP.HealthBarSide == "right"
                             and (bx + bw + 3)
                             or  (bx - barW - 3)
            local filledH  = math.floor(bh * hpRatio)
            local r        = 1 - hpRatio
            local g        = hpRatio
            e.healthBg.Size     = Vector2.new(barW, bh)
            e.healthBg.Position = Vector2.new(barX, by)
            e.healthBg.Visible  = true
            e.healthFill.Size     = Vector2.new(barW, filledH)
            e.healthFill.Position = Vector2.new(barX, by + bh - filledH)
            e.healthFill.Color    = Color3.fromRGB(math.floor(r*255), math.floor(g*255), 0)
            e.healthFill.Visible  = filledH > 0
        else
            if e.healthBg   then e.healthBg.Visible   = false end
            if e.healthFill then e.healthFill.Visible = false end
        end

        -- Tracer
        if Config.ESP.Tracers and e.tracer then
            local vp = Camera.ViewportSize
            local originY = Config.ESP.TracerOrigin == "top"    and 0
                         or Config.ESP.TracerOrigin == "center" and vp.Y / 2
                         or vp.Y
            e.tracer.From      = Vector2.new(vp.X / 2, originY)
            e.tracer.To        = Vector2.new(sp.X, sp.Y)
            e.tracer.Color     = Config.ESP.TracerColor
            e.tracer.Thickness = Config.ESP.TracerThick
            e.tracer.Visible   = true
        else
            if e.tracer then e.tracer.Visible = false end
        end

        -- Skeleton
        if Config.ESP.Skeletons then
            for i, pair in ipairs(SKELETON_PAIRS) do
                local p1 = char:FindFirstChild(pair[1])
                local p2 = char:FindFirstChild(pair[2])
                local line = e.skeleton[i]
                if p1 and p2 and line then
                    local s1, on1 = Camera:WorldToViewportPoint(p1.Position)
                    local s2, on2 = Camera:WorldToViewportPoint(p2.Position)
                    if on1 and on2 then
                        line.From      = Vector2.new(s1.X, s1.Y)
                        line.To        = Vector2.new(s2.X, s2.Y)
                        line.Color     = Config.ESP.SkeletonColor
                        line.Thickness = Config.ESP.SkeletonThick
                        line.Visible   = true
                    else
                        line.Visible = false
                    end
                elseif line then
                    line.Visible = false
                end
            end
        else
            for _, line in ipairs(e.skeleton) do
                if line then line.Visible = false end
            end
        end

        -- Chams: applied via SelectionBox on character (not per-frame drawing)
        if Config.ESP.Chams then
            if not char:FindFirstChild("_NyraESPCham") then applyCham(player, char) end
        else
            removeCham(char)
        end

        return true
    end

    -- RenderStepped update loop
    RunService.RenderStepped:Connect(function()
        if not Config.ESP.Enabled then
            -- Hide all when disabled
            for player, e in pairs(pool) do hidePool(e) end
            return
        end
        local seen = {}
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= LocalPlayer then
                local ok = updatePlayer(player)
                if not ok then
                    local e = pool[player]
                    if e then hidePool(e) end
                end
                seen[player] = true
            end
        end
        -- Clean up pools for players who left
        for player in pairs(pool) do
            if not seen[player] then removePool(player) end
        end
    end)

    -- Clean up when a player leaves
    Players.PlayerRemoving:Connect(function(player)
        removePool(player)
    end)

    -- Clean up chams on character removal
    Players.PlayerAdded:Connect(function(player)
        player.CharacterRemoving:Connect(function(char)
            removeCham(char)
        end)
    end)
    -- Also hook existing players
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            player.CharacterRemoving:Connect(function(char)
                removeCham(char)
            end)
        end
    end

    ESP._pool = pool
end

-- =============================================
--  UI  --  Modern Nyra LS Control Panel
-- =============================================

-- Remove any previous instance
local existingGui = LocalPlayer:WaitForChild("PlayerGui"):FindFirstChild("NyraLSUI")
if existingGui then existingGui:Destroy() end

local CONFIG_UI = {
    Background = Color3.fromRGB(13,  14,  17),
    Panel      = Color3.fromRGB(18,  20,  24),
    Panel2     = Color3.fromRGB(22,  24,  29),
    Panel3     = Color3.fromRGB(27,  29,  35),
    Border     = Color3.fromRGB(43,  46,  54),
    Text       = Color3.fromRGB(235, 237, 242),
    SubText    = Color3.fromRGB(139, 144, 154),
    Muted      = Color3.fromRGB(91,  96,  106),
    Accent     = Color3.fromRGB(255, 190, 70),
    AccentDark = Color3.fromRGB(112, 81,  32),
    Success    = Color3.fromRGB(93,  214, 137),
    Danger     = Color3.fromRGB(235, 92,  92),
    AnimSpeed  = 0.18,
}

local UIState = { Animations = true }

-- helpers
local function New(cls, props)
    local o = Instance.new(cls)
    for k, v in pairs(props or {}) do o[k] = v end
    return o
end
local function Corner(p, r)
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, r or 8); c.Parent = p; return c
end
local function Stroke(p, col, th, tr)
    local s = Instance.new("UIStroke"); s.Color = col or CONFIG_UI.Border
    s.Thickness = th or 1; s.Transparency = tr or 0; s.Parent = p; return s
end
local function Pad(p, l, r, t, b)
    local pad = Instance.new("UIPadding")
    pad.PaddingLeft   = UDim.new(0, l or 0); pad.PaddingRight  = UDim.new(0, r or 0)
    pad.PaddingTop    = UDim.new(0, t or 0); pad.PaddingBottom = UDim.new(0, b or 0)
    pad.Parent = p; return pad
end
local function Tween(obj, props, dur)
    if not UIState.Animations then for k, v in pairs(props) do obj[k] = v end; return end
    TweenService:Create(obj, TweenInfo.new(dur or CONFIG_UI.AnimSpeed,
        Enum.EasingStyle.Quart, Enum.EasingDirection.Out), props):Play()
end
local function Label(parent, text, size, color, font)
    return New("TextLabel", {
        Parent = parent, BackgroundTransparency = 1,
        Text = text, TextColor3 = color or CONFIG_UI.Text,
        TextSize = size or 14, Font = font or Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Center,
    })
end

-- ROOT GUI
local Gui = New("ScreenGui", {
    Name = "NyraLSUI", Parent = LocalPlayer:WaitForChild("PlayerGui"),
    ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
})

local Main = New("Frame", {
    Name = "Main", Parent = Gui,
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(0.5, 0.5),
    Size = UDim2.fromOffset(1000, 610),
    BackgroundColor3 = CONFIG_UI.Background, BorderSizePixel = 0,
})
Corner(Main, 12); Stroke(Main, CONFIG_UI.Border, 1)

-- HEADER
local Header = New("Frame", {
    Name = "Header", Parent = Main,
    Size = UDim2.new(1, 0, 0, 68),
    BackgroundColor3 = CONFIG_UI.Panel, BorderSizePixel = 0,
})
Corner(Header, 12)
New("Frame", { Parent = Header, Position = UDim2.new(0,0,1,-12),
    Size = UDim2.new(1,0,0,12), BackgroundColor3 = CONFIG_UI.Panel, BorderSizePixel = 0 })

local LogoLabel = Label(Header, "NYRA", 22, CONFIG_UI.Text, Enum.Font.GothamBold)
LogoLabel.Position = UDim2.fromOffset(25, 11); LogoLabel.Size = UDim2.fromOffset(100, 28)

local LogoLine = New("Frame", { Parent = Header, Position = UDim2.fromOffset(25, 42),
    Size = UDim2.fromOffset(28, 2), BackgroundColor3 = CONFIG_UI.Accent, BorderSizePixel = 0 })
Corner(LogoLine, 2)

local SubLbl = Label(Header, "LS / CONTROL PANEL", 10, CONFIG_UI.SubText, Enum.Font.GothamMedium)
SubLbl.Position = UDim2.fromOffset(72, 43); SubLbl.Size = UDim2.fromOffset(160, 16)

local OnlineDot = New("Frame", { Parent = Header, Position = UDim2.new(1,-188,0,25),
    Size = UDim2.fromOffset(7,7), BackgroundColor3 = CONFIG_UI.Success, BorderSizePixel = 0 })
Corner(OnlineDot, 10)
local OnlineLbl = Label(Header, "ONLINE", 11, CONFIG_UI.Success, Enum.Font.GothamBold)
OnlineLbl.Position = UDim2.new(1,-173,0,18); OnlineLbl.Size = UDim2.fromOffset(70,22)

local MinBtn = New("TextButton", { Parent = Header, Position = UDim2.new(1,-80,0,16),
    Size = UDim2.fromOffset(28,28), BackgroundColor3 = CONFIG_UI.Panel3, BorderSizePixel = 0,
    Text = "—", TextColor3 = CONFIG_UI.SubText, TextSize = 16, Font = Enum.Font.GothamBold,
    AutoButtonColor = false })
Corner(MinBtn, 7)
MinBtn.MouseEnter:Connect(function() Tween(MinBtn, {BackgroundColor3 = CONFIG_UI.Border}) end)
MinBtn.MouseLeave:Connect(function() Tween(MinBtn, {BackgroundColor3 = CONFIG_UI.Panel3}) end)

local CloseBtn = New("TextButton", { Parent = Header, Position = UDim2.new(1,-45,0,16),
    Size = UDim2.fromOffset(28,28), BackgroundColor3 = CONFIG_UI.Panel3, BorderSizePixel = 0,
    Text = "x", TextColor3 = CONFIG_UI.SubText, TextSize = 18, Font = Enum.Font.GothamMedium,
    AutoButtonColor = false })
Corner(CloseBtn, 7)
CloseBtn.MouseEnter:Connect(function() Tween(CloseBtn,{BackgroundColor3=CONFIG_UI.Danger,TextColor3=Color3.new(1,1,1)}) end)
CloseBtn.MouseLeave:Connect(function() Tween(CloseBtn,{BackgroundColor3=CONFIG_UI.Panel3,TextColor3=CONFIG_UI.SubText}) end)

-- SIDEBAR
local Sidebar = New("Frame", { Name = "Sidebar", Parent = Main,
    Position = UDim2.fromOffset(0,68), Size = UDim2.new(0,205,1,-68),
    BackgroundColor3 = CONFIG_UI.Panel, BorderSizePixel = 0 })
Stroke(Sidebar, CONFIG_UI.Border, 1, 0.65)

local NavTitleLbl = Label(Sidebar, "NAVIGATION", 10, CONFIG_UI.Muted, Enum.Font.GothamBold)
NavTitleLbl.Position = UDim2.fromOffset(24,25); NavTitleLbl.Size = UDim2.fromOffset(150,20)

local NavHolder = New("Frame", { Parent = Sidebar, Position = UDim2.fromOffset(13,52),
    Size = UDim2.new(1,-26,0,165), BackgroundTransparency = 1 })
New("UIListLayout", { Parent = NavHolder, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0,5) })

local SysTitleLbl = Label(Sidebar, "SYSTEM", 10, CONFIG_UI.Muted, Enum.Font.GothamBold)
SysTitleLbl.Position = UDim2.fromOffset(24,235); SysTitleLbl.Size = UDim2.fromOffset(150,20)

local SysHolder = New("Frame", { Parent = Sidebar, Position = UDim2.fromOffset(13,260),
    Size = UDim2.new(1,-26,0,55), BackgroundTransparency = 1 })

-- CONTENT
local Content = New("Frame", { Name = "Content", Parent = Main,
    Position = UDim2.fromOffset(205,68), Size = UDim2.new(1,-205,1,-68),
    BackgroundColor3 = CONFIG_UI.Background, BorderSizePixel = 0 })

local Pages = {}

local function CreatePage(name)
    local page = New("ScrollingFrame", {
        Name = name, Parent = Content, Size = UDim2.fromScale(1,1),
        BackgroundTransparency = 1, BorderSizePixel = 0,
        ScrollBarThickness = 3, ScrollBarImageColor3 = CONFIG_UI.Border,
        CanvasSize = UDim2.new(0,0,0,0), Visible = false,
    })
    Pad(page, 28, 28, 26, 28)
    local layout = New("UIListLayout", { Parent = page,
        SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0,18) })
    layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        page.CanvasSize = UDim2.fromOffset(0, layout.AbsoluteContentSize.Y + 35)
    end)
    Pages[name] = page
    return page
end

local OverviewPage = CreatePage("Overview")
local FlightPage   = CreatePage("Flight")
local AimbotPage   = CreatePage("Aimbot")
local SettingsPage = CreatePage("Settings")

local function PageHeader(parent, title, desc)
    local h = New("Frame", { Parent = parent, Size = UDim2.new(1,0,0,54), BackgroundTransparency = 1 })
    local t = Label(h, title, 23, CONFIG_UI.Text, Enum.Font.GothamBold)
    t.Size = UDim2.new(1,0,0,28); t.Position = UDim2.fromOffset(0,0)
    local d = Label(h, desc, 11, CONFIG_UI.SubText, Enum.Font.Gotham)
    d.Size = UDim2.new(1,0,0,20); d.Position = UDim2.fromOffset(0,30)
    return h
end

-- NAV BUTTONS
local NavButtons = {}

local function NavBtn(parent, name, icon, order)
    local btn = New("TextButton", { Parent = parent, Size = UDim2.new(1,0,0,42),
        BackgroundColor3 = CONFIG_UI.Panel, BorderSizePixel = 0,
        Text = "", AutoButtonColor = false, LayoutOrder = order })
    Corner(btn, 7)
    local indicator = New("Frame", { Parent = btn, Position = UDim2.fromOffset(0,8),
        Size = UDim2.fromOffset(3,26), BackgroundColor3 = CONFIG_UI.Accent,
        BorderSizePixel = 0, Visible = false })
    Corner(indicator, 3)
    local iconLbl = Label(btn, icon, 14, CONFIG_UI.Muted, Enum.Font.GothamBold)
    iconLbl.Position = UDim2.fromOffset(16,0); iconLbl.Size = UDim2.fromOffset(25,42)
    iconLbl.TextXAlignment = Enum.TextXAlignment.Center
    local textLbl = Label(btn, name, 12, CONFIG_UI.SubText, Enum.Font.GothamMedium)
    textLbl.Position = UDim2.fromOffset(48,0); textLbl.Size = UDim2.new(1,-58,1,0)
    NavButtons[name] = { Button = btn, Indicator = indicator, Icon = iconLbl, Text = textLbl }
    btn.MouseEnter:Connect(function()
        if not indicator.Visible then Tween(btn,{BackgroundColor3=CONFIG_UI.Panel3}) end
    end)
    btn.MouseLeave:Connect(function()
        if not indicator.Visible then Tween(btn,{BackgroundColor3=CONFIG_UI.Panel}) end
    end)
    return btn
end

NavBtn(NavHolder, "Overview", "o", 1)
NavBtn(NavHolder, "Flight",   "^", 2)
NavBtn(NavHolder, "Aimbot",   "@", 3)
NavBtn(SysHolder, "Settings", "*", 1)

local CurrentPage
local function SelectPage(name)
    for pName, page in pairs(Pages) do page.Visible = pName == name end
    for bName, data in pairs(NavButtons) do
        local sel = bName == name
        data.Indicator.Visible = sel
        Tween(data.Button, {BackgroundColor3 = sel and CONFIG_UI.Panel3 or CONFIG_UI.Panel})
        Tween(data.Icon,   {TextColor3       = sel and CONFIG_UI.Accent  or CONFIG_UI.Muted})
        Tween(data.Text,   {TextColor3       = sel and CONFIG_UI.Text    or CONFIG_UI.SubText})
    end
    CurrentPage = name
end

for name, data in pairs(NavButtons) do
    data.Button.MouseButton1Click:Connect(function() SelectPage(name) end)
end

-- COMPONENT BUILDERS
local function Section(parent, title, subtitle)
    local s = New("Frame", { Parent = parent, Size = UDim2.new(1,0,0,100),
        BackgroundColor3 = CONFIG_UI.Panel, BorderSizePixel = 0 })
    Corner(s, 9); Stroke(s, CONFIG_UI.Border, 1, 0.3)
    local t = Label(s, title, 13, CONFIG_UI.Text, Enum.Font.GothamBold)
    t.Position = UDim2.fromOffset(18,13); t.Size = UDim2.new(1,-36,0,20)
    if subtitle then
        local sub = Label(s, subtitle, 10, CONFIG_UI.SubText, Enum.Font.Gotham)
        sub.Position = UDim2.fromOffset(18,34); sub.Size = UDim2.new(1,-36,0,18)
    end
    return s
end

local function Toggle(parent, title, desc, initial, cb)
    local h = New("Frame", { Parent = parent, Size = UDim2.new(1,-36,0,52),
        Position = UDim2.fromOffset(18,47), BackgroundTransparency = 1 })
    local t = Label(h, title, 12, CONFIG_UI.Text, Enum.Font.GothamMedium)
    t.Size = UDim2.new(1,-75,0,22)
    local d = Label(h, desc or "", 10, CONFIG_UI.SubText, Enum.Font.Gotham)
    d.Position = UDim2.fromOffset(0,22); d.Size = UDim2.new(1,-75,0,18)
    local tog = New("TextButton", { Parent = h,
        Position = UDim2.new(1,-48,0,5), Size = UDim2.fromOffset(44,24),
        BackgroundColor3 = initial and CONFIG_UI.AccentDark or CONFIG_UI.Panel3,
        BorderSizePixel = 0, Text = "", AutoButtonColor = false })
    Corner(tog, 12); Stroke(tog, CONFIG_UI.Border, 1)
    local knob = New("Frame", { Parent = tog,
        Position = initial and UDim2.new(1,-21,0.5,-8) or UDim2.new(0,5,0.5,-8),
        Size = UDim2.fromOffset(16,16),
        BackgroundColor3 = initial and CONFIG_UI.Accent or CONFIG_UI.Muted,
        BorderSizePixel = 0 })
    Corner(knob, 20)
    local val = initial
    local function Set(v)
        val = v
        Tween(tog,  {BackgroundColor3 = v and CONFIG_UI.AccentDark or CONFIG_UI.Panel3})
        Tween(knob, {Position = v and UDim2.new(1,-21,0.5,-8) or UDim2.new(0,5,0.5,-8),
                     BackgroundColor3 = v and CONFIG_UI.Accent  or CONFIG_UI.Muted})
        if cb then cb(v) end
    end
    tog.MouseButton1Click:Connect(function() Set(not val) end)
    return { Set = Set, Get = function() return val end }
end

local function Slider(parent, title, min, max, initial, cb)
    local h = New("Frame", { Parent = parent, Size = UDim2.new(1,-36,0,70),
        Position = UDim2.fromOffset(18,47), BackgroundTransparency = 1 })
    local t = Label(h, title, 12, CONFIG_UI.Text, Enum.Font.GothamMedium)
    t.Position = UDim2.fromOffset(0,0); t.Size = UDim2.fromOffset(200,22)
    local valLbl = Label(h, tostring(initial), 11, CONFIG_UI.Accent, Enum.Font.GothamBold)
    valLbl.Position = UDim2.new(1,-80,0,0); valLbl.Size = UDim2.fromOffset(80,22)
    valLbl.TextXAlignment = Enum.TextXAlignment.Right
    local bar = New("Frame", { Parent = h, Position = UDim2.fromOffset(0,35),
        Size = UDim2.new(1,0,0,5), BackgroundColor3 = CONFIG_UI.Panel3, BorderSizePixel = 0 })
    Corner(bar, 5)
    local fill = New("Frame", { Parent = bar,
        Size = UDim2.fromScale((initial-min)/(max-min),1),
        BackgroundColor3 = CONFIG_UI.Accent, BorderSizePixel = 0 })
    Corner(fill, 5)
    local knob = New("Frame", { Parent = bar,
        AnchorPoint = Vector2.new(0.5,0.5),
        Position = UDim2.new((initial-min)/(max-min),0,0.5,0),
        Size = UDim2.fromOffset(13,13),
        BackgroundColor3 = CONFIG_UI.Text, BorderSizePixel = 0 })
    Corner(knob, 20)
    local dragging, cur = false, initial
    local function SetVal(v)
        cur = math.clamp(v, min, max)
        local a = (cur-min)/(max-min)
        valLbl.Text = tostring(math.floor(cur))
        Tween(fill, {Size = UDim2.fromScale(a,1)})
        Tween(knob, {Position = UDim2.new(a,0,0.5,0)})
        if cb then cb(cur) end
    end
    local function Update(ix)
        local a = math.clamp((ix - bar.AbsolutePosition.X)/bar.AbsoluteSize.X, 0, 1)
        SetVal(min + (max-min)*a)
    end
    bar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true; Update(input.Position.X)
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            Update(input.Position.X)
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
    end)
    return { Set = SetVal, Get = function() return cur end }
end

local function Button(parent, text, cb)
    local btn = New("TextButton", { Parent = parent, Size = UDim2.new(1,-36,0,40),
        Position = UDim2.fromOffset(18,47), BackgroundColor3 = CONFIG_UI.Panel3,
        BorderSizePixel = 0, Text = text, TextColor3 = CONFIG_UI.Text,
        TextSize = 11, Font = Enum.Font.GothamMedium, AutoButtonColor = false })
    Corner(btn, 7); Stroke(btn, CONFIG_UI.Border, 1)
    btn.MouseEnter:Connect(function() Tween(btn,{BackgroundColor3=CONFIG_UI.Border}) end)
    btn.MouseLeave:Connect(function() Tween(btn,{BackgroundColor3=CONFIG_UI.Panel3}) end)
    btn.MouseButton1Click:Connect(function() if cb then cb() end end)
    return btn
end

-- =============================================
--  STATUS CARDS (shared refs)
-- =============================================
local function StatusCard(parent, title, value, desc, order)
    local card = New("Frame", { Parent = parent,
        BackgroundColor3 = CONFIG_UI.Panel, BorderSizePixel = 0, LayoutOrder = order })
    Corner(card, 8); Stroke(card, CONFIG_UI.Border, 1, 0.35)
    local dot = New("Frame", { Parent = card, Position = UDim2.fromOffset(17,17),
        Size = UDim2.fromOffset(7,7), BackgroundColor3 = CONFIG_UI.Muted, BorderSizePixel = 0 })
    Corner(dot, 10)
    local tLbl = Label(card, title, 10, CONFIG_UI.SubText, Enum.Font.GothamMedium)
    tLbl.Position = UDim2.fromOffset(31,10); tLbl.Size = UDim2.new(1,-45,0,20)
    local vLbl = Label(card, value, 15, CONFIG_UI.Text, Enum.Font.GothamBold)
    vLbl.Position = UDim2.fromOffset(17,30); vLbl.Size = UDim2.new(1,-34,0,25)
    local dLbl = Label(card, desc, 9, CONFIG_UI.SubText, Enum.Font.Gotham)
    dLbl.Position = UDim2.new(1,-115,0,10); dLbl.Size = UDim2.fromOffset(98,20)
    dLbl.TextXAlignment = Enum.TextXAlignment.Right
    return { Card = card, Dot = dot, Value = vLbl }
end

-- =============================================
--  OVERVIEW PAGE
-- =============================================
PageHeader(OverviewPage, "Overview", "Monitor your current Nyra configuration.")

local StatusGrid = New("Frame", { Parent = OverviewPage,
    Size = UDim2.new(1,0,0,142), BackgroundTransparency = 1 })
New("UIGridLayout", { Parent = StatusGrid,
    CellSize = UDim2.new(0.5,-9,0,67), CellPadding = UDim2.fromOffset(12,9),
    SortOrder = Enum.SortOrder.LayoutOrder })

local FlightStatus = StatusCard(StatusGrid, "FLIGHT",     "DISABLED", "Standby", 1)
local AimStatus    = StatusCard(StatusGrid, "AIM ASSIST", "DISABLED", "Standby", 2)
local SpeedStatus  = StatusCard(StatusGrid, "FLY SPEED",  "60",       "Current", 3)
local ModeStatus   = StatusCard(StatusGrid, "AIM MODE",   "HOLD",     "Current", 4)

local QuickSec = Section(OverviewPage, "Quick Controls", "Toggle flight and aim assist from the overview.")
QuickSec.Size = UDim2.new(1,0,0,114)

local QuickFlightToggle = Toggle(QuickSec, "Flight", "Enable the fly system.", false, function(v)
    flyActive = v
    if v then startFly() else stopFly() end
    FlightStatus.Value.Text = v and "ENABLED" or "DISABLED"
    FlightStatus.Dot.BackgroundColor3 = v and CONFIG_UI.Success or CONFIG_UI.Muted
end)

local QuickAimToggle = Toggle(QuickSec, "Aim Assist", "Enable the aimbot.", false, function(v)
    Config.Aim.Enabled = v
    AimStatus.Value.Text = v and "ENABLED" or "DISABLED"
    AimStatus.Dot.BackgroundColor3 = v and CONFIG_UI.Success or CONFIG_UI.Muted
    -- Force-activate/deactivate so the render loop fires without needing a keypress
    if v then Input.ForceActivate() else Input.ForceDeactivate() end
end)

-- =============================================
--  FLIGHT PAGE
-- =============================================
PageHeader(FlightPage, "Flight", "Configure the flight controller.")

local FlightSec = Section(FlightPage, "Flight Controller", "Movement configuration.")
FlightSec.Size = UDim2.new(1,0,0,145)

local FlightToggle = Toggle(FlightSec, "Enable Flight", "Toggle the fly system.", false, function(v)
    flyActive = v
    if v then startFly() else stopFly() end
    FlightStatus.Value.Text = v and "ENABLED" or "DISABLED"
    FlightStatus.Dot.BackgroundColor3 = v and CONFIG_UI.Success or CONFIG_UI.Muted
    QuickFlightToggle.Set(v)
end)

-- Fly keybind button
local FlyKeyBtn = Button(FlightSec, "FLY KEYBIND: F", nil)
FlyKeyBtn.Position = UDim2.fromOffset(18, 94)
FlyKeyBtn.MouseButton1Click:Connect(function()
    FlyKeyBtn.Text = "PRESS A KEY..."
    local conn
    conn = UserInputService.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Keyboard
            and input.KeyCode ~= Enum.KeyCode.Unknown then
            FlyConfig.Toggle = input.KeyCode
            FlyKeyBtn.Text = "FLY KEYBIND: " .. input.KeyCode.Name
            conn:Disconnect()
        end
    end)
end)

-- Speed: 0.1 (very slow) to 10 (very fast) in 0.1 steps
-- Display as 1 decimal place; stored as-is (studs/tick)
local SpeedSec = Section(FlightPage, "Speed", "How fast the character moves per tick.")
SpeedSec.Size = UDim2.new(1,0,0,98)

local SpeedSlider = Slider(SpeedSec, "Fly Speed  (0.1 – 10)", 1, 100, math.floor(FlyConfig.Speed * 10), function(v)
    -- Slider 1–100 maps to 0.1–10.0 in 0.1 increments
    FlyConfig.Speed = v / 10
    SpeedStatus.Value.Text = string.format("%.1f", FlyConfig.Speed)
end)

local SprintSec = Section(FlightPage, "Sprint", "Speed multiplier when holding Left Shift.")
SprintSec.Size = UDim2.new(1,0,0,98)

local SprintSlider = Slider(SprintSec, "Sprint Multiplier  (1x – 5x)", 10, 50, math.floor(FlyConfig.SprintMult * 10), function(v)
    -- Slider 10–50 maps to 1.0x–5.0x
    FlyConfig.SprintMult = v / 10
end)

local SmoothSec = Section(FlightPage, "Smoothness", "Tween duration — lower = snappier, higher = floatier.")
SmoothSec.Size = UDim2.new(1,0,0,98)

local TweenSlider = Slider(SmoothSec, "Tween Time  (0.01 – 0.15)", 1, 15, math.floor(FlyConfig.TweenTime * 100), function(v)
    -- Slider 1–15 maps to 0.01–0.15
    FlyConfig.TweenTime = v / 100
end)

local PhysicsSec = Section(FlightPage, "Physics", "Wall collision and phase options.")
PhysicsSec.Size = UDim2.new(1,0,0,98)

local NoClipToggle = Toggle(PhysicsSec, "No-Clip", "Phase through walls while flying.", FlyConfig.NoClip, function(v)
    FlyConfig.NoClip = v
    -- Apply immediately if currently flying
    local root = getRoot()
    if root and flyActive then
        root.CanCollide = not v
    end
end)

local ControlSec = Section(FlightPage, "Controls", "Keyboard layout.")
ControlSec.Size = UDim2.new(1,0,0,110)
local CtrlLbl = Label(ControlSec, "W / A / S / D   Move\nSPACE           Ascend\nLEFT CTRL       Descend\nLEFT SHIFT      Sprint\nF               Toggle Flight", 11, CONFIG_UI.SubText, Enum.Font.GothamMedium)
CtrlLbl.Position = UDim2.fromOffset(18,49); CtrlLbl.Size = UDim2.new(1,-36,0,80)
CtrlLbl.TextYAlignment = Enum.TextYAlignment.Top

-- =============================================
--  AIMBOT PAGE
-- =============================================
PageHeader(AimbotPage, "Aimbot", "Configure the aim-assist system.")

local AimSec = Section(AimbotPage, "Aim Assist", "Core aim-assist settings.")
AimSec.Size = UDim2.new(1,0,0,230)

local AimToggle = Toggle(AimSec, "Enable Aim Assist", "Lock onto the closest target in FOV.", false, function(v)
    Config.Aim.Enabled = v
    AimStatus.Value.Text = v and "ENABLED" or "DISABLED"
    AimStatus.Dot.BackgroundColor3 = v and CONFIG_UI.Success or CONFIG_UI.Muted
    if v then Input.ForceActivate() else Input.ForceDeactivate() end
    QuickAimToggle.Set(v)
end)

local SmoothSlider = Slider(AimSec, "Smoothness (camera lerp)", 1, 100, math.floor(Config.Aim.Smoothness*100), function(v)
    Config.Aim.Smoothness = v / 100
end)

local PredToggle = Toggle(AimSec, "Prediction", "Lead moving targets.", Config.Aim.Prediction, function(v)
    Config.Aim.Prediction = v
end)

-- Aimbot mode toggle: Camera vs Cursor
local AimModeBtn = Button(AimSec, "AIM MODE: CAMERA", nil)
AimModeBtn.Position = UDim2.fromOffset(18, 180)
AimModeBtn.MouseButton1Click:Connect(function()
    if Config.Aim.Mode == "camera" then
        Config.Aim.Mode = "cursor"
        AimModeBtn.Text = "AIM MODE: CURSOR"
    else
        Config.Aim.Mode = "camera"
        AimModeBtn.Text = "AIM MODE: CAMERA"
    end
end)

local FOVSec = Section(AimbotPage, "FOV Settings", "Targeting field of view.")
FOVSec.Size = UDim2.new(1,0,0,128)

local FOVToggle = Toggle(FOVSec, "FOV Circle", "Show/use FOV circle.", Config.FOV.Enabled, function(v)
    Config.FOV.Enabled = v
end)

local FOVSlider = Slider(FOVSec, "FOV Radius", 50, 500, Config.FOV.Radius, function(v)
    Config.FOV.Radius = math.floor(v)
end)

local TargetSec = Section(AimbotPage, "Targeting", "Targeting filters.")
TargetSec.Size = UDim2.new(1,0,0,128)

local TeamToggle = Toggle(TargetSec, "Team Check", "Ignore teammates.", Config.Targeting.TeamCheck, function(v)
    Config.Targeting.TeamCheck = v
end)

local VisToggle = Toggle(TargetSec, "Visibility Check", "Only target visible players.", Config.Targeting.VisibilityCheck, function(v)
    Config.Targeting.VisibilityCheck = v
end)

local ActivSec = Section(AimbotPage, "Activation", "How the aimbot activates.")
ActivSec.Size = UDim2.new(1,0,0,145)

local ModeBtn = Button(ActivSec, "MODE: HOLD", function()
    Config.Input.HoldMode = not Config.Input.HoldMode
    ModeBtn.Text = "MODE: " .. (Config.Input.HoldMode and "HOLD" or "TOGGLE")
    ModeStatus.Value.Text = Config.Input.HoldMode and "HOLD" or "TOGGLE"
end)

local KeyBtn = Button(ActivSec, "KEYBIND: Q", nil)
KeyBtn.Position = UDim2.fromOffset(18, 94)
KeyBtn.MouseButton1Click:Connect(function()
    KeyBtn.Text = "PRESS A KEY..."
    local conn
    conn = UserInputService.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Keyboard
            and input.KeyCode ~= Enum.KeyCode.Unknown then
            Config.Input.ActivationKey = input.KeyCode
            KeyBtn.Text = "KEYBIND: " .. input.KeyCode.Name
            conn:Disconnect()
        end
    end)
end)

-- =============================================
--  SETTINGS PAGE
-- =============================================
PageHeader(SettingsPage, "Settings", "Customize the Nyra interface.")

local AppSec = Section(SettingsPage, "Appearance", "Interface options.")
AppSec.Size = UDim2.new(1,0,0,114)

Toggle(AppSec, "Animations", "Enable smooth UI transitions.", true, function(v)
    UIState.Animations = v
end)

Toggle(AppSec, "Minimal Borders", "Reduce border intensity.", false, function(v)
    for _, obj in ipairs(Gui:GetDescendants()) do
        if obj:IsA("UIStroke") then obj.Transparency = v and 1 or 0.3 end
    end
end)

local AboutSec = Section(SettingsPage, "About", "Build information.")
AboutSec.Size = UDim2.new(1,0,0,100)
local AboutLbl = Label(AboutSec, "NYRA LS\nModern Exploit UI\nBuild 2.0.0 -- Full", 11, CONFIG_UI.SubText, Enum.Font.GothamMedium)
AboutLbl.Position = UDim2.fromOffset(18,48); AboutLbl.Size = UDim2.new(1,-36,0,55)
AboutLbl.TextYAlignment = Enum.TextYAlignment.Top

-- FOOTER
local Footer = New("Frame", { Parent = Sidebar,
    Position = UDim2.new(0,20,1,-57), Size = UDim2.new(1,-40,0,37),
    BackgroundTransparency = 1 })
local FtrName = Label(Footer, "NYRA LS", 10, CONFIG_UI.Text, Enum.Font.GothamBold)
FtrName.Size = UDim2.new(1,0,0,17)
local FtrBuild = Label(Footer, "build 2.0.0", 9, CONFIG_UI.Muted, Enum.Font.Gotham)
FtrBuild.Position = UDim2.fromOffset(0,17); FtrBuild.Size = UDim2.new(1,0,0,16)

-- =============================================
--  DRAGGING (header only)
-- =============================================
local _dragging, _dragStart, _startPos = false, nil, nil

Header.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        _dragging = true; _dragStart = input.Position; _startPos = Main.Position
    end
end)
Header.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then _dragging = false end
end)
UserInputService.InputChanged:Connect(function(input)
    if _dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
        local d = input.Position - _dragStart
        Main.Position = UDim2.new(_startPos.X.Scale, _startPos.X.Offset + d.X,
                                   _startPos.Y.Scale, _startPos.Y.Offset + d.Y)
    end
end)

-- =============================================
--  MINIMIZE / CLOSE
-- =============================================
local minimized = false

MinBtn.MouseButton1Click:Connect(function()
    minimized = not minimized
    if minimized then
        Tween(Main, {Size = UDim2.fromOffset(1000,68)}, 0.2)
        Sidebar.Visible = false; Content.Visible = false
    else
        Tween(Main, {Size = UDim2.fromOffset(1000,610)}, 0.2)
        task.delay(0.12, function()
            if not minimized then Sidebar.Visible = true; Content.Visible = true end
        end)
    end
end)

CloseBtn.MouseButton1Click:Connect(function()
    Tween(Main, {Size = UDim2.fromOffset(800,40), BackgroundTransparency = 1}, 0.2)
    task.wait(0.25)
    Gui:Destroy()
end)

-- =============================================
--  F KEY -> FLIGHT TOGGLE (keyboard shortcut)
--  Single source of truth: FlightToggle.Set(v)
--  triggers the callback which sets flyActive,
--  calls startFly/stopFly, and syncs QuickFlightToggle.
-- =============================================
UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end
    if input.KeyCode == FlyConfig.Toggle then
        FlightToggle.Set(not flyActive)
    end
end)

-- =============================================
--  INITIAL STATE
-- =============================================
SelectPage("Overview")
Config.Load()

print("[NYRA LS] Loaded. F = fly toggle, Q = aimbot (hold).")
