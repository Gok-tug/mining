-- Advanced Diamond Mining Bot - CraftOS 1.8 Compatible
-- ======================================================

-- Configuration
local tunnelLength = 50
local tunnelCount = 20
local spacing = 2
local fuelSlot = 1
local torchSlot = 15
local cobbleSlot = 16
local torchInterval = 10

-- Position & State
local currentX, currentY, currentZ = 0, 0, 0
local facing = 0
local totalBlocksMined, totalDiamonds = 0, 0
local currentTunnel, currentStep, stuckCounter = 0, 0, 0
local lastPosition = { x = 0, y = 0, z = 0 }
local maxStuckAttempts, emergencyFuelReserve = 15, 200

-- ================================
-- CORE UTILITIES - CraftOS 1.8
-- ================================

function log(msg)
  print("[" .. textutils.formatTime(os.time(), true) .. "] " .. msg)
end

function safeSelect(slot)
  if slot >= 1 and slot <= 16 then
    turtle.select(slot)
    return true
  end
  return false
end

-- Movement direction management
function turnLeft()
  facing = (facing - 1) % 4
  turtle.turnLeft()
end

function turnRight()
  facing = (facing + 1) % 4
  turtle.turnRight()
end

function turnAround()
  facing = (facing + 2) % 4
  turtle.turnLeft()
  turtle.turnLeft()
end

-- Position tracking
function updatePosition()
  lastPosition.x, lastPosition.y, lastPosition.z = currentX, currentY, currentZ
end

function advancePosition()
  if facing == 0 then currentZ = currentZ - 1
  elseif facing == 1 then currentX = currentX + 1
  elseif facing == 2 then currentZ = currentZ + 1
  elseif facing == 3 then currentX = currentX - 1 end
end

function retreatPosition()
  if facing == 0 then currentZ = currentZ + 1
  elseif facing == 1 then currentX = currentX - 1
  elseif facing == 2 then currentZ = currentZ - 1
  elseif facing == 3 then currentX = currentX + 1 end
end

function checkIfStuck()
  if currentX == lastPosition.x and currentY == lastPosition.y and currentZ == lastPosition.z then
    stuckCounter = stuckCounter + 1
    return stuckCounter >= 3
  else
    stuckCounter = 0
    return false
  end
end

-- ================================
-- FUEL MANAGEMENT - CraftOS 1.8
-- ================================

function isFuelItem(slot)
  if not safeSelect(slot) then return false end
  if turtle.getItemCount(slot) == 0 then return false end
  return turtle.refuel(0)  -- Test without consuming
end

function findFuelSlot()
  -- Primary: designated fuel slot
  if isFuelItem(fuelSlot) then return fuelSlot end
  
  -- Secondary: search inventory slots only
  for slot = 2, 14 do
    if isFuelItem(slot) then return slot end
  end
  return nil
end

function checkFuel(required)
  local fuel = turtle.getFuelLevel()
  if fuel == "unlimited" then return true end
  
  if fuel < required then
    log("Fuel low: " .. fuel .. "/" .. required)
    local fSlot = findFuelSlot()
    if not fSlot then
      log("ERROR: No fuel found!")
      return false
    end
    
    safeSelect(fSlot)
    local attempts = 0
    while turtle.getFuelLevel() < required and turtle.getItemCount() > 0 and attempts < 20 do
      if turtle.refuel(1) then
        attempts = attempts + 1
      else
        break
      end
    end
    
    safeSelect(fuelSlot)  -- Always return to fuel slot
    
    if turtle.getFuelLevel() < required then
      log("ERROR: Still insufficient fuel!")
      return false
    end
    log("Refuel success: " .. turtle.getFuelLevel())
  end
  return true
end

function calculateRequiredFuel()
  return ((tunnelLength * 2 + spacing * 2 + 50) * tunnelCount) + emergencyFuelReserve
end

-- ================================
-- INVENTORY MANAGEMENT
-- ================================

function isInventoryFull()
  for slot = 2, 14 do
    if turtle.getItemCount(slot) == 0 then return false end
  end
  return true
end

function dropItems()
  log("Returning to base...")
  turnAround()
  
  -- Check for chest
  local hasChest = turtle.detect()
  if hasChest then
    log("Chest detected")
  else
    log("No chest - dropping on ground")
  end
  
  local itemsDropped = 0
  for slot = 2, 14 do
    safeSelect(slot)
    if turtle.getItemCount() > 0 then
      turtle.drop()
      itemsDropped = itemsDropped + 1
    end
  end
  
  log("Dropped " .. itemsDropped .. " stacks")
  safeSelect(fuelSlot)
  turnAround()
end

function validateSetup()
  local issues = {}
  
  -- Fuel check
  if turtle.getItemCount(fuelSlot) == 0 then
    table.insert(issues, "ERROR: No fuel in slot " .. fuelSlot)
  elseif not isFuelItem(fuelSlot) then
    table.insert(issues, "ERROR: Slot " .. fuelSlot .. " is not fuel")
  end
  
  -- Torch check
  if turtle.getItemCount(torchSlot) == 0 then
    table.insert(issues, "ERROR: No torches in slot " .. torchSlot)
  end
  
  -- Cobblestone check
  if turtle.getItemCount(cobbleSlot) == 0 then
    table.insert(issues, "WARNING: No cobblestone in slot " .. cobbleSlot)
  end
  
  safeSelect(fuelSlot)
  return issues
end

-- ================================
-- MOVEMENT - CraftOS 1.8 Compatible
-- ================================

function smartDig(direction)
  direction = direction or "forward"
  local success = false
  
  if direction == "forward" then
    if turtle.detect() then
      success = turtle.dig()
    end
  elseif direction == "up" then
    if turtle.detectUp() then
      success = turtle.digUp()
    end
  elseif direction == "down" then
    if turtle.detectDown() then
      success = turtle.digDown()
    end
  end
  
  if success then
    totalBlocksMined = totalBlocksMined + 1
  end
  return success
end

function smartForward()
  updatePosition()
  local attempts = 0
  
  while not turtle.forward() and attempts < maxStuckAttempts do
    if turtle.detect() then
      smartDig("forward")
      sleep(0.1)
    else
      -- Unknown obstacle - wait and retry
      log("Unknown obstacle, waiting...")
      sleep(0.5)
    end
    
    attempts = attempts + 1
    
    if attempts > 5 and checkIfStuck() then
      log("STUCK! Attempting bypass...")
      if not emergencyBypass() then
        log("Bypass failed!")
        return false
      end
    end
  end
  
  if attempts >= maxStuckAttempts then
    log("Movement failed after " .. maxStuckAttempts .. " attempts")
    return false
  end
  
  advancePosition()
  return true
end

function smartBackward()
  updatePosition()
  local attempts = 0
  
  while not turtle.back() and attempts < 10 do
    turnAround()
    if turtle.detect() then
      smartDig("forward")
    end
    turnAround()
    attempts = attempts + 1
    sleep(0.1)
  end
  
  if attempts >= 10 then
    -- Try forward movement as alternative
    turnAround()
    if smartForward() then
      turnAround()
      return true
    end
    return false
  end
  
  retreatPosition()
  return true
end

-- ================================
-- OBSTACLE HANDLING
-- ================================

function handleLava()
  log("Lava detected! Placing protection...")
  safeSelect(cobbleSlot)
  
  if turtle.getItemCount() > 0 then
    if turtle.place() then
      log("Placed cobblestone protection")
      safeSelect(fuelSlot)
      return true
    end
  end
  
  -- Try using mined blocks
  for slot = 2, 14 do
    safeSelect(slot)
    if turtle.getItemCount() > 0 then
      if turtle.place() then
        log("Used mined block for protection")
        safeSelect(fuelSlot)
        return true
      end
    end
  end
  
  log("No blocks available for lava protection")
  safeSelect(fuelSlot)
  return false
end

function emergencyBypass()
  log("Emergency bypass procedure...")
  local originalFacing = facing
  
  -- Try sideways movement
  for i = 1, 4 do
    turnRight()
    if turtle.forward() then
      log("Emergency sideways escape successful")
      -- Try to get back on track
      turnLeft()
      if turtle.forward() then
        log("Back on track")
        return true
      end
      turnRight()
      turtle.back()  -- Return to escape position
    end
  end
  
  -- Reset facing
  while facing ~= originalFacing do
    turnRight()
  end
  
  -- Try vertical escape
  if turtle.up() then
    currentY = currentY + 1
    if turtle.forward() then
      turtle.down()
      currentY = currentY - 1
      log("Vertical escape successful")
      return true
    end
    turtle.down()
    currentY = currentY - 1
  end
  
  -- Force dig everything
  log("Force digging escape route...")
  smartDig("forward")
  smartDig("up")
  smartDig("down")
  
  turnLeft()
  smartDig("forward")
  turnRight()
  turnRight()
  smartDig("forward")
  turnLeft()
  
  return turtle.forward()
end

-- ================================
-- TORCH PLACEMENT
-- ================================

function placeTorchSmart()
  safeSelect(torchSlot)
  if turtle.getItemCount() == 0 then
    log("No torches available")
    safeSelect(fuelSlot)
    return false
  end
  
  -- Try ceiling first
  if turtle.detectUp() and turtle.placeUp() then
    log("Torch placed on ceiling")
    safeSelect(fuelSlot)
    return true
  end
  
  -- Try walls
  local directions = {"left", "right", "back"}
  for _, dir in ipairs(directions) do
    if dir == "left" then turnLeft()
    elseif dir == "right" then turnRight()
    elseif dir == "back" then turnAround() end
    
    if turtle.detect() and turtle.place() then
      log("Torch placed on " .. dir .. " wall")
      if dir == "left" then turnRight()
      elseif dir == "right" then turnLeft()
      elseif dir == "back" then turnAround() end
      safeSelect(fuelSlot)
      return true
    end
    
    if dir == "left" then turnRight()
    elseif dir == "right" then turnLeft()
    elseif dir == "back" then turnAround() end
  end
  
  -- Try floor
  if turtle.detectDown() and turtle.placeDown() then
    log("Torch placed on floor")
    safeSelect(fuelSlot)
    return true
  end
  
  -- Create surface with cobblestone
  safeSelect(cobbleSlot)
  if turtle.getItemCount() > 0 and turtle.placeUp() then
    safeSelect(torchSlot)
    if turtle.placeUp() then
      log("Created cobblestone support + torch")
      safeSelect(fuelSlot)
      return true
    else
      turtle.digUp()  -- Remove cobblestone if torch failed
    end
  end
  
  log("Torch placement failed")
  safeSelect(fuelSlot)
  return false
end

-- ================================
-- TUNNEL DIGGING
-- ================================

function digTunnel(resumeFrom)
  local startStep = resumeFrom or 1
  local blocksThisTunnel = 0
  currentStep = startStep
  
  log("Digging tunnel: step " .. startStep .. " to " .. tunnelLength)
  
  for step = startStep, tunnelLength do
    currentStep = step
    
    -- Fuel check
    if not checkFuel(tunnelLength - step + 30) then
      log("Low fuel, stopping at step " .. step)
      return "fuel_low", step
    end
    
    -- Inventory check
    if isInventoryFull() then
      log("Inventory full at step " .. step)
      return "inventory_full", step
    end
    
    -- Mine 3x1 tunnel
    smartDig("up")
    smartDig("down")
    smartDig("forward")
    
    -- Move forward
    if not smartForward() then
      log("Cannot move forward at step " .. step)
      return "blocked", step
    end
    
    -- Place torch
    if step % torchInterval == 0 then
      placeTorchSmart()
    end
    
    -- Progress update
    if step % 10 == 0 then
      log("Progress: " .. step .. "/" .. tunnelLength)
    end
  end
  
  currentStep = 0
  log("Tunnel completed successfully")
  return "completed", tunnelLength
end

function returnToStart()
  log("Returning to tunnel start...")
  turnAround()
  
  local stepsBack = currentStep > 0 and currentStep or tunnelLength
  
  for step = 1, stepsBack do
    if not smartBackward() then
      log("Return issue at step " .. step)
      if not smartForward() then
        log("Return failed completely")
        break
      end
    end
    
    if step % 10 == 0 then
      log("Return progress: " .. step .. "/" .. stepsBack)
    end
  end
  
  turnAround()
  log("Returned to start")
end

function moveToNextTunnel()
  log("Moving to next tunnel...")
  
  if not checkFuel(spacing + 10) then
    return false
  end
  
  turnRight()
  for step = 1, spacing do
    if not smartForward() then
      log("Cannot reach next tunnel")
      turnLeft()
      return false
    end
  end
  turnLeft()
  
  log("Moved to next tunnel position")
  return true
end

-- ================================
-- EMERGENCY PROCEDURES
-- ================================

function emergencyReturn()
  log("EMERGENCY RETURN TO BASE")
  turnAround()
  
  local maxSteps = tunnelLength + (currentTunnel * spacing) + 50
  
  for i = 1, maxSteps do
    if not smartForward() then
      if turtle.detect() then
        smartDig("forward")
      end
      if not turtle.forward() then
        log("Emergency return stuck at step " .. i)
        break
      end
      advancePosition()
    end
    
    if i % 20 == 0 then
      log("Emergency progress: " .. i .. "/" .. maxSteps)
    end
  end
  
  log("Emergency return completed")
end

-- ================================
-- MAIN PROGRAM
-- ================================

function main()
  log("===== ADVANCED TURTLE MINING BOT =====")
  log("CraftOS 1.8 Compatible Version")
  log("Config: " .. tunnelCount .. " tunnels x " .. tunnelLength .. " blocks")
  log("Torch interval: " .. torchInterval .. " blocks")
  
  -- Validate setup
  local issues = validateSetup()
  if #issues > 0 then
    log("Setup issues found:")
    for _, issue in ipairs(issues) do
      log("  " .. issue)
    end
    if string.find(issues[1] or "", "ERROR") then
      log("ABORTING: Critical setup errors")
      return false
    end
  end
  
  -- Fuel check
  local requiredFuel = calculateRequiredFuel()
  log("Fuel requirement: " .. requiredFuel)
  
  if not checkFuel(requiredFuel) then
    log("ABORTING: Insufficient fuel")
    return false
  end
  
  log("Starting mining operation in 3 seconds...")
  sleep(3)
  
  -- Main mining loop
  for tunnelNum = 1, tunnelCount do
    currentTunnel = tunnelNum
    log("=== TUNNEL #" .. tunnelNum .. " ===")
    
    local result, lastStep = digTunnel()
    
    if result == "completed" then
      returnToStart()
      dropItems()
      log("Tunnel " .. tunnelNum .. " completed successfully")
      
    elseif result == "inventory_full" then
      log("Inventory management...")
      returnToStart()
      dropItems()
      
      if lastStep < tunnelLength then
        log("Resuming from step " .. (lastStep + 1))
        local resumeResult = digTunnel(lastStep + 1)
        returnToStart()
        dropItems()
      end
      
    elseif result == "fuel_low" then
      log("Fuel critically low")
      returnToStart()
      dropItems()
      
      if not checkFuel(emergencyFuelReserve) then
        log("STOPPING: Cannot continue safely")
        break
      end
      
    else
      log("Tunnel issue: " .. result .. ", skipping")
      returnToStart()
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
      log("=== PROGRESS REPORT ===")
      log("Completed: " .. tunnelNum .. "/" .. tunnelCount)
      log("Blocks mined: " .. totalBlocksMined)
      log("Fuel remaining: " .. turtle.getFuelLevel())
    end
  end
  
  -- Final report
  log("===== MINING OPERATION COMPLETE =====")
  log("Tunnels completed: " .. currentTunnel)
  log("Total blocks mined: " .. totalBlocksMined)
  log("Final fuel level: " .. turtle.getFuelLevel())
  
  dropItems()
  log("Program finished successfully!")
  return true
end

-- ================================
-- ERROR HANDLING & STARTUP
-- ================================

function safeMain()
  local success, err = pcall(main)
  if not success then
    log("CRITICAL ERROR: " .. tostring(err))
    log("Executing emergency procedures...")
    
    pcall(function()
      emergencyReturn()
      dropItems()
    end)
    
    log("Emergency procedures completed")
  end
end

-- Program startup
log("Turtle Mining Bot - CraftOS 1.8")
log("Press Ctrl+T to emergency stop")
log("Starting in 3 seconds...")
sleep(3)
safeMain()
