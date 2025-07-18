-- Advanced Diamond Mining Program - Fixed Version
-- Settings
local tunnelLength = 50      -- Length of each tunnel
local tunnelCount = 20       -- Total number of tunnels
local spacing = 2            -- Spacing between tunnels (2 is ideal)
local fuelSlot = 1          -- Slot for fuel (coal/charcoal)
local torchSlot = 15        -- Slot for torches
local cobbleSlot = 16       -- Slot for cobblestone (lava protection)

-- Position tracking
local currentX = 0
local currentY = 0
local currentZ = 0
local facing = 0  -- 0=North, 1=East, 2=South, 3=West

-- Statistics
local totalBlocksMined = 0
local totalDiamonds = 0
local currentTunnel = 0
local currentStep = 0  -- For resume functionality

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
    
    -- Try to refuel multiple times if needed
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

-- Improved fuel calculation
function calculateRequiredFuel()
  local fuelPerTunnel = (tunnelLength * 2) + -- Forward + backward
                       (spacing * 2) +        -- Movement between tunnels
                       30                     -- Safety margin per tunnel
  local totalFuel = fuelPerTunnel * tunnelCount + 500 -- Large safety margin
  return totalFuel
end

-- Safe movement with better obstacle handling
function safeForward()
  local attempts = 0
  while not turtle.forward() and attempts < 10 do
    if turtle.detect() then
      local success, data = turtle.inspect()
      -- Check if it's a torch and skip it
      if success and data.name and string.find(data.name, "torch") then
        log("Torch detected ahead, cannot proceed")
        return false
      end
      turtle.dig()
      os.sleep(0.1)
    else
      -- Something is blocking but not a block (maybe a mob)
      log("Warning: Movement blocked by non-block entity")
      os.sleep(0.5)
    end
    attempts = attempts + 1
  end
  
  if attempts >= 10 then
    log("ERROR: Cannot move forward after 10 attempts!")
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

-- Safe backward movement
function safeBackward()
  local attempts = 0
  while not turtle.back() and attempts < 10 do
    turnAround()
    if turtle.detect() then
      local success, data = turtle.inspect()
      -- Don't dig torches when going backward
      if success and data.name and not string.find(data.name, "torch") then
        turtle.dig()
      end
    end
    turnAround()
    attempts = attempts + 1
    os.sleep(0.1)
  end
  
  if attempts >= 10 then
    log("ERROR: Cannot move backward after 10 attempts!")
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

-- Advanced inventory management
function isInventoryFull()
  for slot = 2, 14 do -- Leave slots 15,16 for torches and cobble
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

-- Fixed item dropping system
function dropItems()
  log("Returning to base to drop items...")
  
  -- Turn around to face the chest
  turnAround()
  
  -- Check if chest is available behind us
  local success, data = turtle.inspect()
  local hasChest = success and data.name and string.find(data.name, "chest")
  
  if hasChest then
    log("Chest detected, dropping items...")
  else
    log("WARNING: No chest detected behind turtle! Dropping on ground...")
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
        turtle.drop()
        itemsDropped = itemsDropped + 1
      end
    end
  end
  
  log("Dropped " .. itemsDropped .. " item stacks")
  if diamondsDropped > 0 then
    log("*** Dropped " .. diamondsDropped .. " diamonds! ***")
  end
  
  turtle.select(fuelSlot)
  
  -- Turn back to mining direction
  turnAround()
end

-- Lava detection and protection
function checkForLava()
  local success, data = turtle.inspect()
  if success and data.name and string.find(data.name, "lava") then
    log("LAVA DETECTED! Attempting to place protective block...")
    
    -- First try cobblestone slot
    turtle.select(cobbleSlot)
    if turtle.getItemCount(cobbleSlot) > 0 then
      if turtle.place() then
        log("Placed cobblestone against lava")
        turtle.select(fuelSlot)
        return true
      end
    end
    
    -- If no cobblestone, try other non-valuable slots
    for slot = 2, 14 do
      turtle.select(slot)
      if turtle.getItemCount(slot) > 0 then
        local item = turtle.getItemDetail()
        if item and not string.find(item.name, "ore") and 
           not string.find(item.name, "gem") and 
           not string.find(item.name, "diamond") and
           not string.find(item.name, "gold") and
           not string.find(item.name, "emerald") then
          if turtle.place() then
            log("Placed " .. item.name .. " against lava")
            turtle.select(fuelSlot)
            return true
          end
        end
      end
    end
    
    log("CRITICAL: No suitable blocks available to place against lava!")
    turtle.select(fuelSlot)
    return false
  end
  return true
end

-- Enhanced mining with torch placement on top
function digTunnel(resumeFromStep)
  local startStep = resumeFromStep or 1
  local blocksMinedThisTunnel = 0
  currentStep = startStep
  
  log("Digging tunnel from step " .. startStep .. " to " .. tunnelLength)
  
  for step = startStep, tunnelLength do
    currentStep = step
    
    -- Check fuel before each step
    if not checkFuel(tunnelLength - step + 20) then
      log("Insufficient fuel, stopping tunnel at step " .. step)
      return "fuel_low", step
    end
    
    -- Check inventory space
    if isInventoryFull() then
      log("Inventory full at step " .. step .. " of tunnel")
      return "inventory_full", step
    end
    
    -- Check for lava before proceeding
    if not checkForLava() then
      log("Lava encountered, stopping tunnel for safety")
      return "lava_danger", step
    end
    
    -- Mine blocks above and below (3-high tunnel)
    if turtle.detectUp() then
      turtle.digUp()
      blocksMinedThisTunnel = blocksMinedThisTunnel + 1
    end
    
    if turtle.detectDown() then
      turtle.digDown()
      blocksMinedThisTunnel = blocksMinedThisTunnel + 1
    end
    
    -- Mine forward
    while turtle.detect() do
      turtle.dig()
      blocksMinedThisTunnel = blocksMinedThisTunnel + 1
      os.sleep(0.1)
    end
    
    -- Move forward
    if not safeForward() then
      log("Cannot move forward, stopping tunnel")
      return "movement_blocked", step
    end
    
    -- Place torch every 8 blocks ON TOP (this prevents torch collision on return)
    if step % 10 == 0 then
      turtle.select(torchSlot)
      if turtle.getItemCount(torchSlot) > 0 then
        if turtle.placeUp() then
          log("Placed torch above at step " .. step)
        else
          log("Could not place torch above at step " .. step)
        end
      else
        log("No torches available for lighting")
      end
      turtle.select(fuelSlot)
    end
  end
  
  totalBlocksMined = totalBlocksMined + blocksMinedThisTunnel
  currentStep = 0  -- Reset step counter
  log("Tunnel completed. Mined " .. blocksMinedThisTunnel .. " blocks")
  return "completed", tunnelLength
end

-- Smart return to starting position
function returnToTunnelStart()
  log("Returning to tunnel start...")
  turnAround()
  
  local stepsToReturn = currentStep > 0 and currentStep or tunnelLength
  
  for step = 1, stepsToReturn do
    if not safeBackward() then
      log("Using forward movement for return...")
      if not safeForward() then
        log("Warning: Could not return to exact start position")
        break
      end
    end
  end
  
  turnAround()
  log("Returned to tunnel start")
end

-- Move to next tunnel position
function moveToNextTunnel()
  log("Moving to next tunnel position...")
  
  if not checkFuel(spacing + 10) then
    return false
  end
  
  turnRight()
  for step = 1, spacing do
    if not safeForward() then
      log("ERROR: Cannot move to next tunnel position")
      turnLeft()  -- Return to original facing
      return false
    end
  end
  turnLeft()
  
  log("Moved to next tunnel position")
  return true
end

-- Emergency return to base
function emergencyReturn()
  log("EMERGENCY: Attempting to return to base...")
  
  -- Simple approach: turn around and go back
  turnAround()
  local maxSteps = tunnelLength + (currentTunnel * spacing)
  
  for i = 1, maxSteps do
    if not turtle.forward() then
      if turtle.detect() then
        turtle.dig()
      end
      turtle.forward()
    end
  end
  
  log("Emergency return completed")
end

-- Main Program
function main()
  log("=== Advanced Diamond Mining Program - Fixed Version ===")
  log("Configuration: " .. tunnelCount .. " tunnels, " .. tunnelLength .. " blocks each")
  log("Torches will be placed ABOVE to prevent collision on return")
  
  -- Initial fuel check
  local requiredFuel = calculateRequiredFuel()
  log("Estimated fuel requirement: " .. requiredFuel)
  
  if not checkFuel(requiredFuel) then
    log("CRITICAL: Insufficient fuel for operation!")
    log("Current fuel: " .. turtle.getFuelLevel() .. ", Required: " .. requiredFuel)
    return false
  end
  
  -- Check initial supplies
  turtle.select(torchSlot)
  local torchCount = turtle.getItemCount(torchSlot)
  if torchCount < tunnelCount * (tunnelLength / 8) then
    log("WARNING: May not have enough torches! Current: " .. torchCount)
  end
  
  turtle.select(cobbleSlot)
  local cobbleCount = turtle.getItemCount(cobbleSlot)
  log("Cobblestone for lava protection: " .. cobbleCount)
  
  -- Select fuel slot
  turtle.select(fuelSlot)
  
  -- Main mining loop
  for tunnelNum = 1, tunnelCount do
    currentTunnel = tunnelNum
    log("=== Starting Tunnel #" .. tunnelNum .. " ===")
    
    local result, lastStep = digTunnel()
    
    -- Handle different tunnel results
    if result == "completed" then
      returnToTunnelStart()
      dropItems()
      
      -- Count valuable items after dropping
      local diamonds, gold, iron = countValuableItems()
      totalDiamonds = totalDiamonds + diamonds
      
      log("Tunnel #" .. tunnelNum .. " completed successfully")
      log("Session diamonds found: " .. totalDiamonds)
      
    elseif result == "inventory_full" then
      log("Inventory full, returning to base to drop items")
      returnToTunnelStart()
      dropItems()
      
      -- Resume tunnel from where we left off
      if lastStep < tunnelLength then
        log("Resuming tunnel #" .. tunnelNum .. " from step " .. (lastStep + 1))
        local resumeResult = digTunnel(lastStep + 1)
        if resumeResult == "completed" then
          returnToTunnelStart()
          dropItems()
        end
      end
      
    elseif result == "fuel_low" then
      log("Fuel low, attempting to return to base")
      returnToTunnelStart()
      dropItems()
      
      if not checkFuel(requiredFuel / 3) then
        log("CRITICAL: Cannot continue, insufficient fuel")
        log("Completed " .. (tunnelNum - 1) .. " full tunnels")
        break
      end
      
    elseif result == "lava_danger" then
      log("Lava encountered, skipping to next tunnel for safety")
      returnToTunnelStart()
      dropItems()
      
    elseif result == "movement_blocked" then
      log("Movement blocked, attempting emergency return")
      emergencyReturn()
      dropItems()
      
    else
      log("Unknown result: " .. tostring(result))
      returnToTunnelStart()
      dropItems()
    end
    
    -- Move to next tunnel position (except for last tunnel)
    if tunnelNum < tunnelCount then
      if not moveToNextTunnel() then
        log("Cannot move to next tunnel, stopping program")
        log("Completed " .. tunnelNum .. " tunnels")
        break
      end
    end
    
    -- Progress report every 5 tunnels
    if tunnelNum % 5 == 0 then
      log("=== Progress Report ===")
      log("Completed " .. tunnelNum .. "/" .. tunnelCount .. " tunnels")
      log("Total blocks mined: " .. totalBlocksMined)
      log("Total diamonds found: " .. totalDiamonds)
      log("Current fuel level: " .. turtle.getFuelLevel())
    end
  end
  
  -- Final statistics
  log("=== Mining Operation Complete ===")
  log("Tunnels completed: " .. currentTunnel)
  log("Total blocks mined: " .. totalBlocksMined)
  log("Total diamonds found: " .. totalDiamonds)
  log("Final fuel level: " .. turtle.getFuelLevel())
  log("Final position: X=" .. currentX .. ", Y=" .. currentY .. ", Z=" .. currentZ)
  
  -- Final return to base and drop remaining items
  dropItems()
  
  log("Mining program finished successfully!")
  return true
end

-- Error handling wrapper
function safeMain()
  local success, error = pcall(main)
  if not success then
    log("ERROR: " .. tostring(error))
    log("Attempting emergency return to base...")
    emergencyReturn()
    dropItems()
  end
end

-- Start the program with error handling
safeMain()
