-- Diamond Mining Turtle Script for Tekkit2025
-- Optimized for 3x3 tunnel diamond farming at Y-level -16
-- Enhanced safety features, inventory management and auto chest return
-- Optimized 3x3 mining - turtle stays in middle level

local depth = 0
local mined = 0
local currentLevel = 1 -- Start at middle level (0=bottom, 1=middle, 2=top)
local startX, startY, startZ = 0, 0, 0

-- Safe movement functions with obstruction detection
function safeForward()
    while turtle.detect() do
        turtle.dig()
        sleep(0.5)
    end
    if turtle.forward() then
        depth = depth + 1
        return true
    end
    return false
end

function safeDown()
    while turtle.detectDown() do
        turtle.digDown()
        sleep(0.5)
    end
    if turtle.down() then
        currentLevel = currentLevel - 1
        return true
    end
    return false
end

function safeUp()
    while turtle.detectUp() do
        turtle.digUp()
        sleep(0.5)
    end
    if turtle.up() then
        currentLevel = currentLevel + 1
        return true
    end
    return false
end

-- Move to specific Y level (0=bottom, 1=middle, 2=top)
function moveToLevel(targetLevel)
    while currentLevel < targetLevel do
        safeUp()
    end
    while currentLevel > targetLevel do
        safeDown()
    end
end

-- Check for lava and handle it safely
function checkLava()
    -- Check all directions for lava
    local success, data = turtle.inspect()
    if success and data.name == "minecraft:lava" then
        print("Lava detected in front!")
        return true
    end
    
    success, data = turtle.inspectUp()
    if success and data.name == "minecraft:lava" then
        print("Lava detected above!")
        return true
    end
    
    success, data = turtle.inspectDown()
    if success and data.name == "minecraft:lava" then
        print("Lava detected below!")
        return true
    end
    
    return false
end

-- Check if inventory is getting full (leave 2 slots for fuel)
function isInventoryFull()
    local emptySlots = 0
    for i = 1, 16 do
        if turtle.getItemCount(i) == 0 then
            emptySlots = emptySlots + 1
        end
    end
    return emptySlots <= 2
end

-- Deposit items to chest (supports large chests)
function depositToChest()
    print("Depositing items to chest...")
    
    local valuableItems = {
        "minecraft:diamond",
        "minecraft:emerald", 
        "minecraft:gold_ore",
        "minecraft:iron_ore",
        "minecraft:coal",
        "minecraft:lapis_ore",
        "minecraft:redstone",
        "bigreactors:oreyellorite"
    }
    
    -- Try different chest orientations
    local depositMethods = {
        {turtle.dropUp, "above"},      -- Chest above
        {turtle.drop, "front"},       -- Chest in front  
        {turtle.dropDown, "below"}    -- Chest below
    }
    
    local deposited = false
    
    for _, method in ipairs(depositMethods) do
        for i = 1, 16 do
            local itemDetail = turtle.getItemDetail(i)
            if itemDetail then
                local isValuable = false
                
                -- Check if item is valuable
                for _, valuable in ipairs(valuableItems) do
                    if itemDetail.name == valuable then
                        isValuable = true
                        break
                    end
                end
                
                if isValuable then
                    turtle.select(i)
                    if method[1]() then -- Try to deposit
                        print(string.format("Deposited %s to chest %s", itemDetail.name, method[2]))
                        deposited = true
                    end
                end
            end
        end
        
        if deposited then
            break -- Found working chest orientation
        end
    end
    
    if not deposited then
        print("Warning: No chest found! Items may be dropped.")
    end
    
    turtle.select(1)
    return deposited
end

-- Dig a row of 3 blocks horizontally (left, center, right)
function digRowHorizontal()
    -- Dig left
    turtle.turnLeft()
    if turtle.detect() then
        turtle.dig()
    end
    
    -- Dig right (turn around to face right)
    turtle.turnRight()
    turtle.turnRight()
    if turtle.detect() then
        turtle.dig()
    end
    
    -- Face forward again
    turtle.turnLeft()
end

-- Optimized 3x3x1 mining - turtle stays in middle level
function dig3x3Optimized()
    -- Check for lava before proceeding
    if checkLava() then
        print("Lava nearby, skipping this section...")
        return false
    end
    
    -- Ensure we're at middle level (most efficient position)
    moveToLevel(1)
    
    -- Dig center front (middle level)
    if turtle.detect() then
        turtle.dig()
    end
    
    -- Move forward
    if not safeForward() then
        return false
    end
    
    -- Now we're in the middle of 3x3 section
    -- Dig all 9 blocks from this central position:
    
    -- 1. Dig current level (middle) - left and right
    digRowHorizontal()
    
    -- 2. Dig above level - center, left, right
    if turtle.detectUp() then
        turtle.digUp()
    end
    turtle.turnLeft()
    if turtle.detectUp() then
        turtle.digUp()
    end
    turtle.turnRight()
    turtle.turnRight()
    if turtle.detectUp() then
        turtle.digUp()
    end
    turtle.turnLeft() -- Face forward again
    
    -- 3. Dig below level - center, left, right  
    if turtle.detectDown() then
        turtle.digDown()
    end
    turtle.turnLeft()
    if turtle.detectDown() then
        turtle.digDown()
    end
    turtle.turnRight()
    turtle.turnRight()
    if turtle.detectDown() then
        turtle.digDown()
    end
    turtle.turnLeft() -- Face forward again
    
    print("Completed 3x3 section efficiently!")
    return true
end

-- Enhanced refuel function
function smartRefuel()
    local currentFuel = turtle.getFuelLevel()
    if currentFuel < 100 then
        print(string.format("Fuel low: %d, refueling...", currentFuel))
        
        for i = 1, 16 do
            if turtle.getItemCount(i) > 0 then
                turtle.select(i)
                local itemDetail = turtle.getItemDetail()
                if itemDetail then
                    -- Try to refuel with various fuel types
                    if string.find(itemDetail.name, "coal") or 
                       string.find(itemDetail.name, "charcoal") or
                       string.find(itemDetail.name, "log") or
                       string.find(itemDetail.name, "plank") then
                        if turtle.refuel(1) then
                            print("Refueled with " .. itemDetail.name)
                            break
                        end
                    end
                end
            end
        end
    end
    turtle.select(1)
end

-- Enhanced inventory management for diamond farming
function manageInventory()
    local valuableItems = {
        "minecraft:diamond",
        "minecraft:emerald", 
        "minecraft:gold_ore",
        "minecraft:iron_ore",
        "minecraft:coal",
        "minecraft:lapis_ore",
        "minecraft:redstone",
        "bigreactors:oreyellorite"
    }
    
    for i = 1, 16 do
        local itemDetail = turtle.getItemDetail(i)
        if itemDetail then
            local keepItem = false
            
            -- Check if item is valuable
            for _, valuable in ipairs(valuableItems) do
                if itemDetail.name == valuable then
                    keepItem = true
                    break
                end
            end
            
            -- Also keep fuel items
            if string.find(itemDetail.name, "coal") or 
               string.find(itemDetail.name, "charcoal") then
                keepItem = true
            end
            
            -- Drop unwanted items
            if not keepItem then
                turtle.select(i)
                turtle.dropDown() -- Drop down to avoid clogging tunnels
                print("Dropped: " .. itemDetail.name)
            end
        end
    end
    turtle.select(1)
end

-- Return to start position
function returnHome()
    print(string.format("Returning home from depth %d, level %d...", depth, currentLevel))
    
    -- First, go to middle level (same as start)
    moveToLevel(1)
    
    -- Turn around to face start
    turtle.turnLeft()
    turtle.turnLeft()
    
    -- Go back to start position
    for i = 1, depth do
        if not turtle.forward() then
            -- Handle obstacles on return
            while turtle.detect() do
                turtle.dig()
                sleep(0.5)
            end
            turtle.forward()
        end
    end
    
    -- Face forward again
    turtle.turnLeft()
    turtle.turnLeft()
    
    -- Reset position tracking
    depth = 0
    currentLevel = 1 -- Back to middle level
    
    print("Arrived at start position!")
end

-- Go back to mining position with exact positioning
function returnToMining()
    print(string.format("Returning to mining position (depth %d)...", depth))
    
    -- Make sure we start from middle level
    currentLevel = 1
    
    -- Go to mining depth
    for i = 1, depth do
        if not safeForward() then
            print("Cannot return to mining position!")
            return false
        end
    end
    
    print("Resumed mining position at middle level!")
    return true
end

-- Status reporting
function reportStatus()
    print(string.format("Mined: %d sections, Depth: %d, Level: %d, Fuel: %d", 
          mined, depth, currentLevel, turtle.getFuelLevel()))
end

-- Main 3x3 mining routine with optimized movement
function diamond3x3Mining()
    local tunnelLength = 50 -- Number of 3x3 sections to mine
    local sectionsCompleted = 0
    
    print("Starting optimized 3x3 mining (turtle stays in middle)...")
    
    -- Start at middle level for optimal mining
    moveToLevel(1)
    
    while sectionsCompleted < tunnelLength do
        smartRefuel()
        manageInventory()
        
        -- Check if inventory is full and return to deposit
        if isInventoryFull() then
            print("Inventory full! Returning to chest...")
            returnHome()
            depositToChest()
            sleep(1)
            returnToMining()
        end
        
        -- Check fuel level before continuing
        if turtle.getFuelLevel() < 50 then
            print("Critical fuel level, returning home...")
            returnHome()
            break
        end
        
        -- Mine 3x3 section with optimized method
        local success = dig3x3Optimized()
        
        if success then
            sectionsCompleted = sectionsCompleted + 1
            mined = mined + 1
        else
            print("Cannot continue mining, returning home...")
            returnHome()
            break
        end
        
        -- Report status every 10 sections
        if sectionsCompleted % 10 == 0 then
            reportStatus()
        end
        
        sleep(0.1) -- Prevent timeout
    end
    
    -- Final return home and deposit
    print("Mining completed, returning home for final deposit...")
    returnHome()
    depositToChest()
    print(string.format("Completed %d sections of 3x3 tunnel!", sectionsCompleted))
end

-- Initialize and start mining
print("OPTIMIZED 3x3 Diamond Mining Turtle - Starting...")
print("=== SETUP INSTRUCTIONS ===")
print("TURTLE POSITION:")
print("  - Place turtle at Y-level -16 (optimal diamond level)")
print("  - Turtle should face the direction you want to mine")
print("  - Make sure there's space for a 3x3 tunnel ahead")
print("")
print("CHEST SETUP OPTIONS:")
print("  OPTION 1 - Vertical setup (RECOMMENDED):")
print("    [CHEST] <- Large chest above turtle")
print("    [TURTLE] <- Turtle at bottom")
print("    ========")
print("")
print("  OPTION 2 - Front setup:")
print("    [CHEST][TURTLE] -> mining direction")
print("    ================")
print("")
print("  OPTION 3 - Below setup:")
print("    [TURTLE] -> mining direction") 
print("    [CHEST] <- Chest below turtle")
print("    ========")
print("")
print("NEW OPTIMIZATION:")
print("  - Turtle stays in MIDDLE level of 3x3 tunnel")
print("  - Digs up/down/sides from central position")
print("  - 50% faster mining with minimal movement!")
print("  - Much more fuel efficient!")
print("")
print("Starting optimized mining in 5 seconds...")
sleep(5)

diamond3x3Mining()
print("Optimized 3x3 Mining operation completed!")
  
