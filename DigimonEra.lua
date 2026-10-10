-- ================================================
-- DIGIMON ERA AUTO FARM
-- SINGLE INSTANCE + AUTO RE-EXECUTE
-- ================================================

local Players = game:GetService("Players")
local PathfindingService = game:GetService("PathfindingService")
local StarterGui = game:GetService("StarterGui")
local VirtualUser = game:GetService("VirtualUser")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CoreGui = game:GetService("CoreGui")

local player = Players.LocalPlayer

-- ================================================
-- CONFIG
-- ================================================

local DIGIMON_SCRIPT_URL =
    "https://raw.githubusercontent.com/khampeegod36-alt/ksgod01/main/DigimonEra.lua"

local UI_NAME = "DigimonEra_MultiUI"
local TELEPORT_LOCK = "DigimonEra_TeleportLock"

-- ================================================
-- ป้องกัน Script รันซ้ำใน Server เดียวกัน
-- ================================================

local function hasExistingUI()

    local found = false

    pcall(function()
        if CoreGui:FindFirstChild(UI_NAME) then
            found = true
        end
    end)

    if found then
        return true
    end

    pcall(function()
        local pGui = player:FindFirstChild("PlayerGui")

        if pGui and pGui:FindFirstChild(UI_NAME) then
            found = true
        end
    end)

    if found then
        return true
    end

    pcall(function()
        if gethui then
            local hui = gethui()

            if hui and hui:FindFirstChild(UI_NAME) then
                found = true
            end
        end
    end)

    return found
end

-- ถ้ามี UI อยู่แล้ว ไม่รันซ้ำ
if hasExistingUI() then
    return
end


-- ================================================
-- AUTO RE-EXECUTE AFTER TELEPORT / DUNGEON
-- SINGLE QUEUE ONLY
-- ================================================

local function setupTeleportQueue()

    local q =
        queue_on_teleport
        or queueonteleport
        or queue_on_tp
        or queueontp

    if not q then
        warn("[Digimon Era] queue_on_teleport not found")
        return false
    end

    local code = [[

        -- ==========================================
        -- TELEPORT LOCK
        -- ต้องสร้างก่อน task.wait()
        -- ==========================================

        local CoreGui =
            game:GetService("CoreGui")

        local LOCK_NAME =
            "DigimonEra_TeleportLock"

        -- ถ้ามี Lock แล้ว
        -- แปลว่ามี Queue ตัวอื่นทำงานอยู่
        if CoreGui:FindFirstChild(LOCK_NAME) then
            return
        end

        -- สร้าง Lock ทันที
        local lock =
            Instance.new("Folder")

        lock.Name = LOCK_NAME
        lock.Parent = CoreGui


        -- ==========================================
        -- รอให้ Dungeon โหลด
        -- ==========================================

        task.wait(10)


        -- ==========================================
        -- เช็ค UI อีกครั้งก่อนโหลด
        -- ==========================================

        local alreadyRunning = false

        pcall(function()

            if CoreGui:FindFirstChild(
                "DigimonEra_MultiUI"
            ) then

                alreadyRunning = true

            end

        end)


        if alreadyRunning then
            return
        end


        -- ==========================================
        -- LOAD SCRIPT
        -- ==========================================

        pcall(function()

            local src =
                game:HttpGet(
                    "]] .. DIGIMON_SCRIPT_URL .. [[",
                    true
                )

            local fn =
                loadstring(src)

            if not fn then
                error("loadstring failed")
            end

            fn()

        end)

    ]]


    local ok, err =
        pcall(function()

            q(code)

        end)


    if not ok then

        warn(
            "[Digimon Era] Queue failed:",
            err
        )

        return false

    end


    print(
        "[Digimon Era] Teleport queue armed"
    )

    return true
end


-- ================================================
-- สำคัญมาก
-- Queue แค่ครั้งเดียว
-- ไม่มี while 15 วินาทีแล้ว
-- ================================================

if not getgenv().DigimonEraQueueInstalled then

    getgenv().DigimonEraQueueInstalled = true

    setupTeleportQueue()

end


-- ================================================
-- GAME CONFIGURATION
-- ================================================

local MIN_DISTANCE = 30
local ARRIVAL_DISTANCE = 4
local MAX_WALK_TIME = 10

local AUTO_FARM = false
local AUTO_CHEST = false
local AUTO_DROPS = false
local AUTO_HEAL = false
local AUTO_FEED = false

local HEAL_DROP_AMOUNT = 3000
local SEARCH_RADIUS = 500

local visited = {}
local openedChests = {}
local collectedDrops = {}


-- ================================================
-- ANTI AFK
-- ================================================

player.Idled:Connect(function()

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


-- ================================================
-- NOTIFICATION
-- ================================================

local function sendNotification(title, text)

    pcall(function()

        StarterGui:SetCore(
            "SendNotification",
            {
                Title = title,
                Text = text,
                Duration = 2
            }
        )

    end)

end


-- ================================================
-- CREATE GUI
-- ================================================

local screenGui =
    Instance.new("ScreenGui")

screenGui.Name = UI_NAME
screenGui.ResetOnSpawn = false


if gethui then

    local ok, hui =
        pcall(gethui)

    if ok and hui then
        screenGui.Parent = hui
    else
        screenGui.Parent = CoreGui
    end

elseif syn and syn.protect_gui then

    syn.protect_gui(screenGui)
    screenGui.Parent = CoreGui

else

    local success =
        pcall(function()

            screenGui.Parent = CoreGui

        end)

    if not success then

        screenGui.Parent =
            player:WaitForChild("PlayerGui")

    end

end


-- ================================================
-- MAIN FRAME
-- ================================================

local mainFrame =
    Instance.new("Frame")

mainFrame.Name = "MainFrame"

mainFrame.Size =
    UDim2.new(
        0,
        210,
        0,
        315
    )

mainFrame.Position =
    UDim2.new(
        0.75,
        0,
        0.2,
        0
    )

mainFrame.BackgroundColor3 =
    Color3.fromRGB(
        30,
        30,
        30
    )

mainFrame.Active = true
mainFrame.Draggable = true
mainFrame.ClipsDescendants = true

mainFrame.Parent =
    screenGui


local frameCorner =
    Instance.new("UICorner")

frameCorner.CornerRadius =
    UDim.new(0, 10)

frameCorner.Parent =
    mainFrame


-- ================================================
-- TITLE
-- ================================================

local titleLabel =
    Instance.new("TextLabel")

titleLabel.Size =
    UDim2.new(
        0.8,
        0,
        0,
        30
    )

titleLabel.Position =
    UDim2.new(
        0.05,
        0,
        0,
        0
    )

titleLabel.BackgroundTransparency = 1

titleLabel.Text =
    "Digimon Era Control"

titleLabel.TextColor3 =
    Color3.fromRGB(
        255,
        255,
        255
    )

titleLabel.TextSize = 14

titleLabel.Font =
    Enum.Font.SourceSansBold

titleLabel.TextXAlignment =
    Enum.TextXAlignment.Left

titleLabel.Parent =
    mainFrame


-- ================================================
-- MINIMIZE BUTTON
-- ================================================

local minimizeBtn =
    Instance.new("TextButton")

minimizeBtn.Name =
    "MinimizeBtn"

minimizeBtn.Size =
    UDim2.new(
        0,
        24,
        0,
        24
    )

minimizeBtn.Position =
    UDim2.new(
        0.85,
        0,
        0.02,
        0
    )

minimizeBtn.BackgroundColor3 =
    Color3.fromRGB(
        50,
        50,
        50
    )

minimizeBtn.TextColor3 =
    Color3.fromRGB(
        255,
        255,
        255
    )

minimizeBtn.TextSize = 16

minimizeBtn.Font =
    Enum.Font.SourceSansBold

minimizeBtn.Text = "-"

minimizeBtn.Parent =
    mainFrame


local minCorner =
    Instance.new("UICorner")

minCorner.CornerRadius =
    UDim.new(0, 5)

minCorner.Parent =
    minimizeBtn


-- ================================================
-- CONTENT
-- ================================================

local contentContainer =
    Instance.new("Frame")

contentContainer.Name =
    "ContentContainer"

contentContainer.Size =
    UDim2.new(
        1,
        0,
        0,
        280
    )

contentContainer.Position =
    UDim2.new(
        0,
        0,
        0,
        30
    )

contentContainer.BackgroundTransparency = 1

contentContainer.Parent =
    mainFrame


local isMinimized = false

minimizeBtn.MouseButton1Click:Connect(function()

    isMinimized =
        not isMinimized

    if isMinimized then

        mainFrame.Size =
            UDim2.new(
                0,
                210,
                0,
                30
            )

        contentContainer.Visible = false

        minimizeBtn.Text = "+"

    else

        mainFrame.Size =
            UDim2.new(
                0,
                210,
                0,
                315
            )

        contentContainer.Visible = true

        minimizeBtn.Text = "-"

    end

end)


-- ================================================
-- TOGGLE BUTTON
-- ================================================

local function createToggleButton(
    name,
    pos,
    defaultText
)

    local btn =
        Instance.new("TextButton")

    btn.Name = name

    btn.Size =
        UDim2.new(
            0.9,
            0,
            0,
            34
        )

    btn.Position = pos

    btn.BackgroundColor3 =
        Color3.fromRGB(
            220,
            53,
            69
        )

    btn.TextColor3 =
        Color3.fromRGB(
            255,
            255,
            255
        )

    btn.TextSize = 13

    btn.Font =
        Enum.Font.SourceSansBold

    btn.Text = defaultText

    btn.Parent =
        contentContainer


    local corner =
        Instance.new("UICorner")

    corner.CornerRadius =
        UDim.new(0, 6)

    corner.Parent = btn

    return btn

end


local farmBtn =
    createToggleButton(
        "FarmBtn",
        UDim2.new(
            0.05,
            0,
            0.01,
            0
        ),
        "Auto Farm: OFF"
    )


local chestBtn =
    createToggleButton(
        "ChestBtn",
        UDim2.new(
            0.05,
            0,
            0.16,
            0
        ),
        "Auto Chest: OFF"
    )


local dropBtn =
    createToggleButton(
        "DropBtn",
        UDim2.new(
            0.05,
            0,
            0.31,
            0
        ),
        "Auto Drops: OFF"
    )


local healBtn =
    createToggleButton(
        "HealBtn",
        UDim2.new(
            0.05,
            0,
            0.46,
            0
        ),
        "Auto Heal: OFF"
    )


local feedBtn =
    createToggleButton(
        "FeedBtn",
        UDim2.new(
            0.05,
            0,
            0.61,
            0
        ),
        "Auto Feed: OFF"
    )


-- ================================================
-- HEAL SETTINGS
-- ================================================

local healFrame =
    Instance.new("Frame")

healFrame.Name =
    "HealSettingsFrame"

healFrame.Size =
    UDim2.new(
        0.9,
        0,
        0,
        30
    )

healFrame.Position =
    UDim2.new(
        0.05,
        0,
        0.78,
        0
    )

healFrame.BackgroundTransparency = 1

healFrame.Parent =
    contentContainer


local healLabel =
    Instance.new("TextLabel")

healLabel.Size =
    UDim2.new(
        0.65,
        0,
        1,
        0
    )

healLabel.Position =
    UDim2.new(
        0,
        0,
        0,
        0
    )

healLabel.BackgroundTransparency = 1

healLabel.Text =
    "Heal Drop >= :"

healLabel.TextColor3 =
    Color3.fromRGB(
        200,
        200,
        200
    )

healLabel.TextSize = 12

healLabel.Font =
    Enum.Font.SourceSansBold

healLabel.TextXAlignment =
    Enum.TextXAlignment.Left

healLabel.Parent =
    healFrame


local healInput =
    Instance.new("TextBox")

healInput.Name =
    "HealInput"

healInput.Size =
    UDim2.new(
        0.32,
        0,
        1,
        0
    )

healInput.Position =
    UDim2.new(
        0.68,
        0,
        0,
        0
    )

healInput.BackgroundColor3 =
    Color3.fromRGB(
        45,
        45,
        45
    )

healInput.TextColor3 =
    Color3.fromRGB(
        255,
        255,
        255
    )

healInput.TextSize = 13

healInput.Font =
    Enum.Font.SourceSansBold

healInput.Text =
    tostring(
        HEAL_DROP_AMOUNT
    )

healInput.ClearTextOnFocus = false

healInput.Parent =
    healFrame


local inputCorner =
    Instance.new("UICorner")

inputCorner.CornerRadius =
    UDim.new(0, 5)

inputCorner.Parent =
    healInput


healInput.FocusLost:Connect(function()

    local val =
        tonumber(
            healInput.Text
        )

    if val and val > 0 then

        HEAL_DROP_AMOUNT =
            math.floor(val)

        sendNotification(
            "Auto Heal Setup",
            "ตั้งค่าปั๊มยาเมื่อเลือดลดลงไป >= "
                .. HEAL_DROP_AMOUNT
        )

    else

        healInput.Text =
            tostring(
                HEAL_DROP_AMOUNT
            )

        sendNotification(
            "Error",
            "กรุณากรอกตัวเลขจำนวนเลือดที่ถูกต้อง"
        )

    end

end)


-- ================================================
-- BUTTON EVENTS
-- ================================================

farmBtn.MouseButton1Click:Connect(function()

    AUTO_FARM =
        not AUTO_FARM

    farmBtn.Text =
        AUTO_FARM
        and "Auto Farm: ON"
        or "Auto Farm: OFF"

    farmBtn.BackgroundColor3 =
        AUTO_FARM
        and Color3.fromRGB(
            40,
            167,
            69
        )
        or Color3.fromRGB(
            220,
            53,
            69
        )

    if not AUTO_FARM then
        table.clear(visited)
    end

end)


chestBtn.MouseButton1Click:Connect(function()

    AUTO_CHEST =
        not AUTO_CHEST

    chestBtn.Text =
        AUTO_CHEST
        and "Auto Chest: ON"
        or "Auto Chest: OFF"

    chestBtn.BackgroundColor3 =
        AUTO_CHEST
        and Color3.fromRGB(
            40,
            167,
            69
        )
        or Color3.fromRGB(
            220,
            53,
            69
        )

    if not AUTO_CHEST then
        table.clear(openedChests)
    end

end)


dropBtn.MouseButton1Click:Connect(function()

    AUTO_DROPS =
        not AUTO_DROPS

    dropBtn.Text =
        AUTO_DROPS
        and "Auto Drops: ON"
        or "Auto Drops: OFF"

    dropBtn.BackgroundColor3 =
        AUTO_DROPS
        and Color3.fromRGB(
            40,
            167,
            69
        )
        or Color3.fromRGB(
            220,
            53,
            69
        )

    if not AUTO_DROPS then
        table.clear(collectedDrops)
    end

end)


healBtn.MouseButton1Click:Connect(function()

    AUTO_HEAL =
        not AUTO_HEAL

    healBtn.Text =
        AUTO_HEAL
        and "Auto Heal: ON"
        or "Auto Heal: OFF"

    healBtn.BackgroundColor3 =
        AUTO_HEAL
        and Color3.fromRGB(
            40,
            167,
            69
        )
        or Color3.fromRGB(
            220,
            53,
            69
        )

end)


feedBtn.MouseButton1Click:Connect(function()

    AUTO_FEED =
        not AUTO_FEED

    feedBtn.Text =
        AUTO_FEED
        and "Auto Feed: ON"
        or "Auto Feed: OFF"

    feedBtn.BackgroundColor3 =
        AUTO_FEED
        and Color3.fromRGB(
            40,
            167,
            69
        )
        or Color3.fromRGB(
            220,
            53,
            69
        )

end)


sendNotification(
    "Digimon Era Control",
    "โหลด UI สำเร็จแล้ว!"
)


-- ================================================
-- AUTO FEED - TELEPORT + REPEAT SAME TARGET
-- คง UI เดิม / วาร์ปหาเป้าหมาย / ให้อาหารซ้ำ
-- ================================================

local function getCaptureFolder()
    return workspace:FindFirstChild("ClientCaptures")
end

local function getCapturePosition(capture)
    if not capture or not capture.Parent then
        return nil
    end

    local ok, pos = pcall(function()
        return capture:GetPivot().Position
    end)

    if ok then
        return pos
    end

    return nil
end

local function findNearestCapture()
    local folder = getCaptureFolder()
    local character = player.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")

    if not folder or not root then
        return nil
    end

    local nearest, nearestDistance = nil, math.huge

    for _, capture in ipairs(folder:GetChildren()) do
        local info = capture:FindFirstChild("CatchableGui", true)
        local nameLabel = info and info:FindFirstChild("DigimonName", true)
        local pos = getCapturePosition(capture)

        if nameLabel and pos then
            local distance = (pos - root.Position).Magnitude

            if distance < nearestDistance then
                nearest = capture
                nearestDistance = distance
            end
        end
    end

    return nearest
end

local function clickGuiButton(btn)
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

-- วาร์ปไปใกล้เป้าหมาย โดยไม่วาร์ปซ้ำทุกเฟรม
local function teleportToCapture(capture)
    local character = player.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    local pos = getCapturePosition(capture)

    if not root or not pos then
        return false
    end

    if (root.Position - pos).Magnitude > 8 then
        local ok = pcall(function()
            root.CFrame = CFrame.new(pos + Vector3.new(0, 3, 0))
        end)

        if not ok then
            return false
        end

        task.wait(0.25)
    end

    return true
end

-- พยายามเปิดหน้าต่างเป้าหมาย
local function tryOpenCapture(capture)
    if not capture or not capture.Parent then
        return
    end

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
        local character = player.Character
        local root = character and character:FindFirstChild("HumanoidRootPart")
        local part = capture:IsA("BasePart")
            and capture
            or capture:FindFirstChildWhichIsA("BasePart", true)

        if root and part and firetouchinterest then
            firetouchinterest(root, part, 0)
            task.wait(0.03)
            firetouchinterest(root, part, 1)
        end
    end)
end

local function getCaptureMain()
    local pGui = player:FindFirstChild("PlayerGui")
    local billboard = pGui and pGui:FindFirstChild("CaptureBillboard")
    return billboard and billboard:FindFirstChild("MainFrame")
end

-- เลือกอาหารที่มีจำนวนเหลือ แล้วกด Feed
local function feedOnce()
    local main = getCaptureMain()

    if not main or not main.Visible then
        return false
    end

    local scrolling = main:FindFirstChild("ScrollingFrame", true)
    local feedButton = main:FindFirstChild("FeedButton", true)

    if not scrolling or not feedButton or not feedButton.Visible then
        return false
    end

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

    if not chosen then
        return false
    end

    if not clickGuiButton(chosen) then
        return false
    end

    task.wait(0.15)

    if not AUTO_FEED then
        return false
    end

    main = getCaptureMain()
    feedButton = main and main:FindFirstChild("FeedButton", true)

    if not main or not main.Visible or not feedButton or not feedButton.Visible then
        return false
    end

    return clickGuiButton(feedButton)
end

task.spawn(function()
    local currentTarget = nil
    local lastFeedTime = 0
    local lastOpenAttempt = 0

    while screenGui.Parent do
        if not AUTO_FEED then
            currentTarget = nil
            task.wait(0.2)
            continue
        end

        -- ใช้เป้าหมายเดิมจนกว่าจะหายไป
        if not currentTarget or not currentTarget.Parent then
            currentTarget = findNearestCapture()
            lastFeedTime = 0
            lastOpenAttempt = 0
        end

        if not currentTarget or not currentTarget.Parent then
            task.wait(0.3)
            continue
        end

        -- ถ้าเป้าหมายหาย ให้ล้างเป้าหมายแล้วค้นหาตัวใหม่
        if not getCapturePosition(currentTarget) then
            currentTarget = nil
            task.wait(0.1)
            continue
        end

        local main = getCaptureMain()

        if not main or not main.Visible then
            teleportToCapture(currentTarget)

            if os.clock() - lastOpenAttempt >= 0.7 then
                lastOpenAttempt = os.clock()
                tryOpenCapture(currentTarget)
            end

            task.wait(0.15)
        else
            -- ให้อาหารเป็นช่วง ๆ ไม่กดรัวทุกเฟรม
            if os.clock() - lastFeedTime >= 0.5 then
                lastFeedTime = os.clock()

                local ok, result = pcall(feedOnce)

                if not ok then
                    warn("[Auto Feed]", result)
                end
            end

            task.wait(0.1)
        end
    end
end)
-- ================================================
-- AUTO HEAL
-- ================================================
local VirtualInputManager =
    game:GetService("VirtualInputManager")


-- ========================================
-- HEAL SYSTEM 1 : กดปุ่ม 4
-- ========================================

local function triggerHealKeyboard()

    pcall(function()

        VirtualInputManager:SendKeyEvent(
            true,
            Enum.KeyCode.Four,
            false,
            game
        )

        task.wait(0.08)

        VirtualInputManager:SendKeyEvent(
            false,
            Enum.KeyCode.Four,
            false,
            game
        )

    end)

end


-- ========================================
-- HEAL SYSTEM 2 : กดปุ่ม 4 บน UI
-- ========================================

local function triggerHealUI()

    local pGui =
        player:FindFirstChild("PlayerGui")

    if not pGui then
        return false
    end

    for _, obj in ipairs(pGui:GetDescendants()) do

        if obj:IsA("TextButton")
            or obj:IsA("ImageButton")
        then

            local text = ""

            pcall(function()
                text = tostring(obj.Text)
            end)

            if text == "4" then

                local ok =
                    pcall(function()
                        obj:Activate()
                    end)

                if ok then
                    return true
                end

            end

        end

    end

    return false

end


-- ========================================
-- ตรวจ HP
-- ========================================

local function getDigimonHP()

    local pGui =
        player:FindFirstChild("PlayerGui")

    if not pGui then
        return nil, nil
    end

    for _, gui in ipairs(pGui:GetDescendants()) do

        if gui:IsA("TextLabel")
            and gui.Visible
            and gui.Text ~= ""
        then

            local text =
                gui.Text:gsub(",", "")

            local cur, max =
                text:match(
                    "(%d+)%s*/%s*(%d+)"
                )

            if cur and max then

                local cVal = tonumber(cur)
                local mVal = tonumber(max)

                if cVal
                    and mVal
                    and mVal > 100
                then

                    return cVal, mVal

                end

            end

        end

    end

    return nil, nil

end


-- ========================================
-- AUTO HEAL
-- ========================================

task.spawn(function()

    local lastHealTime = 0
    local HEAL_COOLDOWN = 2

    while true do

        if AUTO_HEAL then

            pcall(function()

                local curHP, maxHP =
                    getDigimonHP()

                if curHP and maxHP then

                    local missingHP =
                        maxHP - curHP

                    if missingHP >= HEAL_DROP_AMOUNT then

                        if tick() - lastHealTime >= HEAL_COOLDOWN then

                            -- ระบบที่ 1
                            triggerHealKeyboard()

                            task.wait(0.15)

                            -- ระบบที่ 2
                            triggerHealUI()

                            lastHealTime = tick()

                            sendNotification(
                                "Auto Heal",
                                "ลองใช้ยาแล้ว | HP ลด "
                                    .. math.floor(missingHP)
                            )

                        end

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

local function findAndTeleportToChest(
    character,
    rootPart
)

    if
        not AUTO_CHEST
        or
        not rootPart
    then

        return false

    end


    local closestChest = nil
    local closestDist =
        SEARCH_RADIUS


    for _, obj in
        ipairs(
            workspace:GetDescendants()
        )
    do

        if
            (
                obj:IsA("Model")
                or
                obj:IsA("BasePart")
            )
            and
            not openedChests[obj]
        then

            local name =
                obj.Name:lower()


            if
                name:find("chest")
                or
                name:find("rewardbox")
                or
                name:find("treasure")
            then

                local dist =
                    (
                        obj:GetPivot().Position
                        -
                        rootPart.Position
                    ).Magnitude


                if dist < closestDist then

                    closestChest = obj
                    closestDist = dist

                end

            end

        end

    end


    if
        closestChest
        and
        AUTO_CHEST
    then

        openedChests[
            closestChest
        ] = true


        sendNotification(
            "เจอกล่อง!",
            "กำลังเปิดกล่อง..."
        )


        for _, part in
            ipairs(
                closestChest:GetDescendants()
            )
        do

            if part:IsA("BasePart") then

                pcall(function()
                    part.CanCollide = false
                end)

            end

        end


        local chestPos =
            closestChest:GetPivot().Position


        for i = 1, 12 do

            if not AUTO_CHEST then
                break
            end


            pcall(function()

                rootPart.CFrame =
                    CFrame.new(
                        chestPos
                        +
                        Vector3.new(
                            0,
                            0.5,
                            0
                        )
                    )

            end)


            for _, prompt in
                ipairs(
                    closestChest:GetDescendants()
                )
            do

                if
                    prompt:IsA(
                        "ProximityPrompt"
                    )
                then

                    pcall(function()

                        prompt.RequiresLineOfSight =
                            false

                        prompt.MaxActivationDistance =
                            500

                        prompt.HoldDuration =
                            0

                        fireproximityprompt(
                            prompt
                        )

                    end)

                end

            end


            for _, part in
                ipairs(
                    closestChest:GetDescendants()
                )
            do

                if part:IsA("BasePart") then

                    pcall(function()

                        firetouchinterest(
                            rootPart,
                            part,
                            0
                        )

                        task.wait(0.01)

                        firetouchinterest(
                            rootPart,
                            part,
                            1
                        )

                    end)

                end

            end


            task.wait(0.1)

        end


        return true

    end


    return false

end


-- ================================================
-- AUTO DROPS
-- ================================================

local function findAndTeleportToDrop(
    character,
    rootPart
)

    if
        not AUTO_DROPS
        or
        not rootPart
    then

        return false

    end


    local closestDrop = nil

    local closestDist =
        SEARCH_RADIUS


    local dropsContainer =
        workspace:FindFirstChild(
            "ClientDrops"
        )
        or
        workspace:FindFirstChild(
            "Drops"
        )


    local dropItems =
        dropsContainer
        and
        dropsContainer:GetChildren()
        or
        workspace:GetDescendants()


    for _, item in
        ipairs(dropItems)
    do

        if
            (
                item:IsA("Model")
                or
                item:IsA("BasePart")
                or
                item:IsA("Tool")
            )
            and
            not collectedDrops[item]
        then

            local name =
                item.Name:lower()


            if
                not name:find("orb")
                and
                not name:find("chest")
                and
                not name:find("rewardbox")
            then

                local dist =
                    (
                        item:GetPivot().Position
                        -
                        rootPart.Position
                    ).Magnitude


                if dist < closestDist then

                    closestDrop = item
                    closestDist = dist

                end

            end

        end

    end


    if
        closestDrop
        and
        AUTO_DROPS
    then

        collectedDrops[
            closestDrop
        ] = true


        sendNotification(
            "เก็บไอเทม/สัตว์เลี้ยง!",
            "วาร์ปไปเก็บ "
                .. closestDrop.Name
        )


        local dropPos =
            closestDrop:GetPivot().Position


        pcall(function()

            rootPart.CFrame =
                CFrame.new(dropPos)

        end)


        task.wait(0.1)


        local mainParts =
            closestDrop:IsA("BasePart")
            and
            {closestDrop}
            or
            closestDrop:GetDescendants()


        for _, part in
            ipairs(mainParts)
        do

            if part:IsA("BasePart") then

                pcall(function()

                    part.CanCollide = false

                    firetouchinterest(
                        rootPart,
                        part,
                        0
                    )

                    task.wait(0.02)

                    firetouchinterest(
                        rootPart,
                        part,
                        1
                    )

                end)

            end

        end


        for _, prompt in
            ipairs(
                closestDrop:GetDescendants()
            )
        do

            if
                prompt:IsA(
                    "ProximityPrompt"
                )
            then

                pcall(function()

                    prompt.RequiresLineOfSight =
                        false

                    prompt.HoldDuration =
                        0

                    fireproximityprompt(
                        prompt
                    )

                end)

            end

        end


        task.wait(0.2)

        return true

    end


    return false

end


-- ================================================
-- PATHFINDING
-- ================================================

local enemiesFolder =
    workspace:FindFirstChild(
        "Digimons"
    )
    and
    workspace.Digimons:FindFirstChild(
        "Enemies"
    )


local function walkToTarget(
    character,
    humanoid,
    targetPosition
)

    local path =
        PathfindingService:CreatePath({
            AgentRadius = 2.5,
            AgentHeight = 5,
            AgentCanJump = true,
            WaypointSpacing = 4
        })


    local success =
        pcall(function()

            path:ComputeAsync(
                character:GetPivot().Position,
                targetPosition
            )

        end)


    if
        success
        and
        path.Status
            ==
        Enum.PathStatus.Success
    then

        for _, waypoint in
            ipairs(
                path:GetWaypoints()
            )
        do

            if not AUTO_FARM then
                break
            end


            if
                waypoint.Action
                    ==
                Enum.PathWaypointAction.Jump
            then

                humanoid.Jump = true

            end


            humanoid:MoveTo(
                waypoint.Position
            )


            local moveFinished =
                false


            local conn =
                humanoid.MoveToFinished:Connect(
                    function()

                        moveFinished = true

                    end
                )


            local startWait =
                tick()


            while
                not moveFinished
                and
                (
                    tick()
                    -
                    startWait
                    <
                    1.2
                )
                and
                AUTO_FARM
            do

                task.wait(0.05)

            end


            conn:Disconnect()

        end

    else

        if
            targetPosition.Y
            -
            character:GetPivot().Position.Y
            >
            2
        then

            humanoid.Jump = true

        end


        humanoid:MoveTo(
            targetPosition
        )

    end

end


-- ================================================
-- MAIN LOOP
-- ================================================

task.spawn(function()

    while true do

        local character =
            player.Character

        local humanoid =
            character
            and
            character:FindFirstChildOfClass(
                "Humanoid"
            )

        local rootPart =
            character
            and
            character:FindFirstChild(
                "HumanoidRootPart"
            )


        if
            character
            and
            humanoid
            and
            rootPart
            and
            humanoid.Health > 0
        then

            -- 1. CHEST

            local foundChest =
                findAndTeleportToChest(
                    character,
                    rootPart
                )


            -- 2. DROPS

            local foundDrop = false

            if not foundChest then

                foundDrop =
                    findAndTeleportToDrop(
                        character,
                        rootPart
                    )

            end


            -- 3. FARM

            if
                not foundChest
                and
                not foundDrop
                and
                AUTO_FARM
                and
                enemiesFolder
            then

                local myPos =
                    rootPart.Position

                local target = nil

                local targetDistance = -1


                for _, enemy in
                    ipairs(
                        enemiesFolder:GetChildren()
                    )
                do

                    if
                        enemy:IsA("Model")
                        and
                        not visited[enemy]
                        and
                        enemy.Parent
                    then

                        local enemyHumanoid =
                            enemy:FindFirstChildOfClass(
                                "Humanoid"
                            )


                        if
                            not enemyHumanoid
                            or
                            enemyHumanoid.Health > 0
                        then

                            local enemyPos =
                                enemy:GetPivot().Position


                            local distance =
                                (
                                    enemyPos
                                    -
                                    myPos
                                ).Magnitude


                            if
                                distance
                                >=
                                MIN_DISTANCE
                                and
                                distance
                                > targetDistance
                            then

                                target = enemy

                                targetDistance =
                                    distance

                            end

                        end

                    end

                end


                if
                    target
                    and
                    AUTO_FARM
                then

                    visited[target] = true


                    sendNotification(
                        "เดินไปตีมอนสเตอร์",
                        target.Name
                    )


                    local startTime =
                        tick()


                    while
                        AUTO_FARM
                        and
                        target
                        and
                        target.Parent
                        and
                        (
                            tick()
                            -
                            startTime
                            <
                            MAX_WALK_TIME
                        )
                    do

                        local enemyHumanoid =
                            target:FindFirstChildOfClass(
                                "Humanoid"
                            )


                        if
                            enemyHumanoid
                            and
                            enemyHumanoid.Health
                                <=
                            0
                        then

                            break

                        end


                        local targetPos =
                            target:GetPivot().Position


                        local distance =
                            (
                                targetPos
                                -
                                rootPart.Position
                            ).Magnitude


                        if
                            distance
                            <=
                            ARRIVAL_DISTANCE
                        then

                            VirtualUser:ClickButton1(
                                Vector2.new()
                            )

                            task.wait(0.2)

                        else

                            walkToTarget(
                                character,
                                humanoid,
                                targetPos
                            )

                        end

                    end


                    task.wait(0.3)

                else

                    if AUTO_FARM then

                        table.clear(
                            visited
                        )

                        task.wait(1.5)

                    end

                end

            end

        end


        task.wait(0.2)

    end

end)
