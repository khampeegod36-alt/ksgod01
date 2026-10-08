-- ================================================
-- AUTO RE-EXECUTE AFTER TELEPORT / DUNGEON EXIT
-- ================================================
local DIGIMON_SCRIPT_URL = "https://raw.githubusercontent.com/khampeegod36-alt/ksgod01/main/DigimonEra.lua"

local function setupTeleportQueue()
    local q = queue_on_teleport or queueonteleport or queue_on_tp or queueontp
    if not q then
        warn("[Digimon Era] queue_on_teleport not found")
        return false
    end

    local code = [[
        task.wait(10)
        local ok, err = pcall(function()
            local src = game:HttpGet("https://raw.githubusercontent.com/khampeegod36-alt/ksgod01/main/DigimonEra.lua")
            local fn = loadstring(src)
            assert(fn, "loadstring failed")
            fn()
        end)
        if not ok then
            warn("[Digimon Era] Auto reload failed:", err)
        end
    ]]

    local ok, err = pcall(function()
        q(code)
    end)

    if not ok then
        warn("[Digimon Era] Queue failed:", err)
        return false
    end

    print("[Digimon Era] Teleport queue armed")
    return true
end

setupTeleportQueue()

-- Refresh the queue periodically while this client is alive.
task.spawn(function()
    while task.wait(15) do
        setupTeleportQueue()
    end
end)

-- ================================================

local Players = game:GetService("Players")
local PathfindingService = game:GetService("PathfindingService")
local StarterGui = game:GetService("StarterGui")
local VirtualUser = game:GetService("VirtualUser")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CoreGui = game:GetService("CoreGui")

local player = Players.LocalPlayer

-- ================= CONFIGURATION =================
local MIN_DISTANCE = 30         
local ARRIVAL_DISTANCE = 4      
local MAX_WALK_TIME = 10        

-- [สวิตช์สถานะเริ่มต้น]
local AUTO_FARM = false         -- ฟาร์มมอนสเตอร์
local AUTO_CHEST = false        -- เปิดกล่องรางวัล
local AUTO_DROPS = false        -- เก็บของดรอป / สัตว์เลี้ยงบนพื้น
local AUTO_HEAL = false         -- ปั๊มยาอัตโนมัติ
local AUTO_FEED = false         -- ป้อนอาหารสัตว์เลี้ยงอัตโนมัติ (ใหม่)

local HEAL_DROP_AMOUNT = 3000   -- ตั้งค่าให้เลือดลดลงไป >= 3000 ถึงจะกดยา
local SEARCH_RADIUS = 500       -- ระยะสแกนค้นหา
-- =================================================

local visited = {}
local openedChests = {}         
local collectedDrops = {}       

-- Anti-AFK Kick
player.Idled:Connect(function()
	VirtualUser:Button2Down(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
	task.wait(1)
	VirtualUser:Button2Up(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
end)

local function sendNotification(title, text)
	pcall(function()
		StarterGui:SetCore("SendNotification", { Title = title, Text = text, Duration = 2 })
	end)
end

-- -------------------------------------------------
-- 1. สร้างหน้าต่าง GUI Control (เพิ่มปุ่ม Auto Feed)
-- -------------------------------------------------
pcall(function()
	if CoreGui:FindFirstChild("DigimonEra_MultiUI") then
		CoreGui.DigimonEra_MultiUI:Destroy()
	end
	if player.PlayerGui:FindFirstChild("DigimonEra_MultiUI") then
		player.PlayerGui.DigimonEra_MultiUI:Destroy()
	end
end)

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "DigimonEra_MultiUI"
screenGui.ResetOnSpawn = false

if gethui then
	screenGui.Parent = gethui()
elseif syn and syn.protect_gui then
	syn.protect_gui(screenGui)
	screenGui.Parent = CoreGui
else
	local success = pcall(function() screenGui.Parent = CoreGui end)
	if not success then
		screenGui.Parent = player:WaitForChild("PlayerGui")
	end
end

local mainFrame = Instance.new("Frame")
mainFrame.Name = "MainFrame"
mainFrame.Size = UDim2.new(0, 210, 0, 315) -- ขยายความสูงเพิ่มรองรับปุ่มใหม่
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
titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
titleLabel.TextSize = 14
titleLabel.Font = Enum.Font.SourceSansBold
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.Parent = mainFrame

local minimizeBtn = Instance.new("TextButton")
minimizeBtn.Name = "MinimizeBtn"
minimizeBtn.Size = UDim2.new(0, 24, 0, 24)
minimizeBtn.Position = UDim2.new(0.85, 0, 0.02, 0)
minimizeBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
minimizeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
minimizeBtn.TextSize = 16
minimizeBtn.Font = Enum.Font.SourceSansBold
minimizeBtn.Text = "-"
minimizeBtn.Parent = mainFrame

local minCorner = Instance.new("UICorner")
minCorner.CornerRadius = UDim.new(0, 5)
minCorner.Parent = minimizeBtn

local contentContainer = Instance.new("Frame")
contentContainer.Name = "ContentContainer"
contentContainer.Size = UDim2.new(1, 0, 0, 280)
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
		mainFrame.Size = UDim2.new(0, 210, 0, 315)
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
	btn.TextColor3 = Color3.fromRGB(255, 255, 255)
	btn.TextSize = 13
	btn.Font = Enum.Font.SourceSansBold
	btn.Text = defaultText
	btn.Parent = contentContainer

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = btn

	return btn
end

local farmBtn = createToggleButton("FarmBtn", UDim2.new(0.05, 0, 0.01, 0), "Auto Farm: OFF")
local chestBtn = createToggleButton("ChestBtn", UDim2.new(0.05, 0, 0.16, 0), "Auto Chest: OFF")
local dropBtn = createToggleButton("DropBtn", UDim2.new(0.05, 0, 0.31, 0), "Auto Drops: OFF")
local healBtn = createToggleButton("HealBtn", UDim2.new(0.05, 0, 0.46, 0), "Auto Heal: OFF")
local feedBtn = createToggleButton("FeedBtn", UDim2.new(0.05, 0, 0.61, 0), "Auto Feed: OFF") -- ปุ่มใหม่

-- ช่องป้อนค่าจำนวนเลือดที่ลดลง (HP Drop Threshold)
local healFrame = Instance.new("Frame")
healFrame.Name = "HealSettingsFrame"
healFrame.Size = UDim2.new(0.9, 0, 0, 30)
healFrame.Position = UDim2.new(0.05, 0, 0.78, 0)
healFrame.BackgroundTransparency = 1
healFrame.Parent = contentContainer

local healLabel = Instance.new("TextLabel")
healLabel.Size = UDim2.new(0.65, 0, 1, 0)
healLabel.Position = UDim2.new(0, 0, 0, 0)
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
healInput.TextColor3 = Color3.fromRGB(255, 255, 255)
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
		sendNotification("Auto Heal Setup", "ตั้งค่าปั๊มยาเมื่อเลือดลดลงไป >= " .. HEAL_DROP_AMOUNT)
	else
		healInput.Text = tostring(HEAL_DROP_AMOUNT)
		sendNotification("Error", "กรุณากรอกตัวเลขจำนวนเลือดที่ถูกต้อง")
	end
end)

farmBtn.MouseButton1Click:Connect(function()
	AUTO_FARM = not AUTO_FARM
	farmBtn.Text = AUTO_FARM and "Auto Farm: ON" or "Auto Farm: OFF"
	farmBtn.BackgroundColor3 = AUTO_FARM and Color3.fromRGB(40, 167, 69) or Color3.fromRGB(220, 53, 69)
	if not AUTO_FARM then table.clear(visited) end
end)

chestBtn.MouseButton1Click:Connect(function()
	AUTO_CHEST = not AUTO_CHEST
	chestBtn.Text = AUTO_CHEST and "Auto Chest: ON" or "Auto Chest: OFF"
	chestBtn.BackgroundColor3 = AUTO_CHEST and Color3.fromRGB(40, 167, 69) or Color3.fromRGB(220, 53, 69)
	if not AUTO_CHEST then table.clear(openedChests) end
end)

dropBtn.MouseButton1Click:Connect(function()
	AUTO_DROPS = not AUTO_DROPS
	dropBtn.Text = AUTO_DROPS and "Auto Drops: ON" or "Auto Drops: OFF"
	dropBtn.BackgroundColor3 = AUTO_DROPS and Color3.fromRGB(40, 167, 69) or Color3.fromRGB(220, 53, 69)
	if not AUTO_DROPS then table.clear(collectedDrops) end
end)

healBtn.MouseButton1Click:Connect(function()
	AUTO_HEAL = not AUTO_HEAL
	healBtn.Text = AUTO_HEAL and "Auto Heal: ON" or "Auto Heal: OFF"
	healBtn.BackgroundColor3 = AUTO_HEAL and Color3.fromRGB(40, 167, 69) or Color3.fromRGB(220, 53, 69)
end)

feedBtn.MouseButton1Click:Connect(function()
	AUTO_FEED = not AUTO_FEED
	feedBtn.Text = AUTO_FEED and "Auto Feed: ON" or "Auto Feed: OFF"
	feedBtn.BackgroundColor3 = AUTO_FEED and Color3.fromRGB(40, 167, 69) or Color3.fromRGB(220, 53, 69)
end)

sendNotification("Digimon Era Control", "โหลด UI สำเร็จแล้ว!")

-- -------------------------------------------------
-- 2. ระบบกดปุ่มป้อนอัตโนมัติ / ฟีดอาหารสัตว์เลี้ยง
-- -------------------------------------------------
local function triggerAutoFeed()
	pcall(function()
		local pGui = player:FindFirstChild("PlayerGui")
		if not pGui then return end

		local clicked = {}
		local keywords = {
			"การป้อนอัตโนมัติ",
			"ป้อนอัตโนมัติ",
			"ฟีดอัตโนมัติ",
			"ให้อาหาร",
			"ป้อนอาหาร",
			"auto feed",
			"autofeed",
			"feed"
		}

		local function containsKeyword(value)
			value = tostring(value or ""):lower()
			for _, keyword in ipairs(keywords) do
				if value:find(keyword:lower(), 1, true) then
					return true
				end
			end
			return false
		end

		local function findButtonFromGui(gui)
			local current = gui

			for _ = 1, 6 do
				if not current then break end

				if current:IsA("TextButton") or current:IsA("ImageButton") then
					return current
				end

				current = current.Parent
			end

			return nil
		end

		-- หา TextLabel/TextButton ที่เกี่ยวกับการให้อาหาร
		for _, gui in ipairs(pGui:GetDescendants()) do
			local matched = false

			if gui:IsA("TextLabel") or gui:IsA("TextButton") then
				matched = containsKeyword(gui.Text)
			end

			if not matched and (gui:IsA("TextButton") or gui:IsA("ImageButton")) then
				matched = containsKeyword(gui.Name)
			end

			if matched then
				local btn = findButtonFromGui(gui)

				if btn and not clicked[btn] then
					clicked[btn] = true

					pcall(function()
						-- วิธีหลัก: Activate ปุ่มโดยตรง
						btn:Activate()
					end)

					pcall(function()
						-- สำรองสำหรับ executor ที่รองรับ getconnections
						if getconnections and btn:IsA("TextButton") then
							for _, conn in ipairs(getconnections(btn.MouseButton1Click)) do
								pcall(function()
									conn:Fire()
								end)
							end
						end
					end)
				end
			end
		end
	end)
end

task.spawn(function()
	while true do
		if AUTO_FEED then
			triggerAutoFeed()
		end

		task.wait(2.0)
	end
end)

-- -------------------------------------------------
-- 3. ระบบสั่งใช้ยาฟื้นฟูดิจิมอน
-- -------------------------------------------------
local VirtualInputManager = game:GetService("VirtualInputManager")

local function triggerDigimonHeal()
	pcall(function()
		-- กดช่องยา 4 โดยตรง
		VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.Four, false, game)
		task.wait(0.05)
		VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Four, false, game)
	end)
end

local function getDigimonHP()
	local pGui = player:FindFirstChild("PlayerGui")
	if pGui then
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
	end
	return nil, nil
end

task.spawn(function()
	local lastHealTime = 0
	local HEAL_COOLDOWN = 2

	while true do
		if AUTO_HEAL then
			pcall(function()
				local curHP, maxHP = getDigimonHP()

				if curHP and maxHP then
					local missingHP = maxHP - curHP

					if missingHP >= HEAL_DROP_AMOUNT then
						if tick() - lastHealTime >= HEAL_COOLDOWN then
							triggerDigimonHeal()
							lastHealTime = tick()

							sendNotification(
								"Auto Heal",
								"กดใช้ยาแล้ว! HP ลด " .. math.floor(missingHP)
							)
						end
					end
				end
			end)
		end

		task.wait(0.2)
	end
end)

-- -------------------------------------------------
-- 4. ระบบเปิดกล่องรางวัล (Auto Chest)
-- -------------------------------------------------
local function findAndTeleportToChest(character, rootPart)
	if not AUTO_CHEST or not rootPart then return false end

	local closestChest = nil
	local closestDist = SEARCH_RADIUS

	for _, obj in ipairs(workspace:GetDescendants()) do
		if (obj:IsA("Model") or obj:IsA("BasePart")) and not openedChests[obj] then
			local name = obj.Name:lower()
			if name:find("chest") or name:find("rewardbox") or name:find("treasure") then
				local dist = (obj:GetPivot().Position - rootPart.Position).Magnitude
				if dist < closestDist then
					closestChest = obj
					closestDist = dist
				end
			end
		end
	end

	if closestChest and AUTO_CHEST then
		openedChests[closestChest] = true
		sendNotification("เจอกล่อง!", "กำลังเปิดกล่อง...")

		for _, part in ipairs(closestChest:GetDescendants()) do
			if part:IsA("BasePart") then
				pcall(function() part.CanCollide = false end)
			end
		end

		local chestPos = closestChest:GetPivot().Position

		for i = 1, 12 do
			if not AUTO_CHEST then break end

			pcall(function()
				rootPart.CFrame = CFrame.new(chestPos + Vector3.new(0, 0.5, 0))
			end)

			for _, prompt in ipairs(closestChest:GetDescendants()) do
				if prompt:IsA("ProximityPrompt") then
					pcall(function()
						prompt.RequiresLineOfSight = false
						prompt.MaxActivationDistance = 500
						prompt.HoldDuration = 0
						fireproximityprompt(prompt)
					end)
				end
			end

			for _, part in ipairs(closestChest:GetDescendants()) do
				if part:IsA("BasePart") then
					pcall(function()
						firetouchinterest(rootPart, part, 0)
						task.wait(0.01)
						firetouchinterest(rootPart, part, 1)
					end)
				end
			end

			task.wait(0.1)
		end

		return true
	end
	return false
end

-- -------------------------------------------------
-- 5. ระบบเก็บของดรอป รวมถึงตัวดิจิมอน / สัตว์เลี้ยงบนพื้น
-- -------------------------------------------------
local function findAndTeleportToDrop(character, rootPart)
	if not AUTO_DROPS or not rootPart then return false end

	local closestDrop = nil
	local closestDist = SEARCH_RADIUS

	local dropsContainer = workspace:FindFirstChild("ClientDrops") or workspace:FindFirstChild("Drops")
	local dropItems = dropsContainer and dropsContainer:GetChildren() or workspace:GetDescendants()

	for _, item in ipairs(dropItems) do
		if (item:IsA("Model") or item:IsA("BasePart") or item:IsA("Tool")) and not collectedDrops[item] then
			local name = item.Name:lower()
			
			if not name:find("orb") and not name:find("chest") and not name:find("rewardbox") then
				local dist = (item:GetPivot().Position - rootPart.Position).Magnitude
				if dist < closestDist then
					closestDrop = item
					closestDist = dist
				end
			end
		end
	end

	if closestDrop and AUTO_DROPS then
		collectedDrops[closestDrop] = true
		sendNotification("เก็บไอเทม/สัตว์เลี้ยง!", "วาร์ปไปเก็บ " .. closestDrop.Name)

		local dropPos = closestDrop:GetPivot().Position
		
		pcall(function()
			rootPart.CFrame = CFrame.new(dropPos)
		end)
		task.wait(0.1)

		local mainParts = closestDrop:IsA("BasePart") and {closestDrop} or closestDrop:GetDescendants()
		for _, part in ipairs(mainParts) do
			if part:IsA("BasePart") then
				pcall(function()
					part.CanCollide = false
					firetouchinterest(rootPart, part, 0)
					task.wait(0.02)
					firetouchinterest(rootPart, part, 1)
				end)
			end
		end

		for _, prompt in ipairs(closestDrop:GetDescendants()) do
			if prompt:IsA("ProximityPrompt") then
				pcall(function()
					prompt.RequiresLineOfSight = false
					prompt.HoldDuration = 0
					fireproximityprompt(prompt)
				end)
			end
		end

		task.wait(0.2)
		return true
	end
	return false
end

-- -------------------------------------------------
-- 6. ระบบ Pathfinding สำหรับเดินตีมอน
-- -------------------------------------------------
local enemiesFolder = workspace:FindFirstChild("Digimons") and workspace.Digimons:FindFirstChild("Enemies")

local function walkToTarget(character, humanoid, targetPosition)
	local path = PathfindingService:CreatePath({
		AgentRadius = 2.5,
		AgentHeight = 5,
		AgentCanJump = true,
		WaypointSpacing = 4
	})

	local success, _ = pcall(function()
		path:ComputeAsync(character:GetPivot().Position, targetPosition)
	end)

	if success and path.Status == Enum.PathStatus.Success then
		for _, waypoint in ipairs(path:GetWaypoints()) do
			if not AUTO_FARM then break end

			if waypoint.Action == Enum.PathWaypointAction.Jump then
				humanoid.Jump = true
			end

			humanoid:MoveTo(waypoint.Position)
			
			local moveFinished = false
			local conn = humanoid.MoveToFinished:Connect(function() moveFinished = true end)

			local startWait = tick()
			while not moveFinished and (tick() - startWait < 1.2) and AUTO_FARM do
				task.wait(0.05)
			end
			conn:Disconnect()
		end
	else
		if targetPosition.Y - character:GetPivot().Position.Y > 2 then
			humanoid.Jump = true
		end
		humanoid:MoveTo(targetPosition)
	end
end

-- -------------------------------------------------
-- 7. Main Loop
-- -------------------------------------------------
task.spawn(function()
	while true do
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local rootPart = character and character:FindFirstChild("HumanoidRootPart")

		if character and humanoid and rootPart and humanoid.Health > 0 then

			-- 1. เช็คเปิดกล่อง
			local foundChest = findAndTeleportToChest(character, rootPart)

			-- 2. เช็คเก็บของดรอป / ตัวดิจิมอน (สัตว์เลี้ยง)
			local foundDrop = false
			if not foundChest then
				foundDrop = findAndTeleportToDrop(character, rootPart)
			end

			-- 3. เดินไปตีมอนสเตอร์
			if not foundChest and not foundDrop and AUTO_FARM and enemiesFolder then
				local myPos = rootPart.Position
				local target = nil
				local targetDistance = -1

				for _, enemy in ipairs(enemiesFolder:GetChildren()) do
					if enemy:IsA("Model") and not visited[enemy] and enemy.Parent then
						local enemyHumanoid = enemy:FindFirstChildOfClass("Humanoid")
						if not enemyHumanoid or enemyHumanoid.Health > 0 then
							local enemyPos = enemy:GetPivot().Position
							local distance = (enemyPos - myPos).Magnitude

							if distance >= MIN_DISTANCE and distance > targetDistance then
								target = enemy
								targetDistance = distance
							end
						end
					end
				end

				if target and AUTO_FARM then
					visited[target] = true
					sendNotification("เดินไปตีมอนสเตอร์", target.Name)

					local startTime = tick()
					while AUTO_FARM and target and target.Parent and (tick() - startTime < MAX_WALK_TIME) do
						local enemyHumanoid = target:FindFirstChildOfClass("Humanoid")
						if enemyHumanoid and enemyHumanoid.Health <= 0 then break end

						local targetPos = target:GetPivot().Position
						local distance = (targetPos - rootPart.Position).Magnitude

						if distance <= ARRIVAL_DISTANCE then
							VirtualUser:ClickButton1(Vector2.new())
							task.wait(0.2)
						else
							walkToTarget(character, humanoid, targetPos)
						end
					end
					task.wait(0.3)
				else
					if AUTO_FARM then
						table.clear(visited)
						task.wait(1.5)
					end
				end
			end
		end
		task.wait(0.2)
	end
end)
