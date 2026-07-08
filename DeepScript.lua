--[[
    deepscript – discord.gg/gx9H56CHud
    final stable version – fixed nil error
]]

-- ============================================================
-- 1. LOAD LINORIA LIB WITH SAFETY CHECKS
-- ============================================================
local library = nil
local loadErrors = {}

local urls = {
    "https://raw.githubusercontent.com/violin-suzutsuki/LinoriaLib/main/Library.lua",
    "https://raw.githubusercontent.com/violin-suzutsuki/LinoriaLib/master/Library.lua",
    "https://cdn.jsdelivr.net/gh/violin-suzutsuki/LinoriaLib@main/Library.lua",
}

for _, url in ipairs(urls) do
    local success, result = pcall(function()
        return loadstring(game:HttpGet(url, true))()
    end)
    if success and result then
        library = result
        break
    else
        table.insert(loadErrors, url .. ": " .. tostring(success and "loaded but nil" or "error"))
    end
end

-- Verify that library is valid and has required methods
local function isLibraryValid(lib)
    return type(lib) == "table" and type(lib.CreateWindow) == "function"
end

-- ============================================================
-- 2. FALLBACK UI (if library fails or is invalid)
-- ============================================================
if not isLibraryValid(library) then
    local sg = Instance.new("ScreenGui")
    sg.Name = "DeepScriptFallback"
    sg.Parent = game:GetService("CoreGui")

    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 400, 0, 200)
    frame.Position = UDim2.new(0.5, -200, 0.5, -100)
    frame.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
    frame.BorderSizePixel = 0
    frame.Parent = sg
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = frame

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 0, 30)
    label.Position = UDim2.new(0, 0, 0, 10)
    label.BackgroundTransparency = 1
    label.Text = "❌ Library Load Failed"
    label.TextColor3 = Color3.fromRGB(255, 80, 80)
    label.TextScaled = true
    label.Font = Enum.Font.GothamBold
    label.Parent = frame

    local errLabel = Instance.new("TextLabel")
    errLabel.Size = UDim2.new(1, -20, 0, 60)
    errLabel.Position = UDim2.new(0, 10, 0, 50)
    errLabel.BackgroundTransparency = 1
    errLabel.Text = "Could not load LinoriaLib.\nPlease check your internet connection\nor try a different executor."
    errLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    errLabel.TextScaled = true
    errLabel.Font = Enum.Font.Gotham
    errLabel.TextWrapped = true
    errLabel.Parent = frame

    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.new(0, 100, 0, 30)
    closeBtn.Position = UDim2.new(0.5, -50, 1, -40)
    closeBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
    closeBtn.Text = "close"
    closeBtn.TextColor3 = Color3.fromRGB(255,255,255)
    closeBtn.TextScaled = true
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.Parent = frame
    closeBtn.MouseButton1Click:Connect(function() sg:Destroy() end)

    error("LinoriaLib failed to load – fallback UI shown.")
    return
end

-- ============================================================
-- 3. SERVICES & STATE (unchanged)
-- ============================================================
local players = game:GetService("Players")
local workspace = game:GetService("Workspace")
local runservice = game:GetService("RunService")
local userinputservice = game:GetService("UserInputService")
local coregui = game:GetService("CoreGui")
local httpService = game:GetService("HttpService")
local virtualInput = game:GetService("VirtualInputManager")

local localplayer = players.LocalPlayer
local camera = workspace.CurrentCamera
local mouse = localplayer:GetMouse()

-- mobile detection
local isMobile = userinputservice.TouchEnabled
-- scale UI for mobile
if library.SetScale then
    library:SetScale(isMobile and 1.4 or 1.0)
end

local state = {
    aimbotEnabled = false,
    showFov = false,
    fovRadius = 250,
    aimSmoothness = 0.2,
    silentAimEnabled = false,
    silentFovRadius = 400,
    silentX_Smooth = 0.04,
    silentY_Smooth = 0.04,
    targetingVisibleOnly = true,
    targetPart = "Head",
    triggerbotEnabled = false,
    triggerFov = 150,
    triggerDelay = 0.1,
    ragebotEnabled = false,
    rageInterval = 0.1,
    espEnabled = false,
    espBox = false,
    espFill = false,
    espOutline = false,
    espThickness = 1,
    espName = false,
    espDistance = false,
    espHealthbar = false,
    flyEnabled = false,
    flySpeed = 50,
    noclipEnabled = false,
    infiniteJumpEnabled = false,
    infiniteDoubleJump = false,
    doubleJumpHeight = 1.1,
    antiAimEnabled = false,
    antiAimSpeed = 720,
    characterScale = 1.0,
    velocityEnabled = false,
    velocitySpeed = 50,
    tracersEnabled = false,
}

-- fov circle
local fovCircle = Drawing.new("Circle")
fovCircle.Color = Color3.fromRGB(255, 45, 117)
fovCircle.Thickness = 2
fovCircle.NumSides = 64
fovCircle.Filled = false
fovCircle.Visible = false
fovCircle.Transparency = 0.4

-- ============================================================
-- 4. HELPERS (unchanged from working version)
-- ============================================================
local function isTeammate(player)
    if not player or not localplayer then return false end
    if localplayer.Team and player.Team then
        return localplayer.Team == player.Team
    end
    local localChar = localplayer.Character
    local targetChar = player.Character
    if localChar and targetChar then
        local localColor = localChar:FindFirstChild("Head") and localChar.Head.Color or nil
        local targetColor = targetChar:FindFirstChild("Head") and targetChar.Head.Color or nil
        if localColor and targetColor then
            return localColor == targetColor
        end
    end
    return false
end

local function isVisible(player)
    if not player or not player.Character then return false end
    local head = player.Character:FindFirstChild("Head")
    if not head then return false end
    local origin = camera.CFrame.Position
    local direction = (head.Position - origin).Unit
    local distance = (head.Position - origin).Magnitude
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Blacklist
    params.FilterDescendantsInstances = {localplayer.Character, camera}
    local result = workspace:Raycast(origin, direction * distance, params)
    if result then
        local hit = result.Instance
        local targetChar = player.Character
        if hit and hit:IsDescendantOf(targetChar) then
            return true
        end
        return false
    end
    return true
end

local function isAlive(player)
    if not player or not player.Character then return false end
    local hum = player.Character:FindFirstChild("Humanoid")
    return hum and hum.Health > 0
end

local function getClosestEnemyToMouse(fovRadius, requireVisible)
    local closest, shortest = nil, math.huge
    local mousePos = userinputservice:GetMouseLocation()
    for _, player in ipairs(players:GetPlayers()) do
        if player ~= localplayer and player.Character and not isTeammate(player) and isAlive(player) then
            local head = player.Character:FindFirstChild("Head")
            if head then
                if requireVisible and not isVisible(player) then continue end
                local screenPos, onScreen = camera:WorldToViewportPoint(head.Position)
                if onScreen then
                    local dist = (Vector2.new(screenPos.X, screenPos.Y) - mousePos).Magnitude
                    if dist < shortest and dist < fovRadius then
                        shortest = dist
                        closest = player
                    end
                end
            end
        end
    end
    return closest
end

local function getClosestEnemy()
    local closest, shortest = nil, math.huge
    local localPos = localplayer.Character and localplayer.Character:FindFirstChild("HumanoidRootPart")
    if not localPos then return nil end
    local origin = localPos.Position
    for _, player in ipairs(players:GetPlayers()) do
        if player ~= localplayer and player.Character and not isTeammate(player) and isAlive(player) then
            local head = player.Character:FindFirstChild("Head")
            if head then
                local dist = (head.Position - origin).Magnitude
                if dist < shortest then
                    shortest = dist
                    closest = player
                end
            end
        end
    end
    return closest
end

local function getTargetPart(player)
    if not player or not player.Character then return nil end
    if state.targetPart == "Head" then
        return player.Character:FindFirstChild("Head")
    elseif state.targetPart == "Neck" then
        return player.Character:FindFirstChild("Neck") or player.Character:FindFirstChild("Head")
    elseif state.targetPart == "Torso" then
        return player.Character:FindFirstChild("HumanoidRootPart")
    else
        return player.Character:FindFirstChild("Head")
    end
end

-- ============================================================
-- 5. FEATURES – ALL WORKING (same as proven version)
-- ============================================================
local isAiming = false
local aimKey = Enum.UserInputType.MouseButton2

userinputservice.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.UserInputType == aimKey then isAiming = true end
end)
userinputservice.InputEnded:Connect(function(input)
    if input.UserInputType == aimKey then isAiming = false end
end)

runservice.RenderStepped:Connect(function()
    local mousePos = userinputservice:GetMouseLocation()
    fovCircle.Position = mousePos
    fovCircle.Radius = state.fovRadius
    fovCircle.Visible = state.showFov

    if state.aimbotEnabled and isAiming then
        local target = getClosestEnemyToMouse(state.fovRadius, state.targetingVisibleOnly)
        if target then
            local part = getTargetPart(target)
            if part then
                local targetCF = CFrame.new(camera.CFrame.Position, part.Position)
                camera.CFrame = camera.CFrame:Lerp(targetCF, state.aimSmoothness)
            end
        end
    end
end)

-- Silent aim
local silentTarget = nil
local silentSmoothX = 0
local silentSmoothY = 0

userinputservice.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.UserInputType == Enum.UserInputType.MouseButton1 and state.silentAimEnabled then
        local target = getClosestEnemyToMouse(state.silentFovRadius, state.targetingVisibleOnly)
        if target then
            local part = getTargetPart(target)
            if part then
                if state.silentX_Smooth > 0 or state.silentY_Smooth > 0 then
                    silentTarget = target
                    silentSmoothX = state.silentX_Smooth
                    silentSmoothY = state.silentY_Smooth
                else
                    mouse.Hit = CFrame.new(part.Position)
                end
            end
        end
    end
end)

runservice.RenderStepped:Connect(function()
    if silentTarget and isAlive(silentTarget) then
        local part = getTargetPart(silentTarget)
        if part then
            local currentPos = mouse.Hit.Position
            local targetPos = part.Position
            local newX = currentPos.X + (targetPos.X - currentPos.X) * silentSmoothX
            local newY = currentPos.Y + (targetPos.Y - currentPos.Y) * silentSmoothY
            mouse.Hit = CFrame.new(newX, newY, targetPos.Z)
        else
            silentTarget = nil
        end
    else
        silentTarget = nil
    end
end)

-- Triggerbot
local triggerCooldown = false
local function triggerbotLoop()
    if state.triggerbotEnabled and isAiming then
        local target = getClosestEnemyToMouse(state.triggerFov, state.targetingVisibleOnly)
        if target and isAlive(target) and not triggerCooldown then
            triggerCooldown = true
            local success = pcall(function()
                virtualInput:SendMouseButtonEvent(0, 0, 0, true, game, 0)
                task.wait(state.triggerDelay)
                virtualInput:SendMouseButtonEvent(0, 0, 0, false, game, 0)
            end)
            if not success then
                pcall(function()
                    mouse1click()
                    task.wait(state.triggerDelay)
                    mouse1release()
                end)
            end
            task.wait(state.triggerDelay * 0.5)
            triggerCooldown = false
        end
    end
end
runservice.RenderStepped:Connect(triggerbotLoop)

-- Ragebot
local ragebotRunning = false
local function ragebotLoop()
    while state.ragebotEnabled do
        if not localplayer.Character then
            task.wait(0.5)
            continue
        end
        local hum = localplayer.Character:FindFirstChild("Humanoid")
        if not hum or hum.Health <= 0 then
            task.wait(0.5)
            continue
        end
        local target = getClosestEnemy()
        if target and isAlive(target) then
            local part = getTargetPart(target)
            if part then
                local root = localplayer.Character:FindFirstChild("HumanoidRootPart")
                if root then
                    root.CFrame = part.CFrame
                end
            end
        end
        task.wait(state.rageInterval)
    end
end

local function toggleRagebot(enabled)
    state.ragebotEnabled = enabled
    if enabled then
        if not ragebotRunning then
            ragebotRunning = true
            task.spawn(ragebotLoop)
        end
    else
        ragebotRunning = false
    end
end

-- Anti-aim
local antiAimConnection = nil
local function antiAimLoop(delta)
    if state.antiAimEnabled then
        local character = localplayer.Character
        if character then
            local root = character:FindFirstChild("HumanoidRootPart")
            if root then
                local rotSpeed = math.rad(state.antiAimSpeed) * delta
                root.CFrame = root.CFrame * CFrame.Angles(0, rotSpeed, 0)
            end
        end
    end
end

local function toggleAntiAim(enabled)
    state.antiAimEnabled = enabled
    if enabled and not antiAimConnection then
        antiAimConnection = runservice.Heartbeat:Connect(antiAimLoop)
    elseif not enabled and antiAimConnection then
        antiAimConnection:Disconnect()
        antiAimConnection = nil
    end
end

-- Infinite jump
local function infiniteJumpLoop()
    if state.infiniteJumpEnabled then
        local character = localplayer.Character
        if character then
            local root = character:FindFirstChild("HumanoidRootPart")
            if root and userinputservice:IsKeyDown(Enum.KeyCode.Space) then
                local currentY = root.AssemblyLinearVelocity.Y
                if currentY < 50 then
                    root.AssemblyLinearVelocity = Vector3.new(root.AssemblyLinearVelocity.X, 50, root.AssemblyLinearVelocity.Z)
                end
            end
        end
    end
end
local jumpConnection = runservice.RenderStepped:Connect(infiniteJumpLoop)

-- Infinite double jump (with cooldown)
local doubleJumpCooldown = false
local function infiniteDoubleJumpLoop()
    if state.infiniteDoubleJump and not doubleJumpCooldown then
        local character = localplayer.Character
        if character then
            local root = character:FindFirstChild("HumanoidRootPart")
            if root and userinputservice:IsKeyDown(Enum.KeyCode.Space) and root.AssemblyLinearVelocity.Y < 50 then
                root.AssemblyLinearVelocity = Vector3.new(root.AssemblyLinearVelocity.X, 50, root.AssemblyLinearVelocity.Z)
                doubleJumpCooldown = true
                task.spawn(function()
                    task.wait(0.1)
                    doubleJumpCooldown = false
                end)
            end
        end
    end
end
local doubleJumpConnection = runservice.RenderStepped:Connect(infiniteDoubleJumpLoop)

-- Character scaling
local function applyScale(scale)
    local character = localplayer.Character
    if character then
        local hum = character:FindFirstChild("Humanoid")
        if hum then
            local success, err = pcall(function()
                local desc = Instance.new("HumanoidDescription")
                desc.BodyHeightScale = scale
                desc.BodyWidthScale = scale
                desc.BodyDepthScale = scale
                hum:ApplyDescription(desc)
            end)
            if not success then
                pcall(function()
                    hum.Scale = scale
                end)
            end
        end
    end
end

local function onScaleChange(value)
    state.characterScale = value
    applyScale(value)
end

local function onCharacterAdded()
    task.wait(0.5)
    if state.characterScale ~= 1 then
        applyScale(state.characterScale)
    end
end
localplayer.CharacterAdded:Connect(onCharacterAdded)

-- Movement modifiers
local function updateMovementMods()
    local character = localplayer.Character
    if not character then return end
    local hum = character:FindFirstChild("Humanoid")
    if not hum then return end
    if state.velocityEnabled then
        hum.WalkSpeed = state.velocitySpeed
    else
        hum.WalkSpeed = 16
    end
    if state.doubleJumpHeight ~= 1 then
        hum.JumpPower = 50 * state.doubleJumpHeight
    else
        hum.JumpPower = 50
    end
end

-- Fly & Noclip
local flyBodyVelocity, flyBodyGyro = nil, nil
local noclipActive = false

local function updateFlyNoclip()
    local character = localplayer.Character
    if not character then return end
    local root = character:FindFirstChild("HumanoidRootPart")
    local hum = character:FindFirstChild("Humanoid")
    if not root or not hum then return end

    if state.flyEnabled or state.noclipEnabled then
        hum.PlatformStand = true
    else
        hum.PlatformStand = false
    end

    if state.noclipEnabled ~= noclipActive then
        noclipActive = state.noclipEnabled
        for _, part in ipairs(character:GetDescendants()) do
            if part:IsA("BasePart") then
                part.CanCollide = not state.noclipEnabled
            end
        end
    end

    if state.flyEnabled then
        if not flyBodyVelocity or flyBodyVelocity.Parent ~= root then
            if flyBodyVelocity then flyBodyVelocity:Destroy() end
            flyBodyVelocity = Instance.new("BodyVelocity")
            flyBodyVelocity.MaxForce = Vector3.new(1e9, 1e9, 1e9)
            flyBodyVelocity.Parent = root
        end
        if not flyBodyGyro or flyBodyGyro.Parent ~= root then
            if flyBodyGyro then flyBodyGyro:Destroy() end
            flyBodyGyro = Instance.new("BodyGyro")
            flyBodyGyro.MaxTorque = Vector3.new(1e9, 1e9, 1e9)
            flyBodyGyro.Parent = root
        end

        local dir = Vector3.new(0, 0, 0)
        if userinputservice:IsKeyDown(Enum.KeyCode.W) then dir = dir + camera.CFrame.LookVector * Vector3.new(1, 0, 1) end
        if userinputservice:IsKeyDown(Enum.KeyCode.S) then dir = dir - camera.CFrame.LookVector * Vector3.new(1, 0, 1) end
        if userinputservice:IsKeyDown(Enum.KeyCode.A) then dir = dir - camera.CFrame.RightVector end
        if userinputservice:IsKeyDown(Enum.KeyCode.D) then dir = dir + camera.CFrame.RightVector end
        if userinputservice:IsKeyDown(Enum.KeyCode.Space) then dir = dir + Vector3.new(0, 1, 0) end
        if userinputservice:IsKeyDown(Enum.KeyCode.LeftShift) then dir = dir - Vector3.new(0, 1, 0) end
        if dir.Magnitude > 0 then dir = dir.Unit * state.flySpeed else dir = Vector3.new(0, 0, 0) end

        flyBodyVelocity.Velocity = dir
        flyBodyGyro.CFrame = camera.CFrame * CFrame.new(0, 0, -1)
    else
        if flyBodyVelocity then flyBodyVelocity:Destroy(); flyBodyVelocity = nil end
        