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

local function updateCharacter(newChar)
    if not newChar then return end
    character = newChar
    humanoid = newChar:WaitForChild("Humanoid")
    rootPart = newChar:WaitForChild("HumanoidRootPart")
    print("Autowalk: Character Updated")
end

player.CharacterAdded:Connect(updateCharacter)

print("Autowalk: Character Found")

local checkpoints = {} 
local recordingIndex = nil 
local playingIndex = nil   
local isPlayingAll = false 
local recordingConnection
local interactionConnection
local playingCoroutine
local lastJumpTime = 0 
local showLogs = false 

local THEME = {
    Background = Color3.fromRGB(30, 30, 46),
    Surface = Color3.fromRGB(49, 50, 68),
    Primary = Color3.fromRGB(137, 180, 250),
    Success = Color3.fromRGB(166, 227, 161),
    Warning = Color3.fromRGB(250, 179, 135),
    Error = Color3.fromRGB(243, 139, 168),
    Text = Color3.fromRGB(205, 214, 244),
    Subtext = Color3.fromRGB(166, 173, 200)
}

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if input.KeyCode == Enum.KeyCode.F5 then
        if recordingIndex then
            stopAll()
            updateStatus("Recording Stopped via F5")
        end
    end
end)

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "AutowalkRecorderGUI"
screenGui.IgnoreGuiInset = true
screenGui.DisplayOrder = 2000
screenGui.ResetOnSpawn = false 
if player:WaitForChild("PlayerGui"):FindFirstChild("AutowalkRecorderGUI") then
    player.PlayerGui.AutowalkRecorderGUI:Destroy()
end
screenGui.Parent = player:WaitForChild("PlayerGui")

local mainFrame = Instance.new("Frame")
mainFrame.Name = "MainFrame"
mainFrame.Size = UDim2.new(0, 320, 0, 550)
mainFrame.Position = UDim2.new(0, 20, 0.5, -275)
mainFrame.BackgroundColor3 = THEME.Background
mainFrame.BorderSizePixel = 0
mainFrame.Visible = true
mainFrame.Parent = screenGui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 12)
corner.Parent = mainFrame

local stroke = Instance.new("UIStroke")
stroke.Color = THEME.Surface
stroke.Thickness = 2
stroke.Parent = mainFrame


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
titleLabel.Text = "ADEN TAYANK ALEYNA" 
titleLabel.TextColor3 = THEME.Text
titleLabel.Font = Enum.Font.GothamBlack
titleLabel.TextSize = 20
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.Parent = headerFrame

local statusLabel = Instance.new("TextLabel")
statusLabel.Name = "Status"
statusLabel.Size = UDim2.new(1, -20, 0, 20)
statusLabel.Position = UDim2.new(0, 15, 0, 35)
statusLabel.BackgroundTransparency = 1
statusLabel.Text = "READY TO RECORD"
statusLabel.TextColor3 = THEME.Subtext
statusLabel.Font = Enum.Font.GothamBold
statusLabel.TextSize = 10
statusLabel.TextXAlignment = Enum.TextXAlignment.Left
statusLabel.Parent = headerFrame 

local jumpIndicator = Instance.new("Frame")
jumpIndicator.Name = "JumpIndicator"
jumpIndicator.Size = UDim2.new(0, 10, 0, 10)
jumpIndicator.Position = UDim2.new(1, -25, 0.5, -5)
jumpIndicator.BackgroundColor3 = THEME.Surface
jumpIndicator.BorderSizePixel = 0
jumpIndicator.Parent = headerFrame
local jiCorner = Instance.new("UICorner"); jiCorner.CornerRadius = UDim.new(1, 0); jiCorner.Parent = jumpIndicator
local jiStroke = Instance.new("UIStroke"); jiStroke.Color = THEME.Subtext; jiStroke.Thickness = 1; jiStroke.Parent = jumpIndicator

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

local scrollFrame = Instance.new("ScrollingFrame")
scrollFrame.Name = "CheckpointsList"
scrollFrame.Size = UDim2.new(1, -10, 1, -200)
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
listPadding.PaddingBottom = UDim.new(0, 10)
listPadding.Parent = scrollFrame

local footerFrame = Instance.new("Frame")
footerFrame.Name = "Footer"
footerFrame.Size = UDim2.new(1, -20, 0, 155)
footerFrame.Position = UDim2.new(0, 10, 1, -165)
footerFrame.BackgroundTransparency = 1
footerFrame.Parent = mainFrame

local respawnContainer = Instance.new("Frame")
respawnContainer.Name = "RespawnContainer"
respawnContainer.Size = UDim2.new(1, 0, 0, 30)
respawnContainer.Position = UDim2.new(0, 0, 0, 0)
respawnContainer.BackgroundTransparency = 1
respawnContainer.Parent = footerFrame

local respawnLabel = Instance.new("TextLabel")
respawnLabel.Name = "Label"
respawnLabel.Size = UDim2.new(1, -30, 1, 0)
respawnLabel.Position = UDim2.new(0, 30, 0, 0)
respawnLabel.BackgroundTransparency = 1
respawnLabel.Text = "Auto Respawn on Finish"
respawnLabel.TextColor3 = THEME.Subtext
respawnLabel.Font = Enum.Font.GothamMedium
respawnLabel.TextSize = 14
respawnLabel.TextXAlignment = Enum.TextXAlignment.Left
respawnLabel.Parent = respawnContainer

local respawnButton = Instance.new("TextButton")
respawnButton.Name = "ToggleButton"
respawnButton.Size = UDim2.new(0, 20, 0, 20)
respawnButton.Position = UDim2.new(0, 0, 0.5, -10)
respawnButton.BackgroundColor3 = THEME.Surface
respawnButton.Text = ""
respawnButton.AutoButtonColor = false
respawnButton.Parent = respawnContainer

local rCorner = Instance.new("UICorner"); rCorner.CornerRadius = UDim.new(0, 4); rCorner.Parent = respawnButton
local rStroke = Instance.new("UIStroke"); rStroke.Color = THEME.Subtext; rStroke.Thickness = 2; rStroke.Parent = respawnButton

respawnButton.MouseButton1Click:Connect(function()
    isAutoRespawn = not isAutoRespawn
    if isAutoRespawn then
        respawnButton.BackgroundColor3 = THEME.Primary
        rStroke.Color = THEME.Primary
    else
        respawnButton.BackgroundColor3 = THEME.Surface
        rStroke.Color = THEME.Subtext
    end
end)

local isLooping = false

local loopContainer = Instance.new("Frame")
loopContainer.Name = "LoopContainer"
loopContainer.Size = UDim2.new(1, 0, 0, 30)
loopContainer.Position = UDim2.new(0, 0, 0, 30)
loopContainer.BackgroundTransparency = 1
loopContainer.Parent = footerFrame

local loopLabel = Instance.new("TextLabel")
loopLabel.Name = "Label"
loopLabel.Size = UDim2.new(1, -30, 1, 0)
loopLabel.Position = UDim2.new(0, 30, 0, 0)
loopLabel.BackgroundTransparency = 1
loopLabel.Text = "Auto Loop / AFK Mode"
loopLabel.TextColor3 = THEME.Subtext
loopLabel.Font = Enum.Font.GothamMedium
loopLabel.TextSize = 14
loopLabel.TextXAlignment = Enum.TextXAlignment.Left
loopLabel.Parent = loopContainer

local loopButton = Instance.new("TextButton")
loopButton.Name = "ToggleButton"
loopButton.Size = UDim2.new(0, 20, 0, 20)
loopButton.Position = UDim2.new(0, 0, 0.5, -10)
loopButton.BackgroundColor3 = THEME.Surface
loopButton.Text = ""
loopButton.AutoButtonColor = false
loopButton.Parent = loopContainer

local lCorner = Instance.new("UICorner"); lCorner.CornerRadius = UDim.new(0, 4); lCorner.Parent = loopButton
local lStroke = Instance.new("UIStroke"); lStroke.Color = THEME.Subtext; lStroke.Thickness = 2; lStroke.Parent = loopButton

loopButton.MouseButton1Click:Connect(function()
    isLooping = not isLooping
    if isLooping then
        loopButton.BackgroundColor3 = THEME.Primary
        lStroke.Color = THEME.Primary
    else
        loopButton.BackgroundColor3 = THEME.Surface
        lStroke.Color = THEME.Subtext
    end
end)

local playAllBtn = Instance.new("TextButton")
playAllBtn.Name = "PlayAllButton"
playAllBtn.Size = UDim2.new(1, 0, 0, 40) 
playAllBtn.Position = UDim2.new(0, 0, 0, 70)
playAllBtn.BackgroundColor3 = THEME.Success
playAllBtn.Text = "PLAY ALL CHECKPOINTS"
playAllBtn.TextColor3 = THEME.Background
playAllBtn.Font = Enum.Font.GothamBlack
playAllBtn.TextSize = 14
playAllBtn.Parent = footerFrame
local paCorner = Instance.new("UICorner"); paCorner.CornerRadius = UDim.new(0, 8); paCorner.Parent = playAllBtn

local addBtn = Instance.new("TextButton")
addBtn.Name = "AddButton"
addBtn.Size = UDim2.new(1, 0, 0, 40)
addBtn.Position = UDim2.new(0, 0, 0, 120)
addBtn.BackgroundColor3 = THEME.Surface
addBtn.Text = "+ Add New Checkpoint"
addBtn.TextColor3 = THEME.Text
addBtn.Font = Enum.Font.GothamBold
addBtn.TextSize = 14
addBtn.Parent = footerFrame
local addCorner = Instance.new("UICorner"); addCorner.CornerRadius = UDim.new(0, 8); addCorner.Parent = addBtn

addBtn.MouseButton1Click:Connect(createCheckpoint)

local logOverlay = Instance.new("ScrollingFrame")
logOverlay.Name = "LogOverlay"
logOverlay.Size = UDim2.new(1, -20, 0, 150)
logOverlay.Position = UDim2.new(0, 10, 1, -160)
logOverlay.BackgroundColor3 = Color3.new(0,0,0)
logOverlay.BackgroundTransparency = 0.1
logOverlay.Visible = false
logOverlay.ZIndex = 30
logOverlay.Parent = mainFrame
local loCorner = Instance.new("UICorner"); loCorner.Parent = logOverlay

local logLabel = Instance.new("TextLabel")
logLabel.Size = UDim2.new(1, -10, 0, 0)
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

local actionDataBtn = Instance.new("TextButton")
actionDataBtn.Size = UDim2.new(0.3, 0, 0, 35)
actionDataBtn.Position = UDim2.new(0.375, 0, 1, -45)
actionDataBtn.BackgroundColor3 = THEME.Primary
actionDataBtn.Text = "ACTION"
actionDataBtn.TextColor3 = THEME.Background
actionDataBtn.Font = Enum.Font.GothamBold
actionDataBtn.ZIndex = 42
actionDataBtn.Parent = dwContent
local adbCorner = Instance.new("UICorner"); adbCorner.Parent = actionDataBtn

local saveDataBtn = Instance.new("TextButton")
saveDataBtn.Size = UDim2.new(0.25, 0, 0, 35)
saveDataBtn.Position = UDim2.new(0.7, 0, 1, -45)
saveDataBtn.BackgroundColor3 = THEME.Warning
saveDataBtn.Text = "SAVE FILE"
saveDataBtn.TextColor3 = THEME.Background
saveDataBtn.Font = Enum.Font.GothamBold
saveDataBtn.ZIndex = 42
saveDataBtn.Visible = false
saveDataBtn.Parent = dwContent
local sdbCorner = Instance.new("UICorner"); sdbCorner.Parent = saveDataBtn

if not writefile then
    saveDataBtn.Visible = false
    actionDataBtn.Size = UDim2.new(0.6, 0, 0, 35)
    actionDataBtn.Position = UDim2.new(0.375, 0, 1, -45)
end

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

        if interactionConnection then
            interactionConnection:Disconnect()
            interactionConnection = nil
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

local currentExportData = ""

local canWriteFile = (writefile ~= nil) or (makefolder ~= nil)
if not canWriteFile and getgenv then
    canWriteFile = (getgenv().writefile ~= nil)
end
print("Autowalk: Can Write File? " .. tostring(canWriteFile))

exportBtn.MouseButton1Click:Connect(function()
    print("Autowalk: Export Button Clicked")
    stopAll()
    
    dwTitle.Text = "EXPORTING..."
    dataTextBox.Text = "Generating JSON data... Please wait."
    dataWindow.Visible = true
    saveDataBtn.Visible = false
    actionDataBtn.Visible = false
    
    task.wait()
    
    local success, json = pcall(serializeCheckpoints)
    if not success then 
        logError("Serialize: " .. json)
        dataTextBox.Text = "ERROR: " .. tostring(json)
        return 
    end
    
    currentExportData = json
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
        actionDataBtn.Size = UDim2.new(0.3, 0, 0, 35)
        actionDataBtn.Position = UDim2.new(0.375, 0, 1, -45)
    else
        saveDataBtn.Visible = false
        actionDataBtn.Size = UDim2.new(0.55, 0, 0, 35)
        actionDataBtn.Position = UDim2.new(0.4, 0, 1, -45)
    end
end)

importBtn.MouseButton1Click:Connect(function()
    stopAll()
    dataTextBox.Text = ""
    currentExportData = ""
    actionDataBtn.Text = "LOAD"
    actionDataBtn.Visible = true
    actionDataBtn.Size = UDim2.new(0.55, 0, 0, 35)
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
    
    local mouse = player:GetMouse()
    
    -- Removed 'local' to use the upvalue defined at top of script
    interactionConnection = UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
             local target = mouse.Target
             print("Autowalk Debug: Clicked Target: " .. (target and target.Name or "NIL"))
             
             local foundInteraction = false
             
             if target then
                 -- CHECK 1: Direct Hit
                 local cd = target:FindFirstChild("ClickDetector") or target.Parent:FindFirstChild("ClickDetector")
                 local pp = target:FindFirstChild("ProximityPrompt") or target.Parent:FindFirstChild("ProximityPrompt")
                 
                 if cd then
                     print("Autowalk Debug: Found ClickDetector on " .. target.Name)
                     updateStatus("Recorded Click: " .. target.Name)
                     table.insert(checkpoints[index].inputs, {
                         dt = 0.1, d = Vector3.zero, j = false, p = rootPart.Position,
                         interaction = { type = "ClickDetector", targetName = target.Name }
                     })
                     foundInteraction = true
                 elseif pp then
                     print("Autowalk Debug: Found ProximityPrompt on " .. target.Name)
                     updateStatus("Recorded Prompt: " .. target.Name)
                     table.insert(checkpoints[index].inputs, {
                         dt = 0.1, d = Vector3.zero, j = false, p = rootPart.Position,
                         interaction = { type = "ProximityPrompt", targetName = target.Name }
                     })
                     foundInteraction = true
                 end
             end
             
             -- CHECK 2: Scan Nearby (Fallback if direct hit failed)
             if not foundInteraction then
                 print("Autowalk Debug: Direct Hit Failed/Terrain. Scanning Nearby (15 studs)...")
                 local r = 15
                 local region = Region3.new(rootPart.Position - Vector3.new(r,r,r), rootPart.Position + Vector3.new(r,r,r))
                 local parts = workspace:FindPartsInRegion3(region, nil, 100)
                 
                 for _, part in ipairs(parts) do
                     local cd = part:FindFirstChild("ClickDetector") or part.Parent:FindFirstChild("ClickDetector")
                     local pp = part:FindFirstChild("ProximityPrompt") or part.Parent:FindFirstChild("ProximityPrompt")
                     
                     if cd then
                         print("Autowalk Debug: Found Nearby ClickDetector on " .. part.Name)
                         updateStatus("Auto-Recorded Nearby Click: " .. part.Name)
                         table.insert(checkpoints[index].inputs, {
                             dt = 0.1, d = Vector3.zero, j = false, p = rootPart.Position,
                             interaction = { type = "ClickDetector", targetName = part.Name }
                         })
                         foundInteraction = true
                         break
                     elseif pp then
                         print("Autowalk Debug: Found Nearby ProximityPrompt on " .. part.Name)
                         updateStatus("Auto-Recorded Nearby Prompt: " .. part.Name)
                         table.insert(checkpoints[index].inputs, {
                             dt = 0.1, d = Vector3.zero, j = false, p = rootPart.Position,
                             interaction = { type = "ProximityPrompt", targetName = part.Name }
                         })
                         foundInteraction = true
                         break
                     end
                 end
                 
                 if not foundInteraction then
                     print("Autowalk Debug: No Interaction Component Found ANYWHERE nearby")
                     
                     -- CHECK 3: Smart UI Button Detection
                     -- Try to find the button under the mouse in PlayerGui
                     local pGui = player:WaitForChild("PlayerGui")
                     local guiObjects = pGui:GetGuiObjectsAtPosition(mouse.X, mouse.Y)
                     
                     -- Also check CoreGui? Maybe not safe/allowed depending on context. sticking to PlayerGui.
                     
                     for _, guiObj in ipairs(guiObjects) do
                         if guiObj:IsA("TextButton") or guiObj:IsA("ImageButton") then
                             print("Autowalk Debug: Found UI Button: " .. guiObj.Name)
                             updateStatus("Recorded UI Button: " .. guiObj.Name)
                             
                             -- Store hierarchy path for re-finding
                             local pathTable = {}
                             local current = guiObj
                             while current and current ~= pGui and current ~= game do
                                 table.insert(pathTable, 1, current.Name)
                                 current = current.Parent
                             end
                             
                             table.insert(checkpoints[index].inputs, {
                                 dt = 0.1, d = Vector3.zero, j = false, p = rootPart.Position,
                                 interaction = { 
                                     type = "GuiButton", 
                                     targetName = guiObj.Name,
                                     path = pathTable 
                                 }
                             })
                             foundInteraction = true
                             break
                         end
                     end
                     
                     if not foundInteraction then
                         -- CHECK 4: Screen Click (Last Resort Fallback)
                         print("Autowalk Debug: No Button Found. Recording Screen Click at " .. mouse.X .. ", " .. mouse.Y)
                         updateStatus("Recorded Area Click at " .. mouse.X .. ", " .. mouse.Y)
                         
                         table.insert(checkpoints[index].inputs, {
                             dt = 0.1, d = Vector3.zero, j = false, p = rootPart.Position,
                             interaction = { type = "ScreenClick", x = mouse.X, y = mouse.Y, targetName = "Screen_Click" }
                         })
                         foundInteraction = true
                     end
                 end
             end
        end
    end)
    
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
                
                -- INTERACTION REPLAY Logic
                if inp.interaction then
                    print("Autowalk Debug: Replaying Interaction for " .. (inp.interaction.targetName or "Unknown"))
                    local targetObj = nil
                    pcall(function()
                        local r = 20 -- Increased Radius
                        local region = Region3.new(rootPart.Position - Vector3.new(r,r,r), rootPart.Position + Vector3.new(r,r,r))
                        local parts = workspace:FindPartsInRegion3(region, nil, 100)
                        for _, part in ipairs(parts) do
                            if part.Name == inp.interaction.targetName then
                                if inp.interaction.type == "ClickDetector" and (part:FindFirstChild("ClickDetector") or part.Parent:FindFirstChild("ClickDetector")) then
                                    targetObj = part:FindFirstChild("ClickDetector") or part.Parent:FindFirstChild("ClickDetector")
                                    break
                                elseif inp.interaction.type == "ProximityPrompt" and (part:FindFirstChild("ProximityPrompt") or part.Parent:FindFirstChild("ProximityPrompt")) then
                                    targetObj = part:FindFirstChild("ProximityPrompt") or part.Parent:FindFirstChild("ProximityPrompt")
                                    break
                                end
                            end
                        end
                    end)
                    
                    if targetObj then
                        print("Autowalk Debug: Found Object! Parent: " .. targetObj.Parent.Name)
                        updateStatus("Interacting with " .. targetObj.Parent.Name .. "...")
                        
                        if inp.interaction.type == "ClickDetector" then
                            if fireclickdetector then 
                                print("Autowalk Debug: Firing via fireclickdetector...")
                                fireclickdetector(targetObj) 
                            else
                                print("Autowalk Debug: fireclickdetector missing! Trying VirtualInputManager...")
                                -- Fallback: Virtual Input
                                local vim = game:GetService("VirtualInputManager")
                                vim:SendMouseButtonEvent(0, 0, 0, true, game, 0)
                                task.wait(0.05)
                                vim:SendMouseButtonEvent(0, 0, 0, false, game, 0)
                            end
                        elseif inp.interaction.type == "ProximityPrompt" then
                            if fireproximityprompt then 
                                print("Autowalk Debug: Firing via fireproximityprompt...")
                                fireproximityprompt(targetObj) 
                            end
                        end
                        task.wait(0.5) 
                    else
                        -- Fallback for UI Interaction (Smart Button & Screen Click)
                        if inp.interaction.type == "GuiButton" then
                             print("Autowalk Debug: Searching for UI Button: " .. inp.interaction.targetName)
                             
                             local pGui = player:WaitForChild("PlayerGui")
                             local targetButton = nil
                             
                             -- Helper: Recursive Search by Name
                             local function findButtonByName(parent, name)
                                 for _, child in ipairs(parent:GetDescendants()) do
                                     if child.Name == name and (child:IsA("GuiButton") or child:IsA("ImageButton")) then
                                         return child
                                     end
                                 end
                                 return nil
                             end
                             
                             targetButton = findButtonByName(pGui, inp.interaction.targetName)
                             
                             if targetButton then
                                 print("Autowalk Debug: Found Button via Global Search! " .. targetButton:GetFullName())
                                 updateStatus("Clicking Button: " .. targetButton.Name)
                                 
                                 -- Try firesignal first (Best for exploits)
                                 local fired = false
                                 if firesignal then
                                     pcall(function()
                                         print("Autowalk Debug: Attempting firesignal(MouseButton1Click)...")
                                         firesignal(targetButton.MouseButton1Click)
                                         fired = true
                                     end)
                                 end
                                 
                                 -- Try getconnections (Common exploit method)
                                 if not fired and getconnections then
                                     pcall(function()
                                         print("Autowalk Debug: Attempting getconnections(MouseButton1Click)...")
                                         for _, conn in ipairs(getconnections(targetButton.MouseButton1Click)) do
                                             conn:Fire()
                                             fired = true
                                         end
                                         print("Autowalk Debug: Attempting getconnections(Activated)...")
                                         for _, conn in ipairs(getconnections(targetButton.Activated)) do
                                             conn:Fire()
                                             fired = true
                                         end
                                     end)
                                 end
                                 
                                 if not fired then
                                     -- Fallback: VirtualInputManager (Simulated Click)
                                     print("Autowalk Debug: Attempting VirtualInputManager Click...")
                                     local absPos = targetButton.AbsolutePosition
                                     local absSize = targetButton.AbsoluteSize
                                     local centerX = absPos.X + (absSize.X / 2)
                                     local centerY = absPos.Y + (absSize.Y / 2)
                                     
                                     local vim = game:GetService("VirtualInputManager")
                                     vim:SendMouseButtonEvent(centerX, centerY, 0, true, game, 0)
                                     task.wait(0.05)
                                     vim:SendMouseButtonEvent(centerX, centerY, 0, false, game, 0)
                                 end
                                 
                                 task.wait(0.5)
                             else
                                 print("Autowalk Debug: UI Button NOT FOUND anywhere in PlayerGui.")
                                 updateStatus("Button Not Found: " .. inp.interaction.targetName)
                             end
                             
                        elseif inp.interaction.type == "ScreenClick" then
                            print("Autowalk Debug: Replaying Screen Click at " .. inp.interaction.x .. ", " .. inp.interaction.y)
                            updateStatus("Clicking Screen at " .. inp.interaction.x .. ", " .. inp.interaction.y)
                            
                            local vim = game:GetService("VirtualInputManager")
                            vim:SendMouseButtonEvent(inp.interaction.x, inp.interaction.y, 0, true, game, 0)
                            task.wait(0.05)
                            vim:SendMouseButtonEvent(inp.interaction.x, inp.interaction.y, 0, false, game, 0)
                            task.wait(0.5)
                        else
                            print("Autowalk Debug: Target Interaction Object NOT FOUND nearby!")
                            updateStatus("Interaction Target Not Found: " .. (inp.interaction.targetName or "?"))
                        end
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
                if isAutoRespawn then
                    print("Autowalk Debug: Auto Respawn Enabled. Triggering in 2s...")
                    updateStatus("Auto Respawning in 2s...")
                    local char = player.Character
                    if char then
                        local hum = char:FindFirstChild("Humanoid")
                        if hum then hum.Health = 0 end
                    end
                    
                    if isLooping then
                        updateStatus("Waiting for Respawn (Looping)...")
                        local newChar = player.CharacterAdded:Wait()
                        updateStatus("Character Respawned. Waiting 3s...")
                        task.wait(3) -- Wait for load (animate, physics settle)
                        
                        -- Explicitly refresh character variables
                        character = newChar
                        humanoid = newChar:WaitForChild("Humanoid")
                        rootPart = newChar:WaitForChild("HumanoidRootPart")
                        print("Autowalk Debug: Character Variables Refreshed for Loop")
                        
                        updateStatus("Restarting Loop...")
                        playAllCheckpoints()
                        return -- Prevent stopAll
                    end
                elseif isLooping then
                    -- Loop without Respawn (just teleport back to start effectively)
                    updateStatus("Looping in 1s...")
                    task.wait(1)
                    playAllCheckpoints()
                    return -- Prevent stopAll
                end
                
                stopAll() 
            end
        end
    end)
end

-- Define as a named function for recursion
function playAllCheckpoints()
    if isPlayingAll then
        stopAll()
        playAllBtn.Text = "PLAY ALL CHECKPOINTS"
        playAllBtn.BackgroundColor3 = THEME.Success
    else
        stopAll()
        if #checkpoints == 0 then return end
        isPlayingAll = true
        playAllBtn.Text = "STOP PLAYING"
        playAllBtn.BackgroundColor3 = THEME.Error
        playCheckpoint(1)
    end
end

playAllBtn.MouseButton1Click:Connect(playAllCheckpoints)

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
