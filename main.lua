--// NYRA LS — MODERN UI REVAMP
--// UI replacement for the existing Nyra LS interface

local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")

--==============================================================
-- CONFIG
--==============================================================

local flySpeed = 25
local aimbotSmoothness = 0.1
local aimbotKeybind = Enum.KeyCode.G
local aimbotMode = "Toggle"

local flying = false
local aimbotEnabled = false
local currentPage = "Overview"

--==============================================================
-- FLY LOGIC (ANTI-BAN VERSION)
--==============================================================

local function getValidCharacter()
    return Player.Character and Player.Character.Parent and Player.Character:FindFirstChild("HumanoidRootPart") and Player.Character:FindFirstChildOfClass("Humanoid")
end

local function startFly()
    if not getValidCharacter() then return end
    local character = Player.Character
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    local rootPart = character:FindFirstChild("HumanoidRootPart")
    local camera = workspace.CurrentCamera

    humanoid.PlatformStand = true
    -- Do not anchor or disable collides to avoid detection; use low-force BodyVelocity instead

    local bodyVelocity = Instance.new("BodyVelocity")
    bodyVelocity.MaxForce = Vector3.new(10000, 10000, 10000)  -- Lower force to mimic natural physics and avoid detection
    bodyVelocity.Velocity = Vector3.zero
    bodyVelocity.Parent = rootPart

    local flyConnection = RunService.Heartbeat:Connect(function(deltaTime)
        if not flying or not getValidCharacter() then
            stopFly()
            return
        end

        local moveVector = Vector3.zero
        -- Horizontal movement (camera-aligned)
        if UIS:IsKeyDown(Enum.KeyCode.W) then
            moveVector = moveVector + camera.CFrame.LookVector
        end
        if UIS:IsKeyDown(Enum.KeyCode.S) then
            moveVector = moveVector - camera.CFrame.LookVector
        end
        if UIS:IsKeyDown(Enum.KeyCode.A) then
            moveVector = moveVector - camera.CFrame.RightVector
        end
        if UIS:IsKeyDown(Enum.KeyCode.D) then
            moveVector = moveVector + camera.CFrame.RightVector
        end
        -- Vertical movement
        if UIS:IsKeyDown(Enum.KeyCode.Space) then
            moveVector = moveVector + Vector3.new(0, flySpeed, 0)
        end
        if UIS:IsKeyDown(Enum.KeyCode.LeftShift) then
            moveVector = moveVector - Vector3.new(0, flySpeed, 0)
        end
        -- Normalize and clamp speed to realistic values (max 50) to avoid anti-cheat flags
        if moveVector.Magnitude > 0 then
            moveVector = moveVector.Unit * math.min(flySpeed, 50)
        end
        -- Add small random offset to mimic natural movement and keep sending updates
        moveVector = moveVector + Vector3.new(math.random(-0.1, 0.1), math.random(-0.1, 0.1), math.random(-0.1, 0.1))
        bodyVelocity.Velocity = moveVector
    end)
end

local function stopFly()
    if flyConnection then
        flyConnection:Disconnect()
        flyConnection = nil
    end
    if getValidCharacter() then
        local humanoid = Player.Character:FindFirstChildOfClass("Humanoid")
        humanoid.PlatformStand = false
        local bodyVelocity = Player.Character.HumanoidRootPart:FindFirstChild("BodyVelocity")
        if bodyVelocity then
            bodyVelocity:Destroy()
        end
    end
end

-- Toggle fly on F key
UIS.InputBegan:Connect(function(input, gameProcessed)
    if not gameProcessed and input.KeyCode == Enum.KeyCode.F then
        flying = not flying
        if flying then
            startFly()
        else
            stopFly()
        end
    end
end)

--==============================================================
-- COLORS
--==============================================================

local C = {
    Background = Color3.fromRGB(12, 12, 13),
    Sidebar = Color3.fromRGB(15, 15, 16),
    Panel = Color3.fromRGB(19, 19, 20),
    Panel2 = Color3.fromRGB(23, 23, 24),

    Border = Color3.fromRGB(39, 39, 41),
    BorderLight = Color3.fromRGB(49, 49, 51),

    Text = Color3.fromRGB(238, 238, 240),
    TextDim = Color3.fromRGB(145, 145, 149),
    TextDark = Color3.fromRGB(95, 95, 99),

    Accent = Color3.fromRGB(190, 190, 190),
    AccentBright = Color3.fromRGB(225, 225, 225),

    Success = Color3.fromRGB(150, 210, 170),
    Danger = Color3.fromRGB(220, 125, 125),
}

--==============================================================
-- CLEAN OLD UI
--==============================================================

local old = PlayerGui:FindFirstChild("NyraLSUI")
if old then
    old:Destroy()
end

local Gui = Instance.new("ScreenGui")
Gui.Name = "NyraLSUI"
Gui.ResetOnSpawn = false
Gui.IgnoreGuiInset = true
Gui.Parent = PlayerGui

--==============================================================
-- HELPERS
--==============================================================

local function Corner(obj, radius)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, radius or 8)
    c.Parent = obj
    return c
end

local function Stroke(obj, color, thickness, transparency)
    local s = Instance.new("UIStroke")
    s.Color = color or C.Border
    s.Thickness = thickness or 1
    s.Transparency = transparency or 0
    s.Parent = obj
    return s
end

local function Tween(obj, info, props)
    return TweenService:Create(
        obj,
        info or TweenInfo.new(
            0.18,
            Enum.EasingStyle.Quint,
            Enum.EasingDirection.Out
        ),
        props
    )
end

local function Label(parent, text, size, position, font, color)
    local l = Instance.new("TextLabel")
    l.Parent = parent
    l.BackgroundTransparency = 1
    l.Text = text
    l.TextColor3 = color or C.Text
    l.Font = font or Enum.Font.Gotham
    l.TextSize = size or 14
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.Position = position or UDim2.new()
    return l
end

--==============================================================
-- MAIN WINDOW
--==============================================================

local Shadow = Instance.new("Frame")
Shadow.Parent = Gui
Shadow.AnchorPoint = Vector2.new(0.5, 0.5)
Shadow.Position = UDim2.fromScale(0.5, 0.5)
Shadow.Size = UDim2.new(0, 1040, 0, 650)
Shadow.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
Shadow.BackgroundTransparency = 0.45
Shadow.BorderSizePixel = 0
Corner(Shadow, 14)

local Main = Instance.new("Frame")
Main.Parent = Gui
Main.AnchorPoint = Vector2.new(0.5, 0.5)
Main.Position = UDim2.fromScale(0.5, 0.5)
Main.Size = UDim2.new(0, 1000, 0, 610)
Main.BackgroundColor3 = C.Background
Main.BorderSizePixel = 0
Main.Active = true

Corner(Main, 12)
Stroke(Main, C.Border, 1)

--==============================================================
-- HEADER
--==============================================================

local Header = Instance.new("Frame")
Header.Parent = Main
Header.Size = UDim2.new(1, 0, 0, 58)
Header.BackgroundColor3 = C.Panel
Header.BorderSizePixel = 0

Corner(Header, 12)

local HeaderLine = Instance.new("Frame")
HeaderLine.Parent = Header
HeaderLine.Position = UDim2.new(0, 0, 1, -1)
HeaderLine.Size = UDim2.new(1, 0, 0, 1)
HeaderLine.BackgroundColor3 = C.Border
HeaderLine.BorderSizePixel = 0

local Logo = Instance.new("Frame")
Logo.Parent = Header
Logo.Position = UDim2.new(0, 18, 0.5, -16)
Logo.Size = UDim2.new(0, 32, 0, 32)
Logo.BackgroundColor3 = C.Panel2
Logo.BorderSizePixel = 0
Corner(Logo, 8)
Stroke(Logo, C.BorderLight)

local LogoText = Label(
    Logo,
    "N",
    15,
    UDim2.new(0, 0, 0, 6),
    Enum.Font.GothamBold,
    C.Text
)
LogoText.Size = UDim2.new(1, 0, 0, 18)
LogoText.TextXAlignment = Enum.TextXAlignment.Center

local Title = Label(
    Header,
    "NYRA",
    14,
    UDim2.new(0, 60, 0, 10),
    Enum.Font.GothamBold
)

local Subtitle = Label(
    Header,
    "LS / CONTROL PANEL",
    9,
    UDim2.new(0, 60, 0, 29),
    Enum.Font.GothamMedium,
    C.TextDim
)

-- online indicator

local StatusDot = Instance.new("Frame")
StatusDot.Parent = Header
StatusDot.Position = UDim2.new(1, -128, 0.5, -4)
StatusDot.Size = UDim2.new(0, 8, 0, 8)
StatusDot.BackgroundColor3 = C.Success
StatusDot.BorderSizePixel = 0
Corner(StatusDot, 20)

local StatusText = Label(
    Header,
    "ONLINE",
    10,
    UDim2.new(1, -113, 0, 20),
    Enum.Font.GothamBold,
    C.TextDim
)
StatusText.Size = UDim2.new(0, 55, 0, 18)

--==============================================================
-- SIDEBAR
--==============================================================

local Sidebar = Instance.new("Frame")
Sidebar.Parent = Main
Sidebar.Position = UDim2.new(0, 0, 0, 58)
Sidebar.Size = UDim2.new(0, 190, 1, -58)
Sidebar.BackgroundColor3 = C.Sidebar
Sidebar.BorderSizePixel = 0

local SideLine = Instance.new("Frame")
SideLine.Parent = Sidebar
SideLine.Position = UDim2.new(1, -1, 0, 0)
SideLine.Size = UDim2.new(0, 1, 1, 0)
SideLine.BackgroundColor3 = C.Border
SideLine.BorderSizePixel = 0

local NavTitle = Label(
    Sidebar,
    "NAVIGATION",
    9,
    UDim2.new(0, 18, 0, 24),
    Enum.Font.GothamBold,
    C.TextDark
)

local Navigation = Instance.new("Frame")
Navigation.Parent = Sidebar
Navigation.Position = UDim2.new(0, 10, 0, 50)
Navigation.Size = UDim2.new(1, -20, 0, 180)
Navigation.BackgroundTransparency = 1

local NavLayout = Instance.new("UIListLayout")
NavLayout.Parent = Navigation
NavLayout.Padding = UDim.new(0, 5)

local Pages = {}

local function CreateNav(name, icon)
    local Button = Instance.new("TextButton")
    Button.Parent = Navigation
    Button.Size = UDim2.new(1, 0, 0, 40)
    Button.BackgroundColor3 = C.Sidebar
    Button.BorderSizePixel = 0
    Button.AutoButtonColor = false
    Button.Text = ""

    Corner(Button, 7)

    local Icon = Label(
        Button,
        icon,
        14,
        UDim2.new(0, 12, 0, 10),
        Enum.Font.GothamMedium,
        C.TextDim
    )

    Icon.Size = UDim2.new(0, 20, 0, 20)
    Icon.TextXAlignment = Enum.TextXAlignment.Center

    local Text = Label(
        Button,
        name,
        12,
        UDim2.new(0, 42, 0, 11),
        Enum.Font.GothamMedium,
        C.TextDim
    )

    Text.Size = UDim2.new(1, -50, 0, 20)

    Pages[name] = {
        Button = Button,
        Icon = Icon,
        Text = Text
    }

    Button.MouseEnter:Connect(function()
        if currentPage ~= name then
            Tween(Button, nil, {
                BackgroundColor3 = C.Panel
            }):Play()
        end
    end)

    Button.MouseLeave:Connect(function()
        if currentPage ~= name then
            Tween(Button, nil, {
                BackgroundColor3 = C.Sidebar
            }):Play()
        end
    end)

    return Button
end

local OverviewButton = CreateNav("Overview", "◈")
local FlyButton = CreateNav("Fly", "◇")
local AimButton = CreateNav("Aimbot", "◎")

local SettingsTitle = Label(
    Sidebar,
    "SYSTEM",
    9,
    UDim2.new(0, 18, 0, 260),
    Enum.Font.GothamBold,
    C.TextDark
)

local SettingsButton = Instance.new("TextButton")
SettingsButton.Parent = Sidebar
SettingsButton.Position = UDim2.new(0, 10, 0, 285)
SettingsButton.Size = UDim2.new(1, -20, 0, 40)
SettingsButton.BackgroundColor3 = C.Sidebar
SettingsButton.BorderSizePixel = 0
SettingsButton.AutoButtonColor = false
SettingsButton.Text = ""

Corner(SettingsButton, 7)

local SettingsIcon = Label(
    SettingsButton,
    "⚙",
    14,
    UDim2.new(0, 12, 0, 10),
    Enum.Font.GothamMedium,
    C.TextDim
)
SettingsIcon.Size = UDim2.new(0, 20, 0, 20)
SettingsIcon.TextXAlignment = Enum.TextXAlignment.Center

local SettingsText = Label(
    SettingsButton,
    "Settings",
    12,
    UDim2.new(0, 42, 0, 11),
    Enum.Font.GothamMedium,
    C.TextDim
)

-- footer

local Version = Label(
    Sidebar,
    "NYRA LS",
    9,
    UDim2.new(0, 18, 1, -44),
    Enum.Font.GothamBold,
    C.TextDim
)

local VersionNumber = Label(
    Sidebar,
    "build 1.0.0",
    8,
    UDim2.new(0, 18, 1, -28),
    Enum.Font.GothamMedium,
    C.TextDark
)

--==============================================================
-- CONTENT
--==============================================================

local Content = Instance.new("Frame")
Content.Parent = Main
Content.Position = UDim2.new(0, 190, 0, 58)
Content.Size = UDim2.new(1, -190, 1, -58)
Content.BackgroundColor3 = C.Background
Content.BorderSizePixel = 0

local PagesContainer = Instance.new("Frame")
PagesContainer.Parent = Content
PagesContainer.Position = UDim2.new(0, 28, 0, 26)
PagesContainer.Size = UDim2.new(1, -56, 1, -52)
PagesContainer.BackgroundTransparency = 1

--==============================================================
-- PAGE MANAGEMENT
--==============================================================

local PageFrames = {}

local function CreatePage(name)
    local Frame = Instance.new("Frame")
    Frame.Parent = PagesContainer
    Frame.Size = UDim2.fromScale(1, 1)
    Frame.BackgroundTransparency = 1
    Frame.Visible = false

    PageFrames[name] = Frame
    return Frame
end

local function SelectPage(name)
    currentPage = name

    for pageName, frame in pairs(PageFrames) do
        frame.Visible = pageName == name
    end

    for pageName, data in pairs(Pages) do
        local selected = pageName == name

        Tween(data.Button, nil, {
            BackgroundColor3 = selected and C.Panel2 or C.Sidebar
        }):Play()

        Tween(data.Icon, nil, {
            TextColor3 = selected and C.Text or C.TextDim
        }):Play()

        Tween(data.Text, nil, {
            TextColor3 = selected and C.Text or C.TextDim
        }):Play()
    end
end

--==============================================================
-- COMMON CARD
--==============================================================

local function CreateCard(parent, position, size)
    local Card = Instance.new("Frame")
    Card.Parent = parent
    Card.Position = position
    Card.Size = size
    Card.BackgroundColor3 = C.Panel
    Card.BorderSizePixel = 0

    Corner(Card, 9)
    Stroke(Card, C.Border, 1)

    return Card
end

local function CardTitle(parent, text, subtext)
    local title = Label(
        parent,
        text,
        13,
        UDim2.new(0, 16, 0, 14),
        Enum.Font.GothamBold
    )

    local sub = Label(
        parent,
        subtext or "",
        9,
        UDim2.new(0, 16, 0, 34),
        Enum.Font.GothamMedium,
        C.TextDim
    )

    return title, sub
end

--==============================================================
-- TOGGLE
--==============================================================

local function CreateToggle(parent, position, enabled, callback)
    local Holder = Instance.new("TextButton")
    Holder.Parent = parent
    Holder.Position = position
    Holder.Size = UDim2.new(0, 46, 0, 24)
    Holder.BackgroundColor3 = enabled and C.Accent or C.Panel2
    Holder.BorderSizePixel = 0
    Holder.Text = ""
    Holder.AutoButtonColor = false

    Corner(Holder, 20)
    Stroke(Holder, C.BorderLight)

    local Knob = Instance.new("Frame")
    Knob.Parent = Holder
    Knob.Size = UDim2.new(0, 18, 0, 18)
    Knob.Position = enabled
        and UDim2.new(1, -21, 0.5, -9)
        or UDim2.new(0, 3, 0.5, -9)

    Knob.BackgroundColor3 = enabled and C.Background or C.TextDim
    Knob.BorderSizePixel = 0

    Corner(Knob, 20)

    Holder.MouseButton1Click:Connect(function()
        enabled = not enabled

        Tween(Holder, nil, {
            BackgroundColor3 = enabled and C.Accent or C.Panel2
        }):Play()

        Tween(Knob, nil, {
            Position = enabled
                and UDim2.new(1, -21, 0.5, -9)
                or UDim2.new(0, 3, 0.5, -9),

            BackgroundColor3 = enabled and C.Background or C.TextDim
        }):Play()

        if callback then
            callback(enabled)
        end
    end)

    return Holder
end

--==============================================================
-- SLIDER
--==============================================================

local function CreateSlider(parent, position, width, min, max, value, callback)
    local Holder = Instance.new("Frame")
    Holder.Parent = parent
    Holder.Position = position
    Holder.Size = UDim2.new(0, width, 0, 34)
    Holder.BackgroundTransparency = 1

    local Track = Instance.new("Frame")
    Track.Parent = Holder
    Track.Position = UDim2.new(0, 0, 0.5, -3)
    Track.Size = UDim2.new(1, 0, 0, 6)
    Track.BackgroundColor3 = C.Panel2
    Track.BorderSizePixel = 0

    Corner(Track, 10)

    local Fill = Instance.new("Frame")
    Fill.Parent = Track
    Fill.Size = UDim2.new((value - min) / (max - min), 0, 1, 0)
    Fill.BackgroundColor3 = C.Accent
    Fill.BorderSizePixel = 0

    Corner(Fill, 10)

    local Knob = Instance.new("Frame")
    Knob.Parent = Track
    Knob.Size = UDim2.new(0, 12, 0, 12)
    Knob.AnchorPoint = Vector2.new(0.5, 0.5)
    Knob.Position = UDim2.new((value - min) / (max - min), 0, 0.5, 0)
    Knob.BackgroundColor3 = C.Text
    Knob.BorderSizePixel = 0

    Corner(Knob, 20)

    local Dragging = false

    local function Update(x)
        local relative = math.clamp(
            (x - Track.AbsolutePosition.X) / Track.AbsoluteSize.X,
            0,
            1
        )

        local newValue = min + ((max - min) * relative)

        if math.floor(max - min) > 10 then
            newValue = math.floor(newValue)
        else
            newValue = math.floor(newValue * 100) / 100
        end

        Fill.Size = UDim2.new(relative, 0, 1, 0)
        Knob.Position = UDim2.new(relative, 0, 0.5, 0)

        if callback then
            callback(newValue)
        end
    end

    Holder.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            Dragging = true
            Update(input.Position.X)
        end
    end)

    UIS.InputChanged:Connect(function(input)
        if Dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            Update(input.Position.X)
        end
    end)

    UIS.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            Dragging = false
        end
    end)

    return Holder
end

--==============================================================
-- OVERVIEW PAGE
--==============================================================

local Overview = CreatePage("Overview")

local OverviewTitle = Label(
    Overview,
    "Overview",
    22,
    UDim2.new(0, 0, 0, 0),
    Enum.Font.GothamBold
)

local OverviewSub = Label(
    Overview,
    "Quick control and current system status.",
    10,
    UDim2.new(0, 0, 0, 32),
    Enum.Font.GothamMedium,
    C.TextDim
)

-- status cards

local FlyCard = CreateCard(
    Overview,
    UDim2.new(0, 0, 0, 72),
    UDim2.new(0.31, -8, 0, 92)
)

local AimCard = CreateCard(
    Overview,
    UDim2.new(0.345, 0, 0, 72),
    UDim2.new(0.31, -8, 0, 92)
)

local SpeedCard = CreateCard(
    Overview,
    UDim2.new(0.69, 0, 0, 72),
    UDim2.new(0.31, -8, 0, 92)
)

CardTitle(FlyCard, "FLIGHT", "Movement module")

local FlyStatus = Label(
    FlyCard,
    "DISABLED",
    17,
    UDim2.new(0, 16, 0, 54),
    Enum.Font.GothamBold,
    C.TextDim
)

CardTitle(AimCard, "AIM ASSIST", "Targeting module")

local AimStatus = Label(
    AimCard,
    "DISABLED",
    17,
    UDim2.new(0, 16, 0, 54),
    Enum.Font.GothamBold,
    C.TextDim
)

CardTitle(SpeedCard, "FLY SPEED", "Current movement speed")

local SpeedValue = Label(
    SpeedCard,
    tostring(flySpeed),
    24,
    UDim2.new(0, 16, 0, 49),
    Enum.Font.GothamBold
)

-- quick control card

local Quick = CreateCard(
    Overview,
    UDim2.new(0, 0, 0, 184),
    UDim2.new(1, 0, 0, 180)
)

CardTitle(
    Quick,
    "QUICK CONTROL",
    "Toggle your primary modules"
)

local FlyQuickText = Label(
    Quick,
    "Fly",
    12,
    UDim2.new(0, 18, 0, 72),
    Enum.Font.GothamMedium
)

local FlyQuickSub = Label(
    Quick,
    "Camera-aligned movement",
    9,
    UDim2.new(0, 18, 0, 91),
    Enum.Font.GothamMedium,
    C.TextDim
)

CreateToggle(
    Quick,
    UDim2.new(1, -66, 0, 72),
    flying,
    function(state)
        flying = state

        FlyStatus.Text = state and "ACTIVE" or "DISABLED"
        FlyStatus.TextColor3 = state and C.Success or C.TextDim
    end
)

local Divider = Instance.new("Frame")
Divider.Parent = Quick
Divider.Position = UDim2.new(0, 18, 0, 119)
Divider.Size = UDim2.new(1, -36, 0, 1)
Divider.BackgroundColor3 = C.Border
Divider.BorderSizePixel = 0

local AimQuickText = Label(
    Quick,
    "Aimbot",
    12,
    UDim2.new(0, 18, 0, 134),
    Enum.Font.GothamMedium
)

local AimQuickSub = Label(
    Quick,
    "Smooth camera targeting",
    9,
    UDim2.new(0, 18, 0, 153),
    Enum.Font.GothamMedium,
    C.TextDim
)

CreateToggle(
    Quick,
    UDim2.new(1, -66, 0, 136),
    aimbotEnabled,
    function(state)
        aimbotEnabled = state

        AimStatus.Text = state and "ACTIVE" or "DISABLED"
        AimStatus.TextColor3 = state and C.Success or C.TextDim
    end
)

--==============================================================
-- FLY PAGE
--==============================================================

local FlyPage = CreatePage("Fly")

local FlyTitle = Label(
    FlyPage,
    "Flight",
    22,
    UDim2.new(0, 0, 0, 0),
    Enum.Font.GothamBold
)

local FlySub = Label(
    FlyPage,
    "Configure movement and flight behavior.",
    10,
    UDim2.new(0, 0, 0, 32),
    Enum.Font.GothamMedium,
    C.TextDim
)

local FlightCard = CreateCard(
    FlyPage,
    UDim2.new(0, 0, 0, 72),
    UDim2.new(1, 0, 0, 245)
)

CardTitle(
    FlightCard,
    "FLIGHT CONTROL",
    "Movement configuration"
)

local FlyEnabledText = Label(
    FlightCard,
    "Enable Fly",
    12,
    UDim2.new(0, 18, 0, 68),
    Enum.Font.GothamMedium
)

local FlyEnabledSub = Label(
    FlightCard,
    "Toggle the flight controller",
    9,
    UDim2.new(0, 18, 0, 88),
    Enum.Font.GothamMedium,
    C.TextDim
)

CreateToggle(
    FlightCard,
    UDim2.new(1, -66, 0, 68),
    flying,
    function(state)
        flying = state
        FlyStatus.Text = state and "ACTIVE" or "DISABLED"
        FlyStatus.TextColor3 = state and C.Success or C.TextDim
    end
)

local SpeedText = Label(
    FlightCard,
    "Movement Speed",
    12,
    UDim2.new(0, 18, 0, 125),
    Enum.Font.GothamMedium
)

local SpeedNumber = Label(
    FlightCard,
    tostring(flySpeed),
    12,
    UDim2.new(1, -65, 0, 125),
    Enum.Font.GothamBold,
    C.Text
)

SpeedNumber.Size = UDim2.new(0, 45, 0, 20)
SpeedNumber.TextXAlignment = Enum.TextXAlignment.Right

CreateSlider(
    FlightCard,
    UDim2.new(0, 18, 0, 154),
    430,
    1,
    100,
    flySpeed,
    function(value)
        flySpeed = value
        SpeedNumber.Text = tostring(value)
        SpeedValue.Text = tostring(value)
    end
)

local ControlsTitle = Label(
    FlightCard,
    "CONTROLS",
    9,
    UDim2.new(0, 18, 0, 194),
    Enum.Font.GothamBold,
    C.TextDark
)

local Controls = Label(
    FlightCard,
    "W A S D    MOVE\nSPACE       ASCEND\nSHIFT        DESCEND\nF            TOGGLE",
    10,
    UDim2.new(0, 18, 0, 212),
    Enum.Font.GothamMedium,
    C.TextDim
)

--==============================================================
-- AIMBOT PAGE
--==============================================================

local AimPage = CreatePage("Aimbot")

local AimTitle = Label(
    AimPage,
    "Aimbot",
    22,
    UDim2.new(0, 0, 0, 0),
    Enum.Font.GothamBold
)

local AimSub = Label(
    AimPage,
    "Configure targeting behavior and input.",
    10,
    UDim2.new(0, 0, 0, 32),
    Enum.Font.GothamMedium,
    C.TextDim
)

local AimCard = CreateCard(
    AimPage,
    UDim2.new(0, 0, 0, 72),
    UDim2.new(1, 0, 0, 330)
)

CardTitle(
    AimCard,
    "AIM CONFIGURATION",
    "Targeting settings"
)

local AimEnableText = Label(
    AimCard,
    "Enable Aimbot",
    12,
    UDim2.new(0, 18, 0, 68),
    Enum.Font.GothamMedium
)

local AimEnableSub = Label(
    AimCard,
    "Enable camera targeting",
    9,
    UDim2.new(0, 18, 0, 88),
    Enum.Font.GothamMedium,
    C.TextDim
)

CreateToggle(
    AimCard,
    UDim2.new(1, -66, 0, 68),
    aimbotEnabled,
    function(state)
        aimbotEnabled = state

        AimStatus.Text = state and "ACTIVE" or "DISABLED"
        AimStatus.TextColor3 = state and C.Success or C.TextDim
    end
)

local SmoothText = Label(
    AimCard,
    "Smoothness",
    12,
    UDim2.new(0, 18, 0, 125),
    Enum.Font.GothamMedium
)

local SmoothValue = Label(
    AimCard,
    string.format("%.2f", aimbotSmoothness),
    12,
    UDim2.new(1, -65, 0, 125),
    Enum.Font.GothamBold
)

SmoothValue.Size = UDim2.new(0, 45, 0, 20)
SmoothValue.TextXAlignment = Enum.TextXAlignment.Right

CreateSlider(
    AimCard,
    UDim2.new(0, 18, 0, 154),
    430,
    0.01,
    1,
    aimbotSmoothness,
    function(value)
        aimbotSmoothness = value
        SmoothValue.Text = string.format("%.2f", value)
    end
)

local ModeText = Label(
    AimCard,
    "Activation Mode",
    12,
    UDim2.new(0, 18, 0, 202),
    Enum.Font.GothamMedium
)

local ModeButton = Instance.new("TextButton")
ModeButton.Parent = AimCard
ModeButton.Position = UDim2.new(0, 18, 0, 231)
ModeButton.Size = UDim2.new(0, 205, 0, 38)
ModeButton.BackgroundColor3 = C.Panel2
ModeButton.BorderSizePixel = 0
ModeButton.Text = "  " .. aimbotMode
ModeButton.TextColor3 = C.Text
ModeButton.Font = Enum.Font.GothamMedium
ModeButton.TextSize = 11
ModeButton.TextXAlignment = Enum.TextXAlignment.Left
ModeButton.AutoButtonColor = false

Corner(ModeButton, 7)
Stroke(ModeButton, C.BorderLight)

ModeButton.MouseButton1Click:Connect(function()
    aimbotMode = aimbotMode == "Toggle" and "Hold" or "Toggle"
    ModeButton.Text = "  " .. aimbotMode
end)

local KeyText = Label(
    AimCard,
    "Keybind",
    12,
    UDim2.new(0, 250, 0, 202),
    Enum.Font.GothamMedium
)

local KeyButton = Instance.new("TextButton")
KeyButton.Parent = AimCard
KeyButton.Position = UDim2.new(0, 250, 0, 231)
KeyButton.Size = UDim2.new(0, 205, 0, 38)
KeyButton.BackgroundColor3 = C.Panel2
KeyButton.BorderSizePixel = 0
KeyButton.Text = "  " .. aimbotKeybind.Name
KeyButton.TextColor3 = C.Text
KeyButton.Font = Enum.Font.GothamMedium
KeyButton.TextSize = 11
KeyButton.TextXAlignment = Enum.TextXAlignment.Left
KeyButton.AutoButtonColor = false

Corner(KeyButton, 7)
Stroke(KeyButton, C.BorderLight)

KeyButton.MouseButton1Click:Connect(function()
    KeyButton.Text = "  Press a key..."

    local connection
    connection = UIS.InputBegan:Connect(function(input, processed)
        if not processed and input.KeyCode ~= Enum.KeyCode.Unknown then
            aimbotKeybind = input.KeyCode
            KeyButton.Text = "  " .. aimbotKeybind.Name
            connection:Disconnect()
        end
    end)
end)

--==============================================================
-- SETTINGS PAGE
--==============================================================

local Settings = CreatePage("Settings")

local SettingsTitleMain = Label(
    Settings,
    "Settings",
    22,
    UDim2.new(0, 0, 0, 0),
    Enum.Font.GothamBold
)

local SettingsSub = Label(
    Settings,
    "Interface and utility preferences.",
    10,
    UDim2.new(0, 0, 0, 32),
    Enum.Font.GothamMedium,
    C.TextDim
)

local SettingsCard = CreateCard(
    Settings,
    UDim2.new(0, 0, 0, 72),
    UDim2.new(1, 0, 0, 245)
)

CardTitle(
    SettingsCard,
    "INTERFACE",
    "Nyra appearance and behavior"
)

local AnimText = Label(
    SettingsCard,
    "Animations",
    12,
    UDim2.new(0, 18, 0, 68),
    Enum.Font.GothamMedium
)

local AnimSub = Label(
    SettingsCard,
    "Smooth interface transitions",
    9,
    UDim2.new(0, 18, 0, 88),
    Enum.Font.GothamMedium,
    C.TextDim
)

CreateToggle(
    SettingsCard,
    UDim2.new(1, -66, 0, 68),
    true
)

local BorderText = Label(
    SettingsCard,
    "Minimal borders",
    12,
    UDim2.new(0, 18, 0, 125),
    Enum.Font.GothamMedium
)

local BorderSub = Label(
    SettingsCard,
    "Keep the interface clean and subtle",
    9,
    UDim2.new(0, 18, 0, 145),
    Enum.Font.GothamMedium,
    C.TextDim
)

CreateToggle(
    SettingsCard,
    UDim2.new(1, -66, 0, 125),
    true
)

--==============================================================
-- NAVIGATION
--==============================================================

OverviewButton.MouseButton1Click:Connect(function()
    SelectPage("Overview")
end)

FlyButton.MouseButton1Click:Connect(function()
    SelectPage("Fly")
end)

AimButton.MouseButton1Click:Connect(function()
    SelectPage("Aimbot")
end)

SettingsButton.MouseButton1Click:Connect(function()
    SelectPage("Settings")
end)

--==============================================================
-- DRAGGING
--==============================================================

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

UIS.InputChanged:Connect(function(input)
    if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
        local delta = input.Position - dragStart

        Main.Position = UDim2.new(
            startPosition.X.Scale,
            startPosition.X.Offset + delta.X,
            startPosition.Y.Scale,
            startPosition.Y.Offset + delta.Y
        )

        Shadow.Position = Main.Position
    end
end)

UIS.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = false
    end
end)

--==============================================================
-- OPEN
--==============================================================

Main.Size = UDim2.new(0, 940, 0, 570)
Main.BackgroundTransparency = 1

Tween(
    Main,
    TweenInfo.new(0.35, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
    {
        Size = UDim2.new(0, 1000, 0, 610),
        BackgroundTransparency = 0
    }
):Play()

SelectPage("Overview")
