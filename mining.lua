-- Advanced Diamond Mining Program - Complete Fixed Version
-- Settings
local tunnelLength = 50      -- Length of each tunnel
local tunnelCount = 20       -- Total number of tunnels
local spacing = 2            -- Spacing between tunnels (2 is ideal)
local fuelSlot = 1          -- Slot for fuel (coal/charcoal)
local torchSlot = 15        -- Slot for torches
local cobbleSlot = 16       -- Slot for cobblestone (lava protection + torch support)
local torchInterval = 10     -- Place torch every X blocks

-- Position tracking
local currentX = 0
local currentY = 0
local currentZ = 0
local facing = 0  -- 0=North, 1=East, 2=South, 3=West

-- Statistics
local totalBlocksMined = 0
local totalDiamonds = 0
local currentTunnel = 0
local currentStep = 0
local stuckCounter = 0
local lastPosition = {x = 0, y = 0, z = 0}

-- Recovery system
local maxStuckAttempts = 20
local emergencyFuelReserve = 100

-- Utility Functions
function log(message)
  print("[" .. os.date("%H:%M:%S") .. "] " .. message)
end

function turnAround()
  turtle.turnLeft()
  turtle.turnLeft()
  facing = (facing + 2) % 4
end

function turnRight()
  turtle.turnRight()
  facing = (facing + 1) % 4
end

function turnLeft()
  turtle.turnLeft()
  facing = (facing - 1) % 4
end

-- Enhanced fuel management
function checkFuel(requiredFuel)
  local currentFuel = turtle.getFuelLevel()
  if currentFuel == "unlimited" then
    return true
  end
  
  if currentFuel < requiredFuel then
    log("Fuel low (" .. currentFuel .. "/" .. requiredFuel .. "), refueling...")
    turtle.select(fuelSlot)
    
    local attempts = 0
    while turtle.getFuelLevel() < requiredFuel and turtle.getItemCount(fuelSlot) > 0 and attempts < 10 do
      if not turtle.refuel(1) then
        log("Failed to refuel!")
        break
      end
      attempts = attempts + 1
    end
    
    if turtle.getFuelLevel() < requiredFuel then
      log("CRITICAL: Out of fuel! Current: " .. turtle.getFuelLevel() .. ", Required: " .. requiredFuel)
      return false
    end
    
    log("Refueled successfully. Current fuel: " .. turtle.getFuelLevel())
  end
  return true
end

function calculateRequiredFuel()
  local fuelPerTunnel = (tunnelLength * 2) + (spacing * 2) + 50
  local totalFuel = fuelPerTunnel * tunnelCount + emergencyFuelReserve
  return totalFuel
end

-- Position tracking and stuck detection
function updatePosition()
  lastPosition.x = currentX
  lastPosition.y = currentY
  lastPosition.z = currentZ
end

function checkIfStuck()
  if currentX == lastPosition.x and currentY == lastPosition.y and currentZ == lastPosition.z then
    stuckCounter = stuckCounter + 1
    log("Warning: Stuck detection - attempt " .. stuckCounter)
    return stuckCounter >= 3
  else
    stuckCounter = 0
    return false
  end
end

-- Advanced obstacle handling
function identifyBlockType(direction)
  local success, data
  
  if direction == "forward" then
    success, data = turtle.inspect()
  elseif direction == "up" then
    success, data = turtle.inspectUp()
  elseif direction == "down" then
    success, data = turtle.inspectDown()
  end
  
  if not success or not data.name then
    return "empty"
  end
  
  local blockName = data.name:lower()
  
  if string.find(blockName, "torch") then
    return "torch"
  elseif string.find(blockName, "lava") then
    return "lava"
  elseif string.find(blockName, "water") then
    return "water"
  elseif string.find(blockName, "bedrock") then
    return "bedrock"
  elseif string.find(blockName, "chest") then
    return "chest"
  elseif string.find(blockName, "ore") then
    return "ore"
  else
    return "block"
  end
end

-- Smart movement with obstacle bypass
function smartForward()
  updatePosition()
  
  local attempts = 0
  while not turtle.forward() and attempts < maxStuckAttempts do
    local blockType = identifyBlockType("forward")
    
    log("Obstacle detected: " .. blockType)
    
    if blockType == "torch" then
      log("Torch detected - attempting bypass")
      if not bypassTorch() then
        log("Cannot bypass torch, digging it")
        turtle.dig()
      end
      
    elseif blockType == "lava" then
      log("LAVA! Attempting to contain")
      if not handleLava() then
        log("Cannot handle lava safely")
        return false
      end
      
    elseif blockType == "bedrock" then
      log("Bedrock detected - cannot proceed")
      return false
      
    elseif blockType == "chest" then
      log("Chest detected - will not dig")
      return false
      
    elseif blockType == "water" then
      log("Water detected - filling with cobblestone")
      turtle.select(cobbleSlot)
      turtle.place()
      turtle.select(fuelSlot)
      
    elseif blockType == "block" or blockType == "ore" then
      turtle.dig()
      os.sleep(0.1)
      
    else
      -- Unknown obstacle - might be mob or item
      log("Unknown obstacle - waiting and retrying")
      os.sleep(0.5)
    end
    
    attempts = attempts + 1
    
    -- Emergency stuck handling
    if attempts > 5 and checkIfStuck() then
      log("STUCK! Attempting emergency bypass")
      if not emergencyBypass() then
        log("Emergency bypass failed")
        return false
      end
    end
  end
  
  if attempts >= maxStuckAttempts then
    log("ERROR: Cannot move forward after " .. maxStuckAttempts .. " attempts!")
    return false
  end
  
  -- Update position tracking
  if facing == 0 then currentZ = currentZ - 1
  elseif facing == 1 then currentX = currentX + 1
  elseif facing == 2 then currentZ = currentZ + 1
  elseif facing == 3 then currentX = currentX - 1
  end
  
  return true
end

-- Torch bypass system
function bypassTorch()
  log("Attempting to bypass torch...")
  
  -- Try going around the torch
  -- Method 1: Go up and around
  if not turtle.detectUp() then
    if turtle.up() then
      currentY = currentY + 1
      if turtle.forward() then
        if facing == 0 then currentZ = currentZ - 1
        elseif facing == 1 then currentX = currentX + 1
        elseif facing == 2 then currentZ = currentZ + 1
        elseif facing == 3 then currentX = currentX - 1
        end
        
        if turtle.down() then
          currentY = currentY - 1
          log("Successfully bypassed torch by going over")
          return true
        end
      end
      turtle.down()
      currentY = currentY - 1
    end
  end
  
  -- Method 2: Go down and around
  if not turtle.detectDown() then
    if turtle.down() then
      currentY = currentY - 1
      if turtle.forward() then
        if facing == 0 then currentZ = currentZ - 1
        elseif facing == 1 then currentX = currentX + 1
        elseif facing == 2 then currentZ = currentZ + 1
        elseif facing == 3 then currentX = currentX - 1
        end
        
        if turtle.up() then
          currentY = currentY + 1
          log("Successfully bypassed torch by going under")
          return true
        end
      end
      turtle.up()
      currentY = currentY + 1
    end
  end
  
  log("Cannot bypass torch - will need to dig")
  return false
end

-- Emergency bypass when completely stuck
function emergencyBypass()
  log("Executing emergency bypass procedure...")
  
  -- Try all possible escape routes
  local originalFacing = facing
  
  -- Try turning and going sideways
  for i = 1, 4 do
    turnRight()
    if turtle.forward() then
      log("Emergency bypass: moved sideways")
      -- Try to get back on track
      turnLeft()
      if turtle.forward() then
        log("Emergency bypass successful")
        return true
      end
      turnRight()
      turtle.back()
    end
  end
  
  -- Reset to original facing
  while facing ~= originalFacing do
    turnRight()
  end
  
  -- Try vertical escape
  if turtle.up() then
    currentY = currentY + 1
    if turtle.forward() then
      turtle.down()
      currentY = currentY - 1
      log("Emergency bypass: used vertical escape")
      return true
    end
    turtle.down()
    currentY = currentY - 1
  end
  
  -- Last resort: dig everything around
  log("Last resort: digging escape route")
  turtle.dig()
  turtle.digUp()
  turtle.digDown()
  turnLeft()
  turtle.dig()
  turnRight()
  turnRight()
  turtle.dig()
  turnLeft()
  
  if turtle.forward() then
    log("Emergency escape successful")
    return true
  end
  
  log("Emergency bypass failed - turtle is completely stuck")
  return false
end

-- Enhanced lava handling
function handleLava()
  log("Handling lava encounter...")
  
  turtle.select(cobbleSlot)
  if turtle.getItemCount(cobbleSlot) > 0 then
    if turtle.place() then
      log("Placed cobblestone against lava")
      turtle.select(fuelSlot)
      return true
    end
  end
  
  -- Try other non-valuable blocks
  for slot = 2, 14 do
    turtle.select(slot)
    if turtle.getItemCount(slot) > 0 then
      local item = turtle.getItemDetail()
      if item and not isValuableItem(item.name) then
        if turtle.place() then
          log("Placed " .. item.name .. " against lava")
          turtle.select(fuelSlot)
          return true
        end
      end
    end
  end
  
  log("No blocks available to handle lava")
  turtle.select(fuelSlot)
  return false
end

function isValuableItem(itemName)
  local valuableItems = {"diamond", "gold", "emerald", "iron", "coal", "redstone"}
  for _, valuable in ipairs(valuableItems) do
    if string.find(itemName:lower(), valuable) then
      return true
    end
  end
  return false
end

-- Smart backward movement
function smartBackward()
  updatePosition()
  
  local attempts = 0
  while not turtle.back() and attempts < 10 do
    turnAround()
    local blockType = identifyBlockType("forward")
    
    if blockType == "torch" then
      log("Torch behind - attempting to bypass")
      if not bypassTorch() then
        turtle.dig()
      end
    elseif blockType ~= "empty" then
      turtle.dig()
    end
    
    turnAround()
    attempts = attempts + 1
    os.sleep(0.1)
  end
  
  if attempts >= 10 then
    log("Cannot move backward - trying alternative")
    turnAround()
    if smartForward() then
      turnAround()
      return true
    end
    return false
  end
  
  -- Update position tracking (opposite direction)
  if facing == 0 then currentZ = currentZ + 1
  elseif facing == 1 then currentX = currentX - 1
  elseif facing == 2 then currentZ = currentZ - 1
  elseif facing == 3 then currentX = currentX + 1
  end
  
  return true
end

-- Inventory management
function isInventoryFull()
  for slot = 2, 14 do
    if turtle.getItemCount(slot) == 0 then
      return false
    end
  end
  return true
end

function countValuableItems()
  local diamonds = 0
  local gold = 0
  local iron = 0
  
  for slot = 2, 14 do
    turtle.select(slot)
    local item = turtle.getItemDetail()
    if item then
      if string.find(item.name, "diamond") then
        diamonds = diamonds + item.count
      elseif string.find(item.name, "gold") then
        gold = gold + item.count
      elseif string.find(item.name, "iron") then
        iron = iron + item.count
      end
    end
  end
  
  return diamonds, gold, iron
end

-- Enhanced item dropping with recovery
function dropItems()
  log("Returning to base to drop items...")
  
  turnAround()
  
  local success, data = turtle.inspect()
  local hasChest = success and data.name and string.find(data.name, "chest")
  
  if hasChest then
    log("Chest detected, dropping items...")
  else
    log("WARNING: No chest detected! Dropping on ground...")
  end
  
  local itemsDropped = 0
  local diamondsDropped = 0
  
  for slot = 2, 14 do
    turtle.select(slot)
    if turtle.getItemCount(slot) > 0 then
      local item = turtle.getItemDetail()
      if item then
        if string.find(item.name, "diamond") then
          diamondsDropped = diamondsDropped + item.count
        end
        log("Dropping: " .. item.name .. " x" .. item.count)
        
        -- Try multiple drop methods
        if not turtle.drop() then
          if not turtle.dropUp() then
            turtle.dropDown()
          end
        end
        itemsDropped = itemsDropped + 1
      end
    end
  end
  
  log("Dropped " .. itemsDropped .. " item stacks")
  if diamondsDropped > 0 then
    log("*** Dropped " .. diamondsDropped .. " diamonds! ***")
  end
  
  turtle.select(fuelSlot)
  turnAround()
end

-- Smart torch placement
function placeTorchSmart()
  log("Attempting smart torch placement...")
  
  -- Priority 1: Ceiling
  if turtle.detectUp() then
    if turtle.placeUp() then
      log("Torch placed on ceiling")
      return true
    end
  end
  
  -- Priority 2: Walls
  local directions = {"left", "right", "back"}
  for _, direction in ipairs(directions) do
    if direction == "left" then
      turnLeft()
    elseif direction == "right" then
      turnRight()
    elseif direction == "back" then
      turnAround()
    end
    
    if turtle.detect() then
      if turtle.place() then
        log("Torch placed on " .. direction .. " wall")
        -- Return to original facing
        if direction == "left" then
          turnRight()
        elseif direction == "right" then
          turnLeft()
        elseif direction == "back" then
          turnAround()
        end
        return true
      end
    end
    
    -- Return to original facing
    if direction == "left" then
      turnRight()
    elseif direction == "right" then
      turnLeft()
    elseif direction == "back" then
      turnAround()
    end
  end
  
  -- Priority 3: Floor
  if turtle.detectDown() then
    if turtle.placeDown() then
      log("Torch placed on floor")
      return true
    end
  end
  
  -- Priority 4: Create surface with cobblestone
  if turtle.getItemCount(cobbleSlot) > 0 then
    local originalSlot = turtle.getSelectedSlot()
    turtle.select(cobbleSlot)
    
    if turtle.placeUp() then
      turtle.select(torchSlot)
      if turtle.placeUp() then
        log("Placed cobblestone support and torch on ceiling")
        turtle.select(originalSlot)
        return true
      else
        turtle.digUp()  -- Remove cobblestone if torch failed
      end
    end
    
    turtle.select(originalSlot)
  end
  
  log("Could not place torch - no suitable surface")
  return false
end

-- Enhanced tunnel digging with recovery
function digTunnel(resumeFromStep)
  local startStep = resumeFromStep or 1
  local blocksMinedThisTunnel = 0
  currentStep = startStep
  
  log("Digging tunnel from step " .. startStep .. " to " .. tunnelLength)
  
  for step = startStep, tunnelLength do
    currentStep = step
    
    -- Fuel check
    if not checkFuel(tunnelLength - step + 30) then
      log("Insufficient fuel, stopping tunnel at step " .. step)
      return "fuel_low", step
    end
    
    -- Inventory check
    if isInventoryFull() then
      log("Inventory full at step " .. step)
      return "inventory_full", step
    end
    
    -- Mining sequence with error handling
    local miningSuccess = true
    
    -- Mine up
    if turtle.detectUp() then
      local blockType = identifyBlockType("up")
      if blockType ~= "bedrock" then
        if turtle.digUp() then
          blocksMinedThisTunnel = blocksMinedThisTunnel + 1
        end
      end
    end
    
    -- Mine down
    if turtle.detectDown() then
      local blockType = identifyBlockType("down")
      if blockType ~= "bedrock" then
        if turtle.digDown() then
          blocksMinedThisTunnel = blocksMinedThisTunnel + 1
        end
      end
    end
    
    -- Mine forward
    local forwardAttempts = 0
    while turtle.detect() and forwardAttempts < 10 do
      local blockType = identifyBlockType("forward")
      if blockType == "bedrock" then
        log("Bedrock ahead - cannot proceed")
        return "bedrock_blocked", step
      elseif blockType == "lava" then
        if not handleLava() then
          return "lava_danger", step
        end
      else
        if turtle.dig() then
          blocksMinedThisTunnel = blocksMinedThisTunnel + 1
        end
      end
      forwardAttempts = forwardAttempts + 1
      os.sleep(0.1)
    end
    
    -- Move forward with smart movement
    if not smartForward() then
      log("Cannot move forward at step " .. step)
      return "movement_blocked", step
    end
    
    -- Torch placement
    if step % torchInterval == 0 then
      turtle.select(torchSlot)
      if turtle.getItemCount(torchSlot) > 0 then
        placeTorchSmart()
      end
      turtle.select(fuelSlot)
    end
    
    -- Progress report every 10 steps
    if step % 10 == 0 then
      log("Progress: " .. step .. "/" .. tunnelLength .. " blocks")
    end
  end
  
  totalBlocksMined = totalBlocksMined + blocksMinedThisTunnel
  currentStep = 0
  log("Tunnel completed. Mined " .. blocksMinedThisTunnel .. " blocks")
  return "completed", tunnelLength
end

-- Enhanced return to tunnel start
function returnToTunnelStart()
  log("Returning to tunnel start...")
  turnAround()
  
  local stepsToReturn = currentStep > 0 and currentStep or tunnelLength
  local returnSuccess = true
  
  for step = 1, stepsToReturn do
    if not smartBackward() then
      log("Backward movement failed, trying forward approach")
      if not smartForward() then
        log("Warning: Could not return to exact start - step " .. step)
        returnSuccess = false
        break
      end
    end
    
    if step % 10 == 0 then
      log("Return progress: " .. step .. "/" .. stepsToReturn)
    end
  end
  
  turnAround()
  
  if returnSuccess then
    log("Successfully returned to tunnel start")
  else
    log("Return completed with issues")
  end
  
  return returnSuccess
end

-- Move to next tunnel
function moveToNextTunnel()
  log("Moving to next tunnel position...")
  
  if not checkFuel(spacing + 20) then
    return false
  end
  
  turnRight()
  for step = 1, spacing do
    if not smartForward() then
      log("ERROR: Cannot move to next tunnel position")
      turnLeft()
      return false
    end
  end
  turnLeft()
  
  log("Successfully moved to next tunnel")
  return true
end

-- Emergency return to base
function emergencyReturn()
  log("EMERGENCY: Attempting to return to base...")
  
  turnAround()
  local maxSteps = tunnelLength + (currentTunnel * spacing) + 50
  
  for i = 1, maxSteps do
    if not smartForward() then
      log("Emergency return blocked at step " .. i)
      break
    end
    
    if i % 20 == 0 then
      log("Emergency return progress: " .. i .. "/" .. maxSteps)
    end
  end
  
  log("Emergency return completed")
end

-- Main Program
function main()
  log("=== Advanced Diamond Mining Program - Complete Version ===")
  log("Configuration: " .. tunnelCount .. " tunnels, " .. tunnelLength .. " blocks each")
  log("Torch interval: " .. torchInterval .. " blocks")
  log("Features: Smart obstacle detection, torch bypass, stuck recovery")
  
  -- Initial checks
  local requiredFuel = calculateRequiredFuel()
  log("Estimated fuel requirement: " .. requiredFuel)
  
  if not checkFuel(requiredFuel) then
    log("CRITICAL: Insufficient fuel for operation!")
    return false
  end
  
  -- Supply check
  turtle.select(torchSlot)
  local torchCount = turtle.getItemCount(torchSlot)
  local requiredTorches = tunnelCount * math.ceil(tunnelLength / torchInterval)
  log("Torches: " .. torchCount .. "/" .. requiredTorches .. " (required)")
  
  turtle.select(cobbleSlot)
  log("Cobblestone for protection: " .. turtle.getItemCount(cobbleSlot))
  
  turtle.select(fuelSlot)
  
  -- Main mining loop
  for tunnelNum = 1, tunnelCount do
    currentTunnel = tunnelNum
    log("=== Starting Tunnel #" .. tunnelNum .. " ===")
    
    local result, lastStep = digTunnel()
    
    if result == "completed" then
      if returnToTunnelStart() then
        dropItems()
        local diamonds, gold, iron = countValuableItems()
        totalDiamonds = totalDiamonds + diamonds
        log("Tunnel #" .. tunnelNum .. " completed successfully")
        log("Session diamonds: " .. totalDiamonds)
      else
        log("Return failed, attempting emergency procedures")
        emergencyReturn()
        dropItems()
      end
      
    elseif result == "inventory_full" then
      log("Inventory full, managing and resuming...")
      returnToTunnelStart()
      dropItems()
      
      if lastStep < tunnelLength then
        log("Resuming tunnel from step " .. (lastStep + 1))
        local resumeResult = digTunnel(lastStep + 1)
        returnToTunnelStart()
        dropItems()
      end
      
    elseif result == "fuel_low" then
      log("Fuel critically low")
      returnToTunnelStart()
      dropItems()
      
      if not checkFuel(emergencyFuelReserve) then
        log("STOPPING: Insufficient fuel to continue safely")
        break
      end
      
    elseif result == "movement_blocked" or result == "bedrock_blocked" then
      log("Tunnel blocked, skipping to next")
      returnToTunnelStart()
      dropItems()
      
    elseif result == "lava_danger" then
      log("Lava danger, aborting tunnel for safety")
      returnToTunnelStart()
      dropItems()
      
    else
      log("Unknown result: " .. tostring(result))
      returnToTunnelStart()
      dropItems()
    end
    
    -- Move to next tunnel
    if tunnelNum < tunnelCount then
      if not moveToNextTunnel() then
        log("Cannot reach next tunnel position")
        log("Completed " .. tunnelNum .. " tunnels")
        break
      end
    end
    
    -- Progress report
    if tunnelNum % 5 == 0 then
      log("=== Progress Report ===")
      log("Completed: " .. tunnelNum .. "/" .. tunnelCount)
      log("Total blocks mined: " .. totalBlocksMined)
      log("Total diamonds: " .. totalDiamonds)
      log("Fuel remaining: " .. turtle.getFuelLevel())
    end
  end
  
  -- Final operations
  log("=== Mining Operation Complete ===")
  log("Tunnels completed: " .. currentTunnel)
  log("Total blocks mined: " .. totalBlocksMined)
  log("Total diamonds found: " .. totalDiamonds)
  log("Final fuel: " .. turtle.getFuelLevel())
  
  dropItems()
  log("Program finished successfully!")
  return true
end

-- Error handling wrapper
function safeMain()
  local success, error = pcall(main)
  if not success then
    log("CRITICAL ERROR: " .. tostring(error))
    log("Executing emergency procedures...")
    
    pcall(function()
      emergencyReturn()
      dropItems()
    end)
    
    log("Emergency procedures completed")
  end
end

-- Start program
log("Starting Advanced Diamond Mining Bot...")
log("Press Ctrl+T to emergency stop if needed")
os.sleep(3)
safeMain()
