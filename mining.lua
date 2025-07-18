-- Diamond Mining Turtle Script for Tekkit2025
-- Optimized for diamond farming at Y-level -16
-- Strip mining pattern with safety features

local depth = 0
local mined = 0
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
    return turtle.down()
end

function safeUp()
    while turtle.detectUp() do
        turtle.digUp()
        sleep(0.5)
    end
    return turtle.up()
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

-- Strip mining pattern (2x1 tunnel)
function stripMine()
    -- Dig current position
    if turtle.detect() then
        turtle.dig()
    end
    
    -- Check for lava before moving
    if checkLava() then
        print("Lava nearby, skipping this area...")
        return false
    end
    
    if not safeForward() then
        return false
    end
    
    -- Dig above
    if turtle.detectUp() then
        turtle.digUp()
    end
    
    -- Dig sides for more coverage
    turtle.turnLeft()
    if turtle.detect() then
        turtle.dig()
    end
    turtle.turnRight()
    turtle.turnRight()
    if turtle.detect() then
        turtle.dig()
    end
    turtle.turnLeft()
    
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

-- Return to start position (basic implementation)
function returnHome()
    print("Returning to start position...")
    turtle.turnLeft()
    turtle.turnLeft()
    
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
    
    turtle.turnLeft()
    turtle.turnLeft()
    depth = 0
end

-- Status reporting
function reportStatus()
    print(string.format("Mined: %d blocks, Depth: %d, Fuel: %d", 
          mined, depth, turtle.getFuelLevel()))
end

-- Main mining routine
function diamondMining()
    local tunnelLength = 64 -- Adjust based on your needs
    local tunnelsPerLevel = 4
    local currentTunnel = 0
    
    while true do
        smartRefuel()
        manageInventory()
        
        -- Check if we need to start a new tunnel
        if depth >= tunnelLength then
            returnHome()
            
            -- Move to next tunnel position (3 blocks apart for optimal coverage)
            currentTunnel = currentTunnel + 1
            if currentTunnel >= tunnelsPerLevel then
                print("Completed level, stopping...")
                break
            end
            
            turtle.turnRight()
            for i = 1, 3 do
                safeForward()
            end
            turtle.turnLeft()
        end
        
        -- Mine current strip
        if stripMine() then
            mined = mined + 1
        else
            print("Cannot continue mining, stopping...")
            break
        end
        
        -- Report status every 20 blocks
        if mined % 20 == 0 then
            reportStatus()
        end
        
        sleep(0.1) -- Prevent timeout
    end
end

-- Initialize and start mining
print("Diamond Mining Turtle - Starting...")
print("Make sure turtle is at Y-level -16 for optimal diamond mining!")
print("Press Ctrl+T to stop if needed")

diamondMining()
print("Mining operation completed!")
  
