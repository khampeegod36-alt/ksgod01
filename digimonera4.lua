-- ================================================
-- DIGIMON ERA AUTO FARM + AUTO FEED + AUTO EXPLORE + DUNGEON LOOP
-- SINGLE UI + TELEPORT QUEUE (FULL VERSION)
-- ================================================

local Players = game:GetService("Players")
local PathfindingService = game:GetService("PathfindingService")
local StarterGui = game:GetService("StarterGui")
local VirtualUser = game:GetService("VirtualUser")
local VirtualInputManager = game:GetService("VirtualInputManager")
local CoreGui = game:GetService("CoreGui")


local player = Players.LocalPlayer

-- CONFIG
local DIGIMON_SCRIPT_URL =
    "https://raw.githubusercontent.com/khampeegod36-alt/ksgod01/refs/heads/main/digimonEra3.lua"

local UI_NAME = "DigimonEra_MultiUI"
local MIN_DISTANCE = 30
local ARRIVAL_DISTANCE = 4
local MAX_WALK_TIME = 10
local SEARCH_RADIUS = 500

local AUTO_FARM = false
local AUTO_CHEST = false
local AUTO_DROPS = false
local AUTO_HEAL = false
local AUTO_FEED = false
local AUTO_EXPLORE = false

local HEAL_DROP_AMOUNT = 3000

local visited = {}
local unreachableTargets = {}
local openedChests = {}
local collectedDrops = {}

-- SINGLE INSTANCE
local function hasExistingUI()
    local function exists(parent)
        return parent and parent:FindFirstChild(UI_NAME) ~= nil
    end

    if exists(CoreGui) then return true end

    local pGui = player:FindFirstChild("PlayerGui")
    if exists(pGui) then return true end

    if gethui then
        local ok, hui = pcall(gethui)
        if ok and exists(hui) then return true end
    end

    return false
end

if hasExistingUI() then
    return
end

-- TELEPORT QUEUE
local function setupTeleportQueue()
    local q = queue_on_teleport or queueonteleport
        or queue_on_tp or queueontp

    if not q then
        warn("[Digimon Era] queue_on_teleport unavailable")
        return
    end

    local code = [[
        task.wait(10)
        local CoreGui = game:GetService("CoreGui")
        if CoreGui:FindFirstChild("DigimonEra_MultiUI") then
            return
        end
        pcall(function()
            local src = game:HttpGet("]] .. DIGIMON_SCRIPT_URL .. [[", true)
            local fn = loadstring(src)
            if fn then fn() end
        end)
    ]]

    pcall(q, code)
end

-- ตั้งคิวใหม่ทุกครั้งที่สคริปต์เริ่มในเซิร์ฟเวอร์ใหม่
setupTeleportQueue()

-- ANTI AFK
player.Idled:Connect(function()
    pcall(function()
        VirtualUser:Button2Down(
            Vector2.new(0, 0),
            workspace.CurrentCamera.CFrame
        )
        task.wait(1)
        VirtualUser:Button2Up(
            Vector2.new(0, 0),
            workspace.CurrentCamera.CFrame
        )
    end)
end)

-- NOTIFICATION
local function sendNotification(title, text)
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = title,
            Text = text,
            Duration = 2
        })
    end)
end

-- ================================================
-- UI
-- ================================================

local screenGui = Instance.new("ScreenGui")
screenGui.Name = UI_NAME
screenGui.ResetOnSpawn = false

if gethui then
    local ok, hui = pcall(gethui)
    if ok and hui then
        screenGui.Parent = hui
    else
        screenGui.Parent = CoreGui
    end
elseif syn and syn.protect_gui then
    syn.protect_gui(screenGui)
    screenGui.Parent = CoreGui
else
    local ok = pcall(function()
        screenGui.Parent = CoreGui
    end)
    if not ok then
        screenGui.Parent = player:WaitForChild("PlayerGui")
    end
end

local mainFrame = Instance.new("Frame")
mainFrame.Name = "MainFrame"
mainFrame.Size = UDim2.new(0, 210, 0, 420)
mainFrame.Position = UDim2.new(0.75, 0, 0.2, 0)
mainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
mainFrame.Active = true
mainFrame.Draggable = true
mainFrame.ClipsDescendants = true
mainFrame.Parent = screenGui

local frameCorner = Instance.new("UICorner")
frameCorner.CornerRadius = UDim.new(0, 10)
frameCorner.Parent = mainFrame

local titleLabel = Instance.new("TextLabel")
titleLabel.Size = UDim2.new(0.8, 0, 0, 30)
titleLabel.Position = UDim2.new(0.05, 0, 0, 0)
titleLabel.BackgroundTransparency = 1
titleLabel.Text = "Digimon Era Control"
titleLabel.TextColor3 = Color3.new(1, 1, 1)
titleLabel.TextSize = 14
titleLabel.Font = Enum.Font.SourceSansBold
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.Parent = mainFrame

local minimizeBtn = Instance.new("TextButton")
minimizeBtn.Name = "MinimizeBtn"
minimizeBtn.Size = UDim2.new(0, 24, 0, 24)
minimizeBtn.Position = UDim2.new(0.85, 0, 0.02, 0)
minimizeBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
minimizeBtn.TextColor3 = Color3.new(1, 1, 1)
minimizeBtn.TextSize = 16
minimizeBtn.Font = Enum.Font.SourceSansBold
minimizeBtn.Text = "-"
minimizeBtn.Parent = mainFrame

local minCorner = Instance.new("UICorner")
minCorner.CornerRadius = UDim.new(0, 5)
minCorner.Parent = minimizeBtn

local contentContainer = Instance.new("Frame")
contentContainer.Name = "ContentContainer"
contentContainer.Size = UDim2.new(1, 0, 0, 385)
contentContainer.Position = UDim2.new(0, 0, 0, 30)
contentContainer.BackgroundTransparency = 1
contentContainer.Parent = mainFrame

local isMinimized = false
minimizeBtn.MouseButton1Click:Connect(function()
    isMinimized = not isMinimized

    if isMinimized then
        mainFrame.Size = UDim2.new(0, 210, 0, 30)
        contentContainer.Visible = false
        minimizeBtn.Text = "+"
    else
        mainFrame.Size = UDim2.new(0, 210, 0, 420)
        contentContainer.Visible = true
        minimizeBtn.Text = "-"
    end
end)

local function createToggleButton(name, pos, defaultText)
    local btn = Instance.new("TextButton")
    btn.Name = name
    btn.Size = UDim2.new(0.9, 0, 0, 34)
    btn.Position = pos
    btn.BackgroundColor3 = Color3.fromRGB(220, 53, 69)
    btn.TextColor3 = Color3.new(1, 1, 1)
    btn.TextSize = 13
    btn.Font = Enum.Font.SourceSansBold
    btn.Text = defaultText
    btn.Parent = contentContainer

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = btn

    return btn
end

local farmBtn = createToggleButton(
    "FarmBtn", UDim2.new(0.05, 0, 0.01, 0), "Auto Farm: OFF"
)
local chestBtn = createToggleButton(
    "ChestBtn", UDim2.new(0.05, 0, 0.13, 0), "Auto Chest: OFF"
)
local dropBtn = createToggleButton(
    "DropBtn", UDim2.new(0.05, 0, 0.25, 0), "Auto Drops: OFF"
)
local healBtn = createToggleButton(
    "HealBtn", UDim2.new(0.05, 0, 0.37, 0), "Auto Heal: OFF"
)
local feedBtn = createToggleButton(
    "FeedBtn", UDim2.new(0.05, 0, 0.49, 0), "Auto Feed: OFF"
)

local exploreBtn = createToggleButton(
    "ExploreBtn",
    UDim2.new(0.05, 0, 0.61, 0),
    "Auto Explore: OFF"
)
local dungeonBtn = createToggleButton(
    "DungeonLoopBtn",
    UDim2.new(0.05, 0, 0.73, 0),
    "Dungeon Loop: OFF"
)

local env = getgenv and getgenv() or _G
env.DigimonEraDungeonLoop = env.DigimonEraDungeonLoop == true
local AUTO_DUNGEON_LOOP = env.DigimonEraDungeonLoop

-- HEAL SETTING UI
local healFrame = Instance.new("Frame")
healFrame.Name = "HealSettingsFrame"
healFrame.Size = UDim2.new(0.9, 0, 0, 30)
healFrame.Position = UDim2.new(0.05, 0, 0.85, 0)
healFrame.BackgroundTransparency = 1
healFrame.Parent = contentContainer

local healLabel = Instance.new("TextLabel")
healLabel.Size = UDim2.new(0.65, 0, 1, 0)
healLabel.BackgroundTransparency = 1
healLabel.Text = "Heal Drop >= :"
healLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
healLabel.TextSize = 12
healLabel.Font = Enum.Font.SourceSansBold
healLabel.TextXAlignment = Enum.TextXAlignment.Left
healLabel.Parent = healFrame

local healInput = Instance.new("TextBox")
healInput.Name = "HealInput"
healInput.Size = UDim2.new(0.32, 0, 1, 0)
healInput.Position = UDim2.new(0.68, 0, 0, 0)
healInput.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
healInput.TextColor3 = Color3.new(1, 1, 1)
healInput.TextSize = 13
healInput.Font = Enum.Font.SourceSansBold
healInput.Text = tostring(HEAL_DROP_AMOUNT)
healInput.ClearTextOnFocus = false
healInput.Parent = healFrame

local inputCorner = Instance.new("UICorner")
inputCorner.CornerRadius = UDim.new(0, 5)
inputCorner.Parent = healInput

healInput.FocusLost:Connect(function()
    local val = tonumber(healInput.Text)

    if val and val > 0 then
        HEAL_DROP_AMOUNT = math.floor(val)
        healInput.Text = tostring(HEAL_DROP_AMOUNT)
        sendNotification("Auto Heal Setup", "ตั้งค่า HP ที่ต้องการแล้ว")
    else
        healInput.Text = tostring(HEAL_DROP_AMOUNT)
        sendNotification("Error", "กรุณากรอกตัวเลขที่ถูกต้อง")
    end
end)

local function updateButton(btn, enabled, label)
    btn.Text = label .. (enabled and ": ON" or ": OFF")
    btn.BackgroundColor3 = enabled
        and Color3.fromRGB(40, 167, 69)
        or Color3.fromRGB(220, 53, 69)
end

if exploreBtn then updateButton(exploreBtn, AUTO_EXPLORE, "Auto Explore") end
if dungeonBtn then updateButton(dungeonBtn, AUTO_DUNGEON_LOOP, "Dungeon Loop") end

-- ================================================
-- TOGGLE BUTTON EVENTS
-- ================================================

if farmBtn then
    farmBtn.MouseButton1Click:Connect(function()
        AUTO_FARM = not AUTO_FARM
        updateButton(farmBtn, AUTO_FARM, "Auto Farm")

        if AUTO_FARM then
            task.spawn(enableFarmModes)
        else
            table.clear(visited)
        end
    end)
end

if chestBtn then
    chestBtn.MouseButton1Click:Connect(function()
        AUTO_CHEST = not AUTO_CHEST
        updateButton(chestBtn, AUTO_CHEST, "Auto Chest")

        if not AUTO_CHEST then
            table.clear(openedChests)
        end
    end)
end

if dropBtn then
    dropBtn.MouseButton1Click:Connect(function()
        AUTO_DROPS = not AUTO_DROPS
        updateButton(dropBtn, AUTO_DROPS, "Auto Drops")

        if not AUTO_DROPS then
            table.clear(collectedDrops)
        end
    end)
end

if healBtn then
    healBtn.MouseButton1Click:Connect(function()
        AUTO_HEAL = not AUTO_HEAL
        updateButton(healBtn, AUTO_HEAL, "Auto Heal")
    end)
end

if feedBtn then
    feedBtn.MouseButton1Click:Connect(function()
        AUTO_FEED = not AUTO_FEED
        updateButton(feedBtn, AUTO_FEED, "Auto Feed")
    end)
end

if exploreBtn then
    exploreBtn.MouseButton1Click:Connect(function()
        AUTO_EXPLORE = not AUTO_EXPLORE
        updateButton(exploreBtn, AUTO_EXPLORE, "Auto Explore")
        sendNotification(
            "Auto Explore",
            AUTO_EXPLORE and "เปิดแล้ว" or "ปิดแล้ว"
        )
    end)
end

if dungeonBtn then
    dungeonBtn.MouseButton1Click:Connect(function()
        AUTO_DUNGEON_LOOP = not AUTO_DUNGEON_LOOP
        env.DigimonEraDungeonLoop = AUTO_DUNGEON_LOOP
        updateButton(dungeonBtn, AUTO_DUNGEON_LOOP, "Dungeon Loop")

        sendNotification(
            "Dungeon Loop",
            AUTO_DUNGEON_LOOP and "เปิดระบบวนดันเจี้ยน" or "ปิดระบบวนดันเจี้ยน"
        )
    end)
end

sendNotification("Digimon Era Control", "โหลด UI สำเร็จแล้ว!")

-- ================================================
-- AUTO FARM MODES
-- ================================================

local function enableFarmModes()
    local pGui = player:WaitForChild("PlayerGui")
    local hud = pGui:WaitForChild("HUD")

    local controller = hud:WaitForChild("PC_Controller")
    local partyFrame = controller:WaitForChild("PartyFrame")
    local status = partyFrame:WaitForChild("StatusFrame")

    local aggressive = status:FindFirstChild("Aggressive")

    if aggressive and aggressive.Visible and aggressive.Active then
        local ok, err = pcall(function()
            firesignal(aggressive.Activated)
        end)

        if ok then
            print("[Auto Farm] กด Aggressive แล้ว")
        else
            warn("[Auto Farm] กด Aggressive ไม่สำเร็จ:", err)
        end
    else
        warn("[Auto Farm] ไม่พบปุ่ม Aggressive ที่พร้อมใช้งาน")
    end

    local autoSkill = status:FindFirstChild("AutoSkill")
    local state = autoSkill and autoSkill:FindFirstChild("Status")

    if not autoSkill or not state or not state:IsA("TextLabel") then
        warn("[Auto Farm] ไม่พบสถานะ Auto Skill")
        return
    end

    if state.Text == "OFF" then
        if autoSkill.Visible and autoSkill.Active then
            local ok, err = pcall(function()
                firesignal(autoSkill.Activated)
            end)

            if ok then
                print("[Auto Farm] ส่งคำสั่งเปิด Auto Skill แล้ว")
            else
                warn("[Auto Farm] เปิด Auto Skill ไม่สำเร็จ:", err)
            end
        else
            warn("[Auto Farm] ปุ่ม Auto Skill ยังไม่พร้อมใช้งาน")
        end
    else
        print("[Auto Farm] Auto Skill เปิดอยู่แล้ว")
    end
end

-- ================================================
-- AUTO FEED
-- ================================================

local function getCaptureFolder()
    return workspace:FindFirstChild("ClientCaptures")
end

local function getCapturePosition(capture)
    if not capture or not capture.Parent then return nil end

    local ok, pos = pcall(function()
        return capture:GetPivot().Position
    end)

    return ok and pos or nil
end

local function getCaptureName(capture)
    local gui = capture and capture:FindFirstChild("CatchableGui", true)
    local label = gui and gui:FindFirstChild("DigimonName", true)

    if label and label:IsA("TextLabel") then
        return label.Text
    end

    return capture and capture.Name or "Unknown"
end

local function findNearestCapture(rootPart)
    local folder = getCaptureFolder()
    if not folder or not rootPart then return nil end

    local nearest, nearestDistance = nil, math.huge

    for _, capture in ipairs(folder:GetChildren()) do
        local gui = capture:FindFirstChild("CatchableGui", true)
        local nameLabel = gui and gui:FindFirstChild("DigimonName", true)
        local pos = getCapturePosition(capture)

        if nameLabel and pos then
            local distance = (pos - rootPart.Position).Magnitude

            if distance < nearestDistance then
                nearest = capture
                nearestDistance = distance
            end
        end
    end

    return nearest
end

local function getCaptureMain()
    local pGui = player:FindFirstChild("PlayerGui")
    local billboard = pGui and pGui:FindFirstChild("CaptureBillboard")

    return billboard and billboard:FindFirstChild("MainFrame")
end

local function fireButton(btn)
    if not btn or not btn.Parent or not btn.Visible then
        return false
    end

    local fired = false

    pcall(function()
        if getconnections then
            for _, conn in ipairs(getconnections(btn.Activated)) do
                if conn.Enabled ~= false then
                    local ok = pcall(function()
                        conn:Fire()
                    end)

                    if ok then
                        fired = true
                    end
                end
            end
        end
    end)

    if not fired then
        pcall(function()
            if firesignal then
                firesignal(btn.Activated)
                fired = true
            end
        end)
    end

    return fired
end

local function teleportToCapture(capture, rootPart)
    local pos = getCapturePosition(capture)
    if not pos or not rootPart then return false end

    if (rootPart.Position - pos).Magnitude > 7 then
        local ok = pcall(function()
            rootPart.CFrame = CFrame.new(pos + Vector3.new(0, 2, 0))
        end)

        if not ok then return false end
        task.wait(0.2)
    end

    return true
end

local function tryOpenCapture(capture, rootPart)
    if not capture or not capture.Parent then return end

    pcall(function()
        if fireproximityprompt then
            for _, obj in ipairs(capture:GetDescendants()) do
                if obj:IsA("ProximityPrompt") then
                    fireproximityprompt(obj)
                end
            end
        end
    end)

    pcall(function()
        if not firetouchinterest or not rootPart then return end

        local parts = {}

        if capture:IsA("BasePart") then
            table.insert(parts, capture)
        else
            for _, obj in ipairs(capture:GetDescendants()) do
                if obj:IsA("BasePart") then
                    table.insert(parts, obj)
                end
            end
        end

        local part = parts[1]

        if part then
            firetouchinterest(rootPart, part, 0)
            task.wait(0.03)
            firetouchinterest(rootPart, part, 1)
        end
    end)
end

local function selectFoodAndFeed()
    local main = getCaptureMain()
    if not main or not main.Visible then return false end

    local scrolling = main:FindFirstChild("ScrollingFrame", true)
    local feedButton = main:FindFirstChild("FeedButton", true)

    if not scrolling or not feedButton then return false end

    local chosen = nil

    for _, obj in ipairs(scrolling:GetDescendants()) do
        if obj:IsA("TextButton") or obj:IsA("ImageButton") then
            local itemName = obj:FindFirstChild("ItemName", true)
            local amountLabel = obj:FindFirstChild("ItemAmount", true)
            local amount = amountLabel
                and tonumber(tostring(amountLabel.Text):match("%d+"))

            if itemName and amount and amount > 0 and obj.Visible then
                chosen = obj
                break
            end
        end
    end

    if not chosen then return false end
    if not fireButton(chosen) then return false end

    task.wait(0.15)

    if not AUTO_FEED then return false end

    main = getCaptureMain()
    feedButton = main and main:FindFirstChild("FeedButton", true)

    if not main or not main.Visible or not feedButton then
        return false
    end

    return fireButton(feedButton)
end

local function processAutoFeed(rootPart)
    if not AUTO_FEED or not rootPart then return false end

    local capture = findNearestCapture(rootPart)
    if not capture then return false end

    local targetName = getCaptureName(capture)
    sendNotification("Auto Feed", "กำลังไปหา " .. targetName)

    while AUTO_FEED and capture.Parent do
        local character = player.Character
        local currentRoot = character
            and character:FindFirstChild("HumanoidRootPart")

        if not currentRoot then break end

        teleportToCapture(capture, currentRoot)

        local main = getCaptureMain()

        if not main or not main.Visible then
            tryOpenCapture(capture, currentRoot)
            task.wait(0.25)
        else
            local ok, result = pcall(selectFoodAndFeed)

            if not ok then
                warn("[Auto Feed]", result)
            end

            task.wait(0.6)
        end
    end

    sendNotification("Auto Feed", "เป้าหมายหายไปแล้ว")
    return true
end

-- ================================================
-- AUTO EXPLORE
-- ================================================


local EXPLORE_CHECK_INTERVAL = 2
local INVESTIGATE_COOLDOWN = 5
local lastInvestigateTime = 0
local exploringNow = false

local function getMapFrame()
    local pg = player:FindFirstChild("PlayerGui")
    local main = pg and pg:FindFirstChild("Main")
    return main and main:FindFirstChild("MapFrame")
end

local function readExplorePercent(room)
    local label = room:FindFirstChild("ExploreDegree")
    if not label then return nil end

    return tonumber(tostring(label.Text):match("(%d+)%s*%%"))
end

local function openMapForExplore()
    local pg = player:FindFirstChild("PlayerGui")
    local hud = pg and pg:FindFirstChild("HUD")
    local buttons = hud and hud:FindFirstChild("ButtonsFrame")
    local teleport = buttons and buttons:FindFirstChild("TeleportButton")
    local imageButton = teleport and teleport:FindFirstChild("ImageButton")
    local mapFrame = getMapFrame()

    if not mapFrame then return false end
    if mapFrame.Visible then return true end
    if not imageButton then return false end

    fireButton(imageButton)
    task.wait(0.5)

    return mapFrame.Visible
end

local function findCurrentRoom(scrolling)
    for _, layer in ipairs(scrolling:GetChildren()) do
        if layer.Name:match("^Map%d+$") then
            for _, room in ipairs(layer:GetChildren()) do
                if room:IsA("TextButton")
                    and room.Name:match("^Layer_%d+_SmallMap_%d+$") then

                    local degree = readExplorePercent(room)
                    local investigate = room:FindFirstChild("Investigate")

                    if degree ~= nil and investigate
                        and not investigate.Visible then
                        return room, layer, degree
                    end
                end
            end
        end
    end

    return nil, nil, nil
end

-- ตรวจว่าห้องปัจจุบันยังมีม่อนมีชีวิตที่เดินไปถึงได้หรือไม่
-- ม่อนเก่าที่อยู่อีกฝั่งกำแพงและหาเส้นทางไม่พบ จะไม่ล็อก Auto Explore ค้างไว้
local function hasLivingEnemyInCurrentRoom()
    local digimons = workspace:FindFirstChild("Digimons")
    local enemies = digimons and digimons:FindFirstChild("Enemies")
    local character = player.Character
    local rootPart = character and character:FindFirstChild("HumanoidRootPart")
    if not enemies or not rootPart then return false end

    for _, enemy in ipairs(enemies:GetChildren()) do
        if enemy:IsA("Model") and enemy.Parent == enemies then
            local enemyHumanoid = enemy:FindFirstChildOfClass("Humanoid")
            if not enemyHumanoid or enemyHumanoid.Health > 0 then
                local ok, enemyPos = pcall(function()
                    return enemy:GetPivot().Position
                end)

                if ok then
                    local path = PathfindingService:CreatePath({
                        AgentRadius = 2.5,
                        AgentHeight = 5,
                        AgentCanJump = true,
                        WaypointSpacing = 4
                    })
                    local pathOK = pcall(function()
                        path:ComputeAsync(rootPart.Position, enemyPos)
                    end)

                    if pathOK and path.Status == Enum.PathStatus.Success then
                        return true
                    end
                end
            end
        end
    end

    return false
end

local function findNextRoom(currentLayer, currentRoom)
    local rooms = {}

    for _, room in ipairs(currentLayer:GetChildren()) do
        if room:IsA("TextButton")
            and room.Name:match("^Layer_%d+_SmallMap_%d+$")
            and room ~= currentRoom
            and room.Visible
            and room.Active then

            local locked = room:FindFirstChild("LockedFrame")
            if not (locked and locked.Visible) then
                table.insert(rooms, room)
            end
        end
    end

    table.sort(rooms, function(a, b)
        return a.Name < b.Name
    end)

    for _, room in ipairs(rooms) do
        local degree = readExplorePercent(room)
        if degree == nil or degree < 100 then
            return room
        end
    end

    return nil
end

task.spawn(function()
    while screenGui.Parent do
        if AUTO_EXPLORE and not exploringNow then
            exploringNow = true

            local ok, err = pcall(function()
                if tick() - lastInvestigateTime < INVESTIGATE_COOLDOWN then
                    return
                end

                -- ห้ามเปลี่ยนห้องหากยังมีม่อนมีชีวิตในโฟลเดอร์ศัตรูปัจจุบัน
                if hasLivingEnemyInCurrentRoom() then
                    return
                end

                if not openMapForExplore() then return end

                local mapFrame = getMapFrame()
                local scrolling = mapFrame
                    and mapFrame:FindFirstChild("ScrollingFrame")

                if not scrolling then return end

                local currentRoom, currentLayer, percent =
                    findCurrentRoom(scrolling)

                if not currentRoom or not percent or percent < 100 then
                    return
                end

                local nextRoom = findNextRoom(currentLayer, currentRoom)

                if nextRoom then
                    sendNotification(
                        "Auto Explore",
                        "กำลังเข้าห้อง " .. nextRoom.Name
                    )

                    if fireButton(nextRoom) then
                        lastInvestigateTime = tick()
                        task.wait(2)
                    end
                else
                    print(
                        "[Auto Explore] ไม่พบห้องถัดไปใน",
                        currentLayer.Name
                    )
                end
            end)

            if not ok then
                warn("[Auto Explore]", err)
            end

            exploringNow = false
        end

        task.wait(EXPLORE_CHECK_INTERVAL)
    end
end)
-- ================================================
-- AUTO HEAL
-- ================================================

local function triggerHealKeyboard()
    pcall(function()
        VirtualInputManager:SendKeyEvent(
            true, Enum.KeyCode.Four, false, game
        )
        task.wait(0.08)
        VirtualInputManager:SendKeyEvent(
            false, Enum.KeyCode.Four, false, game
        )
    end)
end

local function triggerHealUI()
    local pGui = player:FindFirstChild("PlayerGui")
    if not pGui then return false end

    for _, obj in ipairs(pGui:GetDescendants()) do
        if obj:IsA("TextButton") or obj:IsA("ImageButton") then
            local text = ""

            pcall(function()
                text = tostring(obj.Text)
            end)

            if text == "4" then
                local ok = pcall(function()
                    obj:Activate()
                end)

                if ok then return true end
            end
        end
    end

    return false
end

local function getDigimonHP()
    local pGui = player:FindFirstChild("PlayerGui")
    if not pGui then return nil, nil end

    for _, gui in ipairs(pGui:GetDescendants()) do
        if gui:IsA("TextLabel") and gui.Visible and gui.Text ~= "" then
            local text = gui.Text:gsub(",", "")
            local cur, max = text:match("(%d+)%s*/%s*(%d+)")

            if cur and max then
                local cVal, mVal = tonumber(cur), tonumber(max)

                if cVal and mVal and mVal > 100 then
                    return cVal, mVal
                end
            end
        end
    end

    return nil, nil
end

task.spawn(function()
    local lastHealTime = 0

    while screenGui.Parent do
        if AUTO_HEAL then
            pcall(function()
                local curHP, maxHP = getDigimonHP()

                if curHP and maxHP then
                    local missingHP = maxHP - curHP

                    if missingHP >= HEAL_DROP_AMOUNT
                        and tick() - lastHealTime >= 2 then

                        triggerHealKeyboard()
                        task.wait(0.15)
                        triggerHealUI()
                        lastHealTime = tick()

                        sendNotification(
                            "Auto Heal",
                            "HP ลด " .. math.floor(missingHP)
                        )
                    end
                end
            end)
        end

        task.wait(0.2)
    end
end)

-- ================================================
-- AUTO CHEST
-- ================================================

local function findAndTeleportToChest(rootPart)
    if not AUTO_CHEST or not rootPart then return false end

    local closestChest, closestDist = nil, SEARCH_RADIUS

    for _, obj in ipairs(workspace:GetDescendants()) do
        if (obj:IsA("Model") or obj:IsA("BasePart"))
            and not openedChests[obj] then

            local name = obj.Name:lower()

            if name:find("chest") or name:find("rewardbox")
                or name:find("treasure") then

                local ok, pos = pcall(function()
                    return obj:GetPivot().Position
                end)

                if ok then
                    local dist = (pos - rootPart.Position).Magnitude

                    if dist < closestDist then
                        closestChest, closestDist = obj, dist
                    end
                end
            end
        end
    end

    if not closestChest or not AUTO_CHEST then return false end

    openedChests[closestChest] = true
    sendNotification("เจอกล่อง!", "กำลังเปิดกล่อง...")

    local ok, chestPos = pcall(function()
        return closestChest:GetPivot().Position
    end)

    if not ok then return false end

    for i = 1, 12 do
        if not AUTO_CHEST or not closestChest.Parent then break end

        pcall(function()
            rootPart.CFrame = CFrame.new(
                chestPos + Vector3.new(0, 0.5, 0)
            )
        end)

        for _, obj in ipairs(closestChest:GetDescendants()) do
            if obj:IsA("ProximityPrompt") then
                pcall(function()
                    obj.RequiresLineOfSight = false
                    obj.MaxActivationDistance = 500
                    obj.HoldDuration = 0

                    if fireproximityprompt then
                        fireproximityprompt(obj)
                    end
                end)
            elseif obj:IsA("BasePart") then
                pcall(function()
                    obj.CanCollide = false

                    if firetouchinterest then
                        firetouchinterest(rootPart, obj, 0)
                        task.wait(0.01)
                        firetouchinterest(rootPart, obj, 1)
                    end
                end)
            end
        end

        task.wait(0.1)
    end

    return true
end

-- ================================================
-- AUTO DROPS
-- ================================================

local function findAndTeleportToDrop(rootPart)
    if not AUTO_DROPS or not rootPart then return false end

    local container = workspace:FindFirstChild("ClientDrops")
        or workspace:FindFirstChild("Drops")

    if not container then return false end

    local closestDrop, closestDist = nil, SEARCH_RADIUS

    for _, item in ipairs(container:GetChildren()) do
        if (item:IsA("Model") or item:IsA("BasePart")
            or item:IsA("Tool")) and not collectedDrops[item] then

            local name = item.Name:lower()

            if not name:find("orb") and not name:find("chest")
                and not name:find("rewardbox") then

                local ok, pos = pcall(function()
                    return item:GetPivot().Position
                end)

                if ok then
                    local dist = (pos - rootPart.Position).Magnitude

                    if dist < closestDist then
                        closestDrop, closestDist = item, dist
                    end
                end
            end
        end
    end

    if not closestDrop or not AUTO_DROPS then return false end

    collectedDrops[closestDrop] = true
    sendNotification("Auto Drops", "วาร์ปไปเก็บ " .. closestDrop.Name)

    local ok, pos = pcall(function()
        return closestDrop:GetPivot().Position
    end)

    if not ok then return false end

    pcall(function()
        rootPart.CFrame = CFrame.new(pos)
    end)

    task.wait(0.1)

    local parts = {}

    if closestDrop:IsA("BasePart") then
        table.insert(parts, closestDrop)
    else
        for _, obj in ipairs(closestDrop:GetDescendants()) do
            if obj:IsA("BasePart") then
                table.insert(parts, obj)
            end
        end
    end

    for _, part in ipairs(parts) do
        pcall(function()
            part.CanCollide = false

            if firetouchinterest then
                firetouchinterest(rootPart, part, 0)
                task.wait(0.02)
                firetouchinterest(rootPart, part, 1)
            end
        end)
    end

    for _, obj in ipairs(closestDrop:GetDescendants()) do
        if obj:IsA("ProximityPrompt") then
            pcall(function()
                obj.RequiresLineOfSight = false
                obj.HoldDuration = 0

                if fireproximityprompt then
                    fireproximityprompt(obj)
                end
            end)
        end
    end

    task.wait(0.2)
    return true
end

-- ================================================
-- PATHFINDING (AUTO FARM)
-- ================================================

local function walkToTarget(character, humanoid, targetPosition)
    local rootPart = character and character:FindFirstChild("HumanoidRootPart")
    if not rootPart or not humanoid or not targetPosition then
        return false
    end

    local path = PathfindingService:CreatePath({
        AgentRadius = 2.5,
        AgentHeight = 5,
        AgentCanJump = true,
        WaypointSpacing = 4
    })

    local success = pcall(function()
        path:ComputeAsync(rootPart.Position, targetPosition)
    end)

    -- ถ้าหาเส้นทางไม่ได้ ห้ามสั่งเดินตรงชนกำแพง ให้ยกเลิกเป้าหมายนี้
    if not success or path.Status ~= Enum.PathStatus.Success then
        pcall(function() humanoid:MoveTo(rootPart.Position) end)
        return false
    end

    for _, waypoint in ipairs(path:GetWaypoints()) do
        if not AUTO_FARM or not character.Parent then
            pcall(function() humanoid:MoveTo(rootPart.Position) end)
            return false
        end

        if waypoint.Action == Enum.PathWaypointAction.Jump then
            humanoid.Jump = true
        end

        local finished = false
        local conn = humanoid.MoveToFinished:Connect(function(reached)
            finished = reached
        end)

        humanoid:MoveTo(waypoint.Position)
        local started = tick()
        while not finished and tick() - started < 1.5 and AUTO_FARM do
            task.wait(0.05)
        end
        conn:Disconnect()

        if not finished then
            pcall(function() humanoid:MoveTo(rootPart.Position) end)
            return false
        end
    end

    return true
end

-- ================================================
-- AUTO DUNGEON LOOP (WITH GUARD LOCK)
-- ================================================

local LOBBY_PLACE_ID = 84773733171614
local DUNGEON_PLACE_ID = 112998674138179
local DUNGEON_DURATION = 60

local function walkIntoNearestLift()
    local folder = workspace:FindFirstChild("MatchmakingZones")
    if not folder then return false end

    local character = player.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")

    if not root or not humanoid then return false end

    local nearest, bestDistance

    for i = 1, 4 do
        local lift = folder:FindFirstChild("StartLift" .. i)

        if lift then
            local ok, pos = pcall(function()
                return lift:GetPivot().Position
            end)

            if ok then
                local distance = (root.Position - pos).Magnitude

                if not bestDistance or distance < bestDistance then
                    nearest = lift
                    bestDistance = distance
                end
            end
        end
    end

    if not nearest then return false end

    local targetPos = nearest:GetPivot().Position
    humanoid:MoveTo(targetPos)

    local started = tick()

    while AUTO_DUNGEON_LOOP and tick() - started < 15 do
        if not root.Parent then return false end

        if (root.Position - targetPos).Magnitude < 8 then
            return true
        end

        task.wait(0.25)
    end

    return false
end

local function selectForestAndStart()
    local pg = player:WaitForChild("PlayerGui", 10)
    local main = pg and pg:WaitForChild("Main", 10)
    local chooseMap = main and main:WaitForChild("ChooseMap", 20)

    if not chooseMap then return false end

    local mapList = chooseMap:FindFirstChild("MapChooseScrolling")
    local forest = mapList and mapList:FindFirstChild("Forest")

    if not forest or not fireButton(forest) then
        return false
    end

    task.wait(0.5)

    chooseMap = main:FindFirstChild("ChooseMap")
    local levelList = chooseMap
        and chooseMap:FindFirstChild("LevelChooseScrolling")

    if not levelList then return false end

    local levelButton

    for _, obj in ipairs(levelList:GetDescendants()) do
        if obj:IsA("GuiButton") then
            local text = tostring(obj.Text):gsub("%s+", "")

            if text == "61~100"
                or text == "61-100"
                or text == "61–100" then
                levelButton = obj
                break
            end
        end
    end

    if not levelButton or not fireButton(levelButton) then
        warn("[Dungeon Loop] ไม่พบปุ่มระดับ 61-100")
        return false
    end

    task.wait(0.5)

    local mapInfo = main:FindFirstChild("MapInfo")
    local startButton = mapInfo and mapInfo:FindFirstChild("StartButton")

    if not startButton or not fireButton(startButton) then
        return false
    end

    local waiting = main:WaitForChild("TeleportWaiting", 15)
    local secondStart = waiting and waiting:WaitForChild("StartButton", 10)

    if not secondStart then return false end

    task.wait(0.5)

    return fireButton(secondStart)
end

local function runDungeonRound()
    if game.PlaceId == LOBBY_PLACE_ID then
        sendNotification("Dungeon Loop", "กำลังหาลิฟต์เข้า Forest")

        if not walkIntoNearestLift() then
            warn("[Dungeon Loop] เดินเข้าลิฟต์ไม่สำเร็จ")
            return
        end

        task.wait(1)

        if not selectForestAndStart() then
            warn("[Dungeon Loop] เลือกแมพหรือกด Start ไม่สำเร็จ")
        end

        return
    end

    if game.PlaceId == DUNGEON_PLACE_ID then
        sendNotification("Dungeon Loop", "เริ่มฟาร์ม 60 วินาที")

        AUTO_FARM = true
        updateButton(farmBtn, true, "Auto Farm")
        task.spawn(enableFarmModes)

        local started = tick()

        while AUTO_DUNGEON_LOOP
            and tick() - started < DUNGEON_DURATION do
            task.wait(0.25)
        end

        if not AUTO_DUNGEON_LOOP then return end

        sendNotification("Dungeon Loop", "ครบเวลา กำลังกลับล็อบบี้")

        local pg = player:FindFirstChild("PlayerGui")
        local hud = pg and pg:FindFirstChild("HUD")
        local buttons = hud and hud:FindFirstChild("ButtonsFrame")
        local evacuate = buttons and buttons:FindFirstChild("EvacuateButton")
        local imageButton = evacuate and evacuate:FindFirstChild("ImageButton")

        if imageButton then
            fireButton(imageButton)
        else
            warn("[Dungeon Loop] ไม่พบ EvacuateButton")
        end
    end
end

-- ป้องกันการรันรอบดันเจี้ยนซ้ำซ้อน
local dungeonRoundRunning = false

task.spawn(function()
    while screenGui.Parent do
        if AUTO_DUNGEON_LOOP and not dungeonRoundRunning then
            dungeonRoundRunning = true

            local ok, err = pcall(runDungeonRound)

            if not ok then
                warn("[Dungeon Loop]", err)
            end

            dungeonRoundRunning = false
        end

        task.wait(1)
    end
end)

-- ================================================
-- MAIN LOOP (WITH DYNAMIC ENEMIES FOLDER)
-- ================================================
local lastEnemiesFolder = nil

task.spawn(function()
    while screenGui.Parent do
        local character = player.Character
        local humanoid = character
            and character:FindFirstChildOfClass("Humanoid")
        local rootPart = character
            and character:FindFirstChild("HumanoidRootPart")

        -- ค้นหาโฟลเดอร์ศัตรูใหม่ทุกรอบเพื่อป้องกันกรณีฉากเปลี่ยน
        local digimons = workspace:FindFirstChild("Digimons")
        local enemiesFolder = digimons and digimons:FindFirstChild("Enemies")

        -- เมื่อโฟลเดอร์ศัตรูเปลี่ยน ให้ล้างรายการเป้าหมายของฉากเดิม
        if enemiesFolder ~= lastEnemiesFolder then
            lastEnemiesFolder = enemiesFolder
            table.clear(visited)
            table.clear(unreachableTargets)
        end

        if character and humanoid and rootPart and humanoid.Health > 0 then
            local handledFeed = false

            if AUTO_FEED then
                local ok, result = pcall(processAutoFeed, rootPart)
                handledFeed = ok and result == true

                if not ok then
                    warn("[Auto Feed]", result)
                end
            end

            if not handledFeed and not AUTO_FEED then
                local foundChest = findAndTeleportToChest(rootPart)
                local foundDrop = false

                if not foundChest then
                    foundDrop = findAndTeleportToDrop(rootPart)
                end

                if not foundChest and not foundDrop
                    and AUTO_FARM and enemiesFolder then

                    local target, targetDistance = nil, math.huge
                    local myPos = rootPart.Position

                    for _, enemy in ipairs(enemiesFolder:GetChildren()) do
                        if enemy:IsA("Model") and enemy.Parent == enemiesFolder
                            and not visited[enemy]
                            and not unreachableTargets[enemy] then

                            local enemyHumanoid =
                                enemy:FindFirstChildOfClass("Humanoid")

                            if not enemyHumanoid or enemyHumanoid.Health > 0 then
                                local distance =
                                    (enemy:GetPivot().Position - myPos).Magnitude

                                if distance >= MIN_DISTANCE
                                    and distance < targetDistance then

                                    target = enemy
                                    targetDistance = distance
                                end
                            end
                        end
                    end

                    if target and AUTO_FARM then
                        visited[target] = true

                        sendNotification(
                            "เดินไปตีมอนสเตอร์",
                            target.Name
                        )

                        local started = tick()

                        while AUTO_FARM and target.Parent == enemiesFolder
                            and tick() - started < MAX_WALK_TIME do

                            local currentDigimons = workspace:FindFirstChild("Digimons")
                            local currentEnemies = currentDigimons
                                and currentDigimons:FindFirstChild("Enemies")
                            if currentEnemies ~= enemiesFolder then
                                break
                            end

                            local enemyHumanoid =
                                target:FindFirstChildOfClass("Humanoid")

                            if enemyHumanoid and enemyHumanoid.Health <= 0 then
                                break
                            end

                            local targetPos = target:GetPivot().Position
                            local distance =
                                (targetPos - rootPart.Position).Magnitude

                            if distance <= ARRIVAL_DISTANCE then
                                pcall(function()
                                    VirtualUser:ClickButton1(Vector2.new())
                                end)

                                task.wait(0.2)
                            else
                                local reached = walkToTarget(character, humanoid, targetPos)
                                if not reached then
                                    -- ทำเครื่องหมายเป้าหมายที่ไปไม่ถึง แล้วเลือกตัวอื่นในรอบถัดไป
                                    visited[target] = true
                                    unreachableTargets[target] = true
                                    break
                                end
                            end
                        end
                    elseif AUTO_FARM then
                        table.clear(visited)
                        task.wait(1)
                    end
                end
            end
        end

        task.wait(0.2)
    end
end)
