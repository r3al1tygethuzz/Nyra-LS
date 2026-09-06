--// NYRA LS — MODERN CONTROL PANEL
--// UI-only / Roblox Studio friendly
--// Full redesigned interface with functional UI controls

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local Player = Play--[[
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

-- ─────────────────────────────────────────────
--  FLY  (untouched — add your fly code below)
-- ─────────────────────────────────────────────

-- ─────────────────────────────────────────────
--  FLY  —  CFrame-based, WASD + Space
--  • Character always faces the camera look direction
--  • WASD moves relative to where you're looking (including up/down)
--  • Space rises straight up in world space
--  • No BodyVelocity / no physics — pure CFrame each heartbeat
--  • Toggle: F key
-- ─────────────────────────────────────────────
do
    local FlyConfig = {
        Speed       = 60,    -- studs/second
        SprintMult  = 2.2,   -- held with Left Shift
        Toggle      = Enum.KeyCode.F,
    }

    local flyActive  = false
    local flyConn    = nil  -- RenderStepped connection

    local UIS        = game:GetService("UserInputService")

    -- Stores original physical properties per BasePart so we can restore them
    -- { [part] = { CustomPhysicalProperties, Massless } }
    local _savedProps = {}

    -- ── helpers ──────────────────────────────────
    local function isDown(keyCode)
        return UIS:IsKeyDown(keyCode)
    end

    local function getRoot()
        local char = LocalPlayer.Character
        return char and char:FindFirstChild("HumanoidRootPart")
    end

    local function getHumanoid()
        local char = LocalPlayer.Character
        return char and char:FindFirstChildOfClass("Humanoid")
    end

    -- ── BodyPosition / BodyGyro anti-gravity ─────
    -- These legacy constraints actively counteract gravity every physics step.
    -- They are the only client-side method that reliably beats server-replicated gravity.
    local _bodyPos  = nil
    local _bodyGyro = nil

    local function attachAntiGrav(root)
        -- BodyPosition: locks the part to its current world position with max force
        local bp = Instance.new("BodyPosition")
        bp.Name      = "_NyraFlyBP"
        bp.MaxForce  = Vector3.new(1e9, 1e9, 1e9)
        bp.D         = 1000
        bp.P         = 10000
        bp.Position  = root.Position
        bp.Parent    = root
        _bodyPos = bp

        -- BodyGyro: prevents physics from rotating the part
        local bg = Instance.new("BodyGyro")
        bg.Name     = "_NyraFlyBG"
        bg.MaxTorque = Vector3.new(1e9, 1e9, 1e9)
        bg.D        = 500
        bg.P        = 10000
        bg.CFrame   = root.CFrame
        bg.Parent   = root
        _bodyGyro = bg
    end

    local function detachAntiGrav()
        if _bodyPos  then _bodyPos:Destroy();  _bodyPos  = nil end
        if _bodyGyro then _bodyGyro:Destroy(); _bodyGyro = nil end
    end

    -- ── core loop ────────────────────────────────
    local function startFly()
        local root = getRoot()
        if not root then return end

        local hum = getHumanoid()
        if hum then
            hum.PlatformStand = true
            hum:ChangeState(Enum.HumanoidStateType.Physics)
        end

        -- Zero any existing fall velocity immediately
        root.AssemblyLinearVelocity  = Vector3.zero
        root.AssemblyAngularVelocity = Vector3.zero

        attachAntiGrav(root)

        flyConn = RunService.RenderStepped:Connect(function(dt)
            root = getRoot()
            if not root then return end
            if not _bodyPos or not _bodyGyro then return end

            local camCF = Camera.CFrame

            -- Build movement vector from WASD in full camera space (X Y Z)
            local moveDir = Vector3.zero

            if isDown(Enum.KeyCode.W) then moveDir = moveDir - camCF.LookVector end
            if isDown(Enum.KeyCode.S) then moveDir = moveDir + camCF.LookVector end
            if isDown(Enum.KeyCode.A) then moveDir = moveDir - camCF.RightVector end
            if isDown(Enum.KeyCode.D) then moveDir = moveDir + camCF.RightVector end
            if isDown(Enum.KeyCode.Space) then
                moveDir = moveDir + Vector3.new(0, 1, 0)
            end
            if isDown(Enum.KeyCode.LeftControl) then
                moveDir = moveDir - Vector3.new(0, 1, 0)
            end

            local speed = FlyConfig.Speed
            if isDown(Enum.KeyCode.LeftShift) then
                speed = speed * FlyConfig.SprintMult
            end

            if moveDir.Magnitude > 0 then
                moveDir = moveDir.Unit
            end

            -- Advance the BodyPosition target — this is what moves the character.
            -- Physics drives the root to this position; gravity is cancelled by MaxForce.
            local newPos = _bodyPos.Position + moveDir * speed * dt
            _bodyPos.Position = newPos

            -- Orient character to face exactly where the camera looks (full pitch)
            local lookCF = CFrame.new(newPos, newPos + camCF.LookVector)
            _bodyGyro.CFrame = lookCF

            -- Also write CFrame directly so the render position is never a frame behind
            root.CFrame = lookCF
        end)
    end

    local function stopFly()
        detachAntiGrav()
        if flyConn then
            flyConn:Disconnect()
            flyConn = nil
        end
        local hum = getHumanoid()
        if hum then
            hum.PlatformStand = false
            hum:ChangeState(Enum.HumanoidStateType.GettingUp)
        end
        -- Kill any residual velocity so the character doesn't rocket off
        local root = getRoot()
        if root then
            root.AssemblyLinearVelocity  = Vector3.zero
            root.AssemblyAngularVelocity = Vector3.zero
        end
    end

    -- ── toggle input ─────────────────────────────
    UIS.InputBegan:Connect(function(input, processed)
        if processed then return end
        if input.KeyCode == FlyConfig.Toggle then
            flyActive = not flyActive
            if flyActive then
                startFly()
            else
                stopFly()
            end
        end
    end)

    -- Clean up if character respawns mid-flight
    LocalPlayer.CharacterAdded:Connect(function()
        flyActive = false
        _savedProps = {}
        if flyConn then
            flyConn:Disconnect()
            flyConn = nil
        end
    end)
end
ers.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")

--// Prevent duplicate UI
local Existing = PlayerGui:FindFirstChild("NyraLSUI")
if Existing then
	Existing:Destroy()
end

--==================================================
-- CONFIG
--==================================================

local CONFIG = {
	WindowSize = UDim2.fromOffset(1000, 610),

	Background = Color3.fromRGB(13, 14, 17),
	Panel = Color3.fromRGB(18, 20, 24),
	Panel2 = Color3.fromRGB(22, 24, 29),
	Panel3 = Color3.fromRGB(27, 29, 35),

	Border = Color3.fromRGB(43, 46, 54),

	Text = Color3.fromRGB(235, 237, 242),
	SubText = Color3.fromRGB(139, 144, 154),
	Muted = Color3.fromRGB(91, 96, 106),

	Accent = Color3.fromRGB(255, 190, 70),
	AccentDark = Color3.fromRGB(112, 81, 32),

	Success = Color3.fromRGB(93, 214, 137),
	Danger = Color3.fromRGB(235, 92, 92),

	AnimationSpeed = 0.18,
}

local State = {
	Flight = false,
	Aimbot = false,

	FlySpeed = 60,
	Smoothness = 0.15,

	Activation = "Toggle",
	Keybind = "F",

	Animations = true,
	MinimalBorders = false,

	-- Flight internals
	FlightConnection = nil,
	Keys = {
		W = false,
		A = false,
		S = false,
		D = false,
		Space = false,
		LeftShift = false,
	},
}

-- UI Status Variables (assigned later)
local FlightStatus
local AimStatus
local SpeedStatus
local ModeStatus

--==================================================
-- HELPERS
--==================================================

local function New(className, properties)
	local object = Instance.new(className)

	for property, value in pairs(properties or {}) do
		object[property] = value
	end

	return object
end

local function Corner(parent, radius)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius or 8)
	corner.Parent = parent
	return corner
end

local function Stroke(parent, color, thickness, transparency)
	local stroke = Instance.new("UIStroke")
	stroke.Color = color or CONFIG.Border
	stroke.Thickness = thickness or 1
	stroke.Transparency = transparency or 0
	stroke.Parent = parent
	return stroke
end

local function Padding(parent, left, right, top, bottom)
	local padding = Instance.new("UIPadding")

	padding.PaddingLeft = UDim.new(0, left or 0)
	padding.PaddingRight = UDim.new(0, right or 0)
	padding.PaddingTop = UDim.new(0, top or 0)
	padding.PaddingBottom = UDim.new(0, bottom or 0)

	padding.Parent = parent
	return padding
end

local function Tween(object, properties, duration)
	if not CONFIG.AnimationSpeed or not State.Animations then
		for property, value in pairs(properties) do
			object[property] = value
		end
		return
	end

	TweenService:Create(
		object,
		TweenInfo.new(
			duration or CONFIG.AnimationSpeed,
			Enum.EasingStyle.Quart,
			Enum.EasingDirection.Out
		),
		properties
	):Play()
end

local function TextLabel(parent, text, size, color, font)
	return New("TextLabel", {
		Parent = parent,
		BackgroundTransparency = 1,
		Text = text,
		TextColor3 = color or CONFIG.Text,
		TextSize = size or 14,
		Font = font or Enum.Font.Gotham,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
	})
end

--==================================================
-- FLIGHT SYSTEM
--==================================================

local FlightConnection = nil
local FlightInputConnection = nil
local FlightInputEndConnection = nil

local FlightKeys = {
	W = false,
	A = false,
	S = false,
	D = false,
	Space = false,
	LeftShift = false,
}

local function GetCharacter()
	local character = Player.Character

	if not character then
		return nil, nil, nil
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")

	return character, humanoid, root
end

local function StartFlight()
	if FlightConnection then
		return
	end

	local character, humanoid, root = GetCharacter()

	if not character or not humanoid or not root then
		warn("[NYRA] Character is not ready for flight.")
		return
	end

	State.Flight = true
	humanoid.AutoRotate = false
	humanoid.PlatformStand = true

	-- Update UI
	if FlightStatus then
		FlightStatus.Value.Text = "ENABLED"
		FlightStatus.Dot.BackgroundColor3 = CONFIG.Success
	end

	-- Keyboard input
	FlightInputConnection = UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end

		if input.UserInputType ~= Enum.UserInputType.Keyboard then
			return
		end

		local key = input.KeyCode.Name

		if FlightKeys[key] ~= nil then
			FlightKeys[key] = true
		end
	end)

	FlightInputEndConnection = UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.Keyboard then
			return
		end

		local key = input.KeyCode.Name

		if FlightKeys[key] ~= nil then
			FlightKeys[key] = false
		end
	end)

	-- Flight loop
	FlightConnection = RunService.RenderStepped:Connect(function(deltaTime)
		local currentCharacter, currentHumanoid, currentRoot = GetCharacter()

		if not currentCharacter or not currentHumanoid or not currentRoot then
			return
		end

		local camera = workspace.CurrentCamera

		if not camera then
			return
		end

		local movement = Vector3.zero

		local look = camera.CFrame.LookVector
		local right = camera.CFrame.RightVector

		if FlightKeys.W then
			movement += look
		end

		if FlightKeys.S then
			movement -= look
		end

		if FlightKeys.A then
			movement -= right
		end

		if FlightKeys.D then
			movement += right
		end

		if FlightKeys.Space then
			movement += Vector3.yAxis
		end

		if FlightKeys.LeftShift then
			movement -= Vector3.yAxis
		end

		if movement.Magnitude > 0 then
			movement = movement.Unit

			-- CFrame movement
			currentRoot.CFrame =
				currentRoot.CFrame +
				(movement * State.FlySpeed * deltaTime)

			-- Horizontal facing
			local horizontal = Vector3.new(
				movement.X,
				0,
				movement.Z
			)

			if horizontal.Magnitude > 0.001 then
				horizontal = horizontal.Unit

				currentRoot.CFrame = CFrame.lookAt(
					currentRoot.Position,
					currentRoot.Position + horizontal
				)
			end
		end
	end)

	print("[NYRA] Flight enabled.")
end

local function StopFlight()
	if FlightConnection then
		FlightConnection:Disconnect()
		FlightConnection = nil
	end

	if FlightInputConnection then
		FlightInputConnection:Disconnect()
		FlightInputConnection = nil
	end

	if FlightInputEndConnection then
		FlightInputEndConnection:Disconnect()
		FlightInputEndConnection = nil
	end

	for key in pairs(FlightKeys) do
		FlightKeys[key] = false
	end

	local character, humanoid = GetCharacter()

	if humanoid then
		humanoid.AutoRotate = true
		humanoid.PlatformStand = false
	end

	State.Flight = false

	-- Update UI
	if FlightStatus then
		FlightStatus.Value.Text = "DISABLED"
		FlightStatus.Dot.BackgroundColor3 = CONFIG.Muted
	end

	print("[NYRA] Flight disabled.")
end

local function SetFlightSpeed(speed)
	State.FlySpeed = math.clamp(
		tonumber(speed) or 60,
		10,
		200
	)

	if SpeedStatus then
		SpeedStatus.Value.Text = tostring(
			math.floor(State.FlySpeed)
		)
	end
end

-- Respawn handling
Player.CharacterAdded:Connect(function(character)
	if State.Flight then
		StopFlight()

		task.wait(0.5)

		if Player.Character == character then
			StartFlight()
		end
	end
end)

--==================================================
-- ROOT
--==================================================

local Gui = New("ScreenGui", {
	Name = "NyraLSUI",
	Parent = PlayerGui,
	ResetOnSpawn = false,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
})

local Main = New("Frame", {
	Name = "Main",
	Parent = Gui,
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = CONFIG.WindowSize,
	BackgroundColor3 = CONFIG.Background,
	BorderSizePixel = 0,
})

Corner(Main, 12)
Stroke(Main, CONFIG.Border, 1)

--==================================================
-- HEADER
--==================================================

local Header = New("Frame", {
	Name = "Header",
	Parent = Main,
	Size = UDim2.new(1, 0, 0, 68),
	BackgroundColor3 = CONFIG.Panel,
	BorderSizePixel = 0,
})

Corner(Header, 12)

local HeaderMask = New("Frame", {
	Parent = Header,
	Position = UDim2.new(0, 0, 1, -12),
	Size = UDim2.new(1, 0, 0, 12),
	BackgroundColor3 = CONFIG.Panel,
	BorderSizePixel = 0,
})

-- Logo
local Logo = TextLabel(
	Header,
	"NYRA",
	22,
	CONFIG.Text,
	Enum.Font.GothamBold
)

Logo.Position = UDim2.fromOffset(25, 11)
Logo.Size = UDim2.fromOffset(100, 28)

local LogoLine = New("Frame", {
	Parent = Header,
	Position = UDim2.fromOffset(25, 42),
	Size = UDim2.fromOffset(28, 2),
	BackgroundColor3 = CONFIG.Accent,
	BorderSizePixel = 0,
})

Corner(LogoLine, 2)

local Subtitle = TextLabel(
	Header,
	"LS / CONTROL PANEL",
	10,
	CONFIG.SubText,
	Enum.Font.GothamMedium
)

Subtitle.Position = UDim2.fromOffset(72, 43)
Subtitle.Size = UDim2.fromOffset(160, 16)

-- Online status
local OnlineDot = New("Frame", {
	Parent = Header,
	Position = UDim2.new(1, -188, 0, 25),
	Size = UDim2.fromOffset(7, 7),
	BackgroundColor3 = CONFIG.Success,
	BorderSizePixel = 0,
})

Corner(OnlineDot, 10)

local OnlineText = TextLabel(
	Header,
	"ONLINE",
	11,
	CONFIG.Success,
	Enum.Font.GothamBold
)

OnlineText.Position = UDim2.new(1, -173, 0, 18)
OnlineText.Size = UDim2.fromOffset(70, 22)

-- Minimize
local Minimize = New("TextButton", {
	Parent = Header,
	Position = UDim2.new(1, -80, 0, 16),
	Size = UDim2.fromOffset(28, 28),
	BackgroundColor3 = CONFIG.Panel3,
	BorderSizePixel = 0,
	Text = "—",
	TextColor3 = CONFIG.SubText,
	TextSize = 16,
	Font = Enum.Font.GothamBold,
	AutoButtonColor = false,
})

Corner(Minimize, 7)

Minimize.MouseEnter:Connect(function()
	Tween(Minimize, {BackgroundColor3 = CONFIG.Border})
end)

Minimize.MouseLeave:Connect(function()
	Tween(Minimize, {BackgroundColor3 = CONFIG.Panel3})
end)

-- Close
local Close = New("TextButton", {
	Parent = Header,
	Position = UDim2.new(1, -45, 0, 16),
	Size = UDim2.fromOffset(28, 28),
	BackgroundColor3 = CONFIG.Panel3,
	BorderSizePixel = 0,
	Text = "×",
	TextColor3 = CONFIG.SubText,
	TextSize = 18,
	Font = Enum.Font.GothamMedium,
	AutoButtonColor = false,
})

Corner(Close, 7)

Close.MouseEnter:Connect(function()
	Tween(Close, {BackgroundColor3 = CONFIG.Danger})
	Tween(Close, {TextColor3 = Color3.new(1, 1, 1)})
end)

Close.MouseLeave:Connect(function()
	Tween(Close, {BackgroundColor3 = CONFIG.Panel3})
	Tween(Close, {TextColor3 = CONFIG.SubText})
end)

--==================================================
-- SIDEBAR
--==================================================

local Sidebar = New("Frame", {
	Name = "Sidebar",
	Parent = Main,
	Position = UDim2.fromOffset(0, 68),
	Size = UDim2.new(0, 205, 1, -68),
	BackgroundColor3 = CONFIG.Panel,
	BorderSizePixel = 0,
})

local SideStroke = Stroke(Sidebar, CONFIG.Border, 1)
SideStroke.Transparency = 0.65

local NavTitle = TextLabel(
	Sidebar,
	"NAVIGATION",
	10,
	CONFIG.Muted,
	Enum.Font.GothamBold
)

NavTitle.Position = UDim2.fromOffset(24, 25)
NavTitle.Size = UDim2.fromOffset(150, 20)

local NavHolder = New("Frame", {
	Parent = Sidebar,
	Position = UDim2.fromOffset(13, 52),
	Size = UDim2.new(1, -26, 0, 145),
	BackgroundTransparency = 1,
})

local NavLayout = New("UIListLayout", {
	Parent = NavHolder,
	SortOrder = Enum.SortOrder.LayoutOrder,
	Padding = UDim.new(0, 5),
})

local SystemTitle = TextLabel(
	Sidebar,
	"SYSTEM",
	10,
	CONFIG.Muted,
	Enum.Font.GothamBold
)

SystemTitle.Position = UDim2.fromOffset(24, 215)
SystemTitle.Size = UDim2.fromOffset(150, 20)

local SystemHolder = New("Frame", {
	Parent = Sidebar,
	Position = UDim2.fromOffset(13, 242),
	Size = UDim2.new(1, -26, 0, 55),
	BackgroundTransparency = 1,
})

--==================================================
-- CONTENT
--==================================================

local Content = New("Frame", {
	Name = "Content",
	Parent = Main,
	Position = UDim2.fromOffset(205, 68),
	Size = UDim2.new(1, -205, 1, -68),
	BackgroundColor3 = CONFIG.Background,
	BorderSizePixel = 0,
})

local Pages = {}

local function CreatePage(name)
	local page = New("ScrollingFrame", {
		Name = name,
		Parent = Content,
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 3,
		ScrollBarImageColor3 = CONFIG.Border,
		CanvasSize = UDim2.new(0, 0, 0, 0),
		Visible = false,
	})

	Padding(page, 28, 28, 26, 28)

	local layout = New("UIListLayout", {
		Parent = page,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 18),
	})

	layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		page.CanvasSize = UDim2.fromOffset(
			0,
			layout.AbsoluteContentSize.Y + 35
		)
	end)

	Pages[name] = page

	return page
end

local OverviewPage = CreatePage("Overview")
local FlightPage = CreatePage("Flight")
local AimbotPage = CreatePage("Aimbot")
local SettingsPage = CreatePage("Settings")

--==================================================
-- PAGE TITLE
--==================================================

local function CreatePageHeader(parent, title, description)
	local holder = New("Frame", {
		Parent = parent,
		Size = UDim2.new(1, 0, 0, 54),
		BackgroundTransparency = 1,
	})

	local titleLabel = TextLabel(
		holder,
		title,
		23,
		CONFIG.Text,
		Enum.Font.GothamBold
	)

	titleLabel.Position = UDim2.fromOffset(0, 0)
	titleLabel.Size = UDim2.new(1, 0, 0, 28)

	local descLabel = TextLabel(
		holder,
		description,
		11,
		CONFIG.SubText,
		Enum.Font.Gotham
	)

	descLabel.Position = UDim2.fromOffset(0, 30)
	descLabel.Size = UDim2.new(1, 0, 0, 20)

	return holder
end

--==================================================
-- NAV BUTTONS
--==================================================

local NavButtons = {}

local function CreateNavButton(parent, name, icon, order)
	local button = New("TextButton", {
		Parent = parent,
		Size = UDim2.new(1, 0, 0, 42),
		BackgroundColor3 = CONFIG.Panel,
		BorderSizePixel = 0,
		Text = "",
		AutoButtonColor = false,
		LayoutOrder = order,
	})

	Corner(button, 7)

	local indicator = New("Frame", {
		Parent = button,
		Position = UDim2.fromOffset(0, 8),
		Size = UDim2.fromOffset(3, 26),
		BackgroundColor3 = CONFIG.Accent,
		BorderSizePixel = 0,
		Visible = false,
	})

	Corner(indicator, 3)

	local iconLabel = TextLabel(
		button,
		icon,
		14,
		CONFIG.Muted,
		Enum.Font.GothamBold
	)

	iconLabel.Position = UDim2.fromOffset(16, 0)
	iconLabel.Size = UDim2.fromOffset(25, 42)
	iconLabel.TextXAlignment = Enum.TextXAlignment.Center

	local text = TextLabel(
		button,
		name,
		12,
		CONFIG.SubText,
		Enum.Font.GothamMedium
	)

	text.Position = UDim2.fromOffset(48, 0)
	text.Size = UDim2.new(1, -58, 1, 0)

	NavButtons[name] = {
		Button = button,
		Indicator = indicator,
		Icon = iconLabel,
		Text = text,
	}

	button.MouseEnter:Connect(function()
		if not indicator.Visible then
			Tween(button, {
				BackgroundColor3 = CONFIG.Panel3
			})
		end
	end)

	button.MouseLeave:Connect(function()
		if not indicator.Visible then
			Tween(button, {
				BackgroundColor3 = CONFIG.Panel
			})
		end
	end)

	return button
end

CreateNavButton(NavHolder, "Overview", "⌂", 1)
CreateNavButton(NavHolder, "Flight", "✦", 2)
CreateNavButton(NavHolder, "Aimbot", "◎", 3)

CreateNavButton(SystemHolder, "Settings", "⚙", 1)

--==================================================
-- PAGE SWITCHING
--==================================================

local CurrentPage

local function SelectPage(name)
	for pageName, page in pairs(Pages) do
		page.Visible = pageName == name
	end

	for buttonName, data in pairs(NavButtons) do
		local selected = buttonName == name

		data.Indicator.Visible = selected

		Tween(data.Button, {
			BackgroundColor3 = selected
				and CONFIG.Panel3
				or CONFIG.Panel
		})

		Tween(data.Icon, {
			TextColor3 = selected
				and CONFIG.Accent
				or CONFIG.Muted
		})

		Tween(data.Text, {
			TextColor3 = selected
				and CONFIG.Text
				or CONFIG.SubText
		})
	end

	CurrentPage = name
end

for name, data in pairs(NavButtons) do
	data.Button.MouseButton1Click:Connect(function()
		SelectPage(name)
	end)
end

--==================================================
-- COMPONENTS
--==================================================

local function CreateSection(parent, title, subtitle)
	local section = New("Frame", {
		Parent = parent,
		Size = UDim2.new(1, 0, 0, 100),
		BackgroundColor3 = CONFIG.Panel,
		BorderSizePixel = 0,
	})

	Corner(section, 9)
	Stroke(section, CONFIG.Border, 1, 0.3)

	local titleLabel = TextLabel(
		section,
		title,
		13,
		CONFIG.Text,
		Enum.Font.GothamBold
	)

	titleLabel.Position = UDim2.fromOffset(18, 13)
	titleLabel.Size = UDim2.new(1, -36, 0, 20)

	if subtitle then
		local sub = TextLabel(
			section,
			subtitle,
			10,
			CONFIG.SubText,
			Enum.Font.Gotham
		)

		sub.Position = UDim2.fromOffset(18, 34)
		sub.Size = UDim2.new(1, -36, 0, 18)
	end

	return section
end

local function CreateToggle(parent, title, description, initial, callback)
	local holder = New("Frame", {
		Parent = parent,
		Size = UDim2.new(1, -36, 0, 52),
		Position = UDim2.fromOffset(18, 47),
		BackgroundTransparency = 1,
	})

	local titleLabel = TextLabel(
		holder,
		title,
		12,
		CONFIG.Text,
		Enum.Font.GothamMedium
	)

	titleLabel.Size = UDim2.new(1, -75, 0, 22)

	local desc = TextLabel(
		holder,
		description or "",
		10,
		CONFIG.SubText,
		Enum.Font.Gotham
	)

	desc.Position = UDim2.fromOffset(0, 22)
	desc.Size = UDim2.new(1, -75, 0, 18)

	local toggle = New("TextButton", {
		Parent = holder,
		Position = UDim2.new(1, -48, 0, 5),
		Size = UDim2.fromOffset(44, 24),
		BackgroundColor3 = initial
			and CONFIG.AccentDark
			or CONFIG.Panel3,
		BorderSizePixel = 0,
		Text = "",
		AutoButtonColor = false,
	})

	Corner(toggle, 12)
	Stroke(toggle, CONFIG.Border, 1)

	local knob = New("Frame", {
		Parent = toggle,
		Position = initial
			and UDim2.new(1, -21, 0.5, -8)
			or UDim2.new(0, 5, 0.5, -8),
		Size = UDim2.fromOffset(16, 16),
		BackgroundColor3 = initial
			and CONFIG.Accent
			or CONFIG.Muted,
		BorderSizePixel = 0,
	})

	Corner(knob, 20)

	local value = initial

	local function SetValue(newValue)
		value = newValue

		Tween(toggle, {
			BackgroundColor3 = value
				and CONFIG.AccentDark
				or CONFIG.Panel3
		})

		Tween(knob, {
			Position = value
				and UDim2.new(1, -21, 0.5, -8)
				or UDim2.new(0, 5, 0.5, -8),

			BackgroundColor3 = value
				and CONFIG.Accent
				or CONFIG.Muted
		})

		if callback then
			callback(value)
		end
	end

	toggle.MouseButton1Click:Connect(function()
		SetValue(not value)
	end)

	return {
		Set = SetValue,
		Get = function()
			return value
		end,
	}
end

local function CreateSlider(parent, title, minimum, maximum, initial, callback)
	local holder = New("Frame", {
		Parent = parent,
		Size = UDim2.new(1, -36, 0, 70),
		Position = UDim2.fromOffset(18, 47),
		BackgroundTransparency = 1,
	})

	local titleLabel = TextLabel(
		holder,
		title,
		12,
		CONFIG.Text,
		Enum.Font.GothamMedium
	)

	titleLabel.Position = UDim2.fromOffset(0, 0)
	titleLabel.Size = UDim2.fromOffset(200, 22)

	local valueLabel = TextLabel(
		holder,
		tostring(initial),
		11,
		CONFIG.Accent,
		Enum.Font.GothamBold
	)

	valueLabel.Position = UDim2.new(1, -80, 0, 0)
	valueLabel.Size = UDim2.fromOffset(80, 22)
	valueLabel.TextXAlignment = Enum.TextXAlignment.Right

	local bar = New("Frame", {
		Parent = holder,
		Position = UDim2.fromOffset(0, 35),
		Size = UDim2.new(1, 0, 0, 5),
		BackgroundColor3 = CONFIG.Panel3,
		BorderSizePixel = 0,
	})

	Corner(bar, 5)

	local fill = New("Frame", {
		Parent = bar,
		Size = UDim2.fromScale(
			(initial - minimum) / (maximum - minimum),
			1
		),
		BackgroundColor3 = CONFIG.Accent,
		BorderSizePixel = 0,
	})

	Corner(fill, 5)

	local knob = New("Frame", {
		Parent = bar,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(
			(initial - minimum) / (maximum - minimum),
			0,
			0.5,
			0
		),
		Size = UDim2.fromOffset(13, 13),
		BackgroundColor3 = CONFIG.Text,
		BorderSizePixel = 0,
	})

	Corner(knob, 20)

	local dragging = false
	local current = initial

	local function SetValue(value)
		current = math.clamp(value, minimum, maximum)

		local alpha = (current - minimum) / (maximum - minimum)

		valueLabel.Text = tostring(math.floor(current))

		Tween(fill, {
			Size = UDim2.fromScale(alpha, 1)
		})

		Tween(knob, {
			Position = UDim2.new(alpha, 0, 0.5, 0)
		})

		if callback then
			callback(current)
		end
	end

	local function Update(inputX)
		local alpha = math.clamp(
			(inputX - bar.AbsolutePosition.X) / bar.AbsoluteSize.X,
			0,
			1
		)

		SetValue(
			minimum + (maximum - minimum) * alpha
		)
	end

	bar.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging = true
			Update(input.Position.X)
		end
	end)

	UserInputService.InputChanged:Connect(function(input)
		if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
			Update(input.Position.X)
		end
	end)

	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging = false
		end
	end)

	return {
		Set = SetValue,
		Get = function()
			return current
		end,
	}
end

local function CreateButton(parent, text, callback)
	local button = New("TextButton", {
		Parent = parent,
		Size = UDim2.new(1, -36, 0, 40),
		Position = UDim2.fromOffset(18, 47),
		BackgroundColor3 = CONFIG.Panel3,
		BorderSizePixel = 0,
		Text = text,
		TextColor3 = CONFIG.Text,
		TextSize = 11,
		Font = Enum.Font.GothamMedium,
		AutoButtonColor = false,
	})

	Corner(button, 7)
	Stroke(button, CONFIG.Border, 1)

	button.MouseEnter:Connect(function()
		Tween(button, {
			BackgroundColor3 = CONFIG.Border
		})
	end)

	button.MouseLeave:Connect(function()
		Tween(button, {
			BackgroundColor3 = CONFIG.Panel3
		})
	end)

	button.MouseButton1Click:Connect(function()
		if callback then
			callback()
		end
	end)

	return button
end

--==================================================
-- OVERVIEW
--==================================================

CreatePageHeader(
	OverviewPage,
	"Overview",
	"Monitor your current Nyra control configuration."
)

local StatusGrid = New("Frame", {
	Parent = OverviewPage,
	Size = UDim2.new(1, 0, 0, 142),
	BackgroundTransparency = 1,
})

local GridLayout = New("UIGridLayout", {
	Parent = StatusGrid,
	CellSize = UDim2.new(0.5, -9, 0, 67),
	CellPadding = UDim2.fromOffset(12, 9),
	SortOrder = Enum.SortOrder.LayoutOrder,
})

local function StatusCard(parent, title, value, description, order)
	local card = New("Frame", {
		Parent = parent,
		Size = UDim2.fromOffset(100, 60),
		BackgroundColor3 = CONFIG.Panel,
		BorderSizePixel = 0,
		LayoutOrder = order,
	})

	Corner(card, 8)
	Stroke(card, CONFIG.Border, 1, 0.35)

	local dot = New("Frame", {
		Parent = card,
		Position = UDim2.fromOffset(17, 17),
		Size = UDim2.fromOffset(7, 7),
		BackgroundColor3 = CONFIG.Muted,
		BorderSizePixel = 0,
	})

	Corner(dot, 10)

	local titleLabel = TextLabel(
		card,
		title,
		10,
		CONFIG.SubText,
		Enum.Font.GothamMedium
	)

	titleLabel.Position = UDim2.fromOffset(31, 10)
	titleLabel.Size = UDim2.new(1, -45, 20, 0)

	local valueLabel = TextLabel(
		card,
		value,
		15,
		CONFIG.Text,
		Enum.Font.GothamBold
	)

	valueLabel.Position = UDim2.fromOffset(17, 30)
	valueLabel.Size = UDim2.new(1, -34, 25, 0)

	local descLabel = TextLabel(
		card,
		description,
		9,
		CONFIG.SubText,
		Enum.Font.Gotham
	)

	descLabel.Position = UDim2.new(1, -115, 0, 10)
	descLabel.Size = UDim2.fromOffset(98, 20)
	descLabel.TextXAlignment = Enum.TextXAlignment.Right

	return {
		Card = card,
		Dot = dot,
		Value = valueLabel,
	}
end

local FlightStatus = StatusCard(
	StatusGrid,
	"FLIGHT",
	"DISABLED",
	"Standby",
	1
)

local AimStatus = StatusCard(
	StatusGrid,
	"AIM ASSIST",
	"DISABLED",
	"Standby",
	2
)

local SpeedStatus = StatusCard(
	StatusGrid,
	"FLY SPEED",
	"60",
	"Current",
	3
)

local ModeStatus = StatusCard(
	StatusGrid,
	"ACTIVATION",
	"TOGGLE",
	"Current",
	4
)

-- Quick Controls
local Quick = CreateSection(
	OverviewPage,
	"Quick Controls",
	"Frequently used interface controls."
)

local QuickFlight = CreateToggle(
	Quick,
	"Flight",
	"Enable the flight interface state.",
	false,
	function(value)
		State.Flight = value

		if value then
			StartFlight()
		else
			StopFlight()
		end
	end
)

local QuickSpeed = CreateSlider(
	Quick,
	"Fly Speed",
	10,
	200,
	State.FlySpeed,
	function(value)
		SetFlightSpeed(math.floor(value))
	end
)

local QuickAim = CreateToggle(
	Quick,
	"Aim Assist",
	"Enable the aim-assist interface state.",
	false,
	function(value)
		State.Aimbot = value

		AimStatus.Value.Text = value and "ENABLED" or "DISABLED"
		AimStatus.Dot.BackgroundColor3 =
			value and CONFIG.Success or CONFIG.Muted

		-- Hook your own game's aim system here.
	end
)

--==================================================
-- FLIGHT PAGE
--==================================================

CreatePageHeader(
	FlightPage,
	"Flight",
	"Configure movement controls for your own Roblox experience."
)

local FlightSection = CreateSection(
	FlightPage,
	"Flight Controller",
	"Movement configuration."
)

local FlightToggle = CreateToggle(
	FlightSection,
	"Enable Flight",
	"Toggle your game's flight controller.",
	State.Flight,
	function(value)
		State.Flight = value

		if value then
			StartFlight()
		else
			StopFlight()
		end
	end
)

local SpeedSlider = CreateSlider(
	FlightSection,
	"Movement Speed",
	10,
	200,
	State.FlySpeed,
	function(value)
		SetFlightSpeed(math.floor(value))
	end
)

local FlightControls = CreateSection(
	FlightPage,
	"Controls",
	"Keyboard controls used by your game's controller."
)

local ControlText = TextLabel(
	FlightControls,
	"W / A / S / D     Move\nSPACE              Ascend\nLEFT SHIFT         Descend\nF                    Toggle Flight",
	11,
	CONFIG.SubText,
	Enum.Font.GothamMedium
)

ControlText.Position = UDim2.fromOffset(18, 49)
ControlText.Size = UDim2.new(1, -36, 0, 70)

--==================================================
-- AIMBOT PAGE
--==================================================

CreatePageHeader(
	AimbotPage,
	"Aimbot",
	"Interface settings for an aim-assist system in your own game."
)

local AimSection = CreateSection(
	AimbotPage,
	"Aim Assist",
	"Configure the interface and activation behavior."
)

local AimToggle = CreateToggle(
	AimSection,
	"Enable Aim Assist",
	"Toggle the aim-assist system.",
	State.Aimbot,
	function(value)
		State.Aimbot = value

		AimStatus.Value.Text = value and "ENABLED" or "DISABLED"
		AimStatus.Dot.BackgroundColor3 =
			value and CONFIG.Success or CONFIG.Muted

		-- CONNECT YOUR OWN AIM SYSTEM HERE
	end
)

local SmoothSlider = CreateSlider(
	AimSection,
	"Smoothness",
	1,
	100,
	15,
	function(value)
		State.Smoothness = value / 100
	end
)

local ActivationSection = CreateSection(
	AimbotPage,
	"Activation",
	"Choose how your own game's system responds to the keybind."
)

local ModeButton = CreateButton(
	ActivationSection,
	"MODE: TOGGLE",
	function()
		if State.Activation == "Toggle" then
			State.Activation = "Hold"
		else
			State.Activation = "Toggle"
		end

		ModeButton.Text = "MODE: " .. string.upper(State.Activation)
		ModeStatus.Value.Text = string.upper(State.Activation)
	end
)

local KeybindButton = CreateButton(
	ActivationSection,
	"KEYBIND: F",
	function()
		KeybindButton.Text = "PRESS A KEY..."

		local connection
		connection = UserInputService.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.Keyboard then
				State.Keybind = input.KeyCode.Name

				KeybindButton.Text =
					"KEYBIND: " .. State.Keybind

				connection:Disconnect()
			end
		end)
	end
)

KeybindButton.Position = UDim2.fromOffset(18, 94)

--==================================================
-- SETTINGS PAGE
--==================================================

CreatePageHeader(
	SettingsPage,
	"Settings",
	"Customize the appearance and behavior of the Nyra interface."
)

local AppearanceSection = CreateSection(
	SettingsPage,
	"Appearance",
	"Interface presentation."
)

CreateToggle(
	AppearanceSection,
	"Animations",
	"Enable smooth interface transitions.",
	true,
	function(value)
		State.Animations = value
	end
)

CreateToggle(
	AppearanceSection,
	"Minimal Borders",
	"Reduce visual border intensity.",
	false,
	function(value)
		State.MinimalBorders = value

		for _, object in ipairs(Gui:GetDescendants()) do
			if object:IsA("UIStroke") then
				object.Transparency = value and 1 or 0.3
			end
		end
	end
)

local AboutSection = CreateSection(
	SettingsPage,
	"About",
	"Nyra interface information."
)

local AboutText = TextLabel(
	AboutSection,
	"NYRA LS\nModern Control Panel\nBuild 1.0.0",
	11,
	CONFIG.SubText,
	Enum.Font.GothamMedium
)

AboutText.Position = UDim2.fromOffset(18, 48)
AboutText.Size = UDim2.new(1, -36, 0, 55)

--==================================================
-- FOOTER
--==================================================

local Footer = New("Frame", {
	Parent = Sidebar,
	Position = UDim2.new(0, 20, 1, -57),
	Size = UDim2.new(1, -40, 0, 37),
	BackgroundTransparency = 1,
})

local FooterName = TextLabel(
	Footer,
	"NYRA LS",
	10,
	CONFIG.Text,
	Enum.Font.GothamBold
)

FooterName.Position = UDim2.fromOffset(0, 0)
FooterName.Size = UDim2.new(1, 0, 0, 17)

local FooterBuild = TextLabel(
	Footer,
	"build 1.0.0",
	9,
	CONFIG.Muted,
	Enum.Font.Gotham
)

FooterBuild.Position = UDim2.fromOffset(0, 17)
FooterBuild.Size = UDim2.new(1, 0, 0, 16)

--==================================================
-- DRAGGING
--==================================================

local dragging = false
local dragStart
local startPosition

Header.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		dragging = true
		dragStart = input.Position
		startPosition = Main.Position
	end
end)

Header.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		dragging = false
	end
end)

UserInputService.InputChanged:Connect(function(input)
	if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
		local delta = input.Position - dragStart

		Main.Position = UDim2.new(
			startPosition.X.Scale,
			startPosition.X.Offset + delta.X,
			startPosition.Y.Scale,
			startPosition.Y.Offset + delta.Y
		)
	end
end)

--==================================================
-- MINIMIZE / CLOSE
--==================================================

local minimized = false
local normalSize = CONFIG.WindowSize

Minimize.MouseButton1Click:Connect(function()
	minimized = not minimized

	if minimized then
		Tween(Main, {
			Size = UDim2.fromOffset(1000, 68)
		}, 0.2)

		Sidebar.Visible = false
		Content.Visible = false
	else
		Tween(Main, {
			Size = normalSize
		}, 0.2)

		task.delay(0.12, function()
			if not minimized then
				Sidebar.Visible = true
				Content.Visible = true
			end
		end)
	end
end)

Close.MouseButton1Click:Connect(function()
	Tween(Main, {
		Size = UDim2.fromOffset(850, 40),
		BackgroundTransparency = 1,
	}, 0.2)

	task.wait(0.22)

	Gui:Destroy()
end)

--==================================================
-- F KEY TOGGLE
--==================================================

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end

	if input.UserInputType ~= Enum.UserInputType.Keyboard then
		return
	end

	if input.KeyCode.Name == State.Keybind then
		if State.Flight then
			StopFlight()
		else
			StartFlight()
		end
	end
end)

--==================================================
-- INITIAL PAGE
--==================================================

SelectPage("Overview")

print("[NYRA LS] Interface loaded successfully.")
