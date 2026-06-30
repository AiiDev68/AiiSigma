local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local CoreGui = game:GetService("CoreGui")
local Teams = game:GetService("Teams")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VirtualInputManager = game:GetService("VirtualInputManager")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local IsMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

if CoreGui:FindFirstChild("MitHub_V3") then CoreGui.MitHub_V3:Destroy() end

local COLORS = {
    THEME = Color3.fromRGB(98, 63, 117),
    THEME_DARK = Color3.fromRGB(60, 35, 75),
    THEME_DARKER = Color3.fromRGB(30, 15, 40),
    THEME_BTN = Color3.fromRGB(75, 45, 95),
}

local States = {
	Noclip = false,
	PlayerESP = false,
	GeneratorESP = false,
	PalletESP = false,
	WindowESP = false,
	InstantHeal = false,
	InstantHealOthers = false,
	AutoHealAll = false,
	AutoLever = false,
  AutoDodge = false
}


local Extras = {
    antiFallEnabled   = false,
    fovEnabled        = false,
    fovValue          = 90,
   myersGrabEnabled  = false,
   myersGrabKey      = Enum.KeyCode.Unknown,
   listeningMyersKey = false,
   MIN_HEALTH_MYERS  = 30,
   breakGenEnabled   = false,
   breakGenCount     = 10,
   breakGenCaptured  = nil,
   breakGenFired     = false,
   myersDragging    = false,
   myersDragLocked  = false,
   myersDragStart   = nil,
   myersDragStartPos = nil,
   autoGeneratorEnabled = false,
   lastGoalRotation     = nil,
   hasClickedThisGoal   = false,
   lastLineRotation     = nil,
   lastTick             = nil,
   wasActive            = false,
   fastAnimSpeed    = 2.0,
   fastAnimEnabled  = false,
   fastAnimHeartbeat = nil,
   speedBoostConn   = nil,
   NoSlowdown       = false,
   CustomSpeed      = 17,
   genBoostEnabled = false,
   genBoostLoop = nil,
   instantSkillcheckEnabled = false,
   instantSkillcheckMode    = false,
   isStatusActive = function(val)
    return val == true or (type(val) == "number" and val > 0)
end,
}

local TARGET_OFFSET        = 106.5
local TOLERANCE            = 2.5
local LATENCY_COMPENSATION = 0

local VAULT_SLIDE_SET = {
    ["WalkingVaultAnimation"]            = true,
    ["RunningVaultAnimation"]            = true,
    ["RunningVaultAnimation2"]           = true,
    ["RunningSlideAnimation"]            = true,
    ["RunningSlideAnimation2"]           = true,
    ["RunningSlideAnimationReversed"]    = true,
    ["RunningSlideAnimationReversed2"]   = true,
    ["RunningSlideWalkAnimation"]        = true,
    ["RunningSlideWalkAnimation2"]       = true,
    ["RunningSlideWalkAnimationRe"]      = true,
    ["RunningSlideWalkAnimationRe2"]     = true,
    ["PalletDropAnimation"]             = true,
    ["PalletDropAnimation2"]            = true,
    ["PalletDropAnimationReversed"]      = true,
    ["PalletDropAnimationReversed2"]     = true,
    ["Vault"]                            = true,  -- test
    ["BreakPallet"]                      = true,  -- test
}

local function setupFastAnimations()
    local char = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    local hum = char:WaitForChild("Humanoid")
    local animator = hum:WaitForChild("Animator")

    animator.AnimationPlayed:Connect(function(track)
        local animName = track.Animation and track.Animation.Name
        if not VAULT_SLIDE_SET[animName] then return end

        if Extras.fastAnimEnabled then
            pcall(function() track:AdjustSpeed(Extras.fastAnimSpeed) end)
        end

        if Extras.speedBoostConn then Extras.speedBoostConn:Disconnect() end
        hum.WalkSpeed = 30
        Extras.speedBoostConn = RunService.Heartbeat:Connect(function()
            if hum and hum.Parent then
                hum.WalkSpeed = 30
            end
        end)

        track.Stopped:Once(function()
            if Extras.speedBoostConn then
                Extras.speedBoostConn:Disconnect()
                Extras.speedBoostConn = nil
            end
            if hum and hum.Parent then
                hum.WalkSpeed = hum:GetAttribute("WalkSpeed") or 16
            end
        end)
    end)

    if Extras.fastAnimHeartbeat then Extras.fastAnimHeartbeat:Disconnect() end
    Extras.fastAnimHeartbeat = RunService.Heartbeat:Connect(function()
        if not Extras.fastAnimEnabled then return end
        for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
            local animName = track.Animation and track.Animation.Name
            if VAULT_SLIDE_SET[animName] and track.Speed ~= Extras.fastAnimSpeed then
                pcall(function() track:AdjustSpeed(Extras.fastAnimSpeed) end)
            end
        end
    end)

    char.AncestryChanged:Connect(function()
        if not char:IsDescendantOf(game) then
            if Extras.fastAnimHeartbeat then Extras.fastAnimHeartbeat:Disconnect(); Extras.fastAnimHeartbeat = nil end
            if Extras.speedBoostConn then Extras.speedBoostConn:Disconnect(); Extras.speedBoostConn = nil end
        end
    end)
end

LocalPlayer.CharacterAdded:Connect(function()
    task.wait(0.5)
    setupFastAnimations()
end)
setupFastAnimations()

RunService.Heartbeat:Connect(function()
    if not Extras.antiStunEnabled then return end
    local char = LocalPlayer.Character
    if not char then return end
    pcall(function()
        local hum = char:FindFirstChildOfClass("Humanoid")
        if not hum then return end
        if char:GetAttribute("Stunned") then
            char:SetAttribute("Stunned", false)
        end
        local stunnedVal = char:FindFirstChild("Stunned")
        if stunnedVal and stunnedVal:IsA("BoolValue") then
            stunnedVal.Value = false
        end
        if hum.PlatformStand then hum.PlatformStand = false end
        if hum.Sit then hum.Sit = false end
    end)
end)

local antiFallHookRef
antiFallHookRef = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
    local method = getnamecallmethod()
    if Extras.antiFallEnabled and method == "FireServer" then
        local ok, name = pcall(function() return self.Name:lower() end)
        if ok and (name:find("falldamage") or name:find("fall") or name:find("ragdollfall")) then
            return
        end
    end
    return antiFallHookRef(self, ...)
end))

RunService.Heartbeat:Connect(function(dt)
    if not Extras.NoSlowdown then return end
    local myChar = LocalPlayer.Character
    if not myChar then return end
    local myHum = myChar:FindFirstChildOfClass("Humanoid")
    local myRoot = myChar:FindFirstChild("HumanoidRootPart")
    if not myHum or not myRoot then return end

    local isImmobilized =
        Extras.isStatusActive(myChar:GetAttribute("IsHooked"))
or Extras.isStatusActive(myChar:GetAttribute("Carried"))
or Extras.isStatusActive(myChar:GetAttribute("Grabbed"))

    local isDoingCriticalAction = false
    for _, track in ipairs(myHum:GetPlayingAnimationTracks()) do
        if track.Animation then
            local name = track.Animation.Name:lower()
            if name:find("hook") or name:find("grab") or name:find("pickup") or name:find("place") then
                isDoingCriticalAction = true
                break
            end
        end
    end

    if myHum.Health > 0
    and not isImmobilized
    and not isDoingCriticalAction
    and myHum.MoveDirection.Magnitude > 0 then
        local currentWalkSpeed = myHum.WalkSpeed
        local desiredSpeed = currentWalkSpeed
        if currentWalkSpeed < Extras.CustomSpeed then
            desiredSpeed = Extras.CustomSpeed
        end
        local speedDiff = desiredSpeed - currentWalkSpeed
        if speedDiff > 0 then
            local offset = myHum.MoveDirection * (speedDiff * dt)
            pcall(function() myRoot.CFrame = myRoot.CFrame + offset end)
        end
    end
end)

local ISC = {
    LastTriggerTick = 0,
    LastGoalRotation = 0,
    LastGoalInstance = nil,
    CurrentGoalID = 0,
    HasClicked = false,
    isForcingRotation  = false,
    RotationConnection = nil,
}
-- ajudaaqui
local ISC_Kingscourge = {
    Active = false,
    ID     = nil,
    Count  = 0,
}

local function ISC_GetNearestGenProgress()
    local char = LocalPlayer.Character
    local myHRP = char and char:FindFirstChild("HumanoidRootPart")
    if not myHRP then return 0 end

    local nearest, nearestDist = nil, math.huge
    
    -- Acessa direto a pasta que você indicou de forma segura
    local map = workspace:FindFirstChild("Map")
    local newGensFolder = map and map:FindFirstChild("new Generators")

    if newGensFolder then
        -- Em vez de GetDescendants() no mapa todo, usamos GetChildren() apenas nos geradores!
        for _, gen in ipairs(newGensFolder:GetChildren()) do
            if gen.Name == "Generator" then
                local part = gen:FindFirstChild("HitBox", true) or gen.PrimaryPart or gen:FindFirstChildWhichIsA("BasePart")
                if part then
                    local dist = (part.Position - myHRP.Position).Magnitude
                    if dist < nearestDist then
                        nearestDist = dist
                        nearest = gen
                    end
                end
            end
        end
    end

    if not nearest then return 0 end
    local pct = tonumber(nearest:GetAttribute("RepairProgress")) or 0
    if pct <= 1 then pct = pct * 100 end
    return pct
end


local function ISC_PressSkill()
    if tick() - ISC.LastTriggerTick < 0.03 then return end
    ISC.LastTriggerTick = tick()
    if IsMobile then
        local btn = PlayerGui:FindFirstChild("check", true)
        if btn and btn:IsA("GuiObject") then
            local pos   = btn.AbsolutePosition
            local size  = btn.AbsoluteSize
            local inset = game:GetService("GuiService"):GetGuiInset()
            local x = pos.X + size.X / 2 + inset.X
            local y = pos.Y + size.Y / 2 + inset.Y
            task.spawn(function()
                pcall(function()
                    VirtualInputManager:SendTouchEvent(8822, Enum.UserInputState.Begin.Value, x, y)
                    task.wait()
                    VirtualInputManager:SendTouchEvent(8822, Enum.UserInputState.End.Value, x, y)
                end)
            end)
            pcall(function()
                if firesignal and btn.MouseButton1Click then firesignal(btn.MouseButton1Click) end
            end)
        end
    else
        task.spawn(function()
            pcall(function()
                VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.Space, false, game)
                task.wait()
                VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Space, false, game)
            end)
        end)
    end
end

local function PressSkill()
    if IsMobile then
        local btn = PlayerGui:FindFirstChild("check", true)
        if btn and btn:IsA("GuiObject") then
            local pos   = btn.AbsolutePosition
            local size  = btn.AbsoluteSize
            local inset = game:GetService("GuiService"):GetGuiInset()
            local x = pos.X + (size.X / 2) + inset.X
            local y = pos.Y + (size.Y / 2) + inset.Y
            pcall(function()
                VirtualInputManager:SendTouchEvent(8822, Enum.UserInputState.Begin.Value, x, y)
            end)
            task.wait(0.01)
            pcall(function()
                VirtualInputManager:SendTouchEvent(8822, Enum.UserInputState.End.Value, x, y)
            end)
            pcall(function()
                if firesignal and btn.MouseButton1Click then
                    firesignal(btn.MouseButton1Click)
                end
            end)
        end
    else
        pcall(function()
            VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.Space, false, game)
        end)
        task.wait(0.01)
        pcall(function()
            VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Space, false, game)
        end)
    end
end

local function GetSkillCheck()
    for _, guiName in ipairs({"SkillCheckPromptGui", "SkillCheckPromptGui-con"}) do
        local gui = PlayerGui:FindFirstChild(guiName, true)
        if gui then
            local check = gui:FindFirstChild("Check", true)
            if check and check.Visible then
                local line = check:FindFirstChild("Line", true)
                local goal = check:FindFirstChild("Goal", true)
                if line and goal then return line, goal end
            end
        end
    end
end

local function AngularDelta(from, to)
    local d = to - from
    if d > 180  then d = d - 360 end
    if d < -180 then d = d + 360 end
    return d
end

local function CrossedZone(prevLr, lr, startPos, endPos)
    local function inZone(r)
        if startPos > endPos then
            return r >= startPos or r <= endPos
        else
            return r >= startPos and r <= endPos
        end
    end

    if inZone(lr) then return true end
    if prevLr == nil then return false end

    local delta = AngularDelta(prevLr, lr)
    local steps = math.abs(math.floor(delta))
    if steps < 2 then return false end

    local stepSize = delta / steps
    for i = 1, steps do
        local sample = (prevLr + stepSize * i) % 360
        if inZone(sample) then return true end
    end

    return false
end

RunService.RenderStepped:Connect(function()
    if not Extras.autoGeneratorEnabled then return end

    local line, goal = GetSkillCheck()

    if not (line and goal) then
        Extras.lastGoalRotation   = nil
        Extras.hasClickedThisGoal = false
        Extras.lastLineRotation   = nil
        Extras.lastTick           = nil
        Extras.wasActive          = false
        return
    end

    local lr = line.Rotation % 360
    local gr = goal.Rotation % 360
    local currentTick = os.clock()

    if not Extras.wasActive then
        Extras.wasActive          = true
        Extras.hasClickedThisGoal = false
        Extras.lastGoalRotation   = gr
        Extras.lastLineRotation   = lr
        Extras.lastTick           = currentTick
        return
    end

    if Extras.lastGoalRotation ~= nil then
        if math.abs(AngularDelta(Extras.lastGoalRotation, gr)) > 5 then
            Extras.hasClickedThisGoal = false
            Extras.lastLineRotation   = nil
            Extras.lastTick           = nil
        end
    end
    Extras.lastGoalRotation = gr

    if Extras.hasClickedThisGoal then
        Extras.lastLineRotation = lr
        Extras.lastTick         = currentTick
        return
    end

    if Extras.lastLineRotation and Extras.lastTick then
        local dt = currentTick - Extras.lastTick
        if dt > 0 then
            local lineSpeed = AngularDelta(Extras.lastLineRotation, lr) / dt
            local predictedLr = (lr + lineSpeed * dt * LATENCY_COMPENSATION) % 360

            local startPos = (gr + TARGET_OFFSET - TOLERANCE) % 360
            local endPos   = (gr + TARGET_OFFSET + TOLERANCE) % 360

            if CrossedZone(Extras.lastLineRotation, predictedLr, startPos, endPos) then
                Extras.hasClickedThisGoal = true
                task.spawn(PressSkill)
            end
        end
    end

    Extras.lastLineRotation = lr
    Extras.lastTick         = currentTick
end)

local lastGenCheck = 0
local cachedProgress = 0

RunService.RenderStepped:Connect(function()
    if not Extras.instantSkillcheckEnabled then return end
    if ISC_Kingscourge.Active then return end

    if tick() - lastGenCheck >= 0.5 then
        lastGenCheck = tick()
        cachedProgress = ISC_GetNearestGenProgress()
    end

    if cachedProgress >= 86 then
        Extras.instantSkillcheckMode = false
        if ISC.RotationConnection then
            ISC.RotationConnection:Disconnect()
            ISC.RotationConnection = nil
        end
        return
    end

    Extras.instantSkillcheckMode = true

    local line, goal = GetSkillCheck()
    if not (line and goal) then
        ISC.HasClicked         = false
        ISC.LastGoalRotation   = 0
        ISC.LastGoalInstance   = nil
        ISC.CurrentGoalID      = 0
        if ISC.RotationConnection then
            ISC.RotationConnection:Disconnect()
            ISC.RotationConnection = nil
        end
        return
    end

    local gr          = goal.Rotation % 360
    local offsetStart = 104
    local offsetEnd   = 108
    local perfectRot  = (gr + (offsetStart + offsetEnd) / 2) % 360

    if not ISC.isForcingRotation then
        ISC.isForcingRotation = true
        pcall(function() line.Rotation = perfectRot end)
        ISC.isForcingRotation = false
    end

    local isNewGoal = false
    local goalDiff  = math.abs(gr - ISC.LastGoalRotation)
    if goalDiff > 180 then goalDiff = 360 - goalDiff end

    if (goalDiff > 0.5) or (ISC.LastGoalInstance ~= goal) then
        isNewGoal             = true
        ISC.HasClicked        = false
    end

    ISC.LastGoalRotation  = gr
    ISC.LastGoalInstance  = goal

    if isNewGoal then
        ISC.CurrentGoalID += 1
        local assignedID = ISC.CurrentGoalID

        if ISC.RotationConnection then ISC.RotationConnection:Disconnect() end
        ISC.RotationConnection = line:GetPropertyChangedSignal("Rotation"):Connect(function()
            if ISC.isForcingRotation then return end
            ISC.isForcingRotation = true
            pcall(function()
                local _, cGoal = GetSkillCheck()
                if cGoal then
                    line.Rotation = (cGoal.Rotation % 360 + (offsetStart + offsetEnd) / 2) % 360
                end
            end)
            ISC.isForcingRotation = false
        end)

        if not ISC.HasClicked then
            ISC.HasClicked = true
            task.spawn(function()
                task.wait(0.05)
                if ISC.CurrentGoalID == assignedID then
                    local cl, cg = GetSkillCheck()
                    if cl and cg then ISC_PressSkill() end
                end
            end)
        end
    end
end)

task.spawn(function()
    local Remotes = ReplicatedStorage:WaitForChild("Remotes", 10)
    local KillerPerks = Remotes and Remotes:WaitForChild("KillerPerks", 5)
    local kingscourgeFolder = KillerPerks and KillerPerks:WaitForChild("kingscourge", 5)

    if kingscourgeFolder then
        local KingScourgeStart = kingscourgeFolder:WaitForChild("KingScourgeStart")
        local KingScourgeHit = kingscourgeFolder:WaitForChild("KingScourgeHit")
        local KingScourgeEnd = kingscourgeFolder:WaitForChild("KingScourgeEnd")

        KingScourgeStart.OnClientEvent:Connect(function(p1, p2, p3)
            if not Extras.instantSkillcheckEnabled then return end
            local char = LocalPlayer.Character
            if not char then return end
            local checkInt = char:FindFirstChild("CheckInterractable")
            if not (checkInt and checkInt:GetAttribute("isRepairing")) then return end

            ISC_Kingscourge.Active = true
            ISC_Kingscourge.ID = p2
            ISC_Kingscourge.Count = p3 or 5

            task.spawn(function()
                for i = 1, ISC_Kingscourge.Count do
                    if not ISC_Kingscourge.Active then break end
                    pcall(function()
                        KingScourgeHit:FireServer(ISC_Kingscourge.ID, "success")
                    end)
                    task.wait(0.03)
                end
                ISC_Kingscourge.Active = false
            end)
        end)

        KingScourgeEnd.OnClientEvent:Connect(function(p1)
            if p1 == ISC_Kingscourge.ID then
                ISC_Kingscourge.Active = false
            end
        end)
    end
end)

-- crazykj
local GenBypass = {
    Enabled     = false,
    Button      = nil,
    UI          = nil,
    Cache       = {},
    CacheTimer  = 0,
    Processed   = {},
    HotkeyCode  = Enum.KeyCode.G,
}

local RepairEvent = ReplicatedStorage:FindFirstChild("Remotes")
    and ReplicatedStorage.Remotes:FindFirstChild("Generator")
    and ReplicatedStorage.Remotes.Generator:FindFirstChild("RepairEvent")

local function GB_GetAllGenerators()
    local now = tick()
    if now - GenBypass.CacheTimer < 5 then return GenBypass.Cache end
    GenBypass.Cache = {}
    GenBypass.CacheTimer = now
    local mapFolder = workspace:FindFirstChild("Map")
    if not mapFolder then return GenBypass.Cache end
    pcall(function()
        for _, v in pairs(mapFolder:GetDescendants()) do
            if not v:IsA("Model") then continue end
            if v.Name ~= "Generator" then continue end
            local isReal = v:GetAttribute("RepairProgress") ~= nil
                or v:GetAttribute("kickcount") ~= nil
                or v:GetAttribute("ProgressRepair") ~= nil
            if isReal then table.insert(GenBypass.Cache, v) end
        end
    end)
    return GenBypass.Cache
end

local function GB_GetPoints(genModel)
    local points = {}
    pcall(function()
        for _, obj in pairs(genModel:GetChildren()) do
            if obj.Name:find("GeneratorPoint") and obj:IsA("BasePart") then
                table.insert(points, obj)
            end
        end
    end)
    return points
end

local function GB_WaitRepairing(point, timeout)
    local start = tick()
    while tick() - start < (timeout or 1) do
        if point:GetAttribute("IsRepairing") == true then return true end
        task.wait(0.05)
    end
    return false
end

local function GB_DoRepair(targetPoint)
    local genModel = targetPoint.Parent
    if GenBypass.Processed[genModel] then return end
    GenBypass.Processed[genModel] = true

    local character = LocalPlayer.Character
    local hrp = character and character:FindFirstChild("HumanoidRootPart")
    if not hrp then GenBypass.Processed[genModel] = nil return end

    local originalCFrame = hrp.CFrame
    pcall(function()
        for _, point in pairs(GB_GetPoints(genModel)) do
            if point ~= targetPoint and point.Parent then
                hrp.Anchored = true
                hrp.CFrame = point.CFrame
                task.wait(0.15)
                pcall(function() if RepairEvent then RepairEvent:FireServer(point, true) end end)
                if not GB_WaitRepairing(point, 0.8) then
                    pcall(function() if RepairEvent then RepairEvent:FireServer(point, false) end end)
                    task.wait(0.1)
                    hrp.CFrame = point.CFrame
                    task.wait(0.15)
                    pcall(function() if RepairEvent then RepairEvent:FireServer(point, true) end end)
                    GB_WaitRepairing(point, 0.5)
                end
                hrp.Anchored = false
                task.wait(0.05)
            end
        end
    end)
    pcall(function()
        if hrp and hrp.Parent then
            hrp.Anchored = false
            hrp.CFrame = originalCFrame
        end
    end)
    task.wait(0.1)
    pcall(function() if RepairEvent then RepairEvent:FireServer(targetPoint, false) end end)
end

local function GB_GetNearestPoint()
    local character = LocalPlayer.Character
    local hrp = character and character:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil end
    local bestPoint, bestDist = nil, math.huge
    for _, gen in pairs(GB_GetAllGenerators()) do
        for _, point in pairs(GB_GetPoints(gen)) do
            local d = (hrp.Position - point.Position).Magnitude
            if d < bestDist then bestDist = d; bestPoint = point end
        end
    end
    return bestPoint, bestDist
end

local function GB_IsPromptVisible()
    local ok, frame = pcall(function()
        return LocalPlayer.PlayerGui.pcprompts.Frame.GeneratorRepair
    end)
    return ok and frame and frame.Visible
end

local function GB_UpdateButton()
    if GenBypass.Button then
        GenBypass.Button.Visible = GenBypass.Enabled and IsMobile
    end
end

local function GB_CreateButton()
    local oldUI = LocalPlayer.PlayerGui:FindFirstChild("BypassGenUI")
    if oldUI then oldUI:Destroy() end

    GenBypass.UI = Instance.new("ScreenGui")
    GenBypass.UI.Name = "BypassGenUI"
    GenBypass.UI.ResetOnSpawn = false
    GenBypass.UI.IgnoreGuiInset = true
    GenBypass.UI.Parent = LocalPlayer:WaitForChild("PlayerGui")

    GenBypass.Button = Instance.new("ImageButton")
    GenBypass.Button.Name = "BypassGenButton"
    GenBypass.Button.Size = UDim2.new(0, 55, 0, 55)
    GenBypass.Button.Position = UDim2.new(0.88, 0, 0.55, 0)
    GenBypass.Button.AnchorPoint = Vector2.new(0.5, 0.5)
    GenBypass.Button.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    GenBypass.Button.BackgroundTransparency = 0.15
    GenBypass.Button.AutoButtonColor = true
    GenBypass.Button.Visible = false
    GenBypass.Button.ZIndex = 10
    GenBypass.Button.Parent = GenBypass.UI
    Instance.new("UICorner", GenBypass.Button).CornerRadius = UDim.new(1, 0)
    local s = Instance.new("UIStroke", GenBypass.Button)
    s.Color = Color3.fromRGB(255, 255, 255)
    s.Thickness = 1.5; s.Transparency = 0.4
    local lbl = Instance.new("TextLabel", GenBypass.Button)
    lbl.Size = UDim2.new(1, 0, 1, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = "BOOST"
    lbl.TextColor3 = Color3.fromRGB(255, 0, 255)
    lbl.TextScaled = true
    lbl.Font = Enum.Font.GothamBold
    lbl.ZIndex = 11

    GenBypass.Button.MouseButton1Click:Connect(function()
        if not GenBypass.Enabled then return end
        local bestPoint, bestDist = GB_GetNearestPoint()
        if bestPoint and bestDist <= 8 then GB_DoRepair(bestPoint) end
    end)
end
GB_CreateButton()

LocalPlayer.CharacterAdded:Connect(function()
    task.wait(0.5)
    GB_CreateButton()
    GB_UpdateButton()
end)

-- pc
UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    if IsMobile then return end
    if input.KeyCode == GenBypass.HotkeyCode and GenBypass.Enabled then
        if not GB_IsPromptVisible() then return end
        local bestPoint, bestDist = GB_GetNearestPoint()
        if not bestPoint or bestDist > 8 then return end
        if GenBypass.Processed[bestPoint.Parent] then return end
        GB_DoRepair(bestPoint)
    end
end)

-- outro fix
UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
    if not GenBypass.Enabled then return end
    if not GB_IsPromptVisible() then return end
    local bestPoint, bestDist = GB_GetNearestPoint()
    if not bestPoint or bestDist > 8 then return end
    if GenBypass.Processed[bestPoint.Parent] then return end
    GB_DoRepair(bestPoint)
end)

-- fix
task.spawn(function()
    while true do
        task.wait(2)
        local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if hrp then
            for genModel in pairs(GenBypass.Processed) do
                if not genModel or not genModel.Parent then
                    GenBypass.Processed[genModel] = nil
                    continue
                end
                local nearAny = false
                for _, point in pairs(GB_GetPoints(genModel)) do
                    if point.Parent and (hrp.Position - point.Position).Magnitude <= 10 then
                        nearAny = true; break
                    end
                end
                if not nearAny then GenBypass.Processed[genModel] = nil end
            end
        end
    end
end)

-- SEÇÃO VEIL - PREDIÇÃO HORIZONTAL SIMPLES (BASEADA NA VELOCIDADE)

-- Configurações
local VeilConfig = {
    Enabled              = false,
    ShowFOV              = true,
    FOV                  = 150,
    SpearSpeed           = 165,
    Gravity              = workspace.Gravity * 0.5,
    MaxDist              = 200,
    AutoPredict          = false,   -- ajusta gravidade dinamicamente
    TargetPart           = "Torso",
    HorizontalPredictFactor = 2.8,  -- fator de predição horizontal (configurável)
}

-- Estado e cache próprio
local VeilState = {
    chargingSpear    = false,
    touchInput       = nil,
    attackCooldown   = false,
    passiveCooldown  = false,
    remoteHooked     = false,
    lastPredictedPos = nil,   -- para o tracer
}

-- Cache de velocidade exclusivo do Veil
local VeilVelocityCache = {}

-- Desenhos
local VeilDraw = {
    FOVCircle = Drawing.new("Circle"),
    Highlight = Instance.new("Highlight"),
    Tracer    = Drawing.new("Circle"),
}

VeilDraw.FOVCircle.Color     = Color3.fromRGB(255, 0, 255)
VeilDraw.FOVCircle.Thickness = 1.5
VeilDraw.FOVCircle.Filled    = false
VeilDraw.FOVCircle.Visible   = false

VeilDraw.Highlight.Name                = "VD_VeilTarget"
VeilDraw.Highlight.FillColor           = Color3.fromRGB(255, 0, 0)
VeilDraw.Highlight.OutlineColor        = Color3.fromRGB(255, 255, 255)
VeilDraw.Highlight.FillTransparency    = 0.5
VeilDraw.Highlight.OutlineTransparency = 0

VeilDraw.Tracer.Thickness = 2
VeilDraw.Tracer.Radius    = 5
VeilDraw.Tracer.Color     = Color3.fromRGB(255, 0, 255)
VeilDraw.Tracer.Filled    = true
VeilDraw.Tracer.Visible   = false

-- Funções auxiliares LOCAIS (cache de velocidade)

local function Veil_GetRealVelocity(part, playerName)
    if not part then return Vector3.zero end
    local currentPos = part.Position
    local currentTime = tick()
    if not VeilVelocityCache[playerName] then
        VeilVelocityCache[playerName] = {lastPos = currentPos, lastTime = currentTime, velocity = Vector3.zero}
        return Vector3.zero
    end
    local cache = VeilVelocityCache[playerName]
    local dt = currentTime - cache.lastTime
    if dt > 0.01 then
        local rawVelocity = (currentPos - cache.lastPos) / dt
        if rawVelocity.Magnitude < 100 then
            cache.velocity = cache.velocity:Lerp(rawVelocity, 0.4)
        end
    end
    cache.lastPos = currentPos
    cache.lastTime = currentTime
    return cache.velocity
end

-- Funções principais do Veil

local function veil_getTargetPart(char)
    if VeilConfig.TargetPart == "Head" then
        return char:FindFirstChild("Head")
    elseif VeilConfig.TargetPart == "Root" then
        return char:FindFirstChild("HumanoidRootPart")
    else
        return char:FindFirstChild("Torso")
            or char:FindFirstChild("UpperTorso")
            or char:FindFirstChild("HumanoidRootPart")
    end
end

local function veil_getClosestSurvivor()
    local myChar = LocalPlayer.Character
    local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
    if not myRoot then return nil end
    local cam      = workspace.CurrentCamera
    local center   = Vector2.new(cam.ViewportSize.X / 2, cam.ViewportSize.Y / 2)
    local bestDist = VeilConfig.FOV
    local bestTarget = nil  -- {Player, Part}

    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and p.Team and p.Team.Name == "Survivors" and p.Character then
            local char = p.Character
            local hum  = char:FindFirstChildOfClass("Humanoid")
            local part = veil_getTargetPart(char)
            if hum and hum.Health > 0 and part then
                local dist3D = (part.Position - myRoot.Position).Magnitude
                if dist3D <= VeilConfig.MaxDist then
                    local screenPos, onScreen = cam:WorldToViewportPoint(part.Position)
                    if onScreen then
                        local dist2D = (Vector2.new(screenPos.X, screenPos.Y) - center).Magnitude
                        if dist2D < bestDist then
                            bestDist   = dist2D
                            bestTarget = { Player = p, Part = part }
                        end
                    end
                end
            end
        end
    end
    return bestTarget
end

-- Interceptor para evitar que o jogo chame o remote (já existente)
local function veil_setupInterceptor()
    if VeilState.remoteHooked then return end
    task.spawn(function()
        pcall(function()
            local oldNamecall
            oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
                if getnamecallmethod() == "FireServer" and not checkcaller() then
                    if self.Name == "Spearthrow" and VeilConfig.Enabled then
                        return nil
                    end
                end
                return oldNamecall(self, ...)
            end)
            VeilState.remoteHooked = true
        end)
    end)
end
veil_setupInterceptor()

-- Função de disparo com predição horizontal simples + gravidade
local function veil_fire()
    if VeilState.attackCooldown then return end
    VeilState.attackCooldown = true
    task.delay(2, function() VeilState.attackCooldown = false end)

    local myChar    = LocalPlayer.Character
    local startPart = myChar and (myChar:FindFirstChild("Head") or myChar:FindFirstChild("HumanoidRootPart"))
    if not startPart then return end

    local startPos   = startPart.Position
    local targetInfo = veil_getClosestSurvivor()
    local aimDir

    if targetInfo and targetInfo.Part then
        local targetPart = targetInfo.Part
        local targetPlayer = targetInfo.Player
        local targetPos = targetPart.Position

        -- Velocidade real do alvo (horizontal)
        local velocity = Veil_GetRealVelocity(targetPart, targetPlayer.Name)
        local horizontalVel = Vector3.new(velocity.X, 0, velocity.Z)
        local speed = horizontalVel.Magnitude

        local distance = (targetPos - startPos).Magnitude
        local timeToHit = distance / VeilConfig.SpearSpeed

        -- PREDIÇÃO HORIZONTAL SIMPLES (baseada APENAS na velocidade)
        -- Se speed > 4, aplica o fator configurável.
        local horizontalPrediction = Vector3.zero
        if speed > 4 then
            local factor = VeilConfig.HorizontalPredictFactor
            horizontalPrediction = horizontalVel.Unit * factor
        end
        local predictedPos = targetPos + horizontalPrediction

        -- Queda gravitacional (lógica original do Veil)
        local distMult = math.clamp(distance / 100, 1, 2.5)
        local autoGravity = math.max(0, distance - 8)
        local gravity = VeilConfig.AutoPredict and autoGravity or VeilConfig.Gravity
        local drop = 0.5 * gravity * (timeToHit ^ 2) * distMult
        local finalPos = predictedPos + Vector3.new(0, drop, 0)

        aimDir = (finalPos - startPos).Unit
        VeilState.lastPredictedPos = finalPos
    else
        aimDir = workspace.CurrentCamera.CFrame.LookVector
        VeilState.lastPredictedPos = nil
    end

    pcall(function()
        local remotes = ReplicatedStorage:FindFirstChild("Remotes")
        if remotes then
            local killers = remotes:FindFirstChild("Killers")
            if killers then
                local veil = killers:FindFirstChild("Veil")
                if veil and veil:FindFirstChild("Spearthrow") then
                    veil.Spearthrow:FireServer(aimDir, VeilConfig.SpearSpeed, startPos)
                end
            end
        end
    end)

    VeilDraw.FOVCircle.Color = Color3.fromRGB(255, 0, 255)
    if not VeilState.passiveCooldown then
        VeilState.passiveCooldown = true
        task.delay(30, function()
            VeilDraw.FOVCircle.Color = Color3.fromRGB(255, 0, 255)
            VeilState.passiveCooldown = false
        end)
    end
end

-- Eventos de input (charge da lança)
UserInputService.InputBegan:Connect(function(input, gp)
    local isTouch = input.UserInputType == Enum.UserInputType.Touch
    if gp and not isTouch then return end
    local char = LocalPlayer.Character
    local isSpearMode = char and char:GetAttribute("spearmode") == true
    if not VeilConfig.Enabled then return end
    if not isSpearMode then return end
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        VeilState.chargingSpear = true
    elseif isTouch then
        local pGui = LocalPlayer:FindFirstChild("PlayerGui")
        if pGui then
            local slasher = pGui:FindFirstChild("Slasher-mob")
            if slasher then
                local ctrl = slasher:FindFirstChild("Controls")
                if ctrl then
                    local attackBtn = ctrl:FindFirstChild("attack")
                    if attackBtn and attackBtn.Visible then
                        local pos     = input.Position
                        local absPos  = attackBtn.AbsolutePosition
                        local absSize = attackBtn.AbsoluteSize
                        if pos.X >= absPos.X and pos.X <= absPos.X + absSize.X
                        and pos.Y >= absPos.Y and pos.Y <= absPos.Y + absSize.Y then
                            VeilState.chargingSpear = true
                            VeilState.touchInput    = input
                        end
                    end
                end
            end
        end
    end
end)

UserInputService.InputEnded:Connect(function(input, gp)
    if VeilState.chargingSpear
    and (input == VeilState.touchInput or input.UserInputType == Enum.UserInputType.MouseButton1) then
        VeilState.chargingSpear = false
        if VeilState.touchInput == input then VeilState.touchInput = nil end
        veil_fire()
    end
end)

-- Render loop: FOV, Highlight, Tracer
RunService.RenderStepped:Connect(function()
    local cam         = workspace.CurrentCamera
    local myChar      = LocalPlayer.Character
    local isSpearMode = myChar and myChar:GetAttribute("spearmode") == true

    -- FOV Circle
    if VeilConfig.Enabled and VeilConfig.ShowFOV and isSpearMode then
        VeilDraw.FOVCircle.Visible  = true
        VeilDraw.FOVCircle.Radius   = VeilConfig.FOV
        VeilDraw.FOVCircle.Position = Vector2.new(cam.ViewportSize.X / 2, cam.ViewportSize.Y / 2)
    else
        VeilDraw.FOVCircle.Visible = false
    end

    -- Highlight do alvo (enquanto carregando)
    if VeilState.chargingSpear and VeilConfig.Enabled and isSpearMode then
        local target = veil_getClosestSurvivor()
        if target and target.Part and target.Part.Parent then
            VeilDraw.Highlight.Parent = target.Part.Parent
        else
            VeilDraw.Highlight.Parent = nil
        end
    else
        VeilDraw.Highlight.Parent = nil
    end

    -- TRACER: sempre visível na tela (se houver predição)
    if VeilConfig.Enabled and isSpearMode and VeilState.lastPredictedPos then
        local screenPos, onScreen = cam:WorldToViewportPoint(VeilState.lastPredictedPos)
        local viewport = cam.ViewportSize
        local center = Vector2.new(viewport.X / 2, viewport.Y / 2)

        if onScreen then
            -- Dentro da tela: posição real
            VeilDraw.Tracer.Position = Vector2.new(screenPos.X, screenPos.Y)
        else
            -- Fora da tela: posiciona na borda na direção do ponto
            local dx = screenPos.X - center.X
            local dy = screenPos.Y - center.Y
            -- Se estiver exatamente no centro (improvável), coloca no centro
            if math.abs(dx) < 1 and math.abs(dy) < 1 then
                VeilDraw.Tracer.Position = center
            else
                local angle = math.atan2(dy, dx)
                local maxX = viewport.X / 2 - 10  -- margem de 10px
                local maxY = viewport.Y / 2 - 10
                -- Calcula o fator de escala para atingir a borda
                local scaleX = maxX / math.abs(dx)
                local scaleY = maxY / math.abs(dy)
                local scale = math.min(scaleX, scaleY)
                local borderPos = Vector2.new(
                    center.X + dx * scale,
                    center.Y + dy * scale
                )
                VeilDraw.Tracer.Position = borderPos
            end
        end
        VeilDraw.Tracer.Visible = true
    else
        VeilDraw.Tracer.Visible = false
    end
end)


RunService:BindToRenderStep("MitHubFOV", Enum.RenderPriority.Camera.Value + 1, function()
    if Extras.fovEnabled and workspace.CurrentCamera then
        workspace.CurrentCamera.FieldOfView = Extras.fovValue
    end
end)

local Connections = {
    selectedHealTarget = nil,
    healConnection = nil,
    healOthersConnection = nil,
    autoDodgeConnection = nil,
    autoHealAllConnection = nil,
}
local skillCheckHooked = false
local skillCheckOld = nil
local skillCheckMt = nil

local ESP = {
    PlayerESP = { Objects = {}, Connections = {} },
    GeneratorESP = { Objects = {}, Connections = {} },
    PalletESP = { Objects = {}, Connections = {} },
    WindowESP = { Objects = {}, Connections = {} },
    scpESP = { Objects = {}, Connections = {} },
}

local SilentAimEnabled = false
local ShootToggleEnabled = false
local SilentAimKey = Enum.KeyCode.H
local ShootToggleKey = Enum.KeyCode.Unknown
local FOV_RADIUS = 150
local SilentTargetMode = "All"
local MobileShootEnabled = false
local MobileShootLocked = false
local currentTarget = nil
local velocityCache = {}
local listeningForSilentKey = false
local listeningForShootKey = false

local fovCircle = Drawing.new("Circle")
fovCircle.Filled = false
fovCircle.NumSides = 100
fovCircle.Thickness = 1.5
fovCircle.Color = Color3.fromRGB(255, 255, 255)
fovCircle.Visible = false

-- ============================================================
-- AiiSigma V1.0 — UI menggunakan Fluent Library
-- Premium Dark Theme, mobile-friendly, robust
-- ============================================================

local Fluent = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/default.lua"))()

local SaveManager
local InterfaceManager
pcall(function()
    SaveManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/SaveManager.lua"))()
    InterfaceManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/InterfaceManager.lua"))()
end)

-- Tema warna per fitur (untuk accent)
local THEME = {
    MAIN     = Color3.fromRGB(148, 163, 184),
    ESP      = Color3.fromRGB(96, 165, 250),
    MISC     = Color3.fromRGB(52, 211, 153),
    SPEED    = Color3.fromRGB(251, 191, 36),
    COMBAT   = Color3.fromRGB(248, 113, 113),
    KILLER   = Color3.fromRGB(220, 38, 38),
    PARRY    = Color3.fromRGB(167, 139, 250),
    MOONWALK = Color3.fromRGB(45, 212, 191),
    VEIL     = Color3.fromRGB(244, 114, 182),
    INFO     = Color3.fromRGB(244, 114, 182),
}

-- Create Window
local Window = Fluent:CreateWindow({
    Title = "AiiSigma",
    SubTitle = "V1.0 - All-in-One Script Hub",
    TabWidth = 110,
    Size = UDim2.fromOffset(560, 480),
    Acrylic = false,
    Theme = "Dark",
    MinSize = Vector2.new(470, 380)
})

-- Set accent color (pink veil biar match tema)
pcall(function()
    Fluent:SetTheme("Dark")
    if Fluent.Options then
        Fluent.Options.AccentColor = THEME.VEIL
    end
end)

-- UI table (compatibility with old code references like UI.MainFrame.Visible)
local UI = {}
UI.MainFrame = Window
UI.MinBtn = { Visible = false }

-- ScreenGui terpisah untuk floating buttons (MobileShootBtn, MyersGrabBtn)
local AiiSigma = Instance.new("ScreenGui")
AiiSigma.Name = "AiiSigma_Floating"
AiiSigma.ResetOnSpawn = false
AiiSigma.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
if typeof(syn) == "table" and syn.protect_gui then syn.protect_gui(AiiSigma) end
AiiSigma.Parent = CoreGui

-- Page colors mapping
local PageColors = {}

-- ============================================================
-- HELPER FUNCTIONS (Fluent-based, signature-compatible)
-- ============================================================

-- CreateTab: bikin Fluent Tab
local function CreateTab(name, isDefault, color)
    local tabColor = color or THEME.MAIN
    local Tab = Window:AddTab({ Title = name, Icon = "" })
    PageColors[Tab] = tabColor
    return Tab, tabColor
end

-- AddSection: section header
local function AddSection(page, label)
    page:AddSection({ Title = label })
end

-- AddToggle: Fluent Toggle (signature sama dengan asli)
local function AddToggle(page, text, callback, color)
    return page:AddToggle({
        Title = text,
        Default = false,
        Callback = callback
    })
end

-- AddButton: Fluent Button (signature sama dengan asli)
local function AddButton(page, text, callback, color, isFullWidth)
    return page:AddButton({
        Title = text,
        Callback = callback
    })
end

-- AddInput: helper tambahan untuk TextBox-style input
local function AddInput(page, title, default, placeholder, numeric, callback)
    return page:AddInput({
        Title = title,
        Default = tostring(default),
        Placeholder = placeholder or "",
        Numeric = numeric or false,
        Callback = callback
    })
end

-- AddKeybind: helper tambahan untuk keybind
local function AddKeybind(page, title, default, callback)
    return page:AddKeybind({
        Title = title,
        Default = default or Enum.KeyCode.Unknown,
        Callback = callback
    })
end

-- AddDropdown: helper tambahan untuk dropdown
local function AddDropdown(page, title, values, default, callback)
    return page:AddDropdown({
        Title = title,
        Values = values,
        Multi = false,
        Default = default,
        Callback = callback
    })
end

-- AddParagraph: helper tambahan untuk info text
local function AddParagraph(page, title, content)
    return page:AddParagraph({
        Title = title,
        Content = content
    })
end

-- makeRow: stub, return page (untuk kompatibilitas)
local function makeRow(parent, height)
    return parent
end

-- makeLabel: stub, return dummy (tidak menampilkan apa-apa, label akan digabung dengan widget)
local function makeLabel(parent, text, xOff, w)
    return { Text = text, TextColor3 = Color3.new(), BackgroundTransparency = 1 }
end

-- makeSwitch: return dummy objects (Fluent handle toggle sendiri)
local function makeSwitch(parent)
    local dummy = {
        MouseButton1Click = { Connect = function() end },
        BackgroundColor3 = Color3.new(),
        Visible = true
    }
    return dummy, {}
end

-- animSwitch: no-op (Fluent handle animasi sendiri)
local function animSwitch(Switch, Dot, state)
    -- no-op
end

-- makeMwSlider: Fluent Slider
local function makeMwSlider(parent, labelText, key, minVal, maxVal, decimals, MwCfg)
    parent:AddSlider({
        Title = labelText,
        Default = MwCfg[key],
        Min = minVal,
        Max = maxVal,
        Rounding = decimals,
        Callback = function(Value)
            MwCfg[key] = Value
        end
    })
end

-- ============================================================
-- CREATE TABS (10 tabs)
-- ============================================================
local TabInfo    = CreateTab("Info",    true,  THEME.INFO)
local TabMain    = CreateTab("Main",    false, THEME.MAIN)
local TabEsp     = CreateTab("ESP",     false, THEME.ESP)
local TabMisc    = CreateTab("Misc",    false, THEME.MISC)
local TabSpeed   = CreateTab("Speed",   false, THEME.SPEED)
local TabCombat  = CreateTab("Combat",  false, THEME.COMBAT)
local TabKiller  = CreateTab("Killer",  false, THEME.KILLER)
local TabParry   = CreateTab("Parry",   false, THEME.PARRY)
local TabMoonwalk= CreateTab("Moonwalk",false, THEME.MOONWALK)
local TabVeil    = CreateTab("Veil",    false, THEME.VEIL)

-- ============================================================
-- INFO PAGE
-- ============================================================
do
    TabInfo:AddParagraph({
        Title = "AiiSigma V1.0",
        Content = "All-in-One Script Hub dengan 9 modul fitur lengkap untuk Roblox. Dirancang ringan, cepat, dan mudah dipakai. Mendukung platform PC & Mobile dengan UI elegan dan responsif."
    })

    TabInfo:AddSection({ Title = "Statistics" })
    TabInfo:AddParagraph({ Title = "Modules", Content = "9" })
    TabInfo:AddParagraph({ Title = "Features", Content = "50+" })
    TabInfo:AddParagraph({ Title = "Version", Content = "V1.0" })
    TabInfo:AddParagraph({ Title = "Platform", Content = "PC & Mobile" })

    TabInfo:AddSection({ Title = "Creator" })
    TabInfo:AddParagraph({ Title = "AiiSigma", Content = "Developer & Designer\nStatus: Verified ✓" })

    TabInfo:AddSection({ Title = "Credits" })
    TabInfo:AddParagraph({ Title = "Script", Content = "AiiSigma" })
    TabInfo:AddParagraph({ Title = "UI/UX", Content = "AiiSigma" })
    TabInfo:AddParagraph({ Title = "Testing", Content = "Community" })
    TabInfo:AddParagraph({ Title = "Released", Content = "2025" })

    TabInfo:AddParagraph({
        Title = "",
        Content = "Thank you for using AiiSigma 💜"
    })
end

-- ============================================================
-- END OF UI CREATION — Feature calls continue below
-- ============================================================

local function getHrp() return LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") end
local function getHum() return LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid") end
local function alive(i) return i and i.Parent end
local function validPart(p) return p and p:IsA("BasePart") and alive(p) end
local function studs(a, b) return math.floor((a - b).Magnitude) end

local function getNearestGenerator()
        local myHRP = getHrp()
        if not myHRP or not workspace:FindFirstChild("Map") then return nil, nil end
        local nearest, nearestPoint, nearestDist = nil, nil, math.huge
        for _, gen in ipairs(workspace.Map:GetDescendants()) do
                if gen:IsA("Model") and gen.Name == "Generator" then
                        local genPart = gen:FindFirstChild("HitBox", true) or gen.PrimaryPart or gen:FindFirstChildWhichIsA("BasePart")
                        if genPart then
                                local dist = (genPart.Position - myHRP.Position).Magnitude
                                if dist < nearestDist then
                                        local point = gen:FindFirstChild("GeneratorPoint1") or gen:FindFirstChild("GeneratorPoint2") or gen:FindFirstChildWhichIsA("BasePart")
                                        if point then
                                                nearest = gen
                                                nearestPoint = point
                                                nearestDist = dist
                                        end
                                end
                        end
                end
        end
        return nearest, nearestPoint
end

local function makeBillboard(part, sizeY, espTable)
        local existing = part:FindFirstChild("ESP_Billboard")
        if existing then return existing.TextLabel end
        local bb = Instance.new("BillboardGui")
        bb.Name = "ESP_Billboard"
        bb.Adornee = part
        bb.Size = UDim2.new(0, 150, 0, sizeY or 18)
        bb.StudsOffset = Vector3.new(0, 2.5, 0)
        bb.AlwaysOnTop = true
        bb.MaxDistance = 300
        local tl = Instance.new("TextLabel")
        tl.Name = "TextLabel"
        tl.Size = UDim2.new(1, 0, 1, 0)
        tl.BackgroundTransparency = 1
        tl.TextStrokeTransparency = 0.3
        tl.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
        tl.Font = Enum.Font.GothamSemibold
        tl.TextSize = 11
        tl.Parent = bb
        bb.Parent = part
        if espTable then table.insert(espTable, bb) end
        return tl
end

local function createHighlight(obj, color, espTable)
        local existing = obj:FindFirstChild("ESP_Highlight")
        if existing then existing.FillColor = color; return existing end
        local highlight = Instance.new("Highlight")
        highlight.Name = "ESP_Highlight"
        highlight.Adornee = obj
        highlight.FillColor = color
        highlight.FillTransparency = 0.5
        highlight.OutlineColor = color
        highlight.OutlineTransparency = 0
        highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        highlight.Parent = obj
        if espTable then table.insert(espTable, highlight) end
        return highlight
end

local function doSelfHeal()
        local char = LocalPlayer.Character
        if not char then return end
        local skillCheckRemote = ReplicatedStorage.Remotes.Healing.SkillCheckResultEvent
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if not hrp then return end
        pcall(function() skillCheckRemote:FireServer("success", 100, char) end)
end

local function doSelfHealTrue()
        local char = LocalPlayer.Character
        if not char then return end
        local healRemote = ReplicatedStorage.Remotes.Healing.HealEvent
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if not hrp then return end
        pcall(function() healRemote:FireServer(hrp, true) end)
end

local function doSelfHealFalse()
        local char = LocalPlayer.Character
        if not char then return end
        local healRemote = ReplicatedStorage.Remotes.Healing.HealEvent
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if not hrp then return end
        pcall(function() healRemote:FireServer(hrp, false) end)
end

local function doOthersHealSkillCheck(targetPlayer)
        if not targetPlayer or not targetPlayer.Character then return end
        local skillCheckRemote = ReplicatedStorage.Remotes.Healing.SkillCheckResultEvent
        pcall(function() skillCheckRemote:FireServer("success", 100, targetPlayer.Character) end)
end

local function doOthersHealTrue(targetPlayer)
        if not targetPlayer or not targetPlayer.Character then return end
        local targetHRP = targetPlayer.Character:FindFirstChild("HumanoidRootPart")
        if not targetHRP then return end
        local healRemote = ReplicatedStorage.Remotes.Healing.HealEvent
        pcall(function() healRemote:FireServer(targetHRP, true) end)
end

local function doOthersHealFalse(targetPlayer)
        if not targetPlayer or not targetPlayer.Character then return end
        local targetHRP = targetPlayer.Character:FindFirstChild("HumanoidRootPart")
        if not targetHRP then return end
        local healRemote = ReplicatedStorage.Remotes.Healing.HealEvent
        pcall(function() healRemote:FireServer(targetHRP, false) end)
end
AddToggle(TabMain, "Noclip", function(v)
        States.Noclip = v
        if v then
                _G.NLoop = RunService.Stepped:Connect(function()
                        if LocalPlayer.Character then
                                for _, part in pairs(LocalPlayer.Character:GetDescendants()) do
                                        if part:IsA("BasePart") then part.CanCollide = false end
                                end
                        end
                end)
        else
                if _G.NLoop then _G.NLoop:Disconnect() end
        end
end)

AddButton(TabMain, "FullBright", function()
        Lighting.Brightness = 2
        Lighting.ClockTime = 14
        Lighting.FogEnd = 100000
        Lighting.GlobalShadows = false
end)

AddButton(TabMain, "NoFog", function()
        Lighting.FogStart = 0
        Lighting.FogEnd = 999999
end)

AddToggle(TabMain, "Anti Fall Damage", function(v)
    Extras.antiFallEnabled = v
end)

AddToggle(TabMain, "Fast Animations", function(v)
    Extras.fastAnimEnabled = v
end)

AddInput(TabMain, "Fast Animations Speed", tostring(Extras.fastAnimSpeed), "2-10", true, function(val)
    local v = tonumber(val)
    if v then
        Extras.fastAnimSpeed = math.clamp(v, 2, 10)
    end
end)

local survivorColor = Color3.fromRGB(0, 255, 0)
local killerColor = Color3.fromRGB(255, 60, 60)
local genColor = Color3.fromRGB(0, 170, 255)
local palletColor = Color3.fromRGB(255, 140, 0)
local windowColor = Color3.fromRGB(200, 200, 200)

AddToggle(TabEsp, "Players ESP", function(v)
        States.PlayerESP = v
        if not v then
                for _, obj in pairs(ESP.PlayerESP.Objects) do pcall(function() obj:Destroy() end) end
                ESP.PlayerESP.Objects = {}
                for _, conn in pairs(ESP.PlayerESP.Connections) do pcall(function() conn:Disconnect() end) end
                ESP.PlayerESP.Connections = {}
                return
        end
        local processedPlayers = {}
        local function setupPlayer(player)
                if player == LocalPlayer then return end
                if processedPlayers[player] then return end
                processedPlayers[player] = true
                local function bind(char)
                        if not char then return end
                        local hrp = char:WaitForChild("HumanoidRootPart", 10)
                        local head = char:WaitForChild("Head", 10)
                        local hum = char:WaitForChild("Humanoid", 10)
                        if not validPart(hrp) or not validPart(head) or not hum then return end
                        local label = makeBillboard(head, 18, ESP.PlayerESP.Objects)
                        local highlight = nil
                        local conn = RunService.Heartbeat:Connect(function()
                                if not States.PlayerESP then return end
                                if not alive(char) or hum.Health <= 0 then return end
                                local myHRP = getHrp()
                                if not myHRP then return end
                                local isKiller = player.Team == Teams:FindFirstChild("Killer")
                                local color = isKiller and killerColor or survivorColor
                                label.TextColor3 = color
                                label.Text = string.format("%s [%d]", player.Name, studs(myHRP.Position, hrp.Position))
                                if isKiller then
                                        if not highlight then highlight = createHighlight(char, killerColor, ESP.PlayerESP.Objects) end
                                else
                                        if highlight then highlight:Destroy(); highlight = nil end
                                end
                        end)
                        table.insert(ESP.PlayerESP.Connections, conn)
                end
                if player.Character then bind(player.Character) end
                local charConn = player.CharacterAdded:Connect(bind)
                table.insert(ESP.PlayerESP.Connections, charConn)
        end
        for _, p in ipairs(Players:GetPlayers()) do setupPlayer(p) end
        local playerAddedConn = Players.PlayerAdded:Connect(setupPlayer)
        table.insert(ESP.PlayerESP.Connections, playerAddedConn)
end)

AddToggle(TabEsp, "Generator ESP", function(v)
        States.GeneratorESP = v
        if not v then
                for _, obj in pairs(ESP.GeneratorESP.Objects) do pcall(function() obj:Destroy() end) end
                ESP.GeneratorESP.Objects = {}
                for _, conn in pairs(ESP.GeneratorESP.Connections) do pcall(function() conn:Disconnect() end) end
                ESP.GeneratorESP.Connections = {}
                return
        end
        local processedGens = {}
        local function setupGen(gen)
                if not gen:IsA("Model") or gen.Name ~= "Generator" then return end
                if processedGens[gen] then return end
                processedGens[gen] = true
                local part = gen:FindFirstChild("HitBox", true) or gen.PrimaryPart or gen:FindFirstChildWhichIsA("BasePart", true)
                if not validPart(part) then return end
                local label = makeBillboard(part, 16, ESP.GeneratorESP.Objects)
                label.TextColor3 = genColor
                local conn = RunService.Heartbeat:Connect(function()
                        if not States.GeneratorESP or not alive(gen) then label.Text = ""; return end
                        local myHRP = getHrp()
                        if not myHRP then return end
                        local repairAttr = gen:GetAttribute("RepairProgress")
                        local stateAttr = gen:GetAttribute("State")
                        local pct = 0
                        if repairAttr then pct = tonumber(repairAttr) or 0; if pct <= 1 then pct = pct * 100 end end
                        local status = stateAttr == "0" and "0" or stateAttr == "2" and "2" or pct >= 100 and "3" or "1"
                        label.Text = string.format("GEN %.0f%% [%s] %ds", math.clamp(pct, 0, 100), status, studs(myHRP.Position, part.Position))
                end)
                table.insert(ESP.GeneratorESP.Connections, conn)
        end
        if workspace:FindFirstChild("Map") then
                for _, o in ipairs(workspace.Map:GetDescendants()) do setupGen(o) end
                local conn = workspace.Map.DescendantAdded:Connect(setupGen)
                table.insert(ESP.GeneratorESP.Connections, conn)
        end
end)

AddToggle(TabEsp, "Pallets ESP", function(v)
        States.PalletESP = v
        if not v then
                for _, obj in pairs(ESP.PalletESP.Objects) do pcall(function() obj:Destroy() end) end
                ESP.PalletESP.Objects = {}
                for _, conn in pairs(ESP.PalletESP.Connections) do pcall(function() conn:Disconnect() end) end
                ESP.PalletESP.Connections = {}
                return
        end
        local processed = {}
        local function handlePallet(m)
                if not m:IsA("Model") then return end
                if processed[m] then return end
                local lname = m.Name:lower()
                if not (lname:find("pallet") and not lname:find("crate")) then return end
                local part = m:FindFirstChildWhichIsA("BasePart", true)
                if not validPart(part) then return end
                processed[m] = true
                local label = makeBillboard(part, 16, ESP.PalletESP.Objects)
                label.Text = "Pallet"
                label.TextColor3 = palletColor
        end
        if workspace:FindFirstChild("Map") then
                for _, o in ipairs(workspace.Map:GetDescendants()) do handlePallet(o) end
                local conn = workspace.Map.DescendantAdded:Connect(handlePallet)
                table.insert(ESP.PalletESP.Connections, conn)
        end
end)

AddToggle(TabEsp, "Windows ESP", function(v)
        States.WindowESP = v
        if not v then
                for _, obj in pairs(ESP.WindowESP.Objects) do pcall(function() obj:Destroy() end) end
                ESP.WindowESP.Objects = {}
                for _, conn in pairs(ESP.WindowESP.Connections) do pcall(function() conn:Disconnect() end) end
                ESP.WindowESP.Connections = {}
                return
        end
        local processed = {}
        local function handleWindow(m)
                if not m:IsA("Model") then return end
                if processed[m] then return end
                if m.Name:lower() ~= "window" then return end
                local part = m:FindFirstChild("inviswall", true) or m:FindFirstChildWhichIsA("BasePart", true)
                if not validPart(part) then return end
                processed[m] = true
                local label = makeBillboard(part, 16, ESP.WindowESP.Objects)
                label.Text = "Window"
                label.TextColor3 = windowColor
        end
        if workspace:FindFirstChild("Map") then
                for _, o in ipairs(workspace.Map:GetDescendants()) do handleWindow(o) end
                local conn = workspace.Map.DescendantAdded:Connect(handleWindow)
                table.insert(ESP.WindowESP.Connections, conn)
        end
end)

AddToggle(TabEsp, "SCP ESP", function(v)
    if not v then
        for _, obj in pairs(ESP.scpESP.Objects) do pcall(function() obj:Destroy() end) end
        ESP.scpESP.Objects = {}
        for _, conn in pairs(ESP.scpESP.Connections) do pcall(function() conn:Disconnect() end) end
        ESP.scpESP.Connections = {}
        return
    end

    local function setupSCP(model)
        local hrp = model:FindFirstChild("HumanoidRootPart")
        if not hrp then return end
        local highlight = createHighlight(model, Color3.fromRGB(120, 0, 180), ESP.scpESP.Objects)
        highlight.OutlineColor = Color3.fromRGB(180, 0, 255)
        highlight.Enabled = false
        local label = makeBillboard(hrp, 16, ESP.scpESP.Objects)
        label.TextColor3 = Color3.fromRGB(200, 0, 255)
        label.Text = ""
        local activated = false
        local lastPos = hrp.Position
        local conn = RunService.Heartbeat:Connect(function()
            if not alive(model) then label.Text = "" highlight.Enabled = false return end
            local myHRP = getHrp()
            if not myHRP then return end
            local hum = model:FindFirstChildOfClass("Humanoid")
            if not hum then return end
            if not activated then
                local moved = (hrp.Position - lastPos).Magnitude
                lastPos = hrp.Position
                if moved > 0.05 then
                    activated = true
                else
                    return
                end
            end
            if hum.Health > 0 then
                label.Text = string.format("%s [%d]", model.Name, studs(myHRP.Position, hrp.Position))
                highlight.Enabled = true
            else
                label.Text = ""
                highlight.Enabled = false
            end
        end)
        table.insert(ESP.scpESP.Connections, conn)
    end

    local function scanMap()
        local map = workspace:FindFirstChild("Map")
        if not map then return end
        for _, area in ipairs(map:GetChildren()) do
            for _, child in ipairs(area:GetChildren()) do
                local name = child.Name:lower()
                if name == "scp" or name:match("^scp%d$") then
                    setupSCP(child)
                end
            end
        end
    end

    scanMap()

    local conn = workspace.DescendantAdded:Connect(function(obj)
        if obj:IsA("Model") then
            local name = obj.Name:lower()
            if name == "scp" or name:match("^scp%d$") then
                task.wait(0.2)
                setupSCP(obj)
            end
        end
    end)
    table.insert(ESP.scpESP.Connections, conn)
end)

local function getLever()
    local map = workspace:FindFirstChild("Map")
    if not map then return nil end
    if map:FindFirstChild("Rooftop") then
        local rooftopLever = map.Rooftop:FindFirstChild("Gate")
        if rooftopLever and rooftopLever:FindFirstChild("ExitLever") then
            return rooftopLever.ExitLever:FindFirstChild("Main")
        end
    end
    local normalGate = map:FindFirstChild("Gate")
    if normalGate and normalGate:FindFirstChild("ExitLever") then
        return normalGate.ExitLever:FindFirstChild("Main")
    end
    return nil
end

local function fireLever(state)
    local lever = getLever()
    if lever then
        pcall(function()
            ReplicatedStorage.Remotes.Exit.LeverEvent:FireServer(lever, state)
        end)
    end
end

AddToggle(TabMisc, "Instant Heal (Self)", function(v)
        States.InstantHeal = v
        if v then
                local skillCheckTimer = 0
                local healTrueTimer = 0
                local healFalseTimer = 0
                local healTrueActive = false
                Connections.healConnection = RunService.Heartbeat:Connect(function(dt)
                        if not States.InstantHeal then return end
                        local myHum = getHum()
                        if not myHum or myHum.Health >= myHum.MaxHealth * 0.9 then return end
                        skillCheckTimer = skillCheckTimer + dt
                        if skillCheckTimer >= 0.05 then skillCheckTimer = 0; doSelfHeal() end
                        healTrueTimer = healTrueTimer + dt
                        if healTrueTimer >= 0.06 and not healTrueActive then
                                healTrueTimer = 0; healTrueActive = true; doSelfHealTrue()
                        end
                        healFalseTimer = healFalseTimer + dt
                        if healFalseTimer >= 0.09 and healTrueActive then
                                healFalseTimer = 0; healTrueActive = false; doSelfHealFalse(); healTrueTimer = -0.10
                        end
                end)
        else
                if Connections.healConnection then Connections.healConnection:Disconnect(); Connections.healConnection = nil end
        end
end)

-- Heal Others: pakai Fluent Dropdown untuk pilih player
local healOthersDropdown = AddDropdown(TabMisc, "Instant Heal Others (Select Player)", {}, "OFF", function(selected)
    if selected == "OFF" then
        States.InstantHealOthers = false
        Connections.selectedHealTarget = nil
        if Connections.healOthersConnection then Connections.healOthersConnection:Disconnect(); Connections.healOthersConnection = nil end
    else
        local target = Players:FindFirstChild(selected)
        if target then
            Connections.selectedHealTarget = target
            States.InstantHealOthers = true
            if Connections.healOthersConnection then Connections.healOthersConnection:Disconnect() end
            local skillCheckTimer = 0
            local healTrueTimer = 0
            local healFalseTimer = 0
            local healTrueActive = false
            Connections.healOthersConnection = RunService.Heartbeat:Connect(function(dt)
                if not States.InstantHealOthers or not Connections.selectedHealTarget then return end
                local targetChar = Connections.selectedHealTarget.Character
                local targetHum = targetChar and targetChar:FindFirstChildOfClass("Humanoid")
                if not targetHum or targetHum.Health >= targetHum.MaxHealth * 0.9 then return end
                skillCheckTimer = skillCheckTimer + dt
                if skillCheckTimer >= 0.05 then skillCheckTimer = 0; doOthersHealSkillCheck(Connections.selectedHealTarget) end
                healTrueTimer = healTrueTimer + dt
                if healTrueTimer >= 0.09 and not healTrueActive then
                    healTrueTimer = 0; healTrueActive = true; doOthersHealTrue(Connections.selectedHealTarget)
                end
                healFalseTimer = healFalseTimer + dt
                if healFalseTimer >= 0.07 and healTrueActive then
                    healFalseTimer = 0; healTrueActive = false; doOthersHealFalse(Connections.selectedHealTarget); healTrueTimer = -0.10
                end
            end)
        end
    end
end)

-- Update dropdown dengan daftar player
task.spawn(function()
    while true do
        task.wait(2)
        local players = { "OFF" }
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= LocalPlayer then table.insert(players, player.Name) end
        end
        pcall(function()
            healOthersDropdown:SetValues(players)
        end)
    end
end)

AddToggle(TabMisc, "Auto Heal All heh)", function(v)
        States.AutoHealAll = v
        if v then
                local timers = {}
                Connections.autoHealAllConnection = RunService.Heartbeat:Connect(function(dt)
                        if not States.AutoHealAll then return end
                        for _, player in ipairs(Players:GetPlayers()) do
                                if player ~= LocalPlayer and player.Character then
                                        local hum = player.Character:FindFirstChildOfClass("Humanoid")
                                        if hum and hum.Health > 0 and hum.Health < hum.MaxHealth * 0.9 then
                                                if not timers[player] then
                                                        timers[player] = {sc = 0, t = 0, f = 0, active = false}
                                                end
                                                local tm = timers[player]
                                                tm.sc = tm.sc + dt
                                                if tm.sc >= 0.05 then tm.sc = 0; doOthersHealSkillCheck(player) end
                                                tm.t = tm.t + dt
                                                if tm.t >= 0.09 and not tm.active then
                                                        tm.t = 0; tm.active = true; doOthersHealTrue(player)
                                                end
                                                tm.f = tm.f + dt
                                                if tm.f >= 0.07 and tm.active then
                                                        tm.f = 0; tm.active = false; doOthersHealFalse(player); tm.t = -0.10
                                                end
                                        else
                                                timers[player] = nil
                                        end
                                end
                        end
                end)
        else
                if Connections.autoHealAllConnection then Connections.autoHealAllConnection:Disconnect(); Connections.autoHealAllConnection = nil end
        end
end)

do -- Gen Fast Bypass toggle (Fluent: Keybind + Toggle)
    AddKeybind(TabMisc, "Gen Fast Bypass Key", Enum.KeyCode.G, function(key)
        GenBypass.HotkeyCode = key
    end)

    AddToggle(TabMisc, "Gen Fast Bypass", function(v)
        GenBypass.Enabled = v
        GB_UpdateButton()
    end)
end -- fim Gen Fast Bypass toggle

AddToggle(TabMisc, "Auto Generator", function(v)
    Extras.autoGeneratorEnabled = v
end)

AddToggle(TabMisc, "Generator Boost", function(v)
    Extras.genBoostEnabled = v
    if v then
        task.spawn(function()
            while Extras.genBoostEnabled do
                pcall(function()
                    ReplicatedStorage.Remotes.Perks.perfectionistplanning:FireServer("applyBoost", "fast")
                end)
                task.wait(0.2)
            end
        end)
    end
end)

AddToggle(TabMisc, "Instant Skillcheck", function(v)
    Extras.instantSkillcheckEnabled = v
    if not v then
        Extras.instantSkillcheckMode = false
        if ISC.RotationConnection then
            ISC.RotationConnection:Disconnect()
            ISC.RotationConnection = nil
        end
        ISC.HasClicked       = false
        ISC.LastGoalInstance = nil
        ISC.CurrentGoalID    = 0
    end
end)

AddToggle(TabMisc, "Auto Dodge", function(v)
    States.AutoDodge = v
    if v then
        task.spawn(function()
            while States.AutoDodge do
                pcall(function()
                    ReplicatedStorage.Remotes.Mechanics.ChangeAttribute:FireServer("Crouchingserver", true)
                end)
                task.wait(0.20)
            end
        end)
    end
end)

AddToggle(TabMisc, "Auto Lever", function(v)
    States.AutoLever = v
    if v then
        fireLever(true)
        task.spawn(function()
            while States.AutoLever do
                fireLever(true)
                task.wait(0.5)
            end
        end)
    else
        fireLever(false)
    end
end)

local function keyCodeName(kc)
        if kc == Enum.KeyCode.Unknown then return "---" end
        return tostring(kc):gsub("Enum.KeyCode.", "")
end


AddButton(TabSpeed, "Speed keybind (R)", function()
        pcall(function()
                loadstring(game:HttpGet("https://raw.githubusercontent.com/graveszzx/scripts/refs/heads/main/Speedv2"))()
        end)
end)

AddInput(TabSpeed, "NoSlowdown Speed", tostring(Extras.CustomSpeed), "1-100", true, function(val)
    local v = tonumber(val)
    if v and v > 0 and v <= 100 then
        Extras.CustomSpeed = v
    end
end)

AddToggle(TabSpeed, "NoSlowdown", function(v)
    Extras.NoSlowdown = v
end)

-- Main: FOV Changer (toggle + input)
AddInput(TabMain, "FOV Value", tostring(Extras.fovValue), "50-150", true, function(val)
    local v = tonumber(val)
    if v then
        Extras.fovValue = math.clamp(math.floor(v), 50, 150)
    end
end)

AddToggle(TabMain, "FOV Changer", function(v)
    Extras.fovEnabled = v
    if not v and workspace.CurrentCamera then
        workspace.CurrentCamera.FieldOfView = 70
    end
end)

-- ============================================================
-- COMBAT HELPER FUNCTIONS
-- ============================================================
local function getRealVelocity(hrp, playerName)
        if not hrp then return Vector3.zero end
        local currentPos = hrp.Position
        local currentTime = tick()
        if not velocityCache[playerName] then
                velocityCache[playerName] = {lastPos = currentPos, lastTime = currentTime, velocity = Vector3.zero}
                return Vector3.zero
        end
        local cache = velocityCache[playerName]
        local dt = currentTime - cache.lastTime
        if dt > 0.01 then
                local rawVelocity = (currentPos - cache.lastPos) / dt
                if rawVelocity.Magnitude < 100 then
                        cache.velocity = cache.velocity:Lerp(rawVelocity, 0.4)
                end
        end
        cache.lastPos = currentPos
        cache.lastTime = currentTime
        return cache.velocity
end

local function getGunParts()
        local char = LocalPlayer.Character
        if not char then return nil, nil end
        local tool = char:FindFirstChild("Twist of Fate")
        if not tool then return nil, nil end
        local rightArm = tool:FindFirstChild("Right Arm")
        if not rightArm then return nil, nil end
        local gun = rightArm:FindFirstChild("EmperorGun") or rightArm:FindFirstChild("gun")
        if not gun then return nil, nil end
        local gunPart = gun:FindFirstChildWhichIsA("BasePart")
        if not gunPart then return nil, nil end
        return gun, gunPart
end

local function getMyHRP()
        local char = LocalPlayer.Character
        if not char then return nil end
        return char:FindFirstChild("HumanoidRootPart")
end

local function doLookAt(targetPos)
        local myHRP = getMyHRP()
        if not myHRP then return end
        myHRP.CFrame = CFrame.new(myHRP.Position, Vector3.new(targetPos.X, myHRP.Position.Y, targetPos.Z))
end

local function getAutoPrediction(speed, distance)
        if speed < 4 then return 0 end
        if distance < 10 then return 0 end
        if distance <= 20 then return 2.80 end
        return 3.60
end

local function getPredictedPosition(target)
        local hrp = target.Part
        local player = target.Player
        if not hrp then return target.Position, target.Position, 0, 0 end
        local velocity = getRealVelocity(hrp, player.Name)
        local horizontalVel = Vector3.new(velocity.X, 0, velocity.Z)
        local speed = horizontalVel.Magnitude
        local myHRP = getMyHRP()
        local distance = myHRP and (hrp.Position - myHRP.Position).Magnitude or 50
        local targetPos = hrp.Position
        local predValue = getAutoPrediction(speed, distance)
        local horizontalPrediction = Vector3.zero
        if speed > 4 and predValue > 0 then
                horizontalPrediction = horizontalVel.Unit * predValue
        end
        local predictedPos = targetPos + horizontalPrediction
        return targetPos, predictedPos, speed, distance
end

local function fireHitscan(targetPos)
        local gun, gunPart = getGunParts()
        if not gun or not gunPart then return false end
        local fireRemote = ReplicatedStorage:FindFirstChild("Remotes")
        if fireRemote then
                fireRemote = fireRemote:FindFirstChild("Items")
                if fireRemote then
                        fireRemote = fireRemote:FindFirstChild("Twist of Fate")
                        if fireRemote then
                                fireRemote = fireRemote:FindFirstChild("Fire")
                        end
                end
        end
        if not fireRemote then return false end
        local myHRP = getMyHRP()
        if not myHRP then return false end
        local origin = myHRP.Position + Vector3.new(0, 1.2, 0)
        local direction = (targetPos - origin).Unit
        pcall(function()
                fireRemote:FireServer(gun, direction)
        end)
        return true
end

local function isValidTargetForMode(player)
        if SilentTargetMode == "All" then return true end
        local isKiller = player.Team == Teams:FindFirstChild("Killer")
        if SilentTargetMode == "Killer" then return isKiller end
        if SilentTargetMode == "Survivor" then return not isKiller end
        return true
end

local function getTargetInFOV()
        local camera = workspace.CurrentCamera
        if not camera then return nil end
        local closestTarget = nil
        local closestDist = FOV_RADIUS
        local centerX = camera.ViewportSize.X / 2
        local centerY = camera.ViewportSize.Y / 2
        for _, player in ipairs(Players:GetPlayers()) do
                if player ~= LocalPlayer and player.Character and isValidTargetForMode(player) then
                        local hrp = player.Character:FindFirstChild("HumanoidRootPart")
                        local hum = player.Character:FindFirstChildOfClass("Humanoid")
                        if hrp and hum and hum.Health > 0 then
                                local screenPos, onScreen = camera:WorldToViewportPoint(hrp.Position)
                                if onScreen then
                                        local dx = screenPos.X - centerX
                                        local dy = screenPos.Y - centerY
                                        local dist = math.sqrt(dx * dx + dy * dy)
                                        if dist < closestDist then
                                                closestDist = dist
                                                closestTarget = {Player = player, Part = hrp, Position = hrp.Position, Distance = dist}
                                        end
                                end
                        end
                end
        end
        return closestTarget
end

local function doSilentAimFire()
        if not SilentAimEnabled then return end
        currentTarget = getTargetInFOV()
        if currentTarget then
                local _, predictedPos = getPredictedPosition(currentTarget)
                fireHitscan(predictedPos)
        end
end

-- ============================================================
-- COMBAT TAB
-- ============================================================
AddKeybind(TabCombat, "Silent Aim Key", Enum.KeyCode.H, function(key)
    SilentAimKey = key
end)

AddToggle(TabCombat, "Silent Aim", function(v)
    SilentAimEnabled = v
    fovCircle.Visible = v
    if MobileShootBtn then
        MobileShootBtn.Visible = v and MobileShootEnabled
    end
    if not v then
        currentTarget = nil
        velocityCache = {}
    end
end)

AddInput(TabCombat, "FOV (px)", tostring(FOV_RADIUS), "", true, function(val)
    local v = tonumber(val)
    if v and v > 0 then
        FOV_RADIUS = v
        fovCircle.Radius = FOV_RADIUS
    end
end)

AddDropdown(TabCombat, "Target Selection", {"All", "Survivor", "Killer"}, SilentTargetMode, function(selected)
    SilentTargetMode = selected
end)

AddKeybind(TabCombat, "Shoot Toggle Key", Enum.KeyCode.Unknown, function(key)
    ShootToggleKey = key
end)

AddToggle(TabCombat, "Shoot Toggle", function(v)
    ShootToggleEnabled = v
end)

-- Mobile Shoot Button (custom, tetap pakai ImageButton karena floating)
local MobileShootBtn = Instance.new("ImageButton", AiiSigma)
MobileShootBtn.Size = UDim2.new(0, 70, 0, 70)
MobileShootBtn.Position = UDim2.new(0.85, 0, 0.75, 0)
MobileShootBtn.BackgroundColor3 = Color3.fromRGB(30, 15, 40)
MobileShootBtn.BackgroundTransparency = 0.1
MobileShootBtn.Image = ""
MobileShootBtn.Visible = false
MobileShootBtn.ZIndex = 10
Instance.new("UICorner", MobileShootBtn).CornerRadius = UDim.new(1, 0)
local msBtnStroke = Instance.new("UIStroke", MobileShootBtn)
msBtnStroke.Color = Color3.fromRGB(98, 63, 117)
msBtnStroke.Thickness = 2
msBtnStroke.Transparency = 0.2

local msBtnLabel = Instance.new("TextLabel", MobileShootBtn)
msBtnLabel.Size = UDim2.new(1, 0, 1, 0)
msBtnLabel.BackgroundTransparency = 1
msBtnLabel.Text = "Shoot"
msBtnLabel.Font = Enum.Font.GothamBold
msBtnLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
msBtnLabel.TextSize = 13
msBtnLabel.ZIndex = 11

local msDragging, msDragStart, msStartPos
MobileShootBtn.InputBegan:Connect(function(input)
        if MobileShootLocked then return end
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                msDragging = true; msDragStart = input.Position; msStartPos = MobileShootBtn.Position
        end
end)
UserInputService.InputChanged:Connect(function(input)
        if MobileShootLocked then msDragging = false; return end
        if msDragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
                local delta = input.Position - msDragStart
                MobileShootBtn.Position = UDim2.new(msStartPos.X.Scale, msStartPos.X.Offset + delta.X, msStartPos.Y.Scale, msStartPos.Y.Offset + delta.Y)
        end
end)
MobileShootBtn.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then msDragging = false end
end)

MobileShootBtn.MouseButton1Click:Connect(function()
        TweenService:Create(MobileShootBtn, TweenInfo.new(0.08), {BackgroundTransparency = 0}):Play()
        task.delay(0.12, function()
                TweenService:Create(MobileShootBtn, TweenInfo.new(0.08), {BackgroundTransparency = 0.1}):Play()
        end)
        doSilentAimFire()
end)

AddToggle(TabCombat, "Mobile Shoot Button", function(v)
    MobileShootEnabled = v
    MobileShootBtn.Visible = v and SilentAimEnabled
end)

AddToggle(TabCombat, "Lock Mobile Toggle", function(v)
    MobileShootLocked = v
end)

RunService.Heartbeat:Connect(function()
        local camera = workspace.CurrentCamera
        if not camera then return end
        local screenCenter = camera.ViewportSize / 2
        fovCircle.Position = screenCenter
        fovCircle.Radius = FOV_RADIUS
        if not SilentAimEnabled then
                currentTarget = nil
                return
        end
        currentTarget = getTargetInFOV()
        if currentTarget then
                local _, predictedPos = getPredictedPosition(currentTarget)
                doLookAt(predictedPos)
        end
end)

UserInputService.InputBegan:Connect(function(input, gp)
        if gp then return end
        if input.UserInputType == Enum.UserInputType.Keyboard then
                if input.KeyCode == SilentAimKey then
                        SilentAimEnabled = not SilentAimEnabled
                        fovCircle.Visible = SilentAimEnabled
                        MobileShootBtn.Visible = SilentAimEnabled and MobileShootEnabled
                        if not SilentAimEnabled then
                                currentTarget = nil
                                velocityCache = {}
                        end
                end
                if ShootToggleEnabled and ShootToggleKey ~= Enum.KeyCode.Unknown and input.KeyCode == ShootToggleKey then
                        doSilentAimFire()
                end
        end
end)

local function setupParryFeatures()
    local daggerFolder = ReplicatedStorage.Remotes.Items:WaitForChild("Parrying Dagger")
    local ParryRemote  = daggerFolder:WaitForChild("parry")
    local ParryResult  = daggerFolder:WaitForChild("parryResult")

    local PARRY_MAX_DISTANCE              = 14
    local PARRY_LOOK_THRESHOLD            = 0.6
    local PARRY_ANIMATION_START_THRESHOLD = 0.05
    local parryEnabled    = false
    local parryShowCircle = true
    local canParry        = true
    local isParrying      = false
    local isFrozen        = false
    local waitingResult   = false
    local cooldownEndTime = 0

    local killerAnimator, killerChar, killerPlayer
    local parryConnections = {}
    local firedTracks      = {}
    local gradients        = {}

    local COLOR_READY    = Color3.fromRGB(255, 255, 255)
    local COLOR_COOLDOWN = Color3.fromRGB(77, 77, 77)

    local function addGradient(g)
        if not (g and g:IsA("UIGradient")) then return end
        for _, v in ipairs(gradients) do if v == g then return end end
        g.Offset = Vector2.new(0, 0.25)
        table.insert(gradients, g)
    end

    local function setIconsColor(color)
        for _, g in ipairs(gradients) do
            if g and g.Parent and g.Parent.Parent then
                local container = g.Parent.Parent
                local icon = container:FindFirstChild("icon")
                if icon then icon.ImageColor3 = color end
                if container.Parent then
                    local outerGui = container.Parent:FindFirstChild("Gui")
                    if outerGui then outerGui.ImageColor3 = color end
                end
            end
        end
    end

    local function refreshVisual()
        if not canParry or isParrying then
            setIconsColor(COLOR_COOLDOWN)
        else
            setIconsColor(COLOR_READY)
        end
    end

    local function playCooldownTween(duration)
        for _, g in ipairs(gradients) do
            if g and g.Parent then
                g.Offset = Vector2.new(0, 0.75)
                local tw = TweenService:Create(g, TweenInfo.new(duration, Enum.EasingStyle.Linear), { Offset = Vector2.new(0, 0.25) })
                tw:Play()
                tw.Completed:Connect(function()
                    if g.Offset.Y <= 0.26 then refreshVisual() end
                end)
            end
        end
    end

    local function bindPcGradient()
        local pg = LocalPlayer:FindFirstChildOfClass("PlayerGui")
        if not pg then return end
        local survivor = pg:FindFirstChild("Survivor") or pg:FindFirstChild("Survivor-con")
        if not survivor then return end
        local gen = survivor:FindFirstChild("Gen")
        if not gen then return end
        local itemFrame = gen:FindFirstChild("ItemFrame")
        if not itemFrame then return end
        local gui2 = itemFrame:FindFirstChild("Gui")
        if not gui2 then return end
        local bar = gui2:FindFirstChild("Bar")
        if not bar then return end
        local uig = bar:FindFirstChild("UIGradient")
        if uig then addGradient(uig) end
    end

    local function bindMobileGradient()
        local pg = LocalPlayer:FindFirstChildOfClass("PlayerGui")
        if not pg then return end
        local mob = pg:FindFirstChild("Survivor-mob")
        if not mob then return end
        local controls = mob:FindFirstChild("Controls")
        if not controls then return end
        for _, child in ipairs(controls:GetChildren()) do
            if child:IsA("ImageButton") and child.Name == "Gui-mob" then
                local bar = child:FindFirstChild("Bar")
                if bar then
                    local uig = bar:FindFirstChild("UIGradient")
                    if uig then addGradient(uig) end
                end
            end
        end
        controls.ChildAdded:Connect(function(child)
            if child:IsA("ImageButton") and child.Name == "Gui-mob" then
                local bar = child:WaitForChild("Bar", 10)
                if bar then
                    local uig = bar:WaitForChild("UIGradient", 10)
                    if uig then addGradient(uig) end
                end
            end
        end)
    end

    local function tryBindGradients()
    task.wait(0.5)
    bindPcGradient()
    bindMobileGradient()
    refreshVisual()
end

local function setupGradients()
    task.spawn(function()
        local pg = LocalPlayer:WaitForChild("PlayerGui", 10)
        if not pg then return end
        tryBindGradients()
        pg.ChildAdded:Connect(function(child)
            local n = child.Name
            if n == "Survivor" or n == "Survivor-con" or n == "Survivor-mob" then
                task.wait(0.3)
                bindPcGradient()
                bindMobileGradient()
                refreshVisual()
            end
        end)
    end)
end
setupGradients()

LocalPlayer.CharacterAdded:Connect(function()
    task.wait(0.5)
    gradients = {}
    tryBindGradients()
end)

    ParryResult.OnClientEvent:Connect(function(success, cooldownValue)
        if not waitingResult then return end
        waitingResult = false
        local cd = tonumber(cooldownValue)
        if cd and cd > 0 then
            isParrying      = false
            canParry        = false
            cooldownEndTime = tick() + cd
            playCooldownTween(cd)
            refreshVisual()
            task.delay(cd, function()
                canParry        = true
                isParrying      = false
                cooldownEndTime = 0
                refreshVisual()
            end)
        else
            canParry        = true
            isParrying      = false
            cooldownEndTime = 0
            refreshVisual()
        end
    end)

    local PARRY_ANIMS = {
        { name = "Shield",  id = "rbxassetid://75939529748815"  },
        { name = "Robot",   id = "rbxassetid://126894569253341" },
        { name = "Default", id = "rbxassetid://109133187196613" },
        { name = "Katana",  id = "rbxassetid://127096285501517" },
        { name = "Fish",    id = "rbxassetid://123307242865945" },
        { name = "Watcher", id = "rbxassetid://81793464499285"  },
    }
    local selectedAnimIndex = 4
    local ParryAnimation = Instance.new("Animation")
    ParryAnimation.AnimationId = PARRY_ANIMS[selectedAnimIndex].id

    local ATTACK_ANIMS = {
        ["rbxassetid://113255068724446"] = true,
        ["rbxassetid://74968262036854"]  = true,
        ["rbxassetid://110355011987939"] = true,
        ["rbxassetid://139369275981139"] = true,
        ["rbxassetid://132817836308238"] = true,
        ["rbxassetid://129784271201071"] = true,
        ["rbxassetid://133963973694098"] = true,
        ["rbxassetid://117042998468241"] = true,
        ["rbxassetid://105374834496520"] = true,
        ["rbxassetid://111920872708571"] = true,
        ["rbxassetid://78432063483146"]  = true,
        ["rbxassetid://118907603246885"] = true,
        ["rbxassetid://138720291317243"] = true,
        ["rbxassetid://115244153053858"] = true,
        ["rbxassetid://130593238885843"] = true,
        ["rbxassetid://122812055447896"] = true,
        ["rbxassetid://78935059863801"]  = true,
        ["rbxassetid://135002183282873"] = true,
        ["rbxassetid://121216847022485"] = true,
    }

    local rangeAdornment = Instance.new("CylinderHandleAdornment")
    rangeAdornment.Name        = "ParryRange"
    rangeAdornment.Radius      = PARRY_MAX_DISTANCE
    rangeAdornment.InnerRadius = PARRY_MAX_DISTANCE - 0.25
    rangeAdornment.Height      = 0.05
    rangeAdornment.Color3      = Color3.fromRGB(195, 155, 255)
    rangeAdornment.AlwaysOnTop = false
    rangeAdornment.Adornee     = workspace:FindFirstChildOfClass("Terrain")
    rangeAdornment.Transparency = 1
    rangeAdornment.Parent      = CoreGui

    RunService.RenderStepped:Connect(function()
        local char = LocalPlayer.Character
        if not char or not parryEnabled or not parryShowCircle then
            rangeAdornment.Transparency = 1
            return
        end
        local root = char:FindFirstChild("HumanoidRootPart")
        if not root then rangeAdornment.Transparency = 1 return end
        rangeAdornment.Transparency = 0.3
        rangeAdornment.CFrame = CFrame.new(root.Position - Vector3.new(0, 2.6, 0)) * CFrame.Angles(math.pi / 2, 0, 0)
    end)

    local cachedRoot, cachedHum

    local function parryRefreshLocalCache()
        local char = LocalPlayer.Character
        if char then
            cachedRoot = char:FindFirstChild("HumanoidRootPart")
            cachedHum  = char:FindFirstChildOfClass("Humanoid")
        end
    end

    LocalPlayer.CharacterAdded:Connect(function()
        task.wait(0.3)
        parryRefreshLocalCache()
        canParry        = true
        isParrying      = false
        waitingResult   = false
        cooldownEndTime = 0
        refreshVisual()
    end)
    parryRefreshLocalCache()

    local function playParryAnimation()
        if not cachedHum then return end
        local anim = cachedHum:LoadAnimation(ParryAnimation)
        anim:Play()
    end

    local function freezePlayer()
        if not cachedHum or isFrozen then return end
        isFrozen = true
        local originalSpeed = cachedHum.WalkSpeed > 0 and cachedHum.WalkSpeed or 16
        cachedHum.WalkSpeed = 0
        task.delay(1, function()
            isFrozen = false
            if cachedHum then cachedHum.WalkSpeed = originalSpeed end
        end)
    end

    local function killerLookingAtMe()
        if not killerChar or not cachedRoot then return true end
        local killerRoot = killerChar:FindFirstChild("HumanoidRootPart")
        if not killerRoot then return true end
        local toMe = (cachedRoot.Position - killerRoot.Position).Unit
        return killerRoot.CFrame.LookVector:Dot(toMe) > PARRY_LOOK_THRESHOLD
    end

   local function _isLocalBusy()
    local char = LocalPlayer.Character
    if not char then return true end
    if LocalPlayer:GetAttribute("IsDead") then return true end
    if char:GetAttribute("IsCarried") then return true end
    if char:GetAttribute("IsHooked") then return true end
    if cachedRoot and CollectionService:HasTag(cachedRoot, "doing action") then return true end
    local check = char:FindFirstChild("CheckInterractable")
    if check then
        for _, attr in ipairs({
            "isVaulting", "isSliding", "isDroppingPallet",
            "isRepairing", "isHealing", "isUnhooking", "isExiting"
        }) do
            if check:GetAttribute(attr) then return true end
        end
    end
    return false
   end

    local function doParry(track)
    if not canParry or not parryEnabled or isParrying then return false end
    if _isLocalBusy() then return false end
        if not cachedRoot then parryRefreshLocalCache() end
        if not cachedRoot then return false end
        local enemyRoot = killerChar and killerChar:FindFirstChild("HumanoidRootPart")
        if not enemyRoot then return false end
        local distance = (enemyRoot.Position - cachedRoot.Position).Magnitude
        if distance > PARRY_MAX_DISTANCE then return false end
        if not killerLookingAtMe() then return false end
        if track then
            if firedTracks[track] then return false end
            if track.TimePosition > PARRY_ANIMATION_START_THRESHOLD then return false end
            firedTracks[track] = true
            track.Stopped:Once(function() firedTracks[track] = nil end)
        end
        canParry      = false
        isParrying    = true
        waitingResult = true
        refreshVisual()
        ParryRemote:FireServer()
        playParryAnimation()
        freezePlayer()
        task.delay(15, function()
            if waitingResult then
                waitingResult   = false
                canParry        = true
                isParrying      = false
                cooldownEndTime = 0
                refreshVisual()
            end
        end)
        return true
    end

    local function quickCheckAttacks()
        if not parryEnabled or not canParry or isParrying then return false end
        if not killerAnimator or not killerChar then return false end
        for _, track in ipairs(killerAnimator:GetPlayingAnimationTracks()) do
            local anim = track.Animation
            if anim and ATTACK_ANIMS[anim.AnimationId] then
                if not firedTracks[track] and track.TimePosition <= PARRY_ANIMATION_START_THRESHOLD then
                    doParry(track)
                    return true
                end
            end
        end
        return false
    end

    local function onTrackDetected(track)
        if not track.Animation then return end
        if not ATTACK_ANIMS[track.Animation.AnimationId] then return end
        doParry(track)
    end

    local function disconnectAll()
        for _, c in ipairs(parryConnections) do pcall(function() c:Disconnect() end) end
        parryConnections = {}
    end

    local function parryResetKiller()
        disconnectAll()
        killerAnimator = nil
        killerChar     = nil
        killerPlayer   = nil
        firedTracks    = {}
    end

    local function parryGetKiller()
        local killerTeam = Teams:FindFirstChild("Killer")
        if not killerTeam then return nil end
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Team == killerTeam then return p end
        end
    end

    local function parryHookKiller()
        local killer = parryGetKiller()
        if not killer then parryResetKiller() return false end
        if killerPlayer == killer and killerAnimator then return true end
        parryResetKiller()
        killerPlayer = killer
        if not killer.Character then killer.CharacterAdded:Wait() end
        killerChar = killer.Character
        local hum = killerChar:FindFirstChildOfClass("Humanoid")
        if not hum then return false end
        killerAnimator = hum:FindFirstChildOfClass("Animator")
        if not killerAnimator then return false end
        table.insert(parryConnections, killerAnimator.AnimationPlayed:Connect(onTrackDetected))
        return true
    end

    RunService.PreRender:Connect(function()
        if not parryEnabled then return end
        if isFrozen and cachedHum then cachedHum.WalkSpeed = 0 end
        if not canParry or isParrying then return end
        if not killerAnimator then parryHookKiller() end
        quickCheckAttacks()
    end)

    Players.PlayerAdded:Connect(function(p)
        p.CharacterAdded:Connect(function() if parryEnabled then parryHookKiller() end end)
        p:GetPropertyChangedSignal("Team"):Connect(function() if parryEnabled then parryHookKiller() end end)
    end)
    for _, p in pairs(Players:GetPlayers()) do
        p.CharacterAdded:Connect(function() if parryEnabled then parryHookKiller() end end)
        p:GetPropertyChangedSignal("Team"):Connect(function() if parryEnabled then parryHookKiller() end end)
    end

    AddToggle(TabParry, "Auto Parry", function(v)
        parryEnabled = v
        if v then
            parryHookKiller()
        else
            parryResetKiller()
            rangeAdornment.Transparency = 1
        end
        refreshVisual()
    end)

    AddToggle(TabParry, "Parry Circle", function(v)
        parryShowCircle = v
        if not parryEnabled then
            rangeAdornment.Transparency = 1
        end
    end)

    AddInput(TabParry, "Range (studs)", tostring(PARRY_MAX_DISTANCE), "1-60", true, function(val)
        local v = tonumber(val)
        if v and v > 0 then
            PARRY_MAX_DISTANCE = math.clamp(v, 1, 60)
            rangeAdornment.Radius = PARRY_MAX_DISTANCE
            rangeAdornment.InnerRadius = PARRY_MAX_DISTANCE - 0.25
        end
    end)

    AddInput(TabParry, "Look Threshold", tostring(PARRY_LOOK_THRESHOLD), "-1 to 1", false, function(val)
        local v = tonumber(val)
        if v then
            PARRY_LOOK_THRESHOLD = math.clamp(v, -1, 1)
        end
    end)

    -- Parry Anim selector -> Fluent Dropdown
    local animNames = {}
    for _, a in ipairs(PARRY_ANIMS) do table.insert(animNames, a.name) end
    AddDropdown(TabParry, "Parry Anim", animNames, PARRY_ANIMS[selectedAnimIndex].name, function(selected)
        for i, a in ipairs(PARRY_ANIMS) do
            if a.name == selected then
                selectedAnimIndex = i
                ParryAnimation.AnimationId = a.id
                break
            end
        end
    end)

    AddInput(TabParry, "Anim Start Thresh", tostring(PARRY_ANIMATION_START_THRESHOLD), "0-1", false, function(val)
        local v = tonumber(val)
        if v then
            PARRY_ANIMATION_START_THRESHOLD = math.clamp(v, 0, 1)
        end
    end)
end
setupParryFeatures()

local function setupMoonwalkFeatures()
    local MwCfg = {
        MOONWALK_SPEED = 15,
        LERP_FACTOR    = 0.28,
        STEP_INTERVAL  = 0.12,
        SWING_WIDTH    = 6.4,
        MAX_YAW        = 26,
        TURN_LERP      = 0.07,
    }

    local moonwalkActive  = false
    local stepSide        = 1
    local stepTimer       = 0
    local elapsedTime     = 0
    local savedWalkSpeed  = 16
    local currentFwd      = Vector3.new(0, 0, -1)
    local pcEnabled       = false
    local mobileEnabled   = false
    local mwKeybind       = Enum.KeyCode.M
    local listeningForKey = false
    local mobileGui       = nil

    local function getMwHRP()
        local c = LocalPlayer.Character
        return c and c:FindFirstChild("HumanoidRootPart")
    end
    local function getMwHum()
        local c = LocalPlayer.Character
        return c and c:FindFirstChildOfClass("Humanoid")
    end

    local function applyMoonwalk()
        local hum = getMwHum()
        if not hum then return end
        if moonwalkActive then
            savedWalkSpeed = hum.WalkSpeed
            local cl = workspace.CurrentCamera.CFrame.LookVector
            local snap = Vector3.new(cl.X, 0, cl.Z)
            if snap.Magnitude > 0.01 then currentFwd = snap.Unit end
        end
        hum.AutoRotate = not moonwalkActive
        hum.WalkSpeed  = moonwalkActive and MwCfg.MOONWALK_SPEED or savedWalkSpeed
    end

    local function toggleMoonwalk()
        moonwalkActive = not moonwalkActive
        stepTimer = 0; stepSide = 1; elapsedTime = 0
        applyMoonwalk()
    end

    UserInputService.InputBegan:Connect(function(inp, gp)
        if gp or listeningForKey or not pcEnabled then return end
        if inp.KeyCode == mwKeybind then toggleMoonwalk() end
    end)

    LocalPlayer.CharacterAdded:Connect(function(c)
        c:WaitForChild("HumanoidRootPart"); c:WaitForChild("Humanoid")
        task.wait(0.5)
        stepTimer = 0; stepSide = 1; elapsedTime = 0
        if moonwalkActive then applyMoonwalk() end
    end)

    RunService.RenderStepped:Connect(function(dt)
        if not moonwalkActive then return end
        local hrp = getMwHRP(); local hum = getMwHum()
        if not hrp or not hum or hum.Health <= 0 then return end
        if hum.WalkSpeed ~= MwCfg.MOONWALK_SPEED then hum.WalkSpeed = MwCfg.MOONWALK_SPEED end
        stepTimer   = stepTimer + dt
        elapsedTime = elapsedTime + dt
        if stepTimer >= MwCfg.STEP_INTERVAL then stepTimer = 0; stepSide = -stepSide end
        local camLook   = workspace.CurrentCamera.CFrame.LookVector
        local targetFwd = Vector3.new(camLook.X, 0, camLook.Z)
        if targetFwd.Magnitude > 0.01 then
            currentFwd = currentFwd:Lerp(targetFwd.Unit, MwCfg.TURN_LERP)
        end
        local fwd      = currentFwd.Magnitude > 0.01 and currentFwd.Unit or targetFwd.Unit
        local rightVec = Vector3.new(fwd.Z, 0, -fwd.X)
        local sineFreq = 1 / (MwCfg.STEP_INTERVAL * 2)
        local sineVal  = math.sin(elapsedTime * sineFreq * 2 * math.pi)
        local backVel  = -fwd * MwCfg.MOONWALK_SPEED
        local sideVel  = rightVec * sineVal * MwCfg.SWING_WIDTH
        local targetVel = Vector3.new(
            backVel.X + sideVel.X,
            hrp.AssemblyLinearVelocity.Y,
            backVel.Z + sideVel.Z
        )
        hrp.AssemblyLinearVelocity = hrp.AssemblyLinearVelocity:Lerp(targetVel, MwCfg.LERP_FACTOR)
        local yawRad = math.rad(sineVal * MwCfg.MAX_YAW)
        local faceCF = CFrame.new(hrp.Position, hrp.Position + fwd)
        hrp.CFrame   = CFrame.new(hrp.Position)
            * CFrame.fromMatrix(Vector3.new(), faceCF.RightVector, faceCF.UpVector)
            * CFrame.Angles(0, yawRad, 0)
    end)

    -- tab mano

    -- PC Toggle + keybind (Fluent)
    AddKeybind(TabMoonwalk, "Moonwalk (PC) Key", Enum.KeyCode.M, function(key)
        mwKeybind = key
    end)

    AddToggle(TabMoonwalk, "Moonwalk (PC)", function(v)
        pcEnabled = v
        if not pcEnabled and moonwalkActive then
            moonwalkActive = false; applyMoonwalk()
        end
    end)

    -- Mobile Toggle + draggable button
    local function destroyMobileGui()
        if mobileGui then mobileGui:Destroy(); mobileGui = nil end
    end

    local function createMobileGui()
        destroyMobileGui()
        local mwGui = Instance.new("ScreenGui")
        mwGui.Name           = "MwMobileBtn"
        mwGui.ResetOnSpawn   = false
        mwGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
        if typeof(syn) == "table" and syn.protect_gui then syn.protect_gui(mwGui) end
        mwGui.Parent = CoreGui

        local btn = Instance.new("TextButton", mwGui)
        btn.Size             = UDim2.new(0, 60, 0, 60)
        btn.Position         = UDim2.new(0.5, -30, 0.8, 0)
        btn.BackgroundColor3    = Color3.fromRGB(10, 10, 25)
        btn.BackgroundTransparency = 1
        Instance.new("UICorner", btn).CornerRadius = UDim.new(1, 0)
        btn.Text = ""
        local btnIcon = Instance.new("ImageLabel", btn)
        btnIcon.Size                 = UDim2.new(1, 0, 1, 0)
        btnIcon.Position             = UDim2.new(0, 0, 0, 0)
        btnIcon.BackgroundTransparency = 1
        btnIcon.Image                = "rbxassetid://99735480595595"
        btnIcon.ScaleType            = Enum.ScaleType.Fit
        btnIcon.ZIndex               = 2
        Instance.new("UICorner", btnIcon).CornerRadius = UDim.new(1, 0)
        local btnStroke = Instance.new("UIStroke", btn)
        btnStroke.Color = Color3.fromRGB(55, 55, 155); btnStroke.Thickness = 1.5

        local dot = Instance.new("Frame", btn)
        dot.Size             = UDim2.new(0, 10, 0, 10)
        dot.Position         = UDim2.new(1, -12, 0, 2)
        dot.BackgroundColor3 = Color3.fromRGB(90, 90, 90)
        Instance.new("UICorner", dot).CornerRadius = UDim.new(1, 0)

        local function updateDot()
            dot.BackgroundColor3 = moonwalkActive
                and Color3.fromRGB(98, 63, 117) or Color3.fromRGB(60, 60, 60)
            btnStroke.Color = moonwalkActive
                and Color3.fromRGB(98, 63, 117) or Color3.fromRGB(45, 45, 45)
            btn.BackgroundColor3 = moonwalkActive
                and Color3.fromRGB(60, 35, 75) or Color3.fromRGB(10, 10, 25)
        end

        local dragging, dragStart, startPos, activeInput, tapConsumed = false, nil, nil, nil, false
        btn.InputBegan:Connect(function(inp)
            if inp.UserInputType ~= Enum.UserInputType.Touch
            and inp.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
            if activeInput then return end
            activeInput = inp; dragStart = inp.Position
            startPos = btn.Position; dragging = false; tapConsumed = false
        end)
        UserInputService.InputChanged:Connect(function(inp)
            if inp ~= activeInput then return end
            local d = inp.Position - dragStart
            if math.sqrt(d.X^2 + d.Y^2) > 12 then dragging = true end
            if dragging then
                btn.Position = UDim2.new(
                    startPos.X.Scale, startPos.X.Offset + d.X,
                    startPos.Y.Scale, startPos.Y.Offset + d.Y)
            end
        end)
        UserInputService.InputEnded:Connect(function(inp)
            if inp ~= activeInput then return end
            local wasDrag = dragging
            dragging = false; activeInput = nil
            if not tapConsumed and not wasDrag then
                tapConsumed = true
                toggleMoonwalk(); updateDot()
            end
        end)

        mobileGui = mwGui
    end

    AddToggle(TabMoonwalk, "Moonwalk (Mobile)", function(v)
        mobileEnabled = v
        if mobileEnabled then
            createMobileGui()
        else
            destroyMobileGui()
            if moonwalkActive then moonwalkActive = false; applyMoonwalk() end
        end
    end)

    -- Sliders (Fluent)
    makeMwSlider(TabMoonwalk, "Walk Speed",    "MOONWALK_SPEED", 2,    30,   0, MwCfg)
    makeMwSlider(TabMoonwalk, "Swing Width",   "SWING_WIDTH",    0,    15,   1, MwCfg)
    makeMwSlider(TabMoonwalk, "Max Yaw",       "MAX_YAW",        0,    60,   0, MwCfg)
    makeMwSlider(TabMoonwalk, "Lerp Factor",   "LERP_FACTOR",    0.01, 0.5,  2, MwCfg)
    makeMwSlider(TabMoonwalk, "Step Interval", "STEP_INTERVAL",  0.04, 0.4,  2, MwCfg)
    makeMwSlider(TabMoonwalk, "Turn Speed",    "TURN_LERP",      0.01, 0.2,  2, MwCfg)
end
setupMoonwalkFeatures()

local function setupKillerTabFeatures()
local MaskedPower = ReplicatedStorage.Remotes.Killers.Masked.Activatepower
local MaskedDepower = ReplicatedStorage.Remotes.Killers.Masked.Deactivatepower

local function getMyersTarget()
    local char = LocalPlayer.Character
    if not char then return nil end
    local myHRP = char:FindFirstChild("HumanoidRootPart")
    if not myHRP then return nil end
    local candidates = {}
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            local hrp = player.Character:FindFirstChild("HumanoidRootPart")
            local hum = player.Character:FindFirstChildOfClass("Humanoid")
            if hrp and hum and hum.Health > 0 then
                table.insert(candidates, {
                    player = player,
                    dist   = (hrp.Position - myHRP.Position).Magnitude,
                    health = hum.Health
                })
            end
        end
    end
    table.sort(candidates, function(a, b) return a.dist < b.dist end)
    for _, c in ipairs(candidates) do
        if c.health >= Extras.MIN_HEALTH_MYERS then return c.player end
    end
    return candidates[1] and candidates[1].player or nil
end

local function doMyersGrab()
    if not Extras.myersGrabEnabled then return end
    local target = getMyersTarget()
    if not target or not target.Character then return end
    pcall(function()
        ReplicatedStorage.Remotes.Killers.Stalker.grab:FireServer(target.Character)
    end)
end

breakGenHookRef = hookmetamethod(game, "__namecall", function(self, ...)
    local method = getnamecallmethod()
    local BreakGenRemote = ReplicatedStorage.Remotes.Generator.BreakGenEvent
    if method == "FireServer" and self == BreakGenRemote and Extras.breakGenEnabled and not Extras.breakGenFired then
        local args = {...}
        if args[1] then
            Extras.breakGenCaptured = args[1]
            Extras.breakGenFired = true
            local result = breakGenHookRef(self, ...)
            task.spawn(function()
                for i = 2, Extras.breakGenCount do
                    pcall(function() BreakGenRemote:FireServer(Extras.breakGenCaptured) end)
                    task.wait(0.01)
                end
                task.delay(2, function()
                    Extras.breakGenCaptured = nil
                    Extras.breakGenFired = false
                end)
            end)
            return result
        end
    end
    return breakGenHookRef(self, ...)
end)

AddToggle(TabKiller, "Break Whole Gen", function(v)
    Extras.breakGenEnabled = v
end)

AddInput(TabKiller, "Break Count", tostring(Extras.breakGenCount), "2-10", true, function(val)
    local v = tonumber(val)
    if v then
        Extras.breakGenCount = math.clamp(math.floor(v), 2, 10)
    end
end)

-- The Masked: pakai beberapa AddButton
AddSection(TabKiller, "The Masked")
AddButton(TabKiller, "Rabbit", function() MaskedPower:FireServer("Rabbit") end)
AddButton(TabKiller, "Tony", function() MaskedPower:FireServer("Tony") end)
AddButton(TabKiller, "Richter", function() MaskedPower:FireServer("Richter") end)
AddButton(TabKiller, "Cobra", function() MaskedPower:FireServer("Cobra") end)
AddButton(TabKiller, "Alex", function() MaskedPower:FireServer("Alex") end)
AddButton(TabKiller, "Brandon", function() MaskedPower:FireServer("Brandon") end)
AddButton(TabKiller, "Deactivate Power", function() MaskedDepower:FireServer() end)

-- Myers Grab: keybind + toggle
AddKeybind(TabKiller, "Myers Grab Key", Enum.KeyCode.Unknown, function(key)
    Extras.myersGrabKey = key
end)

-- Myers Grab floating button (custom, tetap ImageButton)
local MyersGrabBtn = Instance.new("ImageButton", AiiSigma)
MyersGrabBtn.Size = UDim2.new(0, 70, 0, 70)
MyersGrabBtn.Position = UDim2.new(0.7, 0, 0.75, 0)
MyersGrabBtn.BackgroundColor3 = Color3.fromRGB(30, 15, 40)
MyersGrabBtn.BackgroundTransparency = 0.1
MyersGrabBtn.Image = ""
MyersGrabBtn.Visible = false
Instance.new("UICorner", MyersGrabBtn).CornerRadius = UDim.new(1, 0)
local mgStroke = Instance.new("UIStroke", MyersGrabBtn)
mgStroke.Color = Color3.fromRGB(98, 63, 117)
mgStroke.Thickness = 2

local mgLabel = Instance.new("TextLabel", MyersGrabBtn)
mgLabel.Size = UDim2.new(1, 0, 1, 0)
mgLabel.BackgroundTransparency = 1
mgLabel.Text = "Grab"
mgLabel.Font = Enum.Font.GothamBold
mgLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
mgLabel.TextSize = 14

MyersGrabBtn.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                if Extras.myersDragLocked then return end
                Extras.myersDragging = true
                Extras.myersDragStart = input.Position
                Extras.myersDragStartPos = MyersGrabBtn.Position
        end
end)

UserInputService.InputChanged:Connect(function(input)
        if Extras.myersDragging and not Extras.myersDragLocked and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
                local delta = input.Position - Extras.myersDragStart
                MyersGrabBtn.Position = UDim2.new(Extras.myersDragStartPos.X.Scale, Extras.myersDragStartPos.X.Offset + delta.X, Extras.myersDragStartPos.Y.Scale, Extras.myersDragStartPos.Y.Offset + delta.Y)
        end
end)

MyersGrabBtn.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                Extras.myersDragging = false
        end
end)

MyersGrabBtn.MouseButton1Click:Connect(doMyersGrab)

AddToggle(TabKiller, "Myers Grab", function(v)
    Extras.myersGrabEnabled = v
    MyersGrabBtn.Visible = v
end)

UserInputService.InputBegan:Connect(function(input, gp)
    if gp or Extras.listeningMyersKey then return end
    if Extras.myersGrabKey ~= Enum.KeyCode.Unknown and input.KeyCode == Extras.myersGrabKey then
        doMyersGrab()
    end
end)

AddToggle(TabKiller, "Lock Myers Toggle", function(v)
    Extras.myersDragLocked = v
end)

AddToggle(TabKiller, "Anti Stun", function(v)
    Extras.antiStunEnabled = v
end)
end
setupKillerTabFeatures()

-- crazyveil
local function setupVeilTabFeatures()
    AddToggle(TabVeil, "Silent Aim (Spear)", function(v)
        VeilConfig.Enabled = v
    end)

    AddToggle(TabVeil, "Auto Predict", function(v)
        VeilConfig.AutoPredict = v
    end)

    AddToggle(TabVeil, "Show FOV Circle", function(v)
        VeilConfig.ShowFOV = v
    end)

    AddInput(TabVeil, "FOV Radius", tostring(VeilConfig.FOV), "50-500", true, function(val)
        local v = tonumber(val)
        if v then
            VeilConfig.FOV = math.clamp(math.floor(v), 50, 500)
        end
    end)

    AddInput(TabVeil, "Spear Speed", tostring(VeilConfig.SpearSpeed), "50-400", true, function(val)
        local v = tonumber(val)
        if v then
            VeilConfig.SpearSpeed = math.clamp(math.floor(v), 50, 400)
        end
    end)

    AddInput(TabVeil, "Gravity", tostring(math.floor(VeilConfig.Gravity)), "0-300", true, function(val)
        local v = tonumber(val)
        if v then
            VeilConfig.Gravity = math.clamp(math.floor(v), 0, 300)
        end
    end)

    AddInput(TabVeil, "Horizontal Factor", tostring(VeilConfig.HorizontalPredictFactor), "0-10", false, function(val)
        local v = tonumber(val)
        if v then
            VeilConfig.HorizontalPredictFactor = math.clamp(v, 0, 10)
        end
    end)

    AddDropdown(TabVeil, "Target Part", {"Torso", "Head", "Root"}, VeilConfig.TargetPart, function(selected)
        VeilConfig.TargetPart = selected
    end)

    -- ============================================================
    -- INFORMATION & RECOMMENDED SETTINGS (pakai Fluent Paragraph)
    -- ============================================================
    AddSection(TabVeil, "Information")
    AddParagraph(TabVeil, "📌 Note", "Jika karakter tidak bisa bergerak saat menggunakan Veil, jangan gunakan outfit/skin berwarna hitam.")

    AddSection(TabVeil, "Recommended Settings")
    AddParagraph(TabVeil, "🎯 Silent Aim Setup", [[
Spear Speed: 175
Auto Prediction: ON
Jarak Optimal: ≤ 110 Studs (Akurasi terbaik)
Jarak Jauh (~190 Studs): Spear Speed 290]])
end

setupVeilTabFeatures()