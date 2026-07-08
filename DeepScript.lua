--[[
    deepscript – discord.gg/gx9H56CHud
    final production version – fully audited
]]

-- ============================================================
-- 1. LOAD LINORIA LIB
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

if not library then
    local sg = Instance.new("ScreenGui")
    sg.Name = "DeepScriptFallback"
    sg.Parent = game.CoreGui
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 400, 0, 300)
    frame.Position = UDim2.new(0.5, -200, 0.5, -150)
    frame.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
    frame.BorderSizePixel = 0
    frame.Parent = sg
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = frame
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 0, 30)
    label.BackgroundTransparency = 1
    label.Text = "linoria lib failed to load"
    label.TextColor3 = Color3.fromRGB(255, 80, 80)
    label.TextScaled = true
    label.Font = Enum.Font.GothamBold
    label.Parent = frame
    local errLabel = Instance.new("TextLabel")
    errLabel.Size = UDim2.new(1, -20, 0, 50)
    errLabel.Position = UDim2.new(0, 10, 0, 40)
    errLabel.BackgroundTransparency = 1
    errLabel.Text = "tried:\n" .. table.concat(loadErrors, "\n")
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
    error("linoria lib not loaded – using fallback ui. check console for details.")
    return
end

-- ============================================================
-- 2. SERVICES & STATE
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

local state = {
    aimbotEnabled = false,
    showFov = false,
    fovRadius = 250,
    aimSmoothness = 0.2,
    silentAimEnabled = false,
    silentFovRadius = 400,
    silentX_Smooth = 0.04,
    silentY_Smooth = 0.04,
    silentJumpSmooth = 0.10,
    targetingVisibleOnly = true,
    targetPart = "Head",
    triggerbotEnabled = false,
    triggerFov = 150,
    triggerDelay = 0.1,
    triggerKey = Enum.UserInputType.MouseButton2,
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
    characterScale = 1.0,
    antiAimEnabled = false,
    antiAimSpeed = 720,
    infiniteDoubleJump = false,
    tracersEnabled = false,
    velocityEnabled = false,
    velocitySpeed = 50,
    doubleJumpHeight = 1.1,
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
-- 3. HELPERS
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
    else -- closest
        return player.Character:FindFirstChild("Head")
    end
end

-- ============================================================
-- 4. FEATURES
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

-- Aimbot (smooth)
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

-- Infinite double jump (with small cooldown to prevent spam)
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
                -- fallback: direct scaling (works on some games)
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
        if flyBodyGyro then flyBodyGyro:Destroy(); flyBodyGyro = nil end
        if state.noclipEnabled then
            root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
            root.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
        end
    end
end

runservice.RenderStepped:Connect(function()
    updateFlyNoclip()
    updateMovementMods()
end)

localplayer.CharacterAdded:Connect(function()
    flyBodyVelocity = nil
    flyBodyGyro = nil
    noclipActive = false
    task.wait(0.5)
    updateFlyNoclip()
    updateMovementMods()
end)

-- ESP highlight
local function updateHighlight()
    for _, player in ipairs(players:GetPlayers()) do
        if player ~= localplayer and player.Character then
            local highlight = player.Character:FindFirstChild("HackerESP")
            if state.espEnabled then
                if not highlight then
                    highlight = Instance.new("Highlight")
                    highlight.Name = "HackerESP"
                    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                    highlight.Parent = player.Character
                    highlight.Adornee = player.Character
                end
                local visible = isVisible(player)
                highlight.FillColor = visible and Color3.fromRGB(0, 150, 255) or Color3.fromRGB(255, 45, 117)
                highlight.OutlineColor = visible and Color3.fromRGB(100, 200, 255) or Color3.fromRGB(255, 150, 200)
                highlight.FillTransparency = 0.3
                highlight.OutlineTransparency = 0.1
                highlight.Enabled = true
            elseif highlight then
                highlight.Enabled = false
            end
        end
    end
end

-- ESP drawings
local espDrawings = {}
local function cleanupESPdrawings()
    for _, data in pairs(espDrawings) do
        for _, obj in pairs(data) do
            if obj and obj.Remove then obj:Remove() end
        end
    end
    espDrawings = {}
end

local function updateESPdrawings()
    if not state.espEnabled then
        cleanupESPdrawings()
        return
    end

    local enemies = {}
    for _, player in ipairs(players:GetPlayers()) do
        if player ~= localplayer and player.Character and not isTeammate(player) and isAlive(player) then
            table.insert(enemies, player)
        end
    end

    -- remove dead players
    for player, data in pairs(espDrawings) do
        if not table.find(enemies, player) then
            for _, obj in pairs(data) do
                if obj and obj.Remove then obj:Remove() end
            end
            espDrawings[player] = nil
        end
    end

    for _, player in ipairs(enemies) do
        local root = player.Character:FindFirstChild("HumanoidRootPart")
        local head = player.Character:FindFirstChild("Head")
        if root and head then
            local screenPos, onScreen = camera:WorldToViewportPoint(root.Position)
            if onScreen then
                local dist = (root.Position - camera.CFrame.Position).Magnitude
                local scale = math.max(0.3, 1 / (dist / 20))
                local boxSize = Vector2.new(50, 80) * scale
                local topLeft = Vector2.new(screenPos.X - boxSize.X/2, screenPos.Y - boxSize.Y/2)

                if not espDrawings[player] then
                    espDrawings[player] = {}
                end
                local data = espDrawings[player]

                -- Box
                if state.espBox then
                    if not data.box then
                        data.box = Drawing.new("Square")
                        data.box.Color = Color3.fromRGB(255, 255, 255)
                        data.box.Thickness = state.espThickness
                        data.box.Visible = true
                    end
                    data.box.Size = boxSize
                    data.box.Position = topLeft
                    data.box.Thickness = state.espThickness
                    data.box.Visible = true
                    data.box.Color = state.espOutline and Color3.fromRGB(255,255,255) or Color3.fromRGB(255,45,117)
                else
                    if data.box then data.box:Remove(); data.box = nil end
                end

                -- Fill
                if state.espFill then
                    if not data.fill then
                        data.fill = Drawing.new("Square")
                        data.fill.Color = Color3.fromRGB(0, 150, 255)
                        data.fill.Thickness = 0
                        data.fill.Filled = true
                        data.fill.Visible = true
                    end
                    data.fill.Size = boxSize
                    data.fill.Position = topLeft
                    data.fill.Color = Color3.fromRGB(0, 150, 255)
                    data.fill.Transparency = 0.5
                else
                    if data.fill then data.fill:Remove(); data.fill = nil end
                end

                -- Name
                if state.espName then
                    if not data.nameText then
                        data.nameText = Drawing.new("Text")
                        data.nameText.Color = Color3.fromRGB(255, 255, 255)
                        data.nameText.Size = 14
                        data.nameText.Center = true
                        data.nameText.Visible = true
                    end
                    data.nameText.Text = player.Name
                    data.nameText.Position = Vector2.new(screenPos.X, topLeft.Y - 20)
                else
                    if data.nameText then data.nameText:Remove(); data.nameText = nil end
                end

                -- Distance
                if state.espDistance then
                    if not data.distText then
                        data.distText = Drawing.new("Text")
                        data.distText.Color = Color3.fromRGB(200, 200, 200)
                        data.distText.Size = 12
                        data.distText.Center = true
                        data.distText.Visible = true
                    end
                    data.distText.Text = math.floor(dist) .. "m"
                    data.distText.Position = Vector2.new(screenPos.X, topLeft.Y + boxSize.Y + 14)
                else
                    if data.distText then data.distText:Remove(); data.distText = nil end
                end

                -- Healthbar
                if state.espHealthbar then
                    if not data.healthbar then
                        data.healthbar = Drawing.new("Square")
                        data.healthbar.Color = Color3.fromRGB(255, 0, 0)
                        data.healthbar.Thickness = 1
                        data.healthbar.Filled = false
                        data.healthbar.Visible = true
                        data.healthFill = Drawing.new("Square")
                        data.healthFill.Color = Color3.fromRGB(0, 255, 0)
                        data.healthFill.Thickness = 0
                        data.healthFill.Filled = true
                        data.healthFill.Visible = true
                    end
                    local hum = player.Character:FindFirstChild("Humanoid")
                    if hum then
                        local healthPercent = hum.Health / hum.MaxHealth
                        local barWidth = boxSize.X
                        local barHeight = 4
                        local barPos = Vector2.new(topLeft.X, topLeft.Y - 6)
                        data.healthbar.Size = Vector2.new(barWidth, barHeight)
                        data.healthbar.Position = barPos
                        data.healthFill.Size = Vector2.new(barWidth * healthPercent, barHeight)
                        data.healthFill.Position = barPos
                        if healthPercent > 0.5 then
                            data.healthFill.Color = Color3.fromRGB(0, 255, 0)
                        elseif healthPercent > 0.25 then
                            data.healthFill.Color = Color3.fromRGB(255, 255, 0)
                        else
                            data.healthFill.Color = Color3.fromRGB(255, 0, 0)
                        end
                    end
                else
                    if data.healthbar then data.healthbar:Remove(); data.healthbar = nil end
                    if data.healthFill then data.healthFill:Remove(); data.healthFill = nil end
                end
            else
                if espDrawings[player] then
                    for _, obj in pairs(espDrawings[player]) do
                        if obj and obj.Visible ~= nil then obj.Visible = false end
                    end
                end
            end
        end
    end
end

local espConnection = nil

local function toggleESP(enabled)
    state.espEnabled = enabled
    if enabled then
        if not espConnection then
            espConnection = runservice.RenderStepped:Connect(updateESPdrawings)
        end
    else
        if espConnection then
            espConnection:Disconnect()
            espConnection = nil
        end
        cleanupESPdrawings()
    end
    updateHighlight()
end

-- Tracers
local tracerLines = {}
local screenCenter = Vector2.new()

local function updateTracers()
    if not state.tracersEnabled then
        for _, line in pairs(tracerLines) do
            line:Remove()
        end
        tracerLines = {}
        return
    end
    local viewportSize = camera.ViewportSize
    screenCenter = Vector2.new(viewportSize.X / 2, viewportSize.Y / 2)

    local enemyPlayers = {}
    for _, player in ipairs(players:GetPlayers()) do
        if player ~= localplayer and player.Character and not isTeammate(player) and isAlive(player) then
            table.insert(enemyPlayers, player)
        end
    end

    for player, line in pairs(tracerLines) do
        if not table.find(enemyPlayers, player) then
            line:Remove()
            tracerLines[player] = nil
        end
    end

    for _, player in ipairs(enemyPlayers) do
        local head = player.Character:FindFirstChild("Head")
        if head then
            local screenPos, onScreen = camera:WorldToViewportPoint(head.Position)
            if onScreen then
                local line = tracerLines[player]
                if not line then
                    line = Drawing.new("Line")
                    line.Color = Color3.fromRGB(255, 45, 117)
                    line.Thickness = 2
                    line.Visible = true
                    tracerLines[player] = line
                end
                line.From = Vector2.new(screenPos.X, screenPos.Y)
                line.To = screenCenter
                line.Visible = true
            else
                local line = tracerLines[player]
                if line then
                    line.Visible = false
                end
            end
        end
    end
end

local tracerConnection = nil

local function toggleTracers(enabled)
    state.tracersEnabled = enabled
    if enabled then
        if not tracerConnection then
            tracerConnection = runservice.RenderStepped:Connect(updateTracers)
        end
    else
        if tracerConnection then
            tracerConnection:Disconnect()
            tracerConnection = nil
        end
        for _, line in pairs(tracerLines) do
            line:Remove()
        end
        tracerLines = {}
    end
end

local function cleanupTracers()
    if tracerConnection then
        tracerConnection:Disconnect()
        tracerConnection = nil
    end
    for _, line in pairs(tracerLines) do
        line:Remove()
    end
    tracerLines = {}
end

-- Player leaving cleanup
players.PlayerRemoving:Connect(function(player)
    if espDrawings[player] then
        for _, obj in pairs(espDrawings[player]) do
            if obj and obj.Remove then obj:Remove() end
        end
        espDrawings[player] = nil
    end
    if tracerLines[player] then
        tracerLines[player]:Remove()
        tracerLines[player] = nil
    end
end)

-- ============================================================
-- 5. STATUS DETECTION
-- ============================================================
local executorName = "unknown executor"
local executorVersion = ""

local function detectExecutor()
    local name, ver = "unknown executor", ""
    local success, result = pcall(function() return getexecutorname() end)
    if success and result and result ~= "" then
        name = result
    else
        local known = {
            syn = "synapse z",
            krnl = "krnl",
            script_context = "scriptware",
            sentinel = "sentinel",
            vynixius = "vynixius",
        }
        for var, execName in pairs(known) do
            if rawget(_G, var) then
                name = execName
                break            end
        end
        if name == "unknown executor" and getgenv and getgenv().syn then
            name = "synapse z"
        end
    end
    local vSuccess, v = pcall(function()
        if syn and syn.version then return syn.version end
        if krnl and krnl.version then return krnl.version end
        if script_context and script_context.version then return script_context.version end
        return ""
    end)
    if vSuccess and v then ver = v end
    return name, ver
end

local function fetchGameName()
    if game.PlaceId == 0 then return game.Name end
    local success, result = pcall(function()
        local url = "https://games.roblox.com/v1/games?universeIds=" .. game.GameId
        local response = httpService:GetAsync(url)
        local data = httpService:JSONDecode(response)
        if data and data.data and #data.data > 0 then
            return data.data[1].name
        end
        return game.Name
    end)
    return success and result or game.Name
end

executorName, executorVersion = detectExecutor()
local gameName = fetchGameName()
local placeId = tostring(game.PlaceId)
local jobId = game.JobId or ""

-- ============================================================
-- 6. UI
-- ============================================================
local window = library:CreateWindow({
    Title = "DeepScript - discord.gg/gx9H56CHud",
    Center = true,
    AutoShow = true,
})

local tabs = {
    world = window:AddTab("world"),
    esp = window:AddTab("esp"),
    visuals = window:AddTab("visuals"),
    character = window:AddTab("character"),
    misc = window:AddTab("misc"),
    settings = window:AddTab("settings"),
}

-- world tab (simplified)
local worldGroup = tabs.world:AddLeftGroupbox("world")
worldGroup:AddToggle("worldDisableToggle", {
    Text = "disable",
    Default = false,
    Callback = function(v) state.worldDisable = v end
})

-- esp tab
local espGroup = tabs.esp:AddLeftGroupbox("esp")
espGroup:AddToggle("espToggle", {
    Text = "enabled",
    Default = false,
    Callback = function(v) toggleESP(v) end
})
espGroup:AddToggle("espBox", {
    Text = "box",
    Default = false,
    Callback = function(v) state.espBox = v end
})
espGroup:AddToggle("espFill", {
    Text = "fill",
    Default = false,
    Callback = function(v) state.espFill = v end
})
espGroup:AddToggle("espOutline", {
    Text = "outline",
    Default = false,
    Callback = function(v) state.espOutline = v end
})
espGroup:AddSlider("espThickness", {
    Text = "thickness",
    Default = 1,
    Min = 1,
    Max = 5,
    Rounding = 0,
    Callback = function(v) state.espThickness = v end
})
espGroup:AddToggle("espName", {
    Text = "name",
    Default = false,
    Callback = function(v) state.espName = v end
})
espGroup:AddToggle("espDistance", {
    Text = "distance",
    Default = false,
    Callback = function(v) state.espDistance = v end
})
espGroup:AddToggle("espHealthbar", {
    Text = "healthbar",
    Default = false,
    Callback = function(v) state.espHealthbar = v end
})

-- visuals tab
local visualsGroup = tabs.visuals:AddLeftGroupbox("fov")
visualsGroup:AddToggle("fovToggle", {
    Text = "show fov",
    Default = false,
    Callback = function(v) state.showFov = v end
})
visualsGroup:AddSlider("fovRadius", {
    Text = "radius",
    Default = 250,
    Min = 50,
    Max = 600,
    Rounding = 0,
    Callback = function(v)
        state.fovRadius = v
        fovCircle.Radius = v
    end
})

local tracerGroup = tabs.visuals:AddRightGroupbox("tracers")
tracerGroup:AddToggle("tracersToggle", {
    Text = "enabled",
    Default = false,
    Callback = function(v) toggleTracers(v) end
})

-- character tab
local moveGroup = tabs.character:AddLeftGroupbox("movement")
moveGroup:AddToggle("velocityToggle", {
    Text = "velocity",
    Default = false,
    Callback = function(v)
        state.velocityEnabled = v
        updateMovementMods()
    end
})
moveGroup:AddSlider("velocitySpeed", {
    Text = "speed",
    Default = 50,
    Min = 16,
    Max = 200,
    Rounding = 0,
    Callback = function(v)
        state.velocitySpeed = v
        updateMovementMods()
    end
})
moveGroup:AddSlider("doubleJumpHeight", {
    Text = "double jump height",
    Default = 1.1,
    Min = 1.0,
    Max = 2.0,
    Rounding = 1,
    Callback = function(v)
        state.doubleJumpHeight = v
        updateMovementMods()
    end
})
moveGroup:AddToggle("infiniteDoubleJump", {
    Text = "infinite double jump",
    Default = false,
    Callback = function(v) state.infiniteDoubleJump = v end
})

local charGroup = tabs.character:AddRightGroupbox("character")
charGroup:AddToggle("noclipToggle", {
    Text = "noclip",
    Default = false,
    Callback = function(v)
        state.noclipEnabled = v
        updateFlyNoclip()
    end
})
charGroup:AddToggle("flyToggle", {
    Text = "fly",
    Default = false,
    Callback = function(v)
        state.flyEnabled = v
        updateFlyNoclip()
    end
})
charGroup:AddSlider("flySpeed", {
    Text = "fly speed",
    Default = 50,
    Min = 10,
    Max = 200,
    Rounding = 0,
    Callback = function(v)
        state.flySpeed = v
        if flyBodyVelocity and state.flyEnabled then
            flyBodyVelocity.Velocity = flyBodyVelocity.Velocity.Unit * v
        end
    end
})
charGroup:AddToggle("infiniteJumpToggle", {
    Text = "infinite jump",
    Default = false,
    Callback = function(v) state.infiniteJumpEnabled = v end
})

local antiAimGroup = tabs.character:AddLeftGroupbox("anti-aim")
antiAimGroup:AddToggle("antiAimToggle", {
    Text = "enabled",
    Default = false,
    Callback = function(v) toggleAntiAim(v) end
})
antiAimGroup:AddSlider("antiAimSpeed", {
    Text = "spin speed (deg/s)",
    Default = 720,
    Min = 60,
    Max = 1440,
    Rounding = 0,
    Callback = function(v) state.antiAimSpeed = v end
})

local scaleGroup = tabs.character:AddRightGroupbox("scaling")
scaleGroup:AddSlider("characterScale", {
    Text = "scale (0.5 to 2.0)",
    Default = 1.0,
    Min = 0.5,
    Max = 2.0,
    Rounding = 1,
    Callback = function(v) onScaleChange(v) end
})

-- misc tab
local silentGroup = tabs.misc:AddLeftGroupbox("silent aim")
silentGroup:AddToggle("silentToggle", {
    Text = "enabled",
    Default = false,
    Callback = function(v) state.silentAimEnabled = v end
})
silentGroup:AddSlider("silentFovRadius", {
    Text = "silent fov radius",
    Default = 400,
    Min = 50,
    Max = 800,
    Rounding = 0,
    Callback = function(v) state.silentFovRadius = v end
})
silentGroup:AddSlider("silentX_Smooth", {
    Text = "x smooth",
    Default = 4,
    Min = 0,
    Max = 100,
    Rounding = 0,
    Callback = function(v) state.silentX_Smooth = v / 100 end
})
silentGroup:AddSlider("silentY_Smooth", {
    Text = "y smooth",
    Default = 4,
    Min = 0,
    Max = 100,
    Rounding = 0,
    Callback = function(v) state.silentY_Smooth = v / 100 end
})

local targetGroup = tabs.misc:AddRightGroupbox("targeting")
targetGroup:AddToggle("targetVisibleOnly", {
    Text = "visible only",
    Default = true,
    Callback = function(v) state.targetingVisibleOnly = v end
})
targetGroup:AddDropdown("targetPart", {
    Text = "target part",
    Values = {"Head", "Neck", "Torso"},
    Default = "Head",
    Callback = function(v) state.targetPart = v end
})

local triggerGroup = tabs.misc:AddLeftGroupbox("triggerbot")
triggerGroup:AddToggle("triggerToggle", {
    Text = "enabled",
    Default = false,
    Callback = function(v) state.triggerbotEnabled = v end
})
triggerGroup:AddSlider("triggerFov", {
    Text = "trigger fov",
    Default = 150,
    Min = 30,
    Max = 500,
    Rounding = 0,
    Callback = function(v) state.triggerFov = v end
})
triggerGroup:AddSlider("triggerDelay", {
    Text = "trigger delay (seconds)",
    Default = 0.1,
    Min = 0.05,
    Max = 0.5,
    Rounding = 2,
    Callback = function(v) state.triggerDelay = v end
})

local rageGroup = tabs.misc:AddRightGroupbox("ragebot")
rageGroup:AddToggle("rageToggle", {
    Text = "enabled",
    Default = false,
    Callback = function(v) toggleRagebot(v) end
})
rageGroup:AddSlider("rageInterval", {
    Text = "teleport interval (seconds)",
    Default = 0.1,
    Min = 0.05,
    Max = 0.5,
    Rounding = 2,
    Callback = function(v) state.rageInterval = v end
})

-- settings tab
local settingsGroup = tabs.settings:AddLeftGroupbox("menu")
settingsGroup:AddLabel("menu bind"):AddKeyPicker("menuKey", {
    Default = "RightShift",
    NoUI = false,
    Text = "menu keybind",
})
if library.ToggleKeybind then
    library.ToggleKeybind = Options.menuKey
else
    _G.Options = _G.Options or {}
    _G.Options.menuKey = Options.menuKey
end
settingsGroup:AddButton("unload script", function()
    cleanupTracers()
    cleanupESPdrawings()
    if antiAimConnection then antiAimConnection:Disconnect() end
    if jumpConnection then jumpConnection:Disconnect() end
    if doubleJumpConnection then doubleJumpConnection:Disconnect() end
    if espConnection then espConnection:Disconnect() end
    if flyBodyVelocity then flyBodyVelocity:Destroy() end
    if flyBodyGyro then flyBodyGyro:Destroy() end
    library:Unload()
end)

-- Config system
local configGroup = tabs.settings:AddRightGroupbox("configuration")
local configName = ""

local configTextbox = configGroup:AddTextbox("configName", {
    Text = "config name",
    Default = "",
    Placeholder = "enter name",
    Callback = function(v) configName = v end
})

local configDropdown = configGroup:AddDropdown("configDropdown", {
    Text = "config list",
    Values = {},
    Default = "",
    AllowNull = true,
    Callback = function(v) configName = v end
})

local function refreshConfigs()
    local configs = library:GetConfigs() or {}
    local values = {}
    for _, name in ipairs(configs) do
        table.insert(values, name)
    end
    configDropdown:SetValues(values)
    if configName ~= "" and table.find(values, configName) then
        configDropdown:SetValue(configName)
    else
        configDropdown:SetValue(nil)
    end
end

configGroup:AddButton("create config", function()
    if configName and configName ~= "" then
        library:SaveConfig(configName)
        library:Notify("config " .. configName .. " created", 2)
        refreshConfigs()
    else
        library:Notify("enter a config name", 2)
    end
end)
configGroup:AddButton("load config", function()
    if configName and configName ~= "" then
        library:LoadConfig(configName)
        library:Notify("config " .. configName .. " loaded", 2)
        refreshConfigs()
        onScaleChange(state.characterScale)
        updateMovementMods()
        -- re-apply ESP and tracers
        if state.espEnabled then
            toggleESP(true)
        end
        if state.tracersEnabled then
            toggleTracers(true)
        end
    else
        library:Notify("select a config", 2)
    end
end)
configGroup:AddButton("delete config", function()
    if configName and configName ~= "" then
        library:DeleteConfig(configName)
        library:Notify("config " .. configName .. " deleted", 2)
        refreshConfigs()
    else
        library:Notify("select a config", 2)
    end
end)
configGroup:AddButton("refresh list", function()
    refreshConfigs()
end)

-- Status panel
local statusGroup = tabs.settings:AddLeftGroupbox("status")
local function addStatusLine(parent, labelText, initialValue, copyable)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 0, 24)
    frame.BackgroundTransparency = 1
    frame.Parent = parent

    local textLabel = Instance.new("TextLabel")
    textLabel.Size = UDim2.new(0.6, 0, 1, 0)
    textLabel.BackgroundTransparency = 1
    textLabel.Text = labelText .. " " .. initialValue
    textLabel.TextColor3 = Color3.fromRGB(220, 220, 220)
    textLabel.TextXAlignment = Enum.TextXAlignment.Left
    textLabel.TextScaled = true
    textLabel.Font = Enum.Font.Gotham
    textLabel.Parent = frame

    if copyable then
        local copyBtn = Instance.new("TextButton")
        copyBtn.Size = UDim2.new(0, 60, 0, 20)
        copyBtn.Position = UDim2.new(1, -65, 0.5, -10)
        copyBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 70)
        copyBtn.Text = "copy"
        copyBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        copyBtn.TextScaled = true
        copyBtn.Font = Enum.Font.Gotham
        copyBtn.BorderSizePixel = 0
        copyBtn.Parent = frame
        local copyCorner = Instance.new("UICorner")
        copyCorner.CornerRadius = UDim.new(0, 4)
        copyCorner.Parent = copyBtn

        copyBtn.MouseButton1Click:Connect(function()
            pcall(function()
                if setclipboard then
                    setclipboard(initialValue)
                end
            end)
        end)

        return textLabel, function(newVal)
            textLabel.Text = labelText .. " " .. newVal
        end
    else
        return textLabel, nil
    end
end

local gameLabel, updateGame = addStatusLine(statusGroup, "game:", gameName, false)
local placeLabel, updatePlace = addStatusLine(statusGroup, "place id:", placeId, true)
local jobLabel, updateJob = addStatusLine(statusGroup, "job id:", jobId, true)

local execFrame = Instance.new("Frame")
execFrame.Size = UDim2.new(1, 0, 0, 24)
execFrame.BackgroundTransparency = 1
execFrame.Parent = statusGroup

local execLabel = Instance.new("TextLabel")
execLabel.Size = UDim2.new(1, 0, 1, 0)
execLabel.BackgroundTransparency = 1
local execDisplay = executorName .. (executorVersion ~= "" and " v" .. executorVersion or "")
execLabel.Text = "executor: " .. execDisplay
execLabel.TextColor3 = Color3.fromRGB(220, 220, 220)
execLabel.TextXAlignment = Enum.TextXAlignment.Left
execLabel.TextScaled = true
execLabel.Font = Enum.Font.Gotham
execLabel.Parent = execFrame

local function refreshStatus()
    local newPlace = tostring(game.PlaceId)
    local newJob = game.JobId or ""
    local newName = fetchGameName()

    updateGame(newName)
    updatePlace(newPlace)
    updateJob(newJob)

    if executorName == "unknown executor" then
        local name, ver = detectExecutor()
        executorName = name
        executorVersion = ver
        local execDisplay = executorName .. (executorVersion ~= "" and " v" .. executorVersion or "")
        execLabel.Text = "executor: " .. execDisplay
    end
end

task.spawn(function()
    while task.wait(5) do
        refreshStatus()
    end
end)
refreshStatus()

refreshConfigs()
library:Notify("DeepScript loaded – discord.gg/gx9H56CHud", 3)
print("DeepScript loaded – press RightShift to toggle menu")