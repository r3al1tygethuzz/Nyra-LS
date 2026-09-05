--// NYRA LS — MODERN CONTROL PANEL
--// UI-only / Roblox Studio friendly
--// Full redesigned interface with functional UI controls

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local Player = Players.LocalPlayer
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

		FlightStatus.Value.Text = value and "ENABLED" or "DISABLED"
		FlightStatus.Dot.BackgroundColor3 =
			value and CONFIG.Success or CONFIG.Muted

		if value then
			StartFlight()
		else
			StopFlight()
		end
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

		FlightStatus.Value.Text = value and "ENABLED" or "DISABLED"
		FlightStatus.Dot.BackgroundColor3 =
			value and CONFIG.Success or CONFIG.Muted

		-- CONNECT YOUR STUDIO FLIGHT CONTROLLER HERE
	end
)

local SpeedSlider = CreateSlider(
	FlightSection,
	"Movement Speed",
	10,
	200,
	State.FlySpeed,
	function(value)
		State.FlySpeed = math.floor(value)

		SpeedStatus.Value.Text = tostring(State.FlySpeed)
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
		State.Flight = not State.Flight

		FlightStatus.Value.Text =
			State.Flight and "ENABLED" or "DISABLED"

		FlightStatus.Dot.BackgroundColor3 =
			State.Flight and CONFIG.Success or CONFIG.Muted

		-- CONNECT YOUR OWN FLIGHT START/STOP FUNCTIONS HERE
	end
end)

--==================================================
-- INITIAL PAGE
--==================================================

SelectPage("Overview")

print("[NYRA LS] Interface loaded successfully.")
