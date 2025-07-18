-- Advanced Diamond Mining Program - Improved Version
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

-- Calculate required fuel for entire operation
function calculateRequiredFuel()
  local fuelPerTunnel = tunnelLength * 2 + spacing -- Forward + back + positioning
  local totalFuel = fuelPerTunnel * tunnelCount + 100 -- Extra safety margin
  return totalFuel
end

-- Safe movement with obstacle handling
function safeForward()
  local attempts = 0
  while not turtle.forward() and attempts < 10 do
    if turtle.detect() then
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
  
  -- Update position
  if facing == 0 then currentZ = currentZ - 1
  elseif facing == 1 then currentX = currentX + 1
  elseif facing == 2 then currentZ = currentZ + 1
  elseif facing == 3 then currentX = currentX - 1
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

-- Enhanced item dropping with chest detection
function dropItems()
  log("Returning to base to drop items...")
  
  turnAround()
  
  -- Check if chest is available
  turnAround()
  local success, data = turtle.inspect()
  if not success or not string.find(data.name or "", "chest") then
    log("WARNING: No chest detected behind turtle!")
    log("Dropping items on ground...")
  end
  
  local itemsDropped = 0
  for slot = 2, 14 do
    turtle.select(slot)
    if turtle.getItemCount(slot) > 0 then
      local item = turtle.getItemDetail()
      if item then
        log("Dropping: " .. item.name .. " x" .. item.count)
        turtle.drop()
        itemsDropped = itemsDropped + 1
      end
    end
  end
  
  log("Dropped " .. itemsDropped .. " item stacks")
  turtle.select(fuelSlot)
  turnAround()
end

-- Lava detection and protection
function checkForLava()
  local success, data = turtle.inspect()
  if success and data.name and string.find(data.name, "lava") then
    log("LAVA DETECTED! Attempting to place block...")
    
    -- First try cobblestone slot
    turtle.select(cobbleSlot)
    if turtle.getItemCount(cobbleSlot) > 0 then
      if turtle.place() then
        log("Placed cobblestone against lava")
        turtle.select(fuelSlot)
        return true
      end
    end
    
    -- If no cobblestone, try other slots
    for slot = 2, 14 do
      turtle.select(slot)
      if turtle.getItemCount(slot) > 0 then
        local item = turtle.getItemDetail()
        if item and not string.find(item.name, "ore") and not string.find(item.name, "gem") then
          if turtle.place() then
            log("Placed " .. item.name .. " against lava")
            turtle.select(fuelSlot)
            return true
          end
        end
      end
    end
    
    log("CRITICAL: No blocks available to place against lava!")
    turtle.select(fuelSlot)
    return false
  end
  return true
end

-- Enhanced mining with better block detection
function digTunnel()
  local startX, startY, startZ = currentX, currentY, currentZ
  local blocksMinedThisTunnel = 0
  
  for step = 1, tunnelLength do
    -- Check fuel before each step
    if not checkFuel(tunnelLength - step + 10) then
      log("Insufficient fuel, stopping tunnel at step " .. step)
      return "fuel_low"
    end
    
    -- Check inventory space
    if isInventoryFull() then
      log("Inventory full at step " .. step .. " of tunnel")
      return "inventory_full"
    end
    
    -- Check for lava before proceeding
    if not checkForLava() then
      log("Lava encountered, stopping tunnel for safety")
      return "lava_danger"
    end
    
    -- Mine blocks above and below too (3-high tunnel)
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
      return "movement_blocked"
    end
    
    -- Place torch every 8 blocks
    if step % 8 == 0 then
      turtle.select(torchSlot)
      if turtle.getItemCount(torchSlot) > 0 then
        turnAround()
        turtle.place()
        turnAround()
        log("Placed torch at step " .. step)
      end
      turtle.select(fuelSlot)
    end
  end
  
  totalBlocksMined = totalBlocksMined + blocksMinedThisTunnel
  log("Tunnel completed. Mined " .. blocksMinedThisTunnel .. " blocks")
  return "completed"
end

-- Return to starting position of current tunnel
function returnToTunnelStart()
  log("Returning to tunnel start...")
  turnAround()
  
  for step = 1, tunnelLength do
    if not safeForward() then
      log("Warning: Could not return to exact start position")
      break
    end
  end
  
  turnAround()
end

-- Move to next tunnel position
function moveToNextTunnel()
  log("Moving to next tunnel position...")
  
  if not checkFuel(spacing + 5) then
    return false
  end
  
  turnRight()
  for step = 1, spacing do
    if not safeForward() then
      log("ERROR: Cannot move to next tunnel position")
      return false
    end
  end
  turnLeft()
  
  return true
end

-- Main Program
function main()
  log("=== Advanced Diamond Mining Program Started ===")
  log("Configuration: " .. tunnelCount .. " tunnels, " .. tunnelLength .. " blocks each")
  
  -- Initial fuel check
  local requiredFuel = calculateRequiredFuel()
  log("Estimated fuel requirement: " .. requiredFuel)
  
  if not checkFuel(requiredFuel) then
    log("CRITICAL: Insufficient fuel for operation!")
    return false
  end
  
  -- Select fuel slot
  turtle.select(fuelSlot)
  
  -- Main mining loop
  for tunnelNum = 1, tunnelCount do
    currentTunnel = tunnelNum
    log("=== Starting Tunnel #" .. tunnelNum .. " ===")
    
    local result = digTunnel()
    
    -- Handle different tunnel results
    if result == "completed" then
      returnToTunnelStart()
      dropItems()
      
      -- Count valuable items
      local diamonds, gold, iron = countValuableItems()
      totalDiamonds = totalDiamonds + diamonds
      
      log("Tunnel #" .. tunnelNum .. " completed successfully")
      log("Total diamonds found: " .. totalDiamonds)
      
    elseif result == "inventory_full" then
      log("Inventory full, returning to base")
      returnToTunnelStart()
      dropItems()
      
      -- Resume tunnel from where we left off
      log("Resuming tunnel #" .. tunnelNum)
      digTunnel()
      returnToTunnelStart()
      dropItems()
      
    elseif result == "fuel_low" then
      log("Fuel low, attempting to return to base")
      returnToTunnelStart()
      dropItems()
      
      if not checkFuel(requiredFuel / 2) then
        log("CRITICAL: Cannot continue, insufficient fuel")
        break
      end
      
    elseif result == "lava_danger" then
      log("Lava encountered, skipping to next tunnel")
      returnToTunnelStart()
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
        break
      end
    end
  end
  
  -- Final statistics
  log("=== Mining Operation Complete ===")
  log("Tunnels completed: " .. currentTunnel)
  log("Total blocks mined: " .. totalBlocksMined)
  log("Total diamonds found: " .. totalDiamonds)
  log("Final position: X=" .. currentX .. ", Y=" .. currentY .. ", Z=" .. currentZ)
  
  return true
end

-- Start the program
main()
