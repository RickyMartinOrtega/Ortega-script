-- Ortega gwapo (Loader Ready)

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")
local TweenService = game:GetService("TweenService")

local Camera = workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer

local Config = {
    Aimbot = false,
    SpeedPercent = 25, 
    FOV = 100,
    ShowFOV = false,
    MenuVisible = true,
    TargetPart = "Head"
}

local ScreenGui = Instance.new("ScreenGui", CoreGui)
ScreenGui.ResetOnSpawn = false
ScreenGui.IgnoreGuiInset = true

local OpenBtn = Instance.new("TextButton", ScreenGui)
OpenBtn.Size = UDim2.new(0, 50, 0, 50)
OpenBtn.Position = UDim2.new(0, 10, 0.4, 0)
OpenBtn.BackgroundColor3 = Color3.fromRGB(0, 255, 150)
OpenBtn.Text = "Ortega"
OpenBtn.Font = Enum.Font.GothamBold
OpenBtn.TextSize = 12
Instance.new("UICorner", OpenBtn).CornerRadius = UDim.new(1, 0)

local Main = Instance.new("Frame", ScreenGui)
Main.Size = UDim2.new(0, 260, 0, 340)
Main.Position = UDim2.new(0.5, -130, 0.5, -170)
Main.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
Instance.new("UICorner", Main).CornerRadius = UDim.new(0, 12)

local Stroke = Instance.new("UIStroke", Main)
Stroke.Color = Color3.fromRGB(0, 255, 150)
Stroke.Thickness = 2

local Title = Instance.new("TextLabel", Main)
Title.Size = UDim2.new(1, 0, 0, 40)
Title.Text = "Ortega gwapo"
Title.TextColor3 = Color3.new(0, 1, 0.6)
Title.BackgroundTransparency = 1
Title.Font = Enum.Font.GothamBold
Title.TextSize = 16

local Scroll = Instance.new("ScrollingFrame", Main)
Scroll.Size = UDim2.new(1, -20, 1, -50)
Scroll.Position = UDim2.new(0, 10, 0, 45)
Scroll.BackgroundTransparency = 1
Scroll.CanvasSize = UDim2.new(0, 0, 1.7, 0)
Scroll.ScrollBarThickness = 0

local UIList = Instance.new("UIListLayout", Scroll)
UIList.Padding = UDim.new(0, 10)

local function AddToggle(name, callback)
    local Btn = Instance.new("TextButton", Scroll)
    Btn.Size = UDim2.new(1, 0, 0, 40)
    Btn.BackgroundColor3 = Color3.fromRGB(35, 35, 40)
    Btn.Text = name .. ": OFF"
    Btn.TextColor3 = Color3.new(1, 1, 1)
    Btn.Font = Enum.Font.Gotham
    Instance.new("UICorner", Btn)

    local enabled = false
    Btn.MouseButton1Click:Connect(function()
        enabled = not enabled
        Btn.Text = name .. ": " .. (enabled and "ON" or "OFF")
        Btn.BackgroundColor3 = enabled and Color3.fromRGB(0, 120, 70) or Color3.fromRGB(35, 35, 40)
        callback(enabled)
    end)
end

local function AddSlider(name, min, max, default, callback)
    local value = default

    local SFrame = Instance.new("Frame", Scroll)
    SFrame.Size = UDim2.new(1, 0, 0, 50)
    SFrame.BackgroundTransparency = 1

    local Lab = Instance.new("TextLabel", SFrame)
    Lab.Size = UDim2.new(1, 0, 0, 20)
    Lab.Text = name .. ": " .. value
    Lab.TextColor3 = Color3.new(1,1,1)
    Lab.BackgroundTransparency = 1

    local Bar = Instance.new("Frame", SFrame)
    Bar.Size = UDim2.new(1, -10, 0, 8)
    Bar.Position = UDim2.new(0, 5, 0, 30)
    Bar.BackgroundColor3 = Color3.new(0.2, 0.2, 0.2)
    
    local Fill = Instance.new("Frame", Bar)
    Fill.Size = UDim2.new((value - min)/(max - min), 0, 1, 0)
    Fill.BackgroundColor3 = Color3.fromRGB(0, 255, 150)

    local function Update(input)
        local inputPos = (input.Position.X - Bar.AbsolutePosition.X) / Bar.AbsoluteSize.X
        local ratio = math.clamp(inputPos, 0, 1)

        value = math.floor(min + (max - min) * ratio)
        Fill.Size = UDim2.new(ratio, 0, 1, 0)
        Lab.Text = name .. ": " .. value

        callback(value)
    end

    Bar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
            Update(input)

            local moveCon
            moveCon = UIS.InputChanged:Connect(function(move)
                if move.UserInputType == Enum.UserInputType.Touch or move.UserInputType == Enum.UserInputType.MouseMovement then
                    Update(move)
                end
            end)

            UIS.InputEnded:Connect(function()
                moveCon:Disconnect()
            end)
        end
    end)
end

local function AddTargetSelector()
    local Btn = Instance.new("TextButton", Scroll)
    Btn.Size = UDim2.new(1, 0, 0, 40)
    Btn.BackgroundColor3 = Color3.fromRGB(35, 35, 40)
    Btn.TextColor3 = Color3.new(1,1,1)
    Btn.Font = Enum.Font.Gotham
    Instance.new("UICorner", Btn)

    local mode = "Head"
    Btn.Text = "Target: HEAD"

    Btn.MouseButton1Click:Connect(function()
        if mode == "Head" then
            mode = "HumanoidRootPart"
            Btn.Text = "Target: BODY"
        else
            mode = "Head"
            Btn.Text = "Target: HEAD"
        end

        Config.TargetPart = mode
    end)
end

AddToggle("Aimlock", function(v) Config.Aimbot = v end)

AddSlider("Aim Speed", 1, 100, Config.SpeedPercent, function(val)
    Config.SpeedPercent = val
end)

AddSlider("FOV Size", 50, 300, Config.FOV, function(val)
    Config.FOV = val
end)

AddToggle("FOV Circle", function(v) Config.ShowFOV = v end)

AddTargetSelector()

OpenBtn.MouseButton1Click:Connect(function()
    Config.MenuVisible = not Config.MenuVisible
    Main.Visible = Config.MenuVisible
end)

local function MakeDraggable(frame)
    local dragging = false
    local dragStart, startPos

    frame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            dragStart = input.Position
            startPos = frame.Position
        end
    end)

    frame.InputChanged:Connect(function(input)
        if dragging then
            local delta = input.Position - dragStart
            frame.Position = UDim2.new(
                startPos.X.Scale,
                startPos.X.Offset + delta.X,
                startPos.Y.Scale,
                startPos.Y.Offset + delta.Y
            )
        end
    end)

    UIS.InputEnded:Connect(function()
        dragging = false
    end)
end

MakeDraggable(Main)
MakeDraggable(OpenBtn)

local Circle = Instance.new("Frame", ScreenGui)
Circle.AnchorPoint = Vector2.new(0.5, 0.5)
Circle.BackgroundTransparency = 1
Circle.Visible = false

local StrokeF = Instance.new("UIStroke", Circle)
StrokeF.Color = Color3.new(1, 1, 1)
Instance.new("UICorner", Circle).CornerRadius = UDim.new(1, 0)

RunService.RenderStepped:Connect(function()
    Circle.Visible = Config.ShowFOV

    if Config.ShowFOV then
        Circle.Position = UDim2.new(0.5, 0, 0.5, 0)
        Circle.Size = UDim2.new(0, Config.FOV * 2, 0, Config.FOV * 2)
    end

    if Config.Aimbot then
        local target = nil
        local dist = Config.FOV * 2
        local screenCenter = Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2)

        for _, p in pairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Character and p.Character:FindFirstChild(Config.TargetPart) then
                local part = p.Character[Config.TargetPart]
                local pos, vis = Camera:WorldToViewportPoint(part.Position)

                if vis then
                    local mag = (Vector2.new(pos.X, pos.Y) - screenCenter).Magnitude
                    if mag < dist then
                        dist = mag
                        target = part
                    end
                end
            end
        end

        if target then
            local lerpVal = math.clamp(Config.SpeedPercent / 100, 0.01, 1)
            local current = Camera.CFrame
            local goal = CFrame.lookAt(current.Position, target.Position)
            Camera.CFrame = current:Lerp(goal, lerpVal)
        end
    end
end)
