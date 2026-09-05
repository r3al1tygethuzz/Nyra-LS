-- Revamped Ultra-Smooth, Anti-Ban Roblox Fly Script with Camera-Aligned Orientation, Tweened Movement, Modern CS2-Style UI (Nyra - LS), Tabs, and Enhanced Aimbot
-- Features: Fixed falling by anchoring during fly (physics off/on), camera-following up/down, ultra-smooth tweens for undetectability, bigger modern UI with tabs for Fly and Aimbot, aimbot settings (smoothness, keybind, toggle/hold), robust error handling, optimized for smoothness and ban-resistance, consistent speeds (no deltaTime on horizontal for match), and phasing through walls via CanCollide off on HumanoidRootPart only

local player = game.Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoid = character:FindFirstChildOfClass("Humanoid")
local rootPart = character:FindFirstChild("HumanoidRootPart")
local camera = game.Workspace.CurrentCamera
local tweenService = game:GetService("TweenService")
local userInputService = game:GetService("UserInputService")
local runService = game:GetService("RunService")

-- Variables
local flying = false
local aimbotEnabled = false
local aimbotSmoothness = 0.1  -- Default smoothness for camera lock
local aimbotKeybind = Enum.KeyCode.G  -- Default keybind for aimbot toggle
local aimbotMode = "toggle"  -- "toggle" or "hold"
local flySpeed = 3  -- Increased for faster movement (1-5 range for anti-ban)
local verticalSpeed = flySpeed  -- Matched to flySpeed for consistent, snappier up/down
local turnSpeed = 0.15  -- Subtle for smoothness
local uiVisible = true
local currentTab = "Fly"  -- Default tab
local flyConnection
local aimbotConnection
local aimbotHoldConnection

-- Utility to get valid character
local function getValidCharacter()
    return player.Character and player.Character.Parent and player.Character:FindFirstChild("HumanoidRootPart") and player.Character:FindFirstChildOfClass("Humanoid")
end

-- Utility to find nearest player for aimbot (excluding self)
local function getNearestPlayer()
    local nearest = nil
    local minDist = math.huge
    for _, p in pairs(game.Players:GetPlayers()) do
        if p ~= player and p.Character and p.Character:FindFirstChild("HumanoidRootPart") and p.Character.Humanoid.Health > 0 then
            local dist = (rootPart.Position - p.Character.HumanoidRootPart.Position).Magnitude
            if dist < minDist then
                minDist = dist
                nearest = p
            end
        end
    end
    return nearest
end

-- Create revamped modern CS2-style UI (bigger, tabbed, sleek)
local screenGui = Instance.new("ScreenGui", player.PlayerGui)
screenGui.Name = "NyraLSUI"
screenGui.ResetOnSpawn = false

local mainFrame = Instance.new("Frame", screenGui)
mainFrame.Size = UDim2.new(0, 600, 0, 450)  -- Way bigger for better usability
mainFrame.Position = UDim2.new(0.5, -300, 0.5, -225)  -- Centered
mainFrame.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
mainFrame.BorderSizePixel = 0
mainFrame.BackgroundTransparency = 0.05
mainFrame.Visible = uiVisible
mainFrame.Active = true
mainFrame.Draggable = true

-- Glow effect for modern look
local uiStroke = Instance.new("UIStroke", mainFrame)
uiStroke.Color = Color3.fromRGB(50, 50, 50)
uiStroke.Thickness = 2
uiStroke.Transparency = 0.5

-- Rounded corners, gradient, and shadow
local uiCorner = Instance.new("UICorner", mainFrame)
uiCorner.CornerRadius = UDim.new(0, 15)
local frameGradient = Instance.new("UIGradient", mainFrame)
frameGradient.Color = ColorSequence.new{
    ColorSequenceKeypoint.new(0, Color3.fromRGB(10, 10, 10)),
    ColorSequenceKeypoint.new(0.5, Color3.fromRGB(30, 30, 30)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(50, 50, 50))
}
frameGradient.Rotation = 90
local shadow = Instance.new("Frame", mainFrame.Parent)
shadow.Size = UDim2.new(1, 20, 1, 20)
shadow.Position = UDim2.new(0, -10, 0, -10)
shadow.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
shadow.BackgroundTransparency = 0.7
shadow.BorderSizePixel = 0
local shadowCorner = Instance.new("UICorner", shadow)
shadowCorner.CornerRadius = UDim.new(0, 15)

-- Fade-in animation for UI
tweenService:Create(mainFrame, TweenInfo.new(0.5, Enum.EasingStyle.Quad), {BackgroundTransparency = 0.05}):Play()
tweenService:Create(shadow, TweenInfo.new(0.5, Enum.EasingStyle.Quad), {BackgroundTransparency = 0.7}):Play()

-- Title
local titleLabel = Instance.new("TextLabel", mainFrame)
titleLabel.Size = UDim2.new(1, 0, 0, 50)
titleLabel.Position = UDim2.new(0, 0, 0, 0)
titleLabel.Text = "Nyra - LS"
titleLabel.BackgroundTransparency = 1
titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
titleLabel.Font = Enum.Font.SourceSansBold
titleLabel.TextScaled = true

-- Minimize button
local minimizeButton = Instance.new("TextButton", mainFrame)
minimizeButton.Size = UDim2.new(0, 40, 0, 40)
minimizeButton.Position = UDim2.new(0.92, 0, 0.02, 0)
minimizeButton.Text = "−"
minimizeButton.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
minimizeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
minimizeButton.Font = Enum.Font.SourceSansBold
local minCorner = Instance.new("UICorner", minimizeButton)
minCorner.CornerRadius = UDim.new(0, 8)
minimizeButton.MouseEnter:Connect(function()
    tweenService:Create(minimizeButton, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(100, 100, 100)}):Play()
end)
minimizeButton.MouseLeave:Connect(function()
    tweenService:Create(minimizeButton, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(80, 80, 80)}):Play()
end)
minimizeButton.MouseButton1Click:Connect(function()
    uiVisible = not uiVisible
    mainFrame.Visible = uiVisible
    minimizeButton.Text = uiVisible and "−" or "+"
end)

-- Tab buttons
local tabFrame = Instance.new("Frame", mainFrame)
tabFrame.Size = UDim2.new(1, 0, 0, 50)
tabFrame.Position = UDim2.new(0, 0, 0.1, 0)
tabFrame.BackgroundTransparency = 1

local flyTab = Instance.new("TextButton", tabFrame)
flyTab.Size = UDim2.new(0.5, 0, 1, 0)
flyTab.Position = UDim2.new(0, 0, 0, 0)
flyTab.Text = "Fly"
flyTab.BackgroundColor3 = currentTab == "Fly" and Color3.fromRGB(100, 150, 100) or Color3.fromRGB(50, 50, 50)
flyTab.TextColor3 = Color3.fromRGB(255, 255, 255)
flyTab.Font = Enum.Font.SourceSansBold
flyTab.MouseButton1Click:Connect(function()
    currentTab = "Fly"
    flyTab.BackgroundColor3 = Color3.fromRGB(100, 150, 100)
    aimbotTab.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    updateTabs()
end)

local aimbotTab = Instance.new("TextButton", tabFrame)
aimbotTab.Size = UDim2.new(0.5, 0, 1, 0)
aimbotTab.Position = UDim2.new(0.5, 0, 0, 0)
aimbotTab.Text = "Aimbot"
aimbotTab.BackgroundColor3 = currentTab == "Aimbot" and Color3.fromRGB(100, 150, 100) or Color3.fromRGB(50, 50, 50)
aimbotTab.TextColor3 = Color3.fromRGB(255, 255, 255)
aimbotTab.Font = Enum.Font.SourceSansBold
aimbotTab.MouseButton1Click:Connect(function()
    currentTab = "Aimbot"
    aimbotTab.BackgroundColor3 = Color3.fromRGB(100, 150, 100)
    flyTab.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    updateTabs()
end)

-- Tab content frames
local flyFrame = Instance.new("Frame", mainFrame)
flyFrame.Size = UDim2.new(1, -20, 0, 320)
flyFrame.Position = UDim2.new(0, 10, 0, 110)
flyFrame.BackgroundTransparency = 1
flyFrame.Visible = currentTab == "Fly"

local aimbotFrame = Instance.new("Frame", mainFrame)
aimbotFrame.Size = UDim2.new(1, -20, 0, 320)
aimbotFrame.Position = UDim2.new(0, 10, 0, 110)
aimbotFrame.BackgroundTransparency = 1
aimbotFrame.Visible = currentTab == "Aimbot"

local function updateTabs()
    flyFrame.Visible = currentTab == "Fly"
    aimbotFrame.Visible = currentTab == "Aimbot"
end

-- Fly tab content
local flyToggle = Instance.new("TextButton", flyFrame)
flyToggle.Size = UDim2.new(0.4, 0, 0, 55)
flyToggle.Position = UDim2.new(0.05, 0, 0.05, 0)
flyToggle.Text = flying and "🚫 Fly Off" or "🚀 Fly On"
flyToggle.BackgroundColor3 = flying and Color3.fromRGB(150, 100, 100) or Color3.fromRGB(100, 150, 100)
flyToggle.TextColor3 = Color3.fromRGB(255, 255, 255)
flyToggle.Font = Enum.Font.SourceSansBold
local flyCorner = Instance.new("UICorner", flyToggle)
flyCorner.CornerRadius = UDim.new(0, 10)
flyToggle.MouseEnter:Connect(function()
    tweenService:Create(flyToggle, TweenInfo.new(0.2), {BackgroundColor3 = flying and Color3.fromRGB(170, 120, 120) or Color3.fromRGB(120, 170, 120)}):Play()
end)
flyToggle.MouseLeave:Connect(function()
    tweenService:Create(flyToggle, TweenInfo.new(0.2), {BackgroundColor3 = flying and Color3.fromRGB(150, 100, 100) or Color3.fromRGB(100, 150, 100)}):Play()
end)
flyToggle.MouseButton1Click:Connect(function()
    flying = not flying
    flyToggle.Text = flying and "🚫 Fly Off" or "🚀 Fly On"
    flyToggle.BackgroundColor3 = flying and Color3.fromRGB(150, 100, 100) or Color3.fromRGB(100, 150, 100)
    if flying then
        humanoid.PlatformStand = true
        rootPart.Anchored = true  -- Anchor to prevent falling and disable gravity
        rootPart.CanCollide = false  -- Disable collisions on root for phasing through walls (keeps other parts collidable)
        startFly()
    else
        humanoid.PlatformStand = false
        rootPart.Anchored = false  -- Unanchor to restore physics
        rootPart.CanCollide = true  -- Restore collisions
        stopFly()
    end
end)

-- Speed slider
local speedLabel = Instance.new("TextLabel", flyFrame)
speedLabel.Size = UDim2.new(0.9, 0, 0, 35)
speedLabel.Position = UDim2.new(0.05, 0, 0.2, 0)
speedLabel.Text = "Speed: " .. flySpeed
speedLabel.BackgroundTransparency = 1
speedLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
speedLabel.Font = Enum.Font.SourceSans

local speedSlider = Instance.new("TextBox", flyFrame)
speedSlider.Size = UDim2.new(0.9, 0, 0, 45)
speedSlider.Position = UDim2.new(0.05, 0, 0.3, 0)
speedSlider.Text = tostring(flySpeed)
speedSlider.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
speedSlider.TextColor3 = Color3.fromRGB(255, 255, 255)
speedSlider.PlaceholderText = "1-5"
local sliderCorner = Instance.new("UICorner", speedSlider)
sliderCorner.CornerRadius = UDim.new(0, 8)
speedSlider.FocusLost:Connect(function(enterPressed)
    if enterPressed then
        local newSpeed = tonumber(speedSlider.Text)
        if newSpeed and newSpeed >= 1 and newSpeed <= 5 then
            flySpeed = newSpeed
            verticalSpeed = flySpeed
            speedLabel.Text = "Speed: " .. flySpeed
        else
            speedSlider.Text = tostring(flySpeed)
        end
    end
end)

-- Reset button
local resetButton = Instance.new("TextButton", flyFrame)
resetButton.Size = UDim2.new(0.9, 0, 0, 45)
resetButton.Position = UDim2.new(0.05, 0, 0.45, 0)
resetButton.Text = "🔄 Reset Speed"
resetButton.BackgroundColor3 = Color3.fromRGB(80, 80, 150)
resetButton.TextColor3 = Color3.fromRGB(255, 255, 255)
resetButton.Font = Enum.Font.SourceSansBold
local resetCorner = Instance.new("UICorner", resetButton)
resetCorner.CornerRadius = UDim.new(0, 8)
resetButton.MouseEnter:Connect(function()
    tweenService:Create(resetButton, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(100, 100, 170)}):Play()
end)
resetButton.MouseLeave:Connect(function()
    tweenService:Create(resetButton, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(80, 80, 150)}):Play()
end)
resetButton.MouseButton1Click:Connect(function()
    flySpeed = 3
    verticalSpeed = flySpeed
    speedLabel.Text = "Speed: " .. flySpeed
    speedSlider.Text = tostring(flySpeed)
end)

-- Controls info
local controlsLabel = Instance.new("TextLabel", flyFrame)
controlsLabel.Size = UDim2.new(0.9, 0, 0, 80)
controlsLabel.Position = UDim2.new(0.05, 0, 0.65, 0)
controlsLabel.Text = "WASD: Move\nSpace: Up, Shift: Down\nQ/E: Turn Direction\n(Character & Cam align for height)\nF: Toggle Fly"
controlsLabel.BackgroundTransparency = 1
controlsLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
controlsLabel.Font = Enum.Font.SourceSans
controlsLabel.TextScaled = true

-- Aimbot tab content
local aimbotToggle = Instance.new("TextButton", aimbotFrame)
aimbotToggle.Size = UDim2.new(0.4, 0, 0, 55)
aimbotToggle.Position = UDim2.new(0.05, 0, 0.05, 0)
aimbotToggle.Text = aimbotEnabled and "🎯 Aim Off" or "🎯 Aim On"
aimbotToggle.BackgroundColor3 = aimbotEnabled and Color3.fromRGB(150, 100, 100) or Color3.fromRGB(100, 150, 100)
aimbotToggle.TextColor3 = Color3.fromRGB(255, 255, 255)
aimbotToggle.Font = Enum.Font.SourceSansBold
local aimCorner = Instance.new("UICorner", aimbotToggle)
aimCorner.CornerRadius = UDim.new(0, 10)
aimbotToggle.MouseEnter:Connect(function()
    tweenService:Create(aimbotToggle, TweenInfo.new(0.2), {BackgroundColor3 = aimbotEnabled and Color3.fromRGB(170, 120, 120) or Color3.fromRGB(120, 170, 120)}):Play()
end)
aimbotToggle.MouseLeave:Connect(function()
    tweenService:Create(aimbotToggle, TweenInfo.new(0.2), {BackgroundColor3 = aimbotEnabled and Color3.fromRGB(150, 100, 100) or Color3.fromRGB(100, 150, 100)}):Play()
end)
aimbotToggle.MouseButton1Click:Connect(function()
    aimbotEnabled = not aimbotEnabled
    aimbotToggle.Text = aimbotEnabled and "🎯 Aim Off" or "🎯 Aim On"
    aimbotToggle.BackgroundColor3 = aimbotEnabled and Color3.fromRGB(150, 100, 100) or Color3.fromRGB(100, 150, 100)
    if aimbotEnabled then
        startAimbot()
    else
        stopAimbot()
    end
end)

-- Smoothness slider
local smoothnessLabel = Instance.new("TextLabel", aimbotFrame)
smoothnessLabel.Size = UDim2.new(0.9, 0, 0, 35)
smoothnessLabel.Position = UDim2.new(0.05, 0, 0.2, 0)
smoothnessLabel.Text = "Smoothness: " .. aimbotSmoothness
smoothnessLabel.BackgroundTransparency = 1
smoothnessLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
smoothnessLabel.Font = Enum.Font.SourceSans

local smoothnessSlider = Instance.new("TextBox", aimbotFrame)
smoothnessSlider.Size = UDim2.new(0.9, 0, 0, 45)
smoothnessSlider.Position = UDim2.new(0.05, 0, 0.3, 0)
smoothnessSlider.Text = tostring(aimbotSmoothness)
smoothnessSlider.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
smoothnessSlider.TextColor3 = Color3.fromRGB(255, 255, 255)
smoothnessSlider.PlaceholderText = "0.1-1.0"
local smoothCorner = Instance.new("UICorner", smoothnessSlider)
smoothCorner.CornerRadius = UDim.new(0, 8)
smoothnessSlider.FocusLost:Connect(function(enterPressed)
    if enterPressed then
        local newSmooth = tonumber(smoothnessSlider.Text)
        if newSmooth and newSmooth >= 0.1 and newSmooth <= 1.0 then
            aimbotSmoothness = newSmooth
            smoothnessLabel.Text = "Smoothness: " .. aimbotSmoothness
        else
            smoothnessSlider.Text = tostring(aimbotSmoothness)
        end
    end
end)

-- Keybind input
local keybindLabel = Instance.new("TextLabel", aimbotFrame)
keybindLabel.Size = UDim2.new(0.9, 0, 0, 35)
keybindLabel.Position = UDim2.new(0.05, 0, 0.45, 0)
keybindLabel.Text = "Keybind: " .. aimbotKeybind.Name
keybindLabel.BackgroundTransparency = 1
keybindLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
keybindLabel.Font = Enum.Font.SourceSans

local keybindButton = Instance.new("TextButton", aimbotFrame)
keybindButton.Size = UDim2.new(0.9, 0, 0, 45)
keybindButton.Position = UDim2.new(0.05, 0, 0.55, 0)
keybindButton.Text = "Press Key for Aimbot"
keybindButton.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
keybindButton.TextColor3 = Color3.fromRGB(255, 255, 255)
keybindButton.Font = Enum.Font.SourceSansBold
local keyCorner = Instance.new("UICorner", keybindButton)
keyCorner.CornerRadius = UDim.new(0, 8)
keybindButton.MouseButton1Click:Connect(function()
    keybindButton.Text = "Listening..."
    local inputConn
    inputConn = userInputService.InputBegan:Connect(function(input, gameProcessed)
        if not gameProcessed and input.KeyCode ~= Enum.KeyCode.Unknown then
            aimbotKeybind = input.KeyCode
            keybindLabel.Text = "Keybind: " .. aimbotKeybind.Name
            keybindButton.Text = "Press Key for Aimbot"
            inputConn:Disconnect()
        end
    end)
end)

-- Mode toggle (toggle or hold)
local modeLabel = Instance.new("TextLabel", aimbotFrame)
modeLabel.Size = UDim2.new(0.9, 0, 0, 35)
modeLabel.Position = UDim2.new(0.05, 0, 0.7, 0)
modeLabel.Text = "Mode: " .. aimbotMode
modeLabel.BackgroundTransparency = 1
modeLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
modeLabel.Font = Enum.Font.SourceSans

local modeButton = Instance.new("TextButton", aimbotFrame)
modeButton.Size = UDim2.new(0.9, 0, 0, 45)
modeButton.Position = UDim2.new(0.05, 0, 0.8, 0)
modeButton.Text = "Toggle Mode"
modeButton.BackgroundColor3 = Color3.fromRGB(80, 80, 150)
modeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
modeButton.Font = Enum.Font.SourceSansBold
local modeCorner = Instance.new("UICorner", modeButton)
modeCorner.CornerRadius = UDim.new(0, 8)
modeButton.MouseButton1Click:Connect(function()
    aimbotMode = aimbotMode == "toggle" and "hold" or "toggle"
    modeLabel.Text = "Mode: " .. aimbotMode
end)

-- Fly function with fixed up/down, consistent speeds (removed deltaTime from horizontal for match), and phasing
local function startFly()
    if not getValidCharacter() then return end
    flyConnection = runService.Heartbeat:Connect(function(deltaTime)
        if not flying or not getValidCharacter() then
            stopFly()
            return
        end
        local moveVector = Vector3.zero
        -- Horizontal movement based on camera (consistent speed without deltaTime)
        if userInputService:IsKeyDown(Enum.KeyCode.W) then
            moveVector = moveVector + camera.CFrame.LookVector
        end
        if userInputService:IsKeyDown(Enum.KeyCode.S) then
            moveVector = moveVector - camera.CFrame.LookVector
        end
        if userInputService:IsKeyDown(Enum.KeyCode.A) then
            moveVector = moveVector - camera.CFrame.RightVector
        end
        if userInputService:IsKeyDown(Enum.KeyCode.D) then
            moveVector = moveVector + camera.CFrame.RightVector
        end
        if userInputService:IsKeyDown(Enum.KeyCode.Q) then  -- Turn left (slight)
            moveVector = moveVector - camera.CFrame.RightVector
        end
        if userInputService:IsKeyDown(Enum.KeyCode.E) then  -- Turn right (slight)
            moveVector = moveVector + camera.CFrame.RightVector
        end
        -- Normalize and scale for speed
        if moveVector.Magnitude > 0 then
            moveVector = moveVector.Unit * flySpeed
        end
        -- Vertical movement (with deltaTime for smoothness)
        if userInputService:IsKeyDown(Enum.KeyCode.Space) then
            moveVector = moveVector + Vector3.new(0, verticalSpeed, 0)
        end
        if userInputService:IsKeyDown(Enum.KeyCode.LeftShift) then
            moveVector = moveVector - Vector3.new(0, verticalSpeed, 0)
        end
        -- Apply movement via tween for ultra-smooth, anti-ban movement
        if moveVector.Magnitude > 0 then
            local targetCFrame = rootPart.CFrame + moveVector * deltaTime
            local tween = tweenService:Create(rootPart, TweenInfo.new(deltaTime, Enum.EasingStyle.Linear), {CFrame = targetCFrame})
            tween:Play()
        end
    end)
end

local function stopFly()
    if flyConnection then
        flyConnection:Disconnect()
        flyConnection = nil
    end
    -- Remove BodyVelocity
    local bodyVelocity = rootPart:FindFirstChild("BodyVelocity")
    if bodyVelocity then
        bodyVelocity:Destroy()
    end
end

-- Aimbot function (subtle camera lock with smoothness)
local function startAimbot()
    if aimbotMode == "toggle" then
        aimbotConnection = runService.RenderStepped:Connect(function()
            if not aimbotEnabled or not getValidCharacter() then
                stopAimbot()
                return
            end
            local target = getNearestPlayer()
            if target and target.Character and target.Character:FindFirstChild("HumanoidRootPart") then
                local targetPos = target.Character.HumanoidRootPart.Position
                local currentCFrame = camera.CFrame
                local targetCFrame = CFrame.new(currentCFrame.Position, targetPos)
                camera.CFrame = currentCFrame:Lerp(targetCFrame, aimbotSmoothness)  -- Smooth interpolation
            end
        end)
    else  -- Hold mode
        aimbotHoldConnection = userInputService.InputBegan:Connect(function(input, gameProcessed)
            if not gameProcessed and input.KeyCode == aimbotKeybind then
                aimbotConnection = runService.RenderStepped:Connect(function()
                    if not getValidCharacter() then
                        stopAimbot()
                        return
                    end
                    local target = getNearestPlayer()
                    if target and target.Character and target.Character:FindFirstChild("HumanoidRootPart") then
                        local targetPos = target.Character.HumanoidRootPart.Position
                        local currentCFrame = camera.CFrame
                        local targetCFrame = CFrame.new(currentCFrame.Position, targetPos)
                        camera.CFrame = currentCFrame:Lerp(targetCFrame, aimbotSmoothness)
                    end
                end)
            end
        end)
        userInputService.InputEnded:Connect(function(input, gameProcessed)
            if not gameProcessed and input.KeyCode == aimbotKeybind then
                if aimbotConnection then
                    aimbotConnection:Disconnect()
                    aimbotConnection = nil
                end
            end
        end)
    end
end

local function stopAimbot()
    if aimbotConnection then
        aimbotConnection:Disconnect()
        aimbotConnection = nil
    end
    if aimbotHoldConnection then
        aimbotHoldConnection:Disconnect()
        aimbotHoldConnection = nil
    end
end

-- Input for F key toggle
userInputService.InputBegan:Connect(function(input, gameProcessed)
    if not gameProcessed and input.KeyCode == Enum.KeyCode.F then
        flying = not flying
        flyToggle.Text = flying and "🚫 Fly Off" or "🚀 Fly On"
        flyToggle.BackgroundColor3 = flying and Color3.fromRGB(150, 100, 100) or Color3.fromRGB(100, 150, 100)
        if flying then
            humanoid.PlatformStand = true
            rootPart.Anchored = true
            rootPart.CanCollide = false
            startFly()
        else
            humanoid.PlatformStand = false
            rootPart.Anchored = false
            rootPart.CanCollide = true
            stopFly()
        end
    end
end)

-- Cleanup
player.CharacterRemoving:Connect(function()
    stopFly()
    stopAimbot()
    screenGui:Destroy()
end)
