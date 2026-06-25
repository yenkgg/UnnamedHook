local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera


local Library = loadstring(game:HttpGet('https://raw.githubusercontent.com/violin-suzutsuki/LinoriaLib/refs/heads/main/Library.lua'))()

local Window = Library:CreateWindow({
    Title = 'UH V1 ',
    Center = true, 
    AutoShow = true,
})

local Tabs = {
    Main = Window:AddTab('Aimbot'),
    ['UI Settings'] = Window:AddTab('UI Settings'),
}


local State = {
    AimbotEnabled = false,
    ShowFOV = false,
    FovRadius = 250,
    AimSmoothness = 0.2,
    ESPEnabled = false,
}

local isAiming = false
local AIM_KEY = Enum.UserInputType.MouseButton2


local FOVCircle = Drawing.new("Circle")
FOVCircle.Color = Color3.fromRGB(255, 0, 0)
FOVCircle.Thickness = 1
FOVCircle.NumSides = 64
FOVCircle.Filled = false
FOVCircle.Visible = false


local function getClosestPlayerToMouse()
    local closestPlayer = nil
    local shortestDistance = math.huge
    local mousePosition = UserInputService:GetMouseLocation()

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character and player.Character:FindFirstChild("HumanoidRootPart") and player.Character:FindFirstChild("Humanoid") and player.Character.Humanoid.Health > 0 then
            local head = player.Character:FindFirstChild("Head")
            if head then
                local screenPosition, onScreen = Camera:WorldToViewportPoint(head.Position)
                if onScreen then
                    local distance = (Vector2.new(screenPosition.X, screenPosition.Y) - mousePosition).Magnitude
                    if distance < shortestDistance and distance < State.FovRadius then
                        shortestDistance = distance
                        closestPlayer = player
                    end
                end
            end
        end
    end
    return closestPlayer
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.UserInputType == AIM_KEY then isAiming = true end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == AIM_KEY then isAiming = false end
end)

RunService.RenderStepped:Connect(function()
    local mousePosition = UserInputService:GetMouseLocation()
    FOVCircle.Position = mousePosition
    FOVCircle.Radius = State.FovRadius
    FOVCircle.Visible = State.ShowFOV

    if State.AimbotEnabled and isAiming then
        local targetPlayer = getClosestPlayerToMouse()
        if targetPlayer and targetPlayer.Character and targetPlayer.Character:FindFirstChild("Head") then
            local targetHead = targetPlayer.Character.Head
            local targetCFrame = CFrame.new(Camera.CFrame.Position, targetHead.Position)
            Camera.CFrame = Camera.CFrame:Lerp(targetCFrame, State.AimSmoothness)
        end
    end
end)


local function updateESP()
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            local highlight = player.Character:FindFirstChild("HackerESP")
            
            if State.ESPEnabled then
                if not highlight then
                    highlight = Instance.new("Highlight")
                    highlight.Name = "HackerESP"
                    highlight.FillColor = Color3.fromRGB(255, 0, 0)
                    highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
                    highlight.FillTransparency = 0.5
                    highlight.OutlineTransparency = 0
                    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop 
                    highlight.Parent = player.Character
                    highlight.Adornee = player.Character
                end
                highlight.Enabled = true
            else
                if highlight then highlight.Enabled = false end
            end
        end
    end
end


Players.PlayerAdded:Connect(function(player)
    player.CharacterAdded:Connect(function()
        task.wait(0.5)
        updateESP()
    end)
end)

for _, player in ipairs(Players:GetPlayers()) do
    player.CharacterAdded:Connect(function()
        task.wait(0.5)
        updateESP()
    end)
end


local AimbotBox = Tabs.Main:AddLeftGroupbox('Aimbot')

AimbotBox:AddToggle('AimbotToggle', {
    Text = 'Enable Aimbot',
    Default = false,
    Callback = function(Value)
        State.AimbotEnabled = Value
    end
})

AimbotBox:AddToggle('FOVToggle', {
    Text = 'Show FOV Circle',
    Default = false,
    Callback = function(Value)
        State.ShowFOV = Value
    end
})

AimbotBox:AddSlider('FOVRadius', {
    Text = 'FOV Radius',
    Default = 250,
    Min = 50,
    Max = 600,
    Rounding = 0,
    Callback = function(Value)
        State.FovRadius = Value
    end
})

local ESPBox = Tabs.Main:AddRightGroupbox('Visuals')

ESPBox:AddToggle('ESPToggle', {
    Text = 'Enable ESP (Wallhack)',
    Default = false,
    Callback = function(Value)
        State.ESPEnabled = Value
        updateESP()
    end
})


local MenuGroup = Tabs['UI Settings']:AddLeftGroupbox('Menu')
MenuGroup:AddButton('Unload', function() Library:Unload() end)
MenuGroup:AddLabel('Menu bind'):AddKeyPicker('MenuKeybind', { Default = 'RightShift', NoUI = true, Text = 'Menu keybind' })

Library.ToggleKeybind = Options.MenuKeybind