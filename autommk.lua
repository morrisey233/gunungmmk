local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")

print("Autowalk: Script Started")

local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid")
local rootPart = character:WaitForChild("HumanoidRootPart")

print("Autowalk: Character Found")

-- State Variables
local checkpoints = {} 
local recordingIndex = nil 
local playingIndex = nil   
local isPlayingAll = false 
local recordingConnection
local playingCoroutine
local lastJumpTime = 0 
local showLogs = false 

-- Theme Colors (Catppuccin Macchiato inspired)
local THEME = {
    Background = Color3.fromRGB(30, 30, 46),
    Surface = Color3.fromRGB(49, 50, 68),
    Primary = Color3.fromRGB(137, 180, 250), -- Blue
    Success = Color3.fromRGB(166, 227, 161), -- Green
    Warning = Color3.fromRGB(250, 179, 135), -- Orange
    Error = Color3.fromRGB(243, 139, 168), -- Red
    Text = Color3.fromRGB(205, 214, 244),
    Subtext = Color3.fromRGB(166, 173, 200)
}

-- GUI Setup
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "AutowalkRecorderGUI"
screenGui.IgnoreGuiInset = true -- Ensure it draws over topbar if needed
screenGui.DisplayOrder = 2000 -- Force on top of everything
screenGui.ResetOnSpawn = false 
-- Clean up old GUI if exists to prevent duplicates on reload
if player:WaitForChild("PlayerGui"):FindFirstChild("AutowalkRecorderGUI") then
    player.PlayerGui.AutowalkRecorderGUI:Destroy()
end
screenGui.Parent = player:WaitForChild("PlayerGui")

local mainFrame = Instance.new("Frame")
mainFrame.Name = "MainFrame"
mainFrame.Size = UDim2.new(0, 320, 0, 550) -- Taller to fit stacked footer
mainFrame.Position = UDim2.new(0, 20, 0.5, -275)
mainFrame.BackgroundColor3 = THEME.Background
mainFrame.BorderSizePixel = 0
mainFrame.Visible = true -- Force visible immediately
mainFrame.Parent = screenGui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 12)
corner.Parent = mainFrame

local stroke = Instance.new("UIStroke")
stroke.Color = THEME.Surface
stroke.Thickness = 2
stroke.Parent = mainFrame

-- Header
local headerFrame = Instance.new("Frame")
headerFrame.Name = "Header"
headerFrame.Size = UDim2.new(1, 0, 0, 50)
headerFrame.BackgroundTransparency = 1
headerFrame.Parent = mainFrame

local titleLabel = Instance.new("TextLabel")
titleLabel.Name = "Title"
titleLabel.Size = UDim2.new(1, -20, 1, 0)
titleLabel.Position = UDim2.new(0, 15, 0, 0)
titleLabel.BackgroundTransparency = 1
titleLabel.Text = "ADEN TAYANK ALEYNA" -- User Custom Title
titleLabel.TextColor3 = THEME.Text
titleLabel.Font = Enum.Font.GothamBlack
titleLabel.TextSize = 20
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.Parent = headerFrame

local statusLabel = Instance.new("TextLabel")
statusLabel.Name = "Status"
statusLabel.Size = UDim2.new(1, -20, 0, 20)
statusLabel.Position = UDim2.new(0, 15, 0, 35) -- Sub-header
statusLabel.BackgroundTransparency = 1
statusLabel.Text = "READY TO RECORD"
statusLabel.TextColor3 = THEME.Subtext
statusLabel.Font = Enum.Font.GothamBold
statusLabel.TextSize = 10
statusLabel.TextXAlignment = Enum.TextXAlignment.Left
statusLabel.Parent = headerFrame 

-- Jump Indicator (Dot)
local jumpIndicator = Instance.new("Frame")
jumpIndicator.Name = "JumpIndicator"
jumpIndicator.Size = UDim2.new(0, 10, 0, 10)
jumpIndicator.Position = UDim2.new(1, -25, 0.5, -5)
jumpIndicator.BackgroundColor3 = THEME.Surface
jumpIndicator.BorderSizePixel = 0
jumpIndicator.Parent = headerFrame
local jiCorner = Instance.new("UICorner"); jiCorner.CornerRadius = UDim.new(1, 0); jiCorner.Parent = jumpIndicator
local jiStroke = Instance.new("UIStroke"); jiStroke.Color = THEME.Subtext; jiStroke.Thickness = 1; jiStroke.Parent = jumpIndicator

-- Tools Area
local toolsFrame = Instance.new("Frame")
toolsFrame.Name = "ToolsFrame"
toolsFrame.Size = UDim2.new(1, -20, 0, 30)
toolsFrame.Position = UDim2.new(0, 10, 0, 60)
toolsFrame.BackgroundTransparency = 1
toolsFrame.Parent = mainFrame

local function createToolButton(name, text, color, pos, size)
    local btn = Instance.new("TextButton")
    btn.Name = name
    btn.Size = size
    btn.Position = pos
    btn.BackgroundColor3 = color
    btn.Text = text
    btn.TextColor3 = THEME.Background
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 11
    btn.Parent = toolsFrame
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 6); c.Parent = btn
    return btn
end

local exportBtn = createToolButton("Export", "EXPORT", THEME.Primary, UDim2.new(0, 0, 0, 0), UDim2.new(0.3, 0, 1, 0))
local importBtn = createToolButton("Import", "IMPORT", THEME.Surface, UDim2.new(0.35, 0, 0, 0), UDim2.new(0.3, 0, 1, 0))
importBtn.TextColor3 = THEME.Text 

local logBtn = createToolButton("Logs", "LOGS", THEME.Surface, UDim2.new(0.7, 0, 0, 0), UDim2.new(0.3, 0, 1, 0))
logBtn.TextColor3 = THEME.Text

-- List Area
local scrollFrame = Instance.new("ScrollingFrame")
scrollFrame.Name = "CheckpointsList"
scrollFrame.Size = UDim2.new(1, -10, 1, -200) -- Reduced height to make room for taller footer
scrollFrame.Position = UDim2.new(0, 5, 0, 100)
scrollFrame.BackgroundTransparency = 1
scrollFrame.ScrollBarThickness = 4
scrollFrame.ScrollBarImageColor3 = THEME.Surface
scrollFrame.Parent = mainFrame

local listLayout = Instance.new("UIListLayout")
listLayout.Parent = scrollFrame
listLayout.SortOrder = Enum.SortOrder.LayoutOrder
listLayout.Padding = UDim.new(0, 8)

local listPadding = Instance.new("UIPadding")
listPadding.PaddingLeft = UDim.new(0, 5)
listPadding.PaddingRight = UDim.new(0, 5)
listPadding.PaddingBottom = UDim.new(0, 10) -- Extra padding at bottom
listPadding.Parent = scrollFrame

-- Footer (Stacked Layout)
local footerFrame = Instance.new("Frame")
footerFrame.Name = "Footer"
footerFrame.Size = UDim2.new(1, -20, 0, 90) -- Taller footer
footerFrame.Position = UDim2.new(0, 10, 1, -100)
footerFrame.BackgroundTransparency = 1
footerFrame.Parent = mainFrame

local playAllBtn = Instance.new("TextButton")
playAllBtn.Name = "PlayAllButton"
playAllBtn.Size = UDim2.new(1, 0, 0, 40) -- Full Width
playAllBtn.Position = UDim2.new(0, 0, 0, 0) -- Top
playAllBtn.BackgroundColor3 = THEME.Success
playAllBtn.Text = "PLAY ALL CHECKPOINTS"
playAllBtn.TextColor3 = THEME.Background
playAllBtn.Font = Enum.Font.GothamBlack
playAllBtn.TextSize = 14
playAllBtn.Parent = footerFrame
local paCorner = Instance.new("UICorner"); paCorner.CornerRadius = UDim.new(0, 8); paCorner.Parent = playAllBtn

local addBtn = Instance.new("TextButton")
addBtn.Name = "AddButton"
addBtn.Size = UDim2.new(1, 0, 0, 40) -- Full Width
addBtn.Position = UDim2.new(0, 0, 0, 50) -- Below Play All (with 10px gap)
addBtn.BackgroundColor3 = THEME.Surface
addBtn.Text = "+ Add New Checkpoint"
addBtn.TextColor3 = THEME.Text
addBtn.Font = Enum.Font.GothamBold
addBtn.TextSize = 14
addBtn.Parent = footerFrame
local addCorner = Instance.new("UICorner"); addCorner.CornerRadius = UDim.new(0, 8); addCorner.Parent = addBtn

addBtn.MouseButton1Click:Connect(createCheckpoint)

-- Log Overlay
local logOverlay = Instance.new("ScrollingFrame")
logOverlay.Name = "LogOverlay"
logOverlay.Size = UDim2.new(1, -20, 0, 150)
logOverlay.Position = UDim2.new(0, 10, 1, -160) -- Adjust position above footer if needed, or overlay it
logOverlay.BackgroundColor3 = Color3.new(0,0,0)
logOverlay.BackgroundTransparency = 0.1
logOverlay.Visible = false
logOverlay.ZIndex = 30 -- Above everything
logOverlay.Parent = mainFrame
local loCorner = Instance.new("UICorner"); loCorner.Parent = logOverlay

local logLabel = Instance.new("TextLabel")
logLabel.Size = UDim2.new(1, -10, 0, 0) -- Auto height
logLabel.BackgroundTransparency = 1
logLabel.Text = "System initialized..."
logLabel.TextColor3 = THEME.Text
logLabel.Font = Enum.Font.Code
logLabel.TextSize = 11
logLabel.TextXAlignment = Enum.TextXAlignment.Left
logLabel.TextYAlignment = Enum.TextYAlignment.Top
logLabel.AutomaticSize = Enum.AutomaticSize.Y
logLabel.Parent = logOverlay

local function logError(err)
    warn("Autowalk: " .. tostring(err))
    logLabel.Text = logLabel.Text .. "\n[ERR] " .. string.sub(tostring(err), 1, 50)
end

logBtn.MouseButton1Click:Connect(function()
    showLogs = not showLogs
    logOverlay.Visible = showLogs
    logBtn.BackgroundColor3 = showLogs and THEME.Text or THEME.Surface
    logBtn.TextColor3 = showLogs and THEME.Background or THEME.Text
end)


-- Data Window (Modal)
local dataWindow = Instance.new("Frame")
dataWindow.Name = "DataWindow"
dataWindow.Size = UDim2.new(1, 0, 1, 0)
dataWindow.BackgroundColor3 = Color3.new(0,0,0)
dataWindow.BackgroundTransparency = 0.5
dataWindow.ZIndex = 40
dataWindow.Visible = false
dataWindow.Parent = mainFrame
local dwCorner = Instance.new("UICorner"); dwCorner.Parent = dataWindow

local dwContent = Instance.new("Frame")
dwContent.Size = UDim2.new(0.9, 0, 0.5, 0)
dwContent.Position = UDim2.new(0.05, 0, 0.25, 0)
dwContent.BackgroundColor3 = THEME.Background
dwContent.ZIndex = 41
dwContent.Parent = dataWindow
local dwcCorner = Instance.new("UICorner"); dwcCorner.Parent = dwContent
local dwStroke = Instance.new("UIStroke"); dwStroke.Color = THEME.Surface; dwStroke.Thickness = 2; dwStroke.Parent = dwContent

local dwTitle = Instance.new("TextLabel")
dwTitle.Size = UDim2.new(1, 0, 0, 40)
dwTitle.BackgroundTransparency = 1
dwTitle.Text = "DATA EXCHANGE"
dwTitle.TextColor3 = THEME.Text
dwTitle.Font = Enum.Font.GothamBold
dwTitle.TextSize = 14
dwTitle.ZIndex = 42
dwTitle.Parent = dwContent

local dataTextBox = Instance.new("TextBox")
dataTextBox.Size = UDim2.new(1, -20, 1, -100)
dataTextBox.Position = UDim2.new(0, 10, 0, 40)
dataTextBox.BackgroundColor3 = THEME.Surface
dataTextBox.TextColor3 = THEME.Text
dataTextBox.Font = Enum.Font.Code
dataTextBox.TextSize = 11
dataTextBox.TextXAlignment = Enum.TextXAlignment.Left
dataTextBox.TextYAlignment = Enum.TextYAlignment.Top
dataTextBox.MultiLine = true
dataTextBox.ClearTextOnFocus = false
dataTextBox.ZIndex = 42
dataTextBox.Parent = dwContent
local dtbCorner = Instance.new("UICorner"); dtbCorner.Parent = dataTextBox

local closeDataBtn = Instance.new("TextButton")
closeDataBtn.Size = UDim2.new(0.3, 0, 0, 35)
closeDataBtn.Position = UDim2.new(0.05, 0, 1, -45)
closeDataBtn.BackgroundColor3 = THEME.Error
closeDataBtn.Text = "CLOSE"
closeDataBtn.TextColor3 = THEME.Background
closeDataBtn.Font = Enum.Font.GothamBold
closeDataBtn.ZIndex = 42
closeDataBtn.Parent = dwContent
local cdbCorner = Instance.new("UICorner"); cdbCorner.Parent = closeDataBtn

local actionDataBtn = Instance.new("TextButton") -- Copy/Load
actionDataBtn.Size = UDim2.new(0.3, 0, 0, 35)
actionDataBtn.Position = UDim2.new(0.375, 0, 1, -45)
actionDataBtn.BackgroundColor3 = THEME.Primary
actionDataBtn.Text = "ACTION"
actionDataBtn.TextColor3 = THEME.Background
actionDataBtn.Font = Enum.Font.GothamBold
actionDataBtn.ZIndex = 42
actionDataBtn.Parent = dwContent
local adbCorner = Instance.new("UICorner"); adbCorner.Parent = actionDataBtn

local saveDataBtn = Instance.new("TextButton") -- New Save File Button
saveDataBtn.Size = UDim2.new(0.25, 0, 0, 35)
saveDataBtn.Position = UDim2.new(0.7, 0, 1, -45)
saveDataBtn.BackgroundColor3 = THEME.Warning
saveDataBtn.Text = "SAVE FILE"
saveDataBtn.TextColor3 = THEME.Background
saveDataBtn.Font = Enum.Font.GothamBold
saveDataBtn.ZIndex = 42
saveDataBtn.Visible = false -- Hidden by default, shown on Export
saveDataBtn.Parent = dwContent
local sdbCorner = Instance.new("UICorner"); sdbCorner.Parent = saveDataBtn

if not writefile then
    saveDataBtn.Visible = false -- Hide if executor doesn't support file saving
    actionDataBtn.Size = UDim2.new(0.6, 0, 0, 35) -- Expand action btn
    actionDataBtn.Position = UDim2.new(0.375, 0, 1, -45)
end

-- Logic Functions

local function updateStatus(text)
	statusLabel.Text = string.upper(text)
end

local function updateJumpIndicator(active)
    if active then
        jumpIndicator.BackgroundColor3 = THEME.Success
        jumpIndicator.UIStroke.Color = THEME.Success
    else
        jumpIndicator.BackgroundColor3 = THEME.Surface
        jumpIndicator.UIStroke.Color = THEME.Subtext
    end
end

local function stopAll(fullStop)
    if fullStop == nil then fullStop = true end 
    
    updateJumpIndicator(false)
    player.DevComputerMovementMode = Enum.DevComputerMovementMode.UserChoice
    player.DevTouchMovementMode = Enum.DevTouchMovementMode.UserChoice
    
	if recordingIndex then
		if recordingConnection then
			recordingConnection:Disconnect()
			recordingConnection = nil
		end
        updateStatus("Stopped Recording CP " .. recordingIndex)
		recordingIndex = nil
	end
	if playingIndex then
		if playingCoroutine then
			task.cancel(playingCoroutine)
			playingCoroutine = nil
		end
		humanoid:Move(Vector3.new(0,0,0))
		humanoid.Jump = false
        updateStatus("Stopped Playing CP " .. playingIndex)
		playingIndex = nil
	end
    
    if fullStop then
        isPlayingAll = false
        playAllBtn.Text = "PLAY ALL CHECKPOINTS"
        playAllBtn.BackgroundColor3 = THEME.Success
    end
    
    refreshList() 
end

local function serializeCheckpoints()
    local data = {}
    for i, cp in ipairs(checkpoints) do
        local cpData = { name = cp.name, startPos = nil, inputs = {} }
        if cp.startPos then
             cpData.startPos = {math.floor(cp.startPos.X*100)/100, math.floor(cp.startPos.Y*100)/100, math.floor(cp.startPos.Z*100)/100}
        end
        
        for _, inp in ipairs(cp.inputs) do
            local posData = nil
            if inp.p then
                posData = {math.floor(inp.p.X*100)/100, math.floor(inp.p.Y*100)/100, math.floor(inp.p.Z*100)/100}
            end
            
            table.insert(cpData.inputs, {
                dt = math.floor(inp.dt*1000)/1000, 
                d = {math.floor(inp.d.X*1000)/1000, 0, math.floor(inp.d.Z*1000)/1000},
                j = inp.j,
                p = posData
            })
        end
        table.insert(data, cpData)
    end
    return HttpService:JSONEncode(data)
end

local function deserializeCheckpoints(jsonString)
    local success, result = pcall(function()
        return HttpService:JSONDecode(jsonString)
    end)
    
    if not success then 
        logError("JSON Decode Failed: " .. tostring(result))
        return nil 
    end
    
    local loadedCheckpoints = {}
    for _, cpData in ipairs(result) do
        local newCP = { name = cpData.name, inputs = {} }
        if cpData.startPos then
             newCP.startPos = Vector3.new(cpData.startPos[1], cpData.startPos[2], cpData.startPos[3])
        end
        
        for _, inpData in ipairs(cpData.inputs) do
            local posVec = nil
            if inpData.p then
                posVec = Vector3.new(inpData.p[1], inpData.p[2], inpData.p[3])
            end
            
            table.insert(newCP.inputs, {
                dt = inpData.dt,
                d = Vector3.new(inpData.d[1], inpData.d[2], inpData.d[3]), 
                j = inpData.j,
                p = posVec 
            })
        end
        table.insert(loadedCheckpoints, newCP)
    end
    return loadedCheckpoints
end

local currentExportData = "" -- Store full data here

-- Executor Support Check
local canWriteFile = (writefile ~= nil) or (makefolder ~= nil)
if not canWriteFile and getgenv then
    canWriteFile = (getgenv().writefile ~= nil)
end
print("Autowalk: Can Write File? " .. tostring(canWriteFile))

exportBtn.MouseButton1Click:Connect(function()
    print("Autowalk: Export Button Clicked")
    stopAll()
    
    -- Show window immediately with feedback
    dwTitle.Text = "EXPORTING..."
    dataTextBox.Text = "Generating JSON data... Please wait."
    dataWindow.Visible = true
    saveDataBtn.Visible = false
    actionDataBtn.Visible = false
    
    -- Wait a frame to let UI update
    task.wait()
    
    local success, json = pcall(serializeCheckpoints)
    if not success then 
        logError("Serialize: " .. json)
        dataTextBox.Text = "ERROR: " .. tostring(json)
        return 
    end
    
    currentExportData = json -- Save full data
    print("Autowalk: JSON Generated, Length: " .. #json)
    
    if #json > 100000 then
        dataTextBox.Text = "-- DATA TOO LONG TO DISPLAY (" .. #json .. " chars) --\n\nPlease use 'SAVE FILE' or 'ACTION -> COPY' buttons to get the full data."
    else
        dataTextBox.Text = json
    end
    
    dwTitle.Text = "EXPORT DATA"
    actionDataBtn.Text = "COPY"
    actionDataBtn.Visible = true 
    
    if canWriteFile then
        saveDataBtn.Visible = true
        actionDataBtn.Size = UDim2.new(0.3, 0, 0, 35) -- Smaller to fit SaveBtn
        actionDataBtn.Position = UDim2.new(0.375, 0, 1, -45)
    else
        saveDataBtn.Visible = false
        actionDataBtn.Size = UDim2.new(0.55, 0, 0, 35) -- Fill space
        actionDataBtn.Position = UDim2.new(0.4, 0, 1, -45)
    end
end)

importBtn.MouseButton1Click:Connect(function()
    stopAll()
    dataTextBox.Text = ""
    currentExportData = ""
    actionDataBtn.Text = "LOAD"
    actionDataBtn.Visible = true
    actionDataBtn.Size = UDim2.new(0.55, 0, 0, 35) -- Fill space
    actionDataBtn.Position = UDim2.new(0.4, 0, 1, -45)
    saveDataBtn.Visible = false
    
    dwTitle.Text = "IMPORT DATA"
    dataWindow.Visible = true
end)

closeDataBtn.MouseButton1Click:Connect(function()
    dataWindow.Visible = false
end)

actionDataBtn.MouseButton1Click:Connect(function()
    if actionDataBtn.Text == "LOAD" then
        local text = dataTextBox.Text
        if text == "" then return end
        
        local loaded = deserializeCheckpoints(text)
        if loaded then
            checkpoints = loaded
            refreshList()
            dataWindow.Visible = false
            updateStatus("Data Loaded Successfully")
        else
            dataTextBox.Text = "ERROR: See Log"
        end
    elseif actionDataBtn.Text == "COPY" then
        local dataToCopy = (#currentExportData > 0) and currentExportData or dataTextBox.Text
        if setclipboard then
            setclipboard(dataToCopy)
            updateStatus("Data Copied to Clipboard")
            dataWindow.Visible = false
        elseif toclipboard then
             toclipboard(dataToCopy)
             updateStatus("Data Copied to Clipboard")
             dataWindow.Visible = false
        else
            if #dataToCopy > 100000 then
                dataTextBox.Text = "ERROR: Text too long to copy manually! Use Executor with setclipboard or writefile."
            else
                dataTextBox.Text = "Select All -> Ctrl+C manually"
            end
        end
    end
end)

saveDataBtn.MouseButton1Click:Connect(function()
    if canWriteFile then
        local dataToSave = (#currentExportData > 0) and currentExportData or dataTextBox.Text
        
        -- Try multiple writefile functions just in case
        local wf = writefile or (getgenv and getgenv().writefile)
        
        if wf then
            local success, err = pcall(function()
                wf("autowalk_data.json", dataToSave)
            end)
            if success then
                updateStatus("Saved to: autowalk_data.json")
                dataWindow.Visible = false
            else
                logError("Writefile: " .. tostring(err))
                dataTextBox.Text = "Error Saving File: " .. tostring(err)
            end
        else
             dataTextBox.Text = "Error: writefile function not found!"
        end
    end
end)


local function recordCheckpoint(index)
    if recordingIndex == index then
        stopAll() 
        return
    end
    
    stopAll() 
    
    recordingIndex = index
    checkpoints[index].inputs = {} 
    
    -- Set Start Position
    checkpoints[index].startPos = rootPart.Position
    
    updateStatus("Recording CP " .. index .. "...")
    refreshList()
    
    local lastInputTime = tick()
    local currentInput = {
        d = humanoid.MoveDirection,
        j = (humanoid:GetState() == Enum.HumanoidStateType.Jumping) or UserInputService:IsKeyDown(Enum.KeyCode.Space),
        p = rootPart.Position 
    }
    
    recordingConnection = RunService.Heartbeat:Connect(function() 
        if not character or not rootPart then return end
        
        local success, err = pcall(function()
            local now = tick()
            local dt = now - lastInputTime
            
            local moveDir = humanoid.MoveDirection
            moveDir = Vector3.new(moveDir.X, 0, moveDir.Z)
            
            local isJumping = (humanoid:GetState() == Enum.HumanoidStateType.Jumping) or UserInputService:IsKeyDown(Enum.KeyCode.Space)
            updateJumpIndicator(isJumping)
    
            local dirChanged = (moveDir - currentInput.d).Magnitude > 0.01
            local jumpChanged = (isJumping ~= currentInput.j)
            local maxTime = 1.0 
            
            if dirChanged or jumpChanged or dt > maxTime then
                 table.insert(checkpoints[index].inputs, {
                     dt = dt,
                     d = currentInput.d,
                     j = currentInput.j,
                     p = currentInput.p 
                 })
                 
                 currentInput = {
                     d = moveDir,
                     j = isJumping,
                     p = rootPart.Position
                 }
                 lastInputTime = now
            end
        end)
        if not success then logError("RecLoop: " .. err) end
    end)
end

-- Forward declaration 
local playCheckpoint 

playCheckpoint = function(index)
    if playingIndex == index then
        stopAll() 
        return
    end
    
    stopAll(false) 
    
    if #checkpoints[index].inputs == 0 then
        updateStatus("CP " .. index .. " is empty")
        if isPlayingAll and index < #checkpoints then
            task.delay(0.5, function() playCheckpoint(index + 1) end)
        else
            stopAll()
        end
        return
    end
    
    playingIndex = index
    updateStatus("Playing CP " .. index .. "...")
    refreshList()
    
    player.DevComputerMovementMode = Enum.DevComputerMovementMode.Scriptable
    player.DevTouchMovementMode = Enum.DevTouchMovementMode.Scriptable
    
    playingCoroutine = task.spawn(function()
        local success, err = pcall(function()
            if checkpoints[index].startPos then
                 rootPart.CFrame = CFrame.new(checkpoints[index].startPos) * rootPart.CFrame.Rotation
                 task.wait(0.1) 
            end
            
            for i, inp in ipairs(checkpoints[index].inputs) do
                if playingIndex ~= index then break end
                
                -- STABILIZATION logic
                if inp.p then
                    local currentPos = rootPart.Position
                    local expectedPos = inp.p
                    local dist = (currentPos - expectedPos).Magnitude
                    
                    if dist > 3.0 then
                        rootPart.CFrame = CFrame.new(expectedPos) * rootPart.CFrame.Rotation
                    elseif dist > 0.5 then
                        rootPart.CFrame = CFrame.new(expectedPos) * rootPart.CFrame.Rotation
                    end
                end
                
                local startTime = tick()
                local duration = inp.dt
                
                humanoid.Jump = inp.j
                updateJumpIndicator(inp.j)
                
                while (tick() - startTime) < duration do
                    if playingIndex ~= index then break end
                    
                    humanoid:Move(inp.d)
                    
                    if inp.j then humanoid.Jump = true end
                    
                    RunService.Stepped:Wait() 
                end
            end
        end)
        
        if not success then 
            logError("PlayLoop: " .. err)
            stopAll()
            return
        end
        
        if playingIndex == index then
            humanoid:Move(Vector3.new(0,0,0)) 
            playingIndex = nil
            if isPlayingAll and index < #checkpoints then
                updateStatus("Finished CP " .. index .. ". Next...")
                task.delay(0.1, function() playCheckpoint(index + 1) end)
            else
                updateStatus("Finished CP " .. index)
                stopAll() 
            end
        end
    end)
end

playAllBtn.MouseButton1Click:Connect(function()
    if isPlayingAll then
        stopAll()
    else
        stopAll()
        if #checkpoints == 0 then return end
        isPlayingAll = true
        playAllBtn.Text = "STOP PLAYING"
        playAllBtn.BackgroundColor3 = THEME.Error
        playCheckpoint(1)
    end
end)

local function deleteCheckpoint(index)
    stopAll()
    table.remove(checkpoints, index)
    refreshList()
end

local function createCheckpoint()
    local newIndex = #checkpoints + 1
    table.insert(checkpoints, {
        name = "Checkpoint " .. newIndex,
        inputs = {},
        startPos = nil
    })
    refreshList()
end

function refreshList()
    for _, child in ipairs(scrollFrame:GetChildren()) do
        if child:IsA("Frame") then child:Destroy() end
    end
    
    for i, cp in ipairs(checkpoints) do
        local entry = Instance.new("Frame")
        entry.Name = "CP_" .. i
        entry.Size = UDim2.new(1, 0, 0, 45) -- Taller rows
        entry.BackgroundColor3 = THEME.Surface
        entry.BorderSizePixel = 0
        entry.LayoutOrder = i
        entry.Parent = scrollFrame
        
        local entryCorner = Instance.new("UICorner")
        entryCorner.CornerRadius = UDim.new(0, 8)
        entryCorner.Parent = entry
        
        local cpInfo = "EMPTY"
        if cp.inputs and #cp.inputs > 0 then
             local totalTime = 0
             for _, inp in ipairs(cp.inputs) do totalTime = totalTime + inp.dt end
             cpInfo = string.format("%.1fs", totalTime)
        end
        
        local nameLabel = Instance.new("TextLabel")
        nameLabel.Size = UDim2.new(0, 100, 1, 0)
        nameLabel.Position = UDim2.new(0, 10, 0, 0)
        nameLabel.BackgroundTransparency = 1
        nameLabel.Text = "CHECKPOINT " .. i .. "\n<font color='#a6adc8' size='10'>" .. cpInfo .. "</font>"
        nameLabel.TextColor3 = THEME.Text
        nameLabel.Font = Enum.Font.GothamBold
        nameLabel.TextSize = 12
        nameLabel.RichText = true
        nameLabel.TextXAlignment = Enum.TextXAlignment.Left
        nameLabel.Parent = entry
        
        -- Action Buttons Wrapper for layout
        local actions = Instance.new("Frame")
        actions.Size = UDim2.new(0, 130, 1, 0)
        actions.Position = UDim2.new(1, -135, 0, 0)
        actions.BackgroundTransparency = 1
        actions.Parent = entry
        
        local function makeMiniBtn(text, color, pos)
            local b = Instance.new("TextButton")
            b.Size = UDim2.new(0, 40, 0, 25)
            b.Position = pos
            b.AnchorPoint = Vector2.new(0, 0.5)
            b.BackgroundColor3 = color
            b.Text = text
            b.TextColor3 = THEME.Background
            b.Font = Enum.Font.GothamBold
            b.TextSize = 9
            b.Parent = actions
            local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 6); c.Parent = b
            return b
        end

        local recColor = (recordingIndex == i) and THEME.Error or THEME.Background
        local recTxt = (recordingIndex == i) and "STOP" or "REC"
        local recBtn = makeMiniBtn(recTxt, recColor, UDim2.new(0, 0, 0.5, 0))
        if recordingIndex ~= i then recBtn.TextColor3 = THEME.Error end -- Hollow style ish
        
        local playColor = (playingIndex == i) and THEME.Warning or THEME.Background
        local playTxt = (playingIndex == i) and "STOP" or "PLAY"
        local playBtn = makeMiniBtn(playTxt, playColor, UDim2.new(0.35, 0, 0.5, 0))
        if playingIndex ~= i then playBtn.TextColor3 = THEME.Success end
 
        local delBtn = makeMiniBtn("X", THEME.Background, UDim2.new(0.7, 0, 0.5, 0))
        delBtn.TextColor3 = THEME.Subtext
        
        recBtn.MouseButton1Click:Connect(function() recordCheckpoint(i) end)
        playBtn.MouseButton1Click:Connect(function() playCheckpoint(i) end)
        delBtn.MouseButton1Click:Connect(function() deleteCheckpoint(i) end)
    end
    
    scrollFrame.CanvasSize = UDim2.new(0, 0, 0, listLayout.AbsoluteContentSize.Y + 20)
end

-- Ensure Add Button Connection
if addBtn then
    addBtn.MouseButton1Click:Connect(createCheckpoint)
end

player.CharacterAdded:Connect(function(newChar)
	character = newChar
	humanoid = newChar:WaitForChild("Humanoid")
	rootPart = newChar:WaitForChild("HumanoidRootPart")
    
    stopAll()
end)

if character then
    print("Character Initialized. Showing UI.")
    mainFrame.Visible = true
else
    print("Waiting for Character...")
end
refreshList()
print("Autowalk: Initialization Complete")
