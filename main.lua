--[[
    Nyra — Roblox Aim-Assist (iambot)
    Architecture:
        Config → Input → TargetManager → FOV → Visibility → Prediction → AimController → UI
    All modules are local tables. The fly system is untouched and lives below the "FLY" banner.
--]]

-- ─────────────────────────────────────────────
--  SERVICES
-- ─────────────────────────────────────────────
local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService     = game:GetService("TweenService")

local LocalPlayer      = Players.LocalPlayer
local Mouse            = LocalPlayer:GetMouse()
local Camera           = workspace.CurrentCamera

-- ─────────────────────────────────────────────
--  MODULE: Config
-- ─────────────────────────────────────────────
local Config = {}
Config.Aim = {
    Enabled      = false,
    Smoothness   = 0.15,
    Prediction   = true,
    PredictionTime = 0.12,
    TargetPart   = "Head",
    AllowedParts = { "Head", "UpperTorso", "HumanoidRootPart" },
}
Config.FOV = {
    Enabled      = true,
    Radius       = 150,
    Visible      = true,
    Thickness    = 2,
    Transparency = 0.5,
    Dynamic      = false,
}
Config.Targeting = {
    TeamCheck       = true,
    VisibilityCheck = true,
    MaxDistance     = 500,
    HealthFilter    = true,
    Whitelist       = {},     -- player names; empty = all enemies
}
Config.Lock = {
    HoldToLock        = true,
    SwitchDelay       = 0.25,
    ReleaseOutsideFOV = true,
    Reacquire         = true,
}
Config.Input = {
    ActivationKey = Enum.KeyCode.Q,
    HoldMode      = true,
}
Config.Weapon = {
    ProjectileSpeed = 300,
    Gravity         = workspace.Gravity,
}
Config.Debug = {
    Enabled = false,
}

function Config.Save()
    -- placeholder: serialise Config to a writefile() call for executors that support it
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
                    for k2, v2 in pairs(v) do
                        Config[k][k2] = v2
                    end
                end
            end
        end
    end
end

function Config.Reset()
    Config.Aim.Enabled       = false
    Config.Aim.Smoothness    = 0.15
    Config.FOV.Radius        = 150
    Config.Targeting.TeamCheck      = true
    Config.Targeting.VisibilityCheck = true
    Config.Lock.HoldToLock   = true
end

-- ─────────────────────────────────────────────
--  MODULE: Visibility
-- ─────────────────────────────────────────────
local Visibility = {}

function Visibility.Check(targetPosition)
    local origin    = Camera.CFrame.Position
    local direction = targetPosition - origin

    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    local filterList = { LocalPlayer.Character }
    params.FilterDescendantsInstances = filterList

    local result = workspace:Raycast(origin, direction, params)
    if not result then
        return true  -- nothing in the way
    end

    -- Check whether the ray hit the target character or something else
    local hitInstance = result.Instance
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            if hitInstance:IsDescendantOf(player.Character) then
                return true
            end
        end
    end
    return false
end

-- ─────────────────────────────────────────────
--  MODULE: FOV
-- ─────────────────────────────────────────────
local FOV = {}
do
    local circle = Drawing.new("Circle")
    circle.Color     = Color3.fromRGB(255, 255, 255)
    circle.Thickness = Config.FOV.Thickness
    circle.Radius    = Config.FOV.Radius
    circle.Filled    = false
    circle.Visible   = Config.FOV.Visible and Config.FOV.Enabled
    circle.Transparency = Config.FOV.Transparency
    FOV._circle = circle

    RunService.RenderStepped:Connect(function()
        circle.Position = Vector2.new(Mouse.X, Mouse.Y)
        circle.Radius   = Config.FOV.Radius
        circle.Visible  = Config.FOV.Visible and Config.FOV.Enabled
    end)
end

function FOV.IsInsideFOV(worldPosition)
    local screenPos, onScreen = Camera:WorldToViewportPoint(worldPosition)
    if not onScreen then return false end
    local cursor = Vector2.new(Mouse.X, Mouse.Y)
    local targetScreen = Vector2.new(screenPos.X, screenPos.Y)
    return (targetScreen - cursor).Magnitude <= Config.FOV.Radius
end

function FOV.DistanceToCursor(worldPosition)
    local screenPos, onScreen = Camera:WorldToViewportPoint(worldPosition)
    if not onScreen then return math.huge end
    local cursor = Vector2.new(Mouse.X, Mouse.Y)
    return (Vector2.new(screenPos.X, screenPos.Y) - cursor).Magnitude
end

-- ─────────────────────────────────────────────
--  MODULE: TargetManager
-- ─────────────────────────────────────────────
local TargetManager = {}

local function GetPartPosition(character, partName)
    local part = character:FindFirstChild(partName)
    if part then return part.Position end
    -- fallback cascade
    for _, fallback in ipairs(Config.Aim.AllowedParts) do
        local p = character:FindFirstChild(fallback)
        if p then return p.Position end
    end
    return nil
end

function TargetManager.IsValid(player)
    if not player or player == LocalPlayer then return false end

    -- Whitelist check
    if #Config.Targeting.Whitelist > 0 then
        local found = false
        for _, name in ipairs(Config.Targeting.Whitelist) do
            if name == player.Name then found = true; break end
        end
        if not found then return false end
    end

    local character = player.Character
    if not character then return false end

    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid or humanoid.Health <= 0 then return false end

    -- Team check
    if Config.Targeting.TeamCheck then
        if LocalPlayer.Team and player.Team == LocalPlayer.Team then
            return false
        end
    end

    -- Distance check
    local root = character:FindFirstChild("HumanoidRootPart")
    if root then
        local dist = (root.Position - (LocalPlayer.Character
            and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
            and LocalPlayer.Character.HumanoidRootPart.Position
            or Camera.CFrame.Position)).Magnitude
        if dist > Config.Targeting.MaxDistance then return false end
    end

    return true
end

function TargetManager.GetTargets()
    local targets = {}
    for _, player in ipairs(Players:GetPlayers()) do
        if TargetManager.IsValid(player) then
            table.insert(targets, player)
        end
    end
    return targets
end

function TargetManager.GetClosest()
    local best, bestDist = nil, math.huge
    for _, player in ipairs(TargetManager.GetTargets()) do
        local character = player.Character
        local pos = GetPartPosition(character, Config.Aim.TargetPart)
        if not pos then goto continue end

        -- Optional FOV gate
        if Config.FOV.Enabled and not FOV.IsInsideFOV(pos) then goto continue end

        -- Optional visibility gate
        if Config.Targeting.VisibilityCheck and not Visibility.Check(pos) then
            goto continue
        end

        local d = FOV.DistanceToCursor(pos)
        if d < bestDist then
            bestDist = d
            best     = player
        end
        ::continue::
    end
    return best
end

-- ─────────────────────────────────────────────
--  MODULE: Prediction
-- ─────────────────────────────────────────────
local Prediction = {}

function Prediction.Calculate(character, predictionTime)
    local root = character:FindFirstChild("HumanoidRootPart")
    if not root then return nil end
    local position = root.Position
    local velocity = root.AssemblyLinearVelocity
    return position + velocity * (predictionTime or Config.Aim.PredictionTime)
end

function Prediction.CalculateProjectile(character)
    local root = character:FindFirstChild("HumanoidRootPart")
    if not root then return nil end
    local origin   = Camera.CFrame.Position
    local distance = (root.Position - origin).Magnitude
    local tof      = distance / Config.Weapon.ProjectileSpeed  -- time of flight
    local predicted = root.Position
        + root.AssemblyLinearVelocity * tof
        - Vector3.new(0, 0.5 * Config.Weapon.Gravity * tof * tof, 0)
    return predicted
end

-- ─────────────────────────────────────────────
--  MODULE: AimController
-- ─────────────────────────────────────────────
local AimController = {}

-- States: IDLE | SEARCHING | ACQUIRED | LOCKED | TRACKING | INVALID
AimController.State       = "IDLE"
AimController.CurrentTarget = nil
AimController.IsLocked    = false

local _lastSwitch = 0

function AimController.Acquire()
    local target = TargetManager.GetClosest()
    if target then
        AimController.CurrentTarget = target
        AimController.State = "ACQUIRED"
    else
        AimController.State = "SEARCHING"
    end
    return target
end

function AimController.Lock()
    AimController.IsLocked = true
    AimController.State    = "LOCKED"
end

function AimController.Release()
    AimController.IsLocked    = false
    AimController.CurrentTarget = nil
    AimController.State       = "IDLE"
end

function AimController.Track()
    local target = AimController.CurrentTarget
    if not target or not TargetManager.IsValid(target) then
        AimController.State = "INVALID"
        if Config.Lock.Reacquire then
            AimController.Acquire()
        else
            AimController.Release()
        end
        return
    end

    AimController.State = "TRACKING"

    local character = target.Character
    local aimPos
    if Config.Aim.Prediction then
        aimPos = Prediction.Calculate(character)
    end
    if not aimPos then
        local part = character:FindFirstChild(Config.Aim.TargetPart)
            or character:FindFirstChild("HumanoidRootPart")
        if not part then return end
        aimPos = part.Position
    end

    -- Release if outside FOV and configured to do so
    if Config.Lock.ReleaseOutsideFOV and Config.FOV.Enabled
        and not FOV.IsInsideFOV(aimPos) then
        AimController.Release()
        return
    end

    -- Smooth camera rotation toward aim position
    local targetCF = CFrame.new(Camera.CFrame.Position, aimPos)
    Camera.CFrame  = Camera.CFrame:Lerp(targetCF, Config.Aim.Smoothness)
end

-- ─────────────────────────────────────────────
--  MODULE: Input
-- ─────────────────────────────────────────────
local Input = {}
Input._active = false
Input._binds  = {}

function Input.BindKey(keyCode, callback)
    table.insert(Input._binds, { key = keyCode, cb = callback })
end

function Input.IsActive()
    return Input._active
end

UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end

    -- Activation
    if input.KeyCode == Config.Input.ActivationKey then
        if Config.Input.HoldMode then
            Input._active = true
        else
            Input._active = not Input._active
        end
        if Input._active then
            AimController.Acquire()
            AimController.Lock()
        else
            AimController.Release()
        end
    end

    -- Custom binds
    for _, bind in ipairs(Input._binds) do
        if input.KeyCode == bind.key then
            bind.cb(input)
        end
    end

    -- Right-click aim assist activation alternative
    if input.UserInputType == Enum.UserInputType.MouseButton2 then
        if not Config.Input.HoldMode then
            Input._active = not Input._active
            if Input._active then
                AimController.Acquire()
                AimController.Lock()
            else
                AimController.Release()
            end
        end
    end
end)

UserInputService.InputEnded:Connect(function(input, processed)
    if processed then return end
    if Config.Input.HoldMode then
        if input.KeyCode == Config.Input.ActivationKey
            or input.UserInputType == Enum.UserInputType.MouseButton2 then
            Input._active = false
            AimController.Release()
        end
    end
end)

-- ─────────────────────────────────────────────
--  MODULE: UI  (ScreenGui via CoreGui)
-- ─────────────────────────────────────────────
local UI = {}

local function makeLabel(parent, name, text, posY)
    local lbl = Instance.new("TextLabel")
    lbl.Name            = name
    lbl.Size            = UDim2.new(1, 0, 0, 22)
    lbl.Position        = UDim2.new(0, 0, 0, posY)
    lbl.BackgroundTransparency = 1
    lbl.TextColor3      = Color3.fromRGB(220, 220, 220)
    lbl.TextSize        = 13
    lbl.Font            = Enum.Font.Code
    lbl.TextXAlignment  = Enum.TextXAlignment.Left
    lbl.Text            = text
    lbl.Parent          = parent
    return lbl
end

local function makeToggle(parent, name, labelText, posY, getValue, onToggle)
    local btn = Instance.new("TextButton")
    btn.Name            = name
    btn.Size            = UDim2.new(1, 0, 0, 24)
    btn.Position        = UDim2.new(0, 0, 0, posY)
    btn.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    btn.TextColor3      = Color3.fromRGB(220, 220, 220)
    btn.TextSize        = 13
    btn.Font            = Enum.Font.Code
    btn.BorderSizePixel = 0
    btn.Parent          = parent

    local function refresh()
        btn.Text = labelText .. ": " .. (getValue() and "[ON]" or "[OFF]")
        btn.BackgroundColor3 = getValue()
            and Color3.fromRGB(30, 80, 30)
            or  Color3.fromRGB(40, 40, 40)
    end
    refresh()

    btn.MouseButton1Click:Connect(function()
        onToggle()
        refresh()
    end)
    return btn
end

function UI.CreateWindow()
    local gui = Instance.new("ScreenGui")
    gui.Name            = "NyraUI"
    gui.ResetOnSpawn    = false
    gui.ZIndexBehavior  = Enum.ZIndexBehavior.Sibling

    -- Mount to CoreGui if executor allows, else PlayerGui
    local ok = pcall(function()
        gui.Parent = game:GetService("CoreGui")
    end)
    if not ok then
        gui.Parent = LocalPlayer:WaitForChild("PlayerGui")
    end

    -- ── Main frame ──────────────────────────────
    local frame = Instance.new("Frame")
    frame.Name             = "MainFrame"
    frame.Size             = UDim2.new(0, 230, 0, 320)
    frame.Position         = UDim2.new(0, 10, 0, 10)
    frame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    frame.BorderSizePixel  = 0
    frame.Active           = true
    frame.Draggable        = false   -- manual drag on title bar only
    frame.Parent           = gui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent       = frame

    -- Title bar
    local title = Instance.new("TextLabel")
    title.Size            = UDim2.new(1, 0, 0, 30)
    title.BackgroundColor3 = Color3.fromRGB(18, 18, 18)
    title.TextColor3      = Color3.fromRGB(255, 80, 80)
    title.TextSize        = 15
    title.Font            = Enum.Font.GothamBold
    title.Text            = "NYRA  —  AIM ASSIST"
    title.BorderSizePixel = 0
    title.Parent          = frame

    local tc = Instance.new("UICorner")
    tc.CornerRadius = UDim.new(0, 6)
    tc.Parent       = title

    -- ── Drag: title bar only ──────────────────────
    do
        local dragging, dragStart, startPos = false, nil, nil
        title.Active = true

        title.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                dragging  = true
                dragStart = input.Position
                startPos  = frame.Position
            end
        end)

        title.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                dragging = false
            end
        end)

        UserInputService.InputChanged:Connect(function(input)
            if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
                local delta = input.Position - dragStart
                frame.Position = UDim2.new(
                    startPos.X.Scale,
                    startPos.X.Offset + delta.X,
                    startPos.Y.Scale,
                    startPos.Y.Offset + delta.Y
                )
            end
        end)
    end

    -- Content scroll
    local scroll = Instance.new("ScrollingFrame")
    scroll.Size             = UDim2.new(1, -10, 1, -38)
    scroll.Position         = UDim2.new(0, 5, 0, 33)
    scroll.CanvasSize       = UDim2.new(0, 0, 0, 460)
    scroll.ScrollBarThickness = 4
    scroll.BackgroundTransparency = 1
    scroll.Parent           = frame

    local yOff = 4
    local function sep()
        local line = Instance.new("Frame")
        line.Size = UDim2.new(1, 0, 0, 1)
        line.Position = UDim2.new(0, 0, 0, yOff)
        line.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
        line.BorderSizePixel  = 0
        line.Parent = scroll
        yOff = yOff + 5
    end

    -- ── AIM section ──────────────────────────────
    makeLabel(scroll, "SecAim", "── AIM ──────────────", yOff); yOff = yOff + 22
    makeToggle(scroll, "BtnEnabled", "Aim Assist", yOff,
        function() return Config.Aim.Enabled end,
        function() Config.Aim.Enabled = not Config.Aim.Enabled end)
    yOff = yOff + 28

    makeToggle(scroll, "BtnPrediction", "Prediction", yOff,
        function() return Config.Aim.Prediction end,
        function() Config.Aim.Prediction = not Config.Aim.Prediction end)
    yOff = yOff + 28

    makeToggle(scroll, "BtnHold", "Hold-to-lock", yOff,
        function() return Config.Input.HoldMode end,
        function() Config.Input.HoldMode = not Config.Input.HoldMode end)
    yOff = yOff + 28
    sep()

    -- ── FOV section ──────────────────────────────
    makeLabel(scroll, "SecFOV", "── FOV ──────────────", yOff); yOff = yOff + 22
    makeToggle(scroll, "BtnFOVEnabled", "FOV Circle", yOff,
        function() return Config.FOV.Enabled end,
        function() Config.FOV.Enabled = not Config.FOV.Enabled end)
    yOff = yOff + 28

    makeToggle(scroll, "BtnFOVVisible", "Show Circle", yOff,
        function() return Config.FOV.Visible end,
        function() Config.FOV.Visible = not Config.FOV.Visible end)
    yOff = yOff + 28
    sep()

    -- ── Targeting section ─────────────────────────
    makeLabel(scroll, "SecTarget", "── TARGETING ────────", yOff); yOff = yOff + 22
    makeToggle(scroll, "BtnTeam", "Team Check", yOff,
        function() return Config.Targeting.TeamCheck end,
        function() Config.Targeting.TeamCheck = not Config.Targeting.TeamCheck end)
    yOff = yOff + 28

    makeToggle(scroll, "BtnVis", "Visibility Check", yOff,
        function() return Config.Targeting.VisibilityCheck end,
        function() Config.Targeting.VisibilityCheck = not Config.Targeting.VisibilityCheck end)
    yOff = yOff + 28
    sep()

    -- ── Config section ────────────────────────────
    makeLabel(scroll, "SecCfg", "── CONFIG ───────────", yOff); yOff = yOff + 22
    local btnSave = Instance.new("TextButton")
    btnSave.Size     = UDim2.new(0.48, 0, 0, 24)
    btnSave.Position = UDim2.new(0, 0, 0, yOff)
    btnSave.BackgroundColor3 = Color3.fromRGB(40, 60, 80)
    btnSave.TextColor3 = Color3.fromRGB(220, 220, 220)
    btnSave.TextSize   = 13
    btnSave.Font       = Enum.Font.Code
    btnSave.Text       = "Save"
    btnSave.BorderSizePixel = 0
    btnSave.Parent     = scroll
    btnSave.MouseButton1Click:Connect(Config.Save)

    local btnReset = Instance.new("TextButton")
    btnReset.Size     = UDim2.new(0.48, 0, 0, 24)
    btnReset.Position = UDim2.new(0.52, 0, 0, yOff)
    btnReset.BackgroundColor3 = Color3.fromRGB(80, 40, 40)
    btnReset.TextColor3 = Color3.fromRGB(220, 220, 220)
    btnReset.TextSize   = 13
    btnReset.Font       = Enum.Font.Code
    btnReset.Text       = "Reset"
    btnReset.BorderSizePixel = 0
    btnReset.Parent     = scroll
    btnReset.MouseButton1Click:Connect(Config.Reset)
    yOff = yOff + 28

    -- ── Debug section ─────────────────────────────
    sep()
    makeToggle(scroll, "BtnDebug", "Debug Mode", yOff,
        function() return Config.Debug.Enabled end,
        function() Config.Debug.Enabled = not Config.Debug.Enabled end)
    yOff = yOff + 28

    -- Debug readout
    local dbgLabel = makeLabel(scroll, "DbgLabel", "", yOff)
    dbgLabel.Size       = UDim2.new(1, 0, 0, 120)
    dbgLabel.TextColor3 = Color3.fromRGB(120, 200, 120)
    dbgLabel.TextSize   = 11
    dbgLabel.TextWrapped = true
    dbgLabel.TextYAlignment = Enum.TextYAlignment.Top
    UI._debugLabel = dbgLabel

    scroll.CanvasSize = UDim2.new(0, 0, 0, yOff + 130)
    UI._frame = frame
    return gui
end

function UI.UpdateDebug(target)
    if not UI._debugLabel or not Config.Debug.Enabled then
        if UI._debugLabel then UI._debugLabel.Text = "" end
        return
    end
    if not target or not target.Character then
        UI._debugLabel.Text = "TARGET: none\nSTATE: " .. AimController.State
        return
    end
    local character = target.Character
    local root = character:FindFirstChild("HumanoidRootPart")
    local dist = root and math.floor(
        (root.Position - Camera.CFrame.Position).Magnitude) or "?"
    local vel  = root and math.floor(root.AssemblyLinearVelocity.Magnitude) or "?"
    local fovD = root and math.floor(FOV.DistanceToCursor(root.Position)) or "?"
    local vis  = root and tostring(Visibility.Check(root.Position)) or "?"
    UI._debugLabel.Text = string.format(
        "TARGET: %s\nDIST: %s\nFOV: %s\nVISIBLE: %s\nVELOCITY: %s\nSTATE: %s\nPART: %s",
        target.Name, dist, fovD, vis, vel, AimController.State, Config.Aim.TargetPart
    )
end

-- ─────────────────────────────────────────────
--  MAIN  —  RenderStepped loop
-- ─────────────────────────────────────────────
UI.CreateWindow()
Config.Load()

RunService.RenderStepped:Connect(function()
    -- Only track if aim assist is globally enabled AND input is active
    if Config.Aim.Enabled and Input.IsActive() then
        if AimController.State == "IDLE" or AimController.State == "SEARCHING" then
            AimController.Acquire()
            if AimController.CurrentTarget then
                AimController.Lock()
            end
        elseif AimController.State == "LOCKED" or AimController.State == "TRACKING" then
            AimController.Track()
        elseif AimController.State == "INVALID" then
            if Config.Lock.Reacquire then
                AimController.Acquire()
            else
                AimController.Release()
            end
        end
    else
        if AimController.IsLocked then
            AimController.Release()
        end
    end

    UI.UpdateDebug(AimController.CurrentTarget)
end)

-- ---------------------------------------------
--  FLY  --  BodyVelocity + BodyGyro
--  W/A/S/D  = move relative to camera look
--  Space    = up,  LeftControl = down
--  LeftShift = sprint
--  Toggle: F key
--  Character smoothly rotates to face movement direction.
--  BodyVelocity cancels gravity entirely (MaxForce Y = 1e9).
-- ---------------------------------------------
do
    local FlyConfig = {
        Speed      = 60,
        SprintMult = 2.2,
        Accel      = 10,   -- how fast velocity ramps up (lerp factor per second)
        Toggle     = Enum.KeyCode.F,
    }

    local flyActive = false
    local flyConn   = nil
    local UIS       = UserInputService

    local function isDown(k) return UIS:IsKeyDown(k) end

    local function getRoot()
        local c = LocalPlayer.Character
        return c and c:FindFirstChild("HumanoidRootPart")
    end

    local function getHumanoid()
        local c = LocalPlayer.Character
        return c and c:FindFirstChildOfClass("Humanoid")
    end

    -- BodyVelocity drives movement AND cancels gravity (MaxForce Y = 1e9)
    -- BodyGyro handles smooth rotation to face where the root is heading
    local bv, bg

    local function startFly()
        local root = getRoot()
        if not root then return end

        local hum = getHumanoid()
        if hum then
            hum.PlatformStand = true
            hum:ChangeState(Enum.HumanoidStateType.Physics)
        end

        -- Kill any existing fall
        root.AssemblyLinearVelocity  = Vector3.zero
        root.AssemblyAngularVelocity = Vector3.zero

        -- BodyVelocity: starts at zero, we update .Velocity each frame
        bv          = Instance.new("BodyVelocity")
        bv.Name     = "_NyraFlyBV"
        bv.MaxForce = Vector3.new(1e9, 1e9, 1e9)  -- full 3-axis override, kills gravity on Y
        bv.Velocity = Vector3.zero
        bv.Parent   = root

        -- BodyGyro: smoothly rotates character to face movement direction
        bg            = Instance.new("BodyGyro")
        bg.Name       = "_NyraFlyBG"
        bg.MaxTorque  = Vector3.new(0, 1e9, 0)  -- yaw only; pitch from root CFrame write
        bg.D          = 100
        bg.P          = 3000
        bg.CFrame     = root.CFrame
        bg.Parent     = root

        local currentVel = Vector3.zero

        flyConn = RunService.Heartbeat:Connect(function(dt)
            root = getRoot()
            if not root or not bv or not bg then return end

            local camCF  = Camera.CFrame
            local lookXZ = Vector3.new(camCF.LookVector.X, 0, camCF.LookVector.Z)
            if lookXZ.Magnitude > 0 then lookXZ = lookXZ.Unit end
            local rightXZ = Vector3.new(camCF.RightVector.X, 0, camCF.RightVector.Z)
            if rightXZ.Magnitude > 0 then rightXZ = rightXZ.Unit end

            -- Desired movement direction relative to camera (horizontal only from WASD)
            local moveDir = Vector3.zero
            if isDown(Enum.KeyCode.W) then moveDir = moveDir + lookXZ  end
            if isDown(Enum.KeyCode.S) then moveDir = moveDir - lookXZ  end
            if isDown(Enum.KeyCode.A) then moveDir = moveDir - rightXZ end
            if isDown(Enum.KeyCode.D) then moveDir = moveDir + rightXZ end

            -- Vertical from Space / LeftControl
            local vy = 0
            if isDown(Enum.KeyCode.Space)       then vy =  1 end
            if isDown(Enum.KeyCode.LeftControl) then vy = -1 end

            local speed = FlyConfig.Speed
            if isDown(Enum.KeyCode.LeftShift) then speed = speed * FlyConfig.SprintMult end

            -- Target velocity
            local targetVel
            if moveDir.Magnitude > 0 then
                targetVel = moveDir.Unit * speed + Vector3.new(0, vy * speed, 0)
            else
                targetVel = Vector3.new(0, vy * speed, 0)
            end

            -- Smooth acceleration
            local alpha = math.min(1, dt * FlyConfig.Accel)
            currentVel  = currentVel:Lerp(targetVel, alpha)
            bv.Velocity = currentVel

            -- Smoothly rotate the character to face the horizontal movement direction
            if moveDir.Magnitude > 0 then
                -- Point root toward movement dir (yaw only), BodyGyro does the smooth turn
                local targetCF = CFrame.new(root.Position, root.Position + moveDir.Unit)
                bg.CFrame = targetCF
            end

            -- Pitch the root to match vertical velocity so character tilts up/down
            local totalDir = currentVel
            if totalDir.Magnitude > 0.5 then
                local pitchCF = CFrame.new(root.Position, root.Position + totalDir.Unit)
                root.CFrame   = root.CFrame:Lerp(pitchCF, 0.15)
            end
        end)
    end

    local function stopFly()
        if bv  then bv:Destroy();  bv  = nil end
        if bg  then bg:Destroy();  bg  = nil end
        if flyConn then
            flyConn:Disconnect()
            flyConn = nil
        end
        local hum = getHumanoid()
        if hum then
            hum.PlatformStand = false
            hum:ChangeState(Enum.HumanoidStateType.GettingUp)
        end
        local root = getRoot()
        if root then
            root.AssemblyLinearVelocity  = Vector3.zero
            root.AssemblyAngularVelocity = Vector3.zero
        end
    end

    UIS.InputBegan:Connect(function(input, processed)
        if processed then return end
        if input.KeyCode == FlyConfig.Toggle then
            flyActive = not flyActive
            if flyActive then startFly() else stopFly() end
        end
    end)

    LocalPlayer.CharacterAdded:Connect(function()
        flyActive = false
        if bv  then bv:Destroy();  bv  = nil end
        if bg  then bg:Destroy();  bg  = nil end
        if flyConn then
            flyConn:Disconnect()
            flyConn = nil
        end
    end)
end
