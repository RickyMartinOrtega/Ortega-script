-- LocalScript inside StarterGui

local UserInputService = game:GetService("UserInputService")
local player = game.Players.LocalPlayer

-- Create ScreenGui
local screenGui = Instance.new("ScreenGui")
screenGui.ResetOnSpawn = false -- ✅ prevents GUI from disappearing after respawn
screenGui.Parent = player:WaitForChild("PlayerGui")

-- Create Toggle Button
local button = Instance.new("TextButton")
button.Size = UDim2.new(0, 150, 0, 50)
button.Position = UDim2.new(0.5, -75, 0.9, 0)
button.Text = "AimLock: OFF"
button.TextColor3 = Color3.new(1,1,1) -- white text
button.BackgroundColor3 = Color3.new(0,0,0) -- black background
button.Parent = screenGui

-- Rounded corners
local buttonCorner = Instance.new("UICorner")
buttonCorner.CornerRadius = UDim.new(0, 12)
buttonCorner.Parent = button

-- Rainbow edge (UIStroke with gradient)
local buttonStroke = Instance.new("UIStroke")
buttonStroke.Thickness = 3
buttonStroke.Parent = button

local gradient = Instance.new("UIGradient")
gradient.Color = ColorSequence.new{
    ColorSequenceKeypoint.new(0, Color3.fromRGB(255,0,0)),   -- red
    ColorSequenceKeypoint.new(0.2, Color3.fromRGB(255,165,0)), -- orange
    ColorSequenceKeypoint.new(0.4, Color3.fromRGB(255,255,0)), -- yellow
    ColorSequenceKeypoint.new(0.6, Color3.fromRGB(0,255,0)),   -- green
    ColorSequenceKeypoint.new(0.8, Color3.fromRGB(0,0,255)),   -- blue
    ColorSequenceKeypoint.new(1, Color3.fromRGB(128,0,128))    -- purple
}
gradient.Rotation = 90
gradient.Parent = buttonStroke

-- Create Crosshair (hidden by default)
local crosshair = Instance.new("Frame")
crosshair.Size = UDim2.new(0, 20, 0, 20)
crosshair.Position = UDim2.new(0.5, -10, 0.5, -10)
crosshair.BackgroundColor3 = Color3.new(1, 0, 0) -- red
crosshair.Visible = false
crosshair.Parent = screenGui

local crosshairCorner = Instance.new("UICorner")
crosshairCorner.CornerRadius = UDim.new(0, 10)
crosshairCorner.Parent = crosshair

-- Create Close Button
local closeButton = Instance.new("TextButton")
closeButton.Size = UDim2.new(0, 30, 0, 30)
closeButton.Position = UDim2.new(1, -35, 0, 5)
closeButton.Text = "X"
closeButton.TextColor3 = Color3.new(1,1,1)
closeButton.BackgroundColor3 = Color3.new(0,0,0)
closeButton.Parent = button

local closeCorner = Instance.new("UICorner")
closeCorner.CornerRadius = UDim.new(0, 8)
closeCorner.Parent = closeButton

-- Create Reopen Button (hidden by default)
local reopenButton = Instance.new("TextButton")
reopenButton.Size = UDim2.new(0, 100, 0, 40)
reopenButton.Position = UDim2.new(0.5, -50, 0.8, 0)
reopenButton.Text = "Open GUI"
reopenButton.TextColor3 = Color3.new(1,1,1)
reopenButton.BackgroundColor3 = Color3.new(0,0,0)
reopenButton.Visible = false
reopenButton.Parent = screenGui

local reopenCorner = Instance.new("UICorner")
reopenCorner.CornerRadius = UDim.new(0, 10)
reopenCorner.Parent = reopenButton

-- Strength input box
local strengthBox = Instance.new("TextBox")
strengthBox.Size = UDim2.new(0, 100, 0, 30)
strengthBox.Position = UDim2.new(0.5, -50, 0.8, -40)
strengthBox.Text = "100" -- default strength %
strengthBox.TextColor3 = Color3.new(1,1,1)
strengthBox.BackgroundColor3 = Color3.new(0,0,0)
strengthBox.Parent = screenGui

local strengthCorner = Instance.new("UICorner")
strengthCorner.CornerRadius = UDim.new(0, 8)
strengthCorner.Parent = strengthBox

-- State variables
local aimLockEnabled = false
local aimStrength = 1 -- 1.0 = 100%

-- Toggle function
button.MouseButton1Click:Connect(function()
    aimLockEnabled = not aimLockEnabled
    button.Text = aimLockEnabled and "AimLock: ON" or "AimLock: OFF"
    crosshair.Visible = aimLockEnabled
end)

-- Update aim strength when user types
strengthBox.FocusLost:Connect(function()
    local val = tonumber(strengthBox.Text)
    if val then
        val = math.clamp(val, 1, 100) -- keep between 1 and 100
        aimStrength = val / 100       -- convert to 0.01–1.0
        strengthBox.Text = tostring(val)
    else
        strengthBox.Text = tostring(math.floor(aimStrength*100))
    end
end)

-- Player and camera references
local camera = workspace.CurrentCamera
local range = 200 -- ✅ updated range to 200 studs
local highlight = nil

-- Function to find nearest player
local function getNearestPlayer()
    local nearest, shortestDist = nil, range
    for _, otherPlayer in pairs(game.Players:GetPlayers()) do
        if otherPlayer ~= player and otherPlayer.Character and otherPlayer.Character:FindFirstChild("HumanoidRootPart") then
            local dist = (otherPlayer.Character.HumanoidRootPart.Position - player.Character.HumanoidRootPart.Position).Magnitude
            if dist < shortestDist then
                shortestDist = dist
                nearest = otherPlayer
            end
        end
    end
    return nearest
end

-- Update camera and highlight with adjustable strength
game:GetService("RunService").RenderStepped:Connect(function()
    if aimLockEnabled and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
        local targetPlayer = getNearestPlayer()

        if targetPlayer then
            local targetPos = targetPlayer.Character.HumanoidRootPart.Position
            local currentPos = camera.CFrame.Position
            local desiredCFrame = CFrame.new(currentPos, targetPos)

            -- Smoothly interpolate based on aimStrength
            camera.CFrame = camera.CFrame:Lerp(desiredCFrame, aimStrength)

            -- Add highlight if not already
            if not highlight then
                highlight = Instance.new("Highlight")
                highlight.FillColor = Color3.new(1, 0, 0)
                highlight.OutlineColor = Color3.new(1, 1, 1)
                highlight.Parent = targetPlayer.Character
            end
        else
            if highlight then
                highlight:Destroy()
                highlight = nil
            end
        end
    else
        if highlight then
            highlight:Destroy()
            highlight = nil
        end
    end
end)

-- Drag function (reusable)
local function makeDraggable(guiObject)
    local dragging, dragInput, dragStart, startPos

    local function update(input)
        local delta = input.Position - dragStart
        guiObject.Position = UDim2.new(
            startPos.X.Scale,
            startPos.X.Offset + delta.X,
            startPos.Y.Scale,
            startPos.Y.Offset + delta.Y
        )
    end

    guiObject.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = guiObject.Position

            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)

    guiObject.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            update(input)
        end
    end)
end

-- Make draggable
makeDraggable(button)
makeDraggable(reopenButton)
makeDraggable(strengthBox)

-- Close/Open logic
closeButton.MouseButton1Click:Connect(function()
    button.Visible = false
    crosshair.Visible = false
    strengthBox.Visible = false
    reopenButton.Visible = true
end)

reopenButton.MouseButton1Click:Connect(function()
    button.Visible = true
    strengthBox.Visible = true
    reopenButton.Visible = false
end)
