--[[ Martin Hub // Legends of Speed — v12
     FIX: After trading equipped pets, the server holds the slots.
          Added "Reset Character (Fix Slots)" to force a server sync.
          Upgraded equip/unequip payloads to try both known signatures.
     kept: batch x10, auto hatch, orb picker, map picker, rebirth fix,
           crystal prices, ESP, TP, gem counter. no key. ]]

local Players    = game:GetService("Players")
local RS         = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UIS        = game:GetService("UserInputService")
local CoreGui    = game:GetService("CoreGui")
local plr        = Players.LocalPlayer

-- ============================================================
-- state
-- ============================================================
local S = {
    speed = 16, jump = 50,
    autoOrb   = false, orbMult = 1,
    selectedOrb = "Red Orb", selectedMap = "Auto (current)",
    autoHoop    = false, autoRebirth = false,
    autoHatch   = false, selectedCrystal = "Blue Crystal",
    espOrb      = false, espHoop     = false, espPlayer = false,
}

local SPEED_MAX, JUMP_MAX = 2000, 1000
local MULT_MAX   = 10
local ORB_TICK   = 0.09
local ORB_BUDGET = 18
local HOOP_CHUNK = 30
local ESP_CAP    = 250
local SCAN_CAP   = 12000
local REBIRTH_TICK = 2.0
local HATCH_TICK   = 0.9

local ORB_LIST = {
    "Red Orb", "Blue Orb", "Yellow Orb", "Orange Orb",
    "Green Orb", "Purple Orb", "Ethereal Orb", "Gem", "Crystal",
}
local MAP_LIST = {
    "Auto (current)", "City", "Snow City", "Magma City",
    "Speed Desert", "Speed Jungle", "Outer Space",
    "Electro Cave", "Legends Highway",
}
local WORLD_TP = {
    "City", "Snow City", "Magma City", "Speed Desert",
    "Speed Jungle", "Legends Highway", "Outer Space", "Electro Cave",
}
local CRYSTALS = {
    { name = "Red Crystal",            cost = 300 },
    { name = "Blue Crystal",           cost = 600 },
    { name = "Purple Crystal",         cost = 1000 },
    { name = "Yellow Crystal",         cost = 1200 },
    { name = "Lightning Crystal",      cost = 2500 },
    { name = "Snow Crystal",           cost = 4000 },
    { name = "Lava Crystal",           cost = 8000 },
    { name = "Inferno Crystal",        cost = 8000 },
    { name = "Space Crystal",          cost = 15000 },
    { name = "Alien Crystal",          cost = 25000 },
    { name = "Electro Crystal",        cost = 50000 },
    { name = "Electro Legends Crystal",cost = 100000 },
}

-- ============================================================
-- helpers
-- ============================================================
local function getChar()
    local c = plr.Character
    if not c or not c.Parent then return nil end
    local h = c:FindFirstChildOfClass("Humanoid")
    if not h or h.Health <= 0 then return nil end
    return c, h, c:FindFirstChild("HumanoidRootPart")
end
local function applyStats()
    local _, h = getChar()
    if not h then return end
    h.WalkSpeed = S.speed
    h.UseJumpPower = true
    h.JumpPower = S.jump
end
plr.CharacterAdded:Connect(function(c)
    c:WaitForChild("Humanoid", 10)
    task.wait(0.25)
    applyStats()
end)

-- ============================================================
-- remotes
-- ============================================================
local orbEvent, rebirthEvent, hatchRemote
local equipPetEvent, unequipPetEvent

local function resolveRemotes()
    local rEvents = RS:FindFirstChild("rEvents")
    if not rEvents then return end
    if not orbEvent then orbEvent = rEvents:FindFirstChild("orbEvent") end
    if not rebirthEvent then rebirthEvent = rEvents:FindFirstChild("rebirthEvent") end
    if not hatchRemote then hatchRemote = rEvents:FindFirstChild("openCrystalRemote") end
    if not equipPetEvent then
        equipPetEvent = rEvents:FindFirstChild("equipPetEvent") or rEvents:FindFirstChild("equipPet")
    end
    if not unequipPetEvent then
        unequipPetEvent = rEvents:FindFirstChild("unequipPetEvent") or rEvents:FindFirstChild("unequipPet") or equipPetEvent
    end
end

local function getGems()
    local ls = plr:FindFirstChild("leaderstats")
    if ls then
        local g = ls:FindFirstChild("Gems") or ls:FindFirstChild("Diamonds") or ls:FindFirstChild("Cash")
        if g then return g.Value end
    end
    for _, name in ipairs({"Gems", "Diamonds", "Cash"}) do
        local g = plr:FindFirstChild(name)
        if g and (g:IsA("IntValue") or g:IsA("NumberValue")) then return g.Value end
    end
    return 0
end

local function currentWorld()
    local ok, map = pcall(function()
        local v = plr:FindFirstChild("currentMap")
        if v and v:IsA("StringValue") then return v.Value end
    end)
    if ok and type(map) == "string" and #map > 0 then return map end
    return nil
end

local function fireOrb(t, w)
    if not orbEvent then return false end
    return pcall(function() orbEvent:FireServer("collectOrb", t, w) end)
end

-- ============================================================
-- farming loops
-- ============================================================
local orbTask = nil
local function resolvedMap()
    if S.selectedMap == "Auto (current)" then return currentWorld() end
    return S.selectedMap
end
local function startOrbLoop()
    if orbTask then return end
    orbTask = task.spawn(function()
        while S.autoOrb do
            resolveRemotes()
            if orbEvent then
                local world = resolvedMap()
                local orb   = S.selectedOrb
                if world then
                    local calls = math.clamp(S.orbMult * 2, 1, ORB_BUDGET)
                    for _ = 1, calls do
                        if not S.autoOrb then break end
                        fireOrb(orb, world)
                    end
                end
            end
            task.wait(ORB_TICK)
        end
        orbTask = nil
    end)
end
local function stopOrbLoop() S.autoOrb = false end

local hoopTask = nil
local function startHoopLoop()
    if hoopTask then return end
    hoopTask = task.spawn(function()
        while S.autoHoop do
            local _, _, root = getChar()
            if root then
                local hoops = workspace:FindFirstChild("Hoops")
                if hoops then
                    local moved = 0
                    for _, v in ipairs(hoops:GetChildren()) do
                        if moved >= HOOP_CHUNK or not S.autoHoop then break end
                        if v:IsA("BasePart") then
                            pcall(function() v.CFrame = root.CFrame end)
                            moved += 1
                        end
                    end
                end
            end
            task.wait(0.12)
        end
        hoopTask = nil
    end)
end
local function stopHoopLoop() S.autoHoop = false end

local rebirthTask = nil
local function startRebirthLoop()
    if rebirthTask then return end
    rebirthTask = task.spawn(function()
        while S.autoRebirth do
            resolveRemotes()
            if rebirthEvent then
                pcall(function() rebirthEvent:FireServer("rebirthRequest") end)
            end
            task.wait(REBIRTH_TICK)
        end
        rebirthTask = nil
    end)
end
local function stopRebirthLoop() S.autoRebirth = false end

local hatchTask = nil
local function startHatchLoop()
    if hatchTask then return end
    hatchTask = task.spawn(function()
        while S.autoHatch do
            resolveRemotes()
            if hatchRemote then
                local crystal = S.selectedCrystal
                pcall(function() hatchRemote:InvokeServer("openCrystal", crystal) end)
            end
            task.wait(HATCH_TICK)
        end
        hatchTask = nil
    end)
end
local function stopHatchLoop() S.autoHatch = false end

-- ============================================================
-- PETS
-- ============================================================
local function listOwnedPets()
    local names = {}
    local folders = { "Pets", "PetInventory", "OwnedPets", "Inventory" }
    for _, fName in ipairs(folders) do
        local f = plr:FindFirstChild(fName)
        if f then
            for _, p in ipairs(f:GetChildren()) do
                if not table.find(names, p.Name) then table.insert(names, p.Name) end
            end
        end
    end
    table.sort(names)
    return names
end

local function equipPet(name)
    resolveRemotes()
    if not equipPetEvent then return false end
    return pcall(function()
        equipPetEvent:FireServer("Equip", name)
        task.wait(0.1)
        equipPetEvent:FireServer(name)
    end)
end

local function unequipPet(name)
    resolveRemotes()
    if not unequipPetEvent then return false end
    return pcall(function()
        unequipPetEvent:FireServer("Unequip", name)
        task.wait(0.1)
        unequipPetEvent:FireServer(name)
    end)
end

-- ============================================================
-- ESP
-- ============================================================
local espGui, espEntries = nil, {}
local function ensureEspGui()
    if espGui and espGui.Parent then return end
    local g = Instance.new("ScreenGui")
    g.Name = "martin_hub_esp"; g.ResetOnSpawn = false; g.IgnoreGuiInset = true
    local ok = pcall(function() g.Parent = CoreGui end)
    if not ok or not g.Parent then g.Parent = plr:WaitForChild("PlayerGui") end
    espGui = g
end
local function clearEsp()
    for _, hl in pairs(espEntries) do pcall(function() hl:Destroy() end) end
    espEntries = {}
end
local function addEsp(inst, color)
    ensureEspGui()
    local hl = Instance.new("Highlight")
    hl.FillColor = color; hl.FillTransparency = 0.65
    hl.OutlineColor = color; hl.OutlineTransparency = 0
    hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    hl.Adornee = inst; hl.Parent = espGui
    table.insert(espEntries, hl)
end
local function refreshEsp()
    clearEsp()
    if not (S.espOrb or S.espHoop or S.espPlayer) then return end
    local n = 0
    if S.espOrb then
        for _, d in ipairs(workspace:GetDescendants()) do
            if n >= ESP_CAP then break end
            if d:IsA("BasePart") then
                local nm = d.Name:lower()
                if nm:find("orb", 1, true) or nm:find("gem", 1, true) or nm:find("crystal", 1, true) then
                    addEsp(d, Color3.fromRGB(90, 220, 255)); n += 1
                end
            end
        end
    end
    if S.espHoop and n < ESP_CAP then
        local hoops = workspace:FindFirstChild("Hoops")
        if hoops then
            for _, d in ipairs(hoops:GetDescendants()) do
                if n >= ESP_CAP then break end
                if d:IsA("BasePart") then addEsp(d, Color3.fromRGB(255, 200, 60)); n += 1 end
            end
        end
    end
    if S.espPlayer and n < ESP_CAP then
        for _, p in ipairs(Players:GetPlayers()) do
            if n >= ESP_CAP then break end
            if p ~= plr and p.Character then addEsp(p.Character, Color3.fromRGB(255, 80, 110)); n += 1 end
        end
    end
end
task.spawn(function() while true do task.wait(1.8); pcall(refreshEsp) end end)

-- ============================================================
-- TPs
-- ============================================================
local function tpToPart(part)
    local _, _, root = getChar(); if not root or not part then return end
    root.CFrame = part.CFrame + Vector3.new(0, 8, 0)
    root.AssemblyLinearVelocity = Vector3.zero
end
local function tpToWorld(name)
    local n = 0
    for _, d in ipairs(workspace:GetDescendants()) do
        n += 1; if n > SCAN_CAP then break end
        if d:IsA("BasePart") and d.Name:lower():find(name:lower(), 1, true) then
            tpToPart(d); return true
        end
    end
    return false
end
local function tpNextStage()
    local _, _, root = getChar(); if not root then return end
    local best, bestD, n = nil, math.huge, 0
    for _, d in ipairs(workspace:GetDescendants()) do
        n += 1; if n > SCAN_CAP then break end
        if d:IsA("BasePart") then
            local nm = d.Name:lower()
            if nm:find("checkpoint",1,true) or nm:find("stage",1,true) or nm:find("finish",1,true) or nm:find("portal",1,true) then
                local dist = (d.Position - root.Position).Magnitude
                if dist > 10 and dist < bestD then best, bestD = d, dist end
            end
        end
    end
    if best then tpToPart(best) end
end

-- ============================================================
-- UI
-- ============================================================
local gui = Instance.new("ScreenGui")
gui.Name = "martin_hub"; gui.ResetOnSpawn = false; gui.DisplayOrder = 999
gui.Parent = plr:WaitForChild("PlayerGui")

local openBtn = Instance.new("TextButton")
openBtn.Size = UDim2.new(0,46,0,46)
openBtn.Position = UDim2.new(0,10,0,36)
openBtn.BackgroundColor3 = Color3.fromRGB(60,165,95)
openBtn.Text = "☰"
openBtn.TextColor3 = Color3.fromRGB(255,255,255)
openBtn.Font = Enum.Font.GothamBold; openBtn.TextSize = 20
openBtn.AutoButtonColor = false; openBtn.Active = true; openBtn.Draggable = true; openBtn.Parent = gui
Instance.new("UICorner", openBtn).CornerRadius = UDim.new(0, 10)

local panel = Instance.new("Frame")
panel.Size = UDim2.new(0, 266, 0, 460)
panel.Position = UDim2.new(0, 66, 0, 36)
panel.BackgroundColor3 = Color3.fromRGB(16,16,20)
panel.BackgroundTransparency = 0.05
panel.BorderSizePixel = 0; panel.Active = true; panel.Draggable = true
panel.Visible = false; panel.Parent = gui
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 12)

local hdr = Instance.new("TextLabel")
hdr.Size = UDim2.new(1,0,0,30)
hdr.BackgroundColor3 = Color3.fromRGB(26,26,32)
hdr.BorderSizePixel = 0
hdr.Text = "  martin hub"
hdr.TextColor3 = Color3.fromRGB(235,235,240)
hdr.Font = Enum.Font.GothamBold; hdr.TextSize = 14
hdr.TextXAlignment = Enum.TextXAlignment.Left
hdr.Parent = panel
Instance.new("UICorner", hdr).CornerRadius = UDim.new(0, 12)

local TAB_NAMES = { "Main", "Farm", "Orbs", "Hatch", "Pets", "TP", "Vis" }
local tabBar = Instance.new("Frame")
tabBar.Size = UDim2.new(1,-12,0,26)
tabBar.Position = UDim2.new(0,6,0,34)
tabBar.BackgroundTransparency = 1; tabBar.Parent = panel
local tabLayout = Instance.new("UIListLayout")
tabLayout.FillDirection = Enum.FillDirection.Horizontal
tabLayout.Padding = UDim.new(0,2); tabLayout.Parent = tabBar

local pages = {}
local function showTab(name)
    for n,f in pairs(pages) do f.Visible = (n == name) end
    for _,b in ipairs(tabBar:GetChildren()) do
        if b:IsA("TextButton") then
            local on = (b.Text == name)
            b.BackgroundColor3 = on and Color3.fromRGB(60,165,95) or Color3.fromRGB(34,34,40)
        end
    end
end
local tabW = 1 / #TAB_NAMES
for _,name in ipairs(TAB_NAMES) do
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(tabW,-2,1,0)
    b.BackgroundColor3 = Color3.fromRGB(34,34,40)
    b.Text = name; b.TextColor3 = Color3.fromRGB(225,225,230)
    b.Font = Enum.Font.GothamMedium; b.TextSize = 9
    b.Parent = tabBar
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
    b.MouseButton1Click:Connect(function() showTab(name) end)

    local page = Instance.new("ScrollingFrame")
    page.Size = UDim2.new(1,-12,1,-70)
    page.Position = UDim2.new(0,6,0,64)
    page.BackgroundTransparency = 1; page.BorderSizePixel = 0
    page.ScrollBarThickness = 3; page.CanvasSize = UDim2.new(0,0,0,0)
    page.AutomaticCanvasSize = Enum.AutomaticSize.Y
    page.Visible = false; page.Parent = panel
    local lay = Instance.new("UIListLayout")
    lay.Padding = UDim.new(0,6); lay.Parent = page
    pages[name] = page
end

local function makeBtn(parent, text, cb)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(1,0,0,32)
    b.BackgroundColor3 = Color3.fromRGB(36,36,44)
    b.Text = text; b.TextColor3 = Color3.fromRGB(230,230,236)
    b.Font = Enum.Font.Gotham; b.TextSize = 13
    b.Parent = parent
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 7)
    if cb then b.MouseButton1Click:Connect(function() cb(b) end) end
    return b
end
local function paint(btn, on)
    btn.BackgroundColor3 = on and Color3.fromRGB(58,158,92) or Color3.fromRGB(36,36,44)
end
local function toggle(btn, key, label, cb)
    S[key] = not S[key]
    paint(btn, S[key])
    btn.Text = label .. ": " .. (S[key] and "ON" or "OFF")
    if cb then cb(S[key]) end
end
local function sectionLabel(parent, text)
    local l = Instance.new("TextLabel")
    l.Size = UDim2.new(1,0,0,22); l.BackgroundTransparency = 1
    l.Text = "  " .. text; l.TextColor3 = Color3.fromRGB(140,140,155)
    l.Font = Enum.Font.GothamBold; l.TextSize = 11; l.TextXAlignment = Enum.TextXAlignment.Left
    l.Parent = parent
    return l
end

-- MAIN
local mainP = pages["Main"]
makeBtn(mainP, "Speed: 16", function(b)
    S.speed = (S.speed >= SPEED_MAX) and 16 or math.min(S.speed + 60, SPEED_MAX)
    b.Text = "Speed: " .. S.speed; applyStats()
end)
makeBtn(mainP, "Jump: 50", function(b)
    S.jump = (S.jump >= JUMP_MAX) and 50 or math.min(S.jump + 60, JUMP_MAX)
    b.Text = "Jump: " .. S.jump; applyStats()
end)

-- FARM
local farmP = pages["Farm"]
local pickLbl = Instance.new("TextLabel")
pickLbl.Size = UDim2.new(1,0,0,34)
pickLbl.BackgroundColor3 = Color3.fromRGB(24,24,30); pickLbl.BorderSizePixel = 0
pickLbl.Text = ""; pickLbl.TextColor3 = Color3.fromRGB(200,200,210)
pickLbl.Font = Enum.Font.Gotham; pickLbl.TextSize = 12; pickLbl.TextXAlignment = Enum.TextXAlignment.Left
pickLbl.Parent = farmP
Instance.new("UICorner", pickLbl).CornerRadius = UDim.new(0, 7)

local function refreshPickLbl()
    pickLbl.Text = string.format("  %s  @  %s", S.selectedOrb, S.selectedMap)
end

makeBtn(farmP, "Auto Orb: OFF", function(b)
    S.autoOrb = not S.autoOrb
    paint(b, S.autoOrb)
    b.Text = "Auto Orb: " .. (S.autoOrb and "ON" or "OFF")
    if S.autoOrb then startOrbLoop() else stopOrbLoop() end
end)
makeBtn(farmP, "Batch: x1", function(b)
    S.orbMult = (S.orbMult >= MULT_MAX) and 1 or (S.orbMult + 1)
    b.Text = "Batch: x" .. S.orbMult
end)
makeBtn(farmP, "Hoop Magnet: OFF", function(b)
    S.autoHoop = not S.autoHoop
    paint(b, S.autoHoop)
    b.Text = "Hoop Magnet: " .. (S.autoHoop and "ON" or "OFF")
    if S.autoHoop then startHoopLoop() else stopHoopLoop() end
end)

local rbStatus = Instance.new("TextLabel")
rbStatus.Size = UDim2.new(1,0,0,22); rbStatus.BackgroundTransparency = 1
rbStatus.Text = "  rebirth remote: checking…"; rbStatus.TextColor3 = Color3.fromRGB(140,140,155)
rbStatus.Font = Enum.Font.Gotham; rbStatus.TextSize = 10; rbStatus.TextXAlignment = Enum.TextXAlignment.Left
rbStatus.Parent = farmP

local function refreshRbStatus()
    resolveRemotes()
    if rebirthEvent then
        rbStatus.Text = "  rebirth remote: OK (rEvents.rebirthEvent)"
        rbStatus.TextColor3 = Color3.fromRGB(120,200,140)
    else
        rbStatus.Text = "  rebirth remote: NOT FOUND"
        rbStatus.TextColor3 = Color3.fromRGB(220,100,100)
    end
end

makeBtn(farmP, "Auto Rebirth: OFF", function(b)
    S.autoRebirth = not S.autoRebirth
    paint(b, S.autoRebirth)
    b.Text = "Auto Rebirth: " .. (S.autoRebirth and "ON" or "OFF")
    if S.autoRebirth then resolveRemotes(); refreshRbStatus(); startRebirthLoop() else stopRebirthLoop() end
end)

-- ORBS
local orbsP = pages["Orbs"]
sectionLabel(orbsP, "PICK THE ORB")
local orbButtons = {}
local function repaintOrbs()
    for name, b in pairs(orbButtons) do
        local on = (name == S.selectedOrb)
        b.BackgroundColor3 = on and Color3.fromRGB(58,158,92) or Color3.fromRGB(36,36,44)
        b.Text = on and ("●  " .. name) or ("    " .. name)
    end
end
for _, orbName in ipairs(ORB_LIST) do
    local b = makeBtn(orbsP, "    " .. orbName, function(btn)
        S.selectedOrb = orbName; repaintOrbs(); refreshPickLbl()
    end)
    b.TextXAlignment = Enum.TextXAlignment.Left; orbButtons[orbName] = b
end
sectionLabel(orbsP, "PICK THE MAP")
local mapButtons = {}
local function repaintMaps()
    for name, b in pairs(mapButtons) do
        local on = (name == S.selectedMap)
        b.BackgroundColor3 = on and Color3.fromRGB(58,158,92) or Color3.fromRGB(36,36,44)
        b.Text = on and ("●  " .. name) or ("    " .. name)
    end
end
for _, mapName in ipairs(MAP_LIST) do
    local b = makeBtn(orbsP, "    " .. mapName, function(btn)
        S.selectedMap = mapName; repaintMaps(); refreshPickLbl()
    end)
    b.TextXAlignment = Enum.TextXAlignment.Left; mapButtons[mapName] = b
end

-- HATCH
local hatchP = pages["Hatch"]
local gemsLbl = Instance.new("TextLabel")
gemsLbl.Size = UDim2.new(1,0,0,34)
gemsLbl.BackgroundColor3 = Color3.fromRGB(30,30,40); gemsLbl.BorderSizePixel = 0
gemsLbl.Text = "  💎 Gems: loading..."; gemsLbl.TextColor3 = Color3.fromRGB(150,240,220)
gemsLbl.Font = Enum.Font.GothamBold; gemsLbl.TextSize = 14; gemsLbl.TextXAlignment = Enum.TextXAlignment.Left
gemsLbl.Parent = hatchP
Instance.new("UICorner", gemsLbl).CornerRadius = UDim.new(0, 7)

task.spawn(function()
    while true do
        task.wait(0.5)
        local val = getGems()
        gemsLbl.Text = string.format("  💎 Gems: %s", tostring(val))
        if val == 0 then gemsLbl.TextColor3 = Color3.fromRGB(220,100,100) else gemsLbl.TextColor3 = Color3.fromRGB(150,240,220) end
    end
end)

sectionLabel(hatchP, "PICK THE CRYSTAL (EGG)")
local crystalButtons = {}
local function repaintCrystals()
    for name, b in pairs(crystalButtons) do
        local on = (name == S.selectedCrystal)
        b.BackgroundColor3 = on and Color3.fromRGB(58,158,92) or Color3.fromRGB(36,36,44)
        b.Text = on and ("●  " .. name) or ("    " .. name)
    end
end
for _, crystal in ipairs(CRYSTALS) do
    local label = string.format("%s  —  %s Gems", crystal.name, tostring(crystal.cost))
    local b = makeBtn(hatchP, "    " .. label, function(btn)
        S.selectedCrystal = crystal.name; repaintCrystals()
    end)
    b.TextXAlignment = Enum.TextXAlignment.Left
    crystalButtons[crystal.name] = b
end
sectionLabel(hatchP, "CUSTOM CRYSTAL NAME")
local customBox = Instance.new("TextBox")
customBox.Size = UDim2.new(1,0,0,32)
customBox.BackgroundColor3 = Color3.fromRGB(28,28,34); customBox.BorderSizePixel = 0
customBox.PlaceholderText = "type exact crystal name…"; customBox.Text = ""
customBox.TextColor3 = Color3.fromRGB(230,230,236); customBox.PlaceholderColor3 = Color3.fromRGB(120,120,135)
customBox.Font = Enum.Font.Gotham; customBox.TextSize = 12; customBox.ClearTextOnFocus = false
customBox.Parent = hatchP
Instance.new("UICorner", customBox).CornerRadius = UDim.new(0, 7)
customBox.FocusLost:Connect(function()
    local v = customBox.Text:gsub("^%s+", ""):gsub("%s+$", "")
    if #v > 0 then S.selectedCrystal = v; repaintCrystals() end
end)
local hatchStatus = Instance.new("TextLabel")
hatchStatus.Size = UDim2.new(1,0,0,22); hatchStatus.BackgroundTransparency = 1
hatchStatus.Text = "  hatch remote: checking…"; hatchStatus.TextColor3 = Color3.fromRGB(140,140,155)
hatchStatus.Font = Enum.Font.Gotham; hatchStatus.TextSize = 10; hatchStatus.TextXAlignment = Enum.TextXAlignment.Left
hatchStatus.Parent = hatchP
local function refreshHatchStatus()
    resolveRemotes()
    if hatchRemote then
        hatchStatus.Text = "  hatch remote: OK (rEvents.openCrystalRemote)"
        hatchStatus.TextColor3 = Color3.fromRGB(120,200,140)
    else
        hatchStatus.Text = "  hatch remote: NOT FOUND"
        hatchStatus.TextColor3 = Color3.fromRGB(220,100,100)
    end
end
makeBtn(hatchP, "Auto Hatch: OFF", function(b)
    S.autoHatch = not S.autoHatch
    paint(b, S.autoHatch)
    b.Text = "Auto Hatch: " .. (S.autoHatch and "ON" or "OFF")
    if S.autoHatch then resolveRemotes(); refreshHatchStatus(); startHatchLoop() else stopHatchLoop() end
end)

-- ============================================================
-- PETS
-- ============================================================
local petsP = pages["Pets"]
local petStatus = Instance.new("TextLabel")
petStatus.Size = UDim2.new(1,0,0,34)
petStatus.BackgroundColor3 = Color3.fromRGB(24,24,30); petStatus.BorderSizePixel = 0
petStatus.Text = "  scan to list your pets"; petStatus.TextColor3 = Color3.fromRGB(200,200,210)
petStatus.Font = Enum.Font.Gotham; petStatus.TextSize = 12; petStatus.TextXAlignment = Enum.TextXAlignment.Left
petStatus.Parent = petsP
Instance.new("UICorner", petStatus).CornerRadius = UDim.new(0, 7)

local function resetCharacter()
    local c = plr.Character
    if c then
        local h = c:FindFirstChildOfClass("Humanoid")
        if h then
            h.Health = 0
            petStatus.Text = "  resetting to fix slots…"
        end
    end
end

local resetBtn = makeBtn(petsP, "Reset Character (Fix Trade Bug)", function()
    resetCharacter()
end)
resetBtn.BackgroundColor3 = Color3.fromRGB(200, 80, 80)
resetBtn.TextColor3 = Color3.fromRGB(255, 255, 255)

local petContainer = Instance.new("Frame")
petContainer.Size = UDim2.new(1,0,0,0); petContainer.AutomaticSize = Enum.AutomaticSize.Y
petContainer.BackgroundTransparency = 1; petContainer.Parent = petsP
local petLay = Instance.new("UIListLayout")
petLay.Padding = UDim.new(0,4); petLay.Parent = petContainer

local function clearPetList()
    for _, c in ipairs(petContainer:GetChildren()) do
        if c:IsA("Frame") or c:IsA("TextButton") then c:Destroy() end
    end
end

local function buildPetList()
    clearPetList()
    local owned = listOwnedPets()
    petStatus.Text = "  pets found: " .. #owned
    if #owned == 0 then return end

    for _, name in ipairs(owned) do
        local row = Instance.new("Frame")
        row.Size = UDim2.new(1,0,0,32); row.BackgroundTransparency = 1; row.Parent = petContainer

        local eq = Instance.new("TextButton")
        eq.Size = UDim2.new(0.55,-2,1,0)
        eq.BackgroundColor3 = Color3.fromRGB(36,36,44)
        eq.Text = "  equip: " .. name; eq.TextColor3 = Color3.fromRGB(230,230,236)
        eq.Font = Enum.Font.Gotham; eq.TextSize = 11; eq.TextXAlignment = Enum.TextXAlignment.Left
        eq.Parent = row
        Instance.new("UICorner", eq).CornerRadius = UDim.new(0, 7)
        eq.MouseButton1Click:Connect(function()
            local ok = equipPet(name)
            eq.Text = ok and ("  ✓ " .. name) or ("  ✗ " .. name)
            eq.BackgroundColor3 = ok and Color3.fromRGB(58,158,92) or Color3.fromRGB(90,40,44)
        end)

        local uq = Instance.new("TextButton")
        uq.Size = UDim2.new(0.45,-2,1,0); uq.Position = UDim2.new(0.55,0,0,0)
        uq.BackgroundColor3 = Color3.fromRGB(70,40,44)
        uq.Text = "unequip"; uq.TextColor3 = Color3.fromRGB(240,200,200)
        uq.Font = Enum.Font.Gotham; uq.TextSize = 11; uq.Parent = row
        Instance.new("UICorner", uq).CornerRadius = UDim.new(0, 7)
        uq.MouseButton1Click:Connect(function()
            local ok = unequipPet(name)
            uq.Text = ok and "✓ unequipped" or "✗ failed"
        end)
    end
end

makeBtn(petsP, "Refresh pet list", function() buildPetList() end)
makeBtn(petsP, "Equip MAX (fill 2 slots)", function()
    local owned = listOwnedPets()
    if #owned == 0 then return end
    petStatus.Text = "  equipping…"
    for i = 1, math.min(2, #owned) do
        equipPet(owned[i])
        task.wait(1)
    end
    petStatus.Text = "  equipped up to 2 pets"
end)
makeBtn(petsP, "Unequip ALL", function()
    local owned = listOwnedPets()
    for _, name in ipairs(owned) do
        unequipPet(name)
        task.wait(0.2)
    end
    petStatus.Text = "  unequipped all"
end)

sectionLabel(petsP, "EQUIP BY EXACT NAME (custom)")
local petBox = Instance.new("TextBox")
petBox.Size = UDim2.new(1,0,0,32)
petBox.BackgroundColor3 = Color3.fromRGB(28,28,34); petBox.BorderSizePixel = 0
petBox.PlaceholderText = "e.g. Dark Soul Birdie"; petBox.Text = ""
petBox.TextColor3 = Color3.fromRGB(230,230,236); petBox.PlaceholderColor3 = Color3.fromRGB(120,120,135)
petBox.Font = Enum.Font.Gotham; petBox.TextSize = 12; petBox.ClearTextOnFocus = false
petBox.Parent = petsP
Instance.new("UICorner", petBox).CornerRadius = UDim.new(0, 7)
makeBtn(petsP, "Equip Name from Box", function()
    local v = petBox.Text:gsub("^%s+", ""):gsub("%s+$", "")
    if #v > 0 then
        local ok = equipPet(v)
        petStatus.Text = ok and ("  sent equip: " .. v) or "  failed"
    end
end)

-- TP
local tpP = pages["TP"]
for _, w in ipairs(WORLD_TP) do
    makeBtn(tpP, "TP: " .. w, function()
        if not tpToWorld(w) then tpToWorld(w:match("^(%a+)")) end
    end)
end
makeBtn(tpP, "TP: Next Checkpoint", function() tpNextStage() end)

-- VIS
local visP = pages["Vis"]
makeBtn(visP, "ESP Orbs: OFF", function(b) toggle(b, "espOrb", "ESP Orbs", function() refreshEsp() end) end)
makeBtn(visP, "ESP Hoops: OFF", function(b) toggle(b, "espHoop", "ESP Hoops", function() refreshEsp() end) end)
makeBtn(visP, "ESP Players: OFF", function(b) toggle(b, "espPlayer", "ESP Players", function() refreshEsp() end) end)

-- init
openBtn.MouseButton1Click:Connect(function()
    panel.Visible = not panel.Visible
    if panel.Visible then refreshRbStatus(); refreshHatchStatus() end
end)
gui.AncestryChanged:Connect(function(_, parent)
    if not parent then
        stopOrbLoop(); stopHoopLoop(); stopRebirthLoop(); stopHatchLoop()
        clearEsp(); if espGui then espGui:Destroy() end
    end
end)

showTab("Main")
repaintOrbs(); repaintMaps(); repaintCrystals(); refreshPickLbl(); refreshRbStatus(); refreshHatchStatus()
applyStats(); resolveRemotes()
print("[martin hub] loaded — trade desync fix added, ☰ to open")
