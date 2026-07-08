-- deepscript v1 – universal (no external dependencies required)

task.wait(0.5)

-- ============================================================
-- 1. TRY TO LOAD LINORIA LIB (optional – fallback if fails)
-- ============================================================
local library = nil
local useLibrary = false

local urls = {
    "https://raw.githubusercontent.com/violin-suzutsuki/LinoriaLib/main/Library.lua",
    "https://raw.githubusercontent.com/violin-suzutsuki/LinoriaLib/master/Library.lua",
    "https://cdn.jsdelivr.net/gh/violin-suzutsuki/LinoriaLib@main/Library.lua",
}

for _, url in ipairs(urls) do
    local success, result = pcall(function()
        return loadstring(game:HttpGet(url, true))()
    end)
    if success and result and type(result) == "table" and type(result.CreateWindow) == "function" then
        library = result
        useLibrary = true
        break
    end
end

-- ============================================================
-- 2. SERVICES & STATE (works in both modes)
-- ============================================================
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")
local HttpService = game:GetService("HttpService")
local VirtualInput = game:GetService("VirtualInputManager")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera
local Mouse = LocalPlayer:GetMouse()
local isMobile = UserInputService.TouchEnabled

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

-- fov circle (drawing)
local fovCircle = Drawing.new("Circle")
fovCircle.Color = Color3.fromRGB(255,45,117)
fovCircle.Thickness = 2
fovCircle.NumSides = 64
fovCircle.Filled = false
fovCircle.Visible = false
fovCircle.Transparency = 0.4

-- ============================================================
-- 3. HELPERS (universal)
-- ============================================================
local function isTeammate(player)
    if not player or not LocalPlayer then return false end
    if LocalPlayer.Team and player.Team then
        return LocalPlayer.Team == player.Team
    end
    return false
end

local function isVisible(player)
    if not player or not player.Character then return false end
    local head = player.Character:FindFirstChild("Head")
    if not head then return false end
    local origin = Camera.CFrame.Position
    local direction = (head.Position - origin).Unit
    local distance = (head.Position - origin).Magnitude
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Blacklist
    params.FilterDescendantsInstances = {LocalPlayer.Character, Camera}
    local result = Workspace:Raycast(origin, direction * distance, params)
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
    local mousePos = UserInputService:GetMouseLocation()
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character and not isTeammate(player) and isAlive(player) then
            local head = player.Character:FindFirstChild("Head")
            if head then
                if requireVisible and not isVisible(player) then continue end
                local screenPos, onScreen = Camera:WorldToViewportPoint(head.Position)
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
    local localPos = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not localPos then return nil end
    local origin = localPos.Position
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character and not isTeammate(player) and isAlive(player) then
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
-- 4. FEATURES (universal)
-- ============================================================
local isAiming = false
local aimKey = Enum.UserInputType.MouseButton2

UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.UserInputType == aimKey then isAiming = true end
end)
UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == aimKey then isAiming = false end
end)

-- Aimbot
RunService.RenderStepped:Connect(function()
    local mousePos = UserInputService:GetMouseLocation()
    fovCircle.Position = mousePos
    fovCircle.Radius = state.fovRadius
    fovCircle.Visible = state.showFov

    if state.aimbotEnabled and isAiming then
        local target = getClosestEnemyToMouse(state.fovRadius, state.targetingVisibleOnly)
        if target then
            local part = getTargetPart(target)
            if part then
                local targetCF = CFrame.new(Camera.CFrame.Position, part.Position)
                Camera.CFrame = Camera.CFrame:Lerp(targetCF, state.aimSmoothness)
            end
        end
    end
end)

-- Silent aim
local silentTarget = nil
local silentSmoothX, silentSmoothY = 0, 0

UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
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
                    Mouse.Hit = CFrame.new(part.Position)
                end
            end
        end
    end
end)

RunService.RenderStepped:Connect(function()
    if silentTarget and isAlive(silentTarget) then
        local part = getTargetPart(silentTarget)
        if part then
            local cp = Mouse.Hit.Position
            local tp = part.Position
            local nx = cp.X + (tp.X - cp.X) * silentSmoothX
            local ny = cp.Y + (tp.Y - cp.Y) * silentSmoothY
            Mouse.Hit = CFrame.new(nx, ny, tp.Z)
        else
            silentTarget = nil
        end
    else
        silentTarget = nil
    end
end)

-- Triggerbot
local triggerCooldown = false
RunService.RenderStepped:Connect(function()
    if state.triggerbotEnabled and isAiming then
        local target = getClosestEnemyToMouse(state.triggerFov, state.targetingVisibleOnly)
        if target and isAlive(target) and not triggerCooldown then
            triggerCooldown = true
            pcall(function()
                VirtualInput:SendMouseButtonEvent(0,0,0,true,game,0)
                task.wait(state.triggerDelay)
                VirtualInput:SendMouseButtonEvent(0,0,0,false,game,0)
            end)
            task.wait(state.triggerDelay * 0.5)
            triggerCooldown = false
        end
    end
end)

-- Ragebot
local ragebotRunning = false
local function ragebotLoop()
    while state.ragebotEnabled do
        if not LocalPlayer.Character then task.wait(0.5) continue end
        local hum = LocalPlayer.Character:FindFirstChild("Humanoid")
        if not hum or hum.Health <= 0 then task.wait(0.5) continue end
        local target = getClosestEnemy()
        if target and isAlive(target) then
            local part = getTargetPart(target)
            if part then
                local root = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                if root then
                    root.CFrame = part.CFrame
                end
            end
        end
        task.wait(state.rageInterval)
    end
end

local function toggleRagebot(en)
    state.ragebotEnabled = en
    if en then
        if not ragebotRunning then
            ragebotRunning = true
            task.spawn(ragebotLoop)
        end
    else
        ragebotRunning = false
    end
end

-- Anti-aim
local antiAimConn = nil
local function antiAimLoop(dt)
    if state.antiAimEnabled then
        local root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if root then
            local speed = math.rad(state.antiAimSpeed) * dt
            root.CFrame = root.CFrame * CFrame.Angles(0, speed, 0)
        end
    end
end

local function toggleAntiAim(en)
    state.antiAimEnabled = en
    if en and not antiAimConn then
        antiAimConn = RunService.Heartbeat:Connect(antiAimLoop)
    elseif not en and antiAimConn then
        antiAimConn:Disconnect()
        antiAimConn = nil
    end
end

-- Infinite jump
RunService.RenderStepped:Connect(function()
    if state.infiniteJumpEnabled then
        local root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if root and UserInputService:IsKeyDown(Enum.KeyCode.Space) then
            if root.AssemblyLinearVelocity.Y < 50 then
                root.AssemblyLinearVelocity = Vector3.new(root.AssemblyLinearVelocity.X, 50, root.AssemblyLinearVelocity.Z)
            end
        end
    end
end)

-- Infinite double jump
local doubleJumpCooldown = false
RunService.RenderStepped:Connect(function()
    if state.infiniteDoubleJump and not doubleJumpCooldown then
        local root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if root and UserInputService:IsKeyDown(Enum.KeyCode.Space) and root.AssemblyLinearVelocity.Y < 50 then
            root.AssemblyLinearVelocity = Vector3.new(root.AssemblyLinearVelocity.X, 50, root.AssemblyLinearVelocity.Z)
            doubleJumpCooldown = true
            task.spawn(function() task.wait(0.1) doubleJumpCooldown = false end)
        end
    end
end)

-- Character scaling
local function applyScale(s)
    local char = LocalPlayer.Character
    if char then
        local hum = char:FindFirstChild("Humanoid")
        if hum then
            pcall(function()
                local desc = Instance.new("HumanoidDescription")
                desc.BodyHeightScale = s
                desc.BodyWidthScale = s
                desc.BodyDepthScale = s
                hum:ApplyDescription(desc)
            end)
        end
    end
end

local function onScaleChange(v)
    state.characterScale = v
    applyScale(v)
end

LocalPlayer.CharacterAdded:Connect(function()
    task.wait(0.5)
    applyScale(state.characterScale)
end)

-- Movement speed
local function updateMovement()
    local char = LocalPlayer.Character
    if not char then return end
    local hum = char:FindFirstChild("Humanoid")
    if hum then
        hum.WalkSpeed = state.velocityEnabled and state.velocitySpeed or 16
        hum.JumpPower = 50 * state.doubleJumpHeight
    end
end

-- Fly & Noclip
local flyBV, flyBG = nil, nil
local noclipActive = false

local function updateFlyNoclip()
    local char = LocalPlayer.Character
    if not char then return end
    local root = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChild("Humanoid")
    if not root or not hum then return end

    if state.flyEnabled or state.noclipEnabled then
        hum.PlatformStand = true
    else
        hum.PlatformStand = false
    end

    if state.noclipEnabled ~= noclipActive then
        noclipActive = state.noclipEnabled
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") then
                part.CanCollide = not state.noclipEnabled
            end
        end
    end

    if state.flyEnabled then
        if not flyBV or flyBV.Parent ~= root then
            if flyBV then flyBV:Destroy() end
            flyBV = Instance.new("BodyVelocity")
            flyBV.MaxForce = Vector3.new(1e9,1e9,1e9)
            flyBV.Parent = root
        end
        if not flyBG or flyBG.Parent ~= root then
            if flyBG then flyBG:Destroy() end
            flyBG = Instance.new("BodyGyro")
            flyBG.MaxTorque = Vector3.new(1e9,1e9,1e9)
            flyBG.Parent = root
        end
        local dir = Vector3.new(0,0,0)
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then dir = dir + Camera.CFrame.LookVector * Vector3.new(1,0,1) end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then dir = dir - Camera.CFrame.LookVector * Vector3.new(1,0,1) end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then dir = dir - Camera.CFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then dir = dir + Camera.CFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then dir = dir + Vector3.new(0,1,0) end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then dir = dir - Vector3.new(0,1,0) end
        if dir.Magnitude > 0 then dir = dir.Unit * state.flySpeed else dir = Vector3.new(0,0,0) end
        flyBV.Velocity = dir
        flyBG.CFrame = Camera.CFrame * CFrame.new(0,0,-1)
    else
        if flyBV then flyBV:Destroy(); flyBV = nil end
        if flyBG then flyBG:Destroy(); flyBG = nil end
        if state.noclipEnabled then
            root.AssemblyLinearVelocity = Vector3.new(0,0,0)
            root.AssemblyAngularVelocity = Vector3.new(0,0,0)
        end
    end
end

RunService.RenderStepped:Connect(function()
    updateFlyNoclip()
    updateMovement()
end)

LocalPlayer.CharacterAdded:Connect(function()
    flyBV = nil; flyBG = nil; noclipActive = false
    task.wait(0.5)
    updateFlyNoclip()
    updateMovement()
end)

-- ESP highlight
local function updateHighlight()
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            local h = player.Character:FindFirstChild("HackerESP")
            if state.espEnabled then
                if not h then
                    h = Instance.new("Highlight")
                    h.Name = "HackerESP"
                    h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                    h.Parent = player.Character
                    h.Adornee = player.Character
                end
                local visible = isVisible(player)
                h.FillColor = visible and Color3.fromRGB(0,150,255) or Color3.fromRGB(255,45,117)
                h.OutlineColor = visible and Color3.fromRGB(100,200,255) or Color3.fromRGB(255,150,200)
                h.FillTransparency = 0.3
                h.OutlineTransparency = 0.1
                h.Enabled = true
            elseif h then
                h.Enabled = false
            end
        end
    end
end

-- ESP drawings
local espDrawings = {}
local function cleanupDrawings()
    for _, data in pairs(espDrawings) do
        for _, obj in pairs(data) do
            if obj and obj.Remove then obj:Remove() end
        end
    end
    espDrawings = {}
end

local function updateESPdrawings()
    if not state.espEnabled then
        cleanupDrawings()
        return
    end
    local enemies = {}
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character and not isTeammate(player) and isAlive(player) then
            table.insert(enemies, player)
        end
    end
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
            local screenPos, onScreen = Camera:WorldToViewportPoint(root.Position)
            if onScreen then
                local dist = (root.Position - Camera.CFrame.Position).Magnitude
                local scale = math.max(0.3, 1 / (dist / 20))
                local boxSize = Vector2.new(50,80) * scale
                local topLeft = Vector2.new(screenPos.X - boxSize.X/2, screenPos.Y - boxSize.Y/2)
                if not espDrawings[player] then espDrawings[player] = {} end
                local data = espDrawings[player]
                if state.espBox then
                    if not data.box then
                        data.box = Drawing.new("Square")
                        data.box.Color = Color3.fromRGB(255,255,255)
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
                if state.espFill then
                    if not data.fill then
                        data.fill = Drawing.new("Square")
                        data.fill.Color = Color3.fromRGB(0,150,255)
                        data.fill.Thickness = 0
                        data.fill.Filled = true
                        data.fill.Visible = true
                    end
                    data.fill.Size = boxSize
                    data.fill.Position = topLeft
                    data.fill.Transparency = 0.5
                else
              