--[[
    AUTOWALK PLAYER - Modular Version
    Created by: IO/Antigravity
    
    INSTRUCTIONS:
    1. Put your recording data in: recordings.lua
    2. Execute this script in-game
    3. Press F5 to stop
]]

-------------------------------------------------------------------------
-- LOAD RECORDING DATA
-------------------------------------------------------------------------
local RECORDING_DATA = loadfile("recordings.lua")()

-------------------------------------------------------------------------
-- JSON PARSER
-------------------------------------------------------------------------
local json = loadstring(game:HttpGet("https://raw.githubusercontent.com/rxi/json.lua/master/json.lua"))()

-------------------------------------------------------------------------
-- PLAYER CONTROL VARIABLES
-------------------------------------------------------------------------
local player = game.Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid")
local rootPart = character:WaitForChild("HumanoidRootPart")
local checkpoints = {}
local isRunning = true
local currentCheckpoint = 1

-------------------------------------------------------------------------
-- UI STATUS
-------------------------------------------------------------------------
local function updateStatus(msg)
    print("[AUTOWALK] " .. msg)
end

-------------------------------------------------------------------------
-- STOP MECHANISM (F5)
-------------------------------------------------------------------------
local UserInputService = game:GetService("UserInputService")
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if not gameProcessed and input.KeyCode == Enum.KeyCode.F5 then
        isRunning = false
        updateStatus("Stopped by user (F5)")
    end
end)

-------------------------------------------------------------------------
-- RESPAWN HANDLER
-------------------------------------------------------------------------
player.CharacterAdded:Connect(function(newChar)
    task.wait(0.5)
    character = newChar
    humanoid = newChar:WaitForChild("Humanoid")
    rootPart = newChar:WaitForChild("HumanoidRootPart")
    
    if isRunning and #checkpoints > 0 then
        updateStatus("Respawned! Continuing from checkpoint " .. currentCheckpoint)
        task.wait(1)
        playCheckpoint(currentCheckpoint)
    end
end)

-------------------------------------------------------------------------
-- PLAYBACK FUNCTION
-------------------------------------------------------------------------
function playCheckpoint(cpIndex)
    if not isRunning or cpIndex > #checkpoints then return end
    
    local cp = checkpoints[cpIndex]
    currentCheckpoint = cpIndex
    
    updateStatus("Playing: " .. cp.name)
    
    -- Teleport to start position
    if cp.startPos then
        rootPart.CFrame = CFrame.new(unpack(cp.startPos))
        task.wait(0.1)
    end
    
    -- Play all inputs
    for i, inp in ipairs(cp.inputs) do
        if not isRunning then break end
        
        -- Set position and direction
        if inp.p then
            rootPart.CFrame = CFrame.new(unpack(inp.p))
        end
        
        if inp.d and inp.d[1] ~= 0 or inp.d[2] ~= 0 or inp.d[3] ~= 0 then
            local moveDir = Vector3.new(unpack(inp.d))
            humanoid:Move(moveDir)
        else
            humanoid:Move(Vector3.zero)
        end
        
        -- Handle jump
        if inp.j then
            humanoid.Jump = true
        end
        
        -- Wait for next frame
        if inp.dt then
            task.wait(inp.dt)
        end
    end
    
    updateStatus("Finished: " .. cp.name)
end

-------------------------------------------------------------------------
-- PLAY ALL CHECKPOINTS (LOOP)
-------------------------------------------------------------------------
function playAllCheckpoints()
    while isRunning do
        for i = 1, #checkpoints do
            if not isRunning then break end
            playCheckpoint(i)
            task.wait(0.5)
        end
        
        if isRunning then
            updateStatus("Loop complete! Restarting...")
            task.wait(1)
        end
    end
end

-------------------------------------------------------------------------
-- DESERIALIZE DATA
-------------------------------------------------------------------------
function deserialize(jsonStr)
    local success, data = pcall(function()
        return json.decode(jsonStr)
    end)
    
    if not success then
        updateStatus("Error parsing JSON!")
        return nil
    end
    
    local loaded = {}
    for _, cpData in ipairs(data) do
        local newCP = {
            name = cpData.name,
            startPos = cpData.startPos,
            inputs = {}
        }
        
        for _, inpData in ipairs(cpData.inputs) do
            local dVec = inpData.d or {0, 0, 0}
            
            table.insert(newCP.inputs, {
                dt = inpData.dt,
                d = dVec,
                j = inpData.j,
                i = inpData.i
            })
        end
        table.insert(loaded, newCP)
    end
    return loaded
end

-------------------------------------------------------------------------
-- MAIN START
-------------------------------------------------------------------------
if RECORDING_DATA and RECORDING_DATA ~= "" and RECORDING_DATA:find("%[") then
    local data = deserialize(RECORDING_DATA)
    if data then
        checkpoints = data
        updateStatus("Data Loaded! Starting in 3s...")
        task.wait(3)
        playAllCheckpoints()
    else
        updateStatus("Error: Invalid Data.")
    end
else
    updateStatus("Error: No recording data found in recordings.lua")
end
