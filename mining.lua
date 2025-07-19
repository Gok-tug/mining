-- ========================================
-- DIAMOND MINING TURTLE v2.0 - OPTIMIZED
-- Efficient Diamond Strip Mining
-- ========================================
--
-- SETUP:
-- 1. Place turtle at Y=12 (safe level above diamonds)
-- 2. Place chest BELOW turtle for item storage
-- 3. Inventory:
--    Slot 1: Torches (64 recommended)
--    Slot 15: Fuel (coal/wood)
--    Slot 16: Spare chest
-- 4. Run: lua mining.lua
--
-- FEATURES:
-- ✅ Y=12 Safe Mining (digs Y=11 diamond level)
-- ✅ 3x1 Tunnels (Y=11,12,13) for Maximum Coverage
-- ✅ Smart Torch Placement (avoids lava at Y=10)
-- ✅ Smart Inventory Management
-- ✅ Fuel Safety & Auto-refuel
-- ========================================

local CONFIG = {
    TORCH_INTERVAL = 12,       -- Torch every 12 blocks (saves torches)
    TUNNEL_LENGTH = 64,        -- Main tunnel length
    BRANCH_LENGTH = 32,        -- Branch tunnel length
    BRANCH_SPACING = 3,        -- 3-block spacing (optimal for diamonds)
    FUEL_MIN = 500,           -- Minimum fuel check
    TORCH_SLOT = 1,
    CHEST_SLOT = 16,
    FUEL_SLOT = 15
}

-- GLOBALS
local NORTH, EAST, SOUTH, WEST = 0, 1, 2, 3
local direction = NORTH
local pos = {x = 0, y = 0, z = 0}
local home_pos = {x = 0, y = 0, z = 0}
local diamonds_found = 0

-- UTILITY FUNCTIONS
function log(msg)
    print("[" .. os.date("%H:%M:%S") .. "] " .. msg)
end

function checkFuel()
    local fuel = turtle.getFuelLevel()
    if fuel < CONFIG.FUEL_MIN then
        log("⛽ Low fuel: " .. fuel .. ", refueling...")
        return autoRefuel()
    end
    return true
end

function autoRefuel()
    if turtle.getItemCount(CONFIG.FUEL_SLOT) > 0 then
        turtle.select(CONFIG.FUEL_SLOT)
        turtle.refuel()
        return true
    end
    
    -- Use found coal
    for slot = 2, 14 do
        turtle.select(slot)
        local success, data = turtle.getItemDetail()
        if success and data.name and string.find(data.name, "coal") then
            turtle.refuel(math.min(data.count, 5))
            return true
        end
    end
    return false
end

function selectItem(slot)
    return turtle.getItemCount(slot) > 0 and turtle.select(slot)
end

-- MOVEMENT FUNCTIONS
function updatePos(dx, dy, dz)
    pos.x, pos.y, pos.z = pos.x + dx, pos.y + dy, pos.z + dz
end

function setHome()
    home_pos = {x = pos.x, y = pos.y, z = pos.z}
    log("🏠 Home set at: " .. pos.x .. "," .. pos.y .. "," .. pos.z)
end

function digAndMove()
    -- Dig 3x1 tunnel: forward (Y=12), up (Y=13), down (Y=11 - diamond level)
    while turtle.detect() do turtle.dig() end
    while turtle.detectUp() do turtle.digUp() end
    
    -- Safely dig down (Y=11 - diamond level) with lava check
    if turtle.detectDown() then
        local success, data = turtle.inspectDown()
        if success and data.name then
            if string.find(data.name, "lava") then
                log("🚨 LAVA detected at Y=11! Skipping down dig.")
            else
                -- Check for diamonds before digging
                if string.find(data.name, "diamond") then
                    diamonds_found = diamonds_found + 1
                    log("💎 DIAMOND FOUND at Y=11! Total: " .. diamonds_found)
                end
                turtle.digDown()
            end
        else
            turtle.digDown()
        end
    end
    
    -- Check forward blocks for diamonds too
    local success, data = turtle.inspect()
    if success and data.name and string.find(data.name, "diamond") then
        diamonds_found = diamonds_found + 1
        log("💎 DIAMOND FOUND at Y=12! Total: " .. diamonds_found)
    end
    
    -- Move forward
    while not turtle.forward() do
        turtle.dig()
        turtle.attack()
    end
    
    -- Update position
    if direction == NORTH then updatePos(0, 0, -1)
    elseif direction == EAST then updatePos(1, 0, 0)
    elseif direction == SOUTH then updatePos(0, 0, 1)
    elseif direction == WEST then updatePos(-1, 0, 0) end
end

function turnLeft()
    turtle.turnLeft()
    direction = (direction - 1) % 4
    if direction < 0 then direction = direction + 4 end
end

function turnRight()
    turtle.turnRight()
    direction = (direction + 1) % 4
end

function turnAround()
    turnRight()
    turnRight()
end

-- TORCH SYSTEM
function placeTorch(step)
    if step % CONFIG.TORCH_INTERVAL == 0 and selectItem(CONFIG.TORCH_SLOT) then
        -- Önce aşağıdaki bloğu kaz, sonra torch koy
        if turtle.detectDown() then
            turtle.digDown()
        end
        if turtle.placeDown() then
            log("🔥 Torch placed at step " .. step)
        else
            log("⚠️ Failed to place torch at step " .. step)
        end
    end
end

-- INVENTORY MANAGEMENT
function isInventoryFull()
    for slot = 2, 14 do
        if turtle.getItemCount(slot) == 0 then return false end
    end
    return true
end

-- Güvenli hareket fonksiyonu (torch kırmaz)
function safeMove()
    while not turtle.forward() do
        if turtle.detect() then
            local success, data = turtle.inspect()
            -- Torch ise kırma, sadece geç
            if success and data.name and string.find(data.name, "torch") then
                log("🔥 Torch detected, trying to move around...")
                turtle.up()
                turtle.forward()
                turtle.down()
                break
            else
                turtle.dig()
            end
        end
        turtle.attack() -- Mob varsa saldır
    end
    
    -- Pozisyon güncelle
    if direction == NORTH then updatePos(0, 0, -1)
    elseif direction == EAST then updatePos(1, 0, 0)
    elseif direction == SOUTH then updatePos(0, 0, 1)
    elseif direction == WEST then updatePos(-1, 0, 0) end
end

function returnHome()
    log("🏠 Returning home...")
    
    -- X ekseni
    while pos.x ~= home_pos.x do
        if pos.x < home_pos.x then
            faceDirection(EAST)
        else
            faceDirection(WEST)
        end
        safeMove() -- digAndMove yerine safeMove kullan
    end
    
    -- Z ekseni
    while pos.z ~= home_pos.z do
        if pos.z < home_pos.z then
            faceDirection(SOUTH)
        else
            faceDirection(NORTH)
        end
        safeMove() -- digAndMove yerine safeMove kullan
    end
    
    -- Y ekseni
    while pos.y ~= home_pos.y do
        if pos.y < home_pos.y then
            while not turtle.up() do 
                if turtle.detectUp() then
                    local success, data = turtle.inspectUp()
                    if not (success and data.name and string.find(data.name, "chest")) then
                        turtle.digUp()
                    end
                end
            end
            updatePos(0, 1, 0)
        else
            while not turtle.down() do 
                if turtle.detectDown() then
                    local success, data = turtle.inspectDown()
                    if not (success and data.name and string.find(data.name, "chest")) then
                        turtle.digDown()
                    end
                end
            end
            updatePos(0, -1, 0)
        end
    end
end

function faceDirection(target)
    local tries = 0
    while direction ~= target and tries < 4 do
        turnLeft()
        tries = tries + 1
    end
end

function depositItems()
    log("📦 Depositing items...")
    
    -- Sandık kontrolü
    if not turtle.detectDown() then
        log("⚠️ No chest detected below! Placing spare chest...")
        if selectItem(CONFIG.CHEST_SLOT) then
            turtle.placeDown()
        else
            log("❌ No spare chest available!")
            return false
        end
    end
    
    -- Eşyaları bırak
    for slot = 2, 14 do
        if turtle.getItemCount(slot) > 0 then
            turtle.select(slot)
            if not turtle.dropDown() then
                log("⚠️ Failed to drop items from slot " .. slot)
            end
        end
    end
    return true
end

-- MINING FUNCTIONS
function mineStrip(length)
    for step = 1, length do
        if not checkFuel() then return false end
        
        if isInventoryFull() then
            local saved = {x = pos.x, y = pos.y, z = pos.z, dir = direction}
            log("📦 Inventory full, returning to base...")
            returnHome()
            if depositItems() then
                log("🔄 Returning to mining position...")
                -- Pozisyonu sıfırla
                pos = {x = home_pos.x, y = home_pos.y, z = home_pos.z}
                direction = NORTH
                
                -- Kaydedilen pozisyona geri git
                while pos.x ~= saved.x or pos.z ~= saved.z or pos.y ~= saved.y do
                    if pos.x ~= saved.x then
                        if pos.x < saved.x then faceDirection(EAST) else faceDirection(WEST) end
                        safeMove()
                    elseif pos.z ~= saved.z then
                        if pos.z < saved.z then faceDirection(SOUTH) else faceDirection(NORTH) end
                        safeMove()
                    elseif pos.y ~= saved.y then
                        if pos.y < saved.y then
                            turtle.up()
                            updatePos(0, 1, 0)
                        else
                            turtle.down()
                            updatePos(0, -1, 0)
                        end
                    end
                end
                
                -- Yönü düzelt
                faceDirection(saved.dir)
                log("✅ Resumed mining at position")
            end
        end
        
        digAndMove()
        placeTorch(step)
        
        if step % 16 == 0 then
            log("⛏️ Mined " .. step .. "/" .. length .. " blocks")
        end
    end
    return true
end

function stripMining()
    log("🚀 Starting Diamond Strip Mining at Y=11")
    
    -- Main tunnel
    log("🛤️ Mining main tunnel...")
    mineStrip(CONFIG.TUNNEL_LENGTH)
    
    -- Return to start
    turnAround()
    for i = 1, CONFIG.TUNNEL_LENGTH do
        digAndMove()
    end
    turnAround()
    
    -- Branch mining
    local branches = 0
    local numBranches = math.floor(CONFIG.TUNNEL_LENGTH / CONFIG.BRANCH_SPACING)
    for b = 1, numBranches do
        -- Move to next branch point
        for j = 1, CONFIG.BRANCH_SPACING do
            digAndMove()
        end

        -- LEFT branch
        turnLeft()
        log("🌿 Mining left branch #" .. (branches + 1))
        mineStrip(CONFIG.BRANCH_LENGTH)
        turnAround()
        for j = 1, CONFIG.BRANCH_LENGTH do
            digAndMove()
        end
        turnRight()

        -- RIGHT branch
        turnRight()
        log("🌿 Mining right branch #" .. (branches + 2))
        mineStrip(CONFIG.BRANCH_LENGTH)
        turnAround()
        for j = 1, CONFIG.BRANCH_LENGTH do
            digAndMove()
        end
        turnLeft()

        -- Restore main tunnel direction
        faceDirection(NORTH)

        branches = branches + 2
        log("✅ Completed " .. branches .. " branches")
    end

    log("🎉 Strip mining complete! Branches: " .. branches .. ", Diamonds: " .. diamonds_found)
end

-- MAIN FUNCTION
function main()
    log("💎 DIAMOND MINING TURTLE v2.0")
    log("==============================")
    
    -- Sandık kontrolü (başlangıçta kırmamak için)
    if turtle.detectDown() then
        local success, data = turtle.inspectDown()
        if success and data.name and string.find(data.name, "chest") then
            log("✅ Chest detected below turtle")
        else
            log("⚠️ Block below is not a chest, placing one...")
            if selectItem(CONFIG.CHEST_SLOT) then
                turtle.digDown()
                turtle.placeDown()
            end
        end
    else
        log("⚠️ No block below, placing chest...")
        if selectItem(CONFIG.CHEST_SLOT) then
            turtle.placeDown()
        end
    end
    
    -- Setup kontrolü
    if not selectItem(CONFIG.TORCH_SLOT) then
        log("❌ No torches in slot " .. CONFIG.TORCH_SLOT)
        return
    end
    
    if turtle.getItemCount(CONFIG.CHEST_SLOT) == 0 then
        log("❌ No spare chest in slot " .. CONFIG.CHEST_SLOT)
        return
    end
    
    local fuel = turtle.getFuelLevel()
    log("⛽ Fuel level: " .. fuel)
    
    if fuel < 1000 then
        log("⚠️ Low fuel, attempting refuel...")
        if not autoRefuel() then
            log("❌ Cannot refuel! Add fuel to slot " .. CONFIG.FUEL_SLOT)
            return
        end
    end
    
    log("✅ Setup complete")
    log("🎯 Target: Y=11 Diamond Level")
    log("📏 Pattern: 3x1 Strip Mining")
    
    -- Set home and start mining
    setHome()
    stripMining()
    
    -- Final return and deposit
    log("🏠 Returning home for final deposit...")
    returnHome()
    depositItems()
    
    log("✅ Mining complete!")
    log("💎 Total diamonds found: " .. diamonds_found)
end

-- START SCRIPT
main()
