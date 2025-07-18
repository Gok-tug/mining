-- Diamond Mining Turtle Script for Tekkit2025
-- Optimized and Enhanced for 3x3 Tunnel Diamond Farming at Y-level -16
-- Includes Smart Inventory Management, Torch System, Obstacle Handling, Lava Avoidance

-- SETTINGS
local tunnelLength = 50
local torchInterval = 9 -- Place a torch every 9 steps
local torchSlot = 16 -- Torch should be in this slot

-- INTERNAL STATE
local depth = 0
local mined = 0
local currentLevel = 0
local stepsSinceLastTorch = 0

-- SAFE MOVEMENT
function safeForward()
    while turtle.detect() do turtle.dig(); sleep(0.4) end
    if turtle.forward() then depth = depth + 1; stepsSinceLastTorch = stepsSinceLastTorch + 1; return true end
    return false
end

function safeUp()
    while turtle.detectUp() do turtle.digUp(); sleep(0.4) end
    if turtle.up() then currentLevel = currentLevel + 1; return true end
    return false
end

function safeDown()
    while turtle.detectDown() do turtle.digDown(); sleep(0.4) end
    if turtle.down() then currentLevel = currentLevel - 1; return true end
    return false
end

function moveToLevel(target)
    while currentLevel < target do safeUp() end
    while currentLevel > target do safeDown() end
end

-- TORCH PLACEMENT
function placeTorch()
    if stepsSinceLastTorch >= torchInterval then
        turtle.select(torchSlot)
        turtle.turnLeft()
        turtle.turnLeft()
        if turtle.place() then print("Torch placed") end
        turtle.turnRight()
        turtle.turnRight()
        stepsSinceLastTorch = 0
    end
end

-- LAVA CHECK
function checkLava()
    local directions = {
        function() return turtle.inspect() end,
        function() return turtle.inspectUp() end,
        function() return turtle.inspectDown() end
    }
    for _, check in ipairs(directions) do
        local success, data = check()
        if success and data.name:find("lava") then
            print("Lava detected, skipping...")
            return true
        end
    end
    return false
end

-- INVENTORY MANAGEMENT
function isInventoryFull()
    local count = 0
    for i = 1, 16 do if turtle.getItemCount(i) == 0 then count = count + 1 end end
    return count <= 2
end

function manageInventory()
    local keep = {
        ["minecraft:diamond"] = true,
        ["minecraft:emerald"] = true,
        ["minecraft:coal"] = true,
        ["minecraft:iron_ore"] = true,
        ["minecraft:gold_ore"] = true,
        ["minecraft:redstone"] = true,
        ["minecraft:lapis_ore"] = true,
        ["bigreactors:oreyellorite"] = true
    }
    for i = 1, 16 do
        local detail = turtle.getItemDetail(i)
        if detail then
            if not keep[detail.name] and not detail.name:find("coal") and not detail.name:find("charcoal") then
                turtle.select(i)
                turtle.dropDown()
                print("Dropped " .. detail.name)
            end
        end
    end
    turtle.select(1)
end

function depositToChest()
    print("Depositing to chest...")
    local valuable = {
        ["minecraft:diamond"] = true,
        ["minecraft:emerald"] = true,
        ["minecraft:coal"] = true,
        ["minecraft:iron_ore"] = true,
        ["minecraft:gold_ore"] = true,
        ["minecraft:redstone"] = true,
        ["minecraft:lapis_ore"] = true,
        ["bigreactors:oreyellorite"] = true
    }
    local methods = {turtle.dropUp, turtle.drop, turtle.dropDown}
    for _, dropFn in ipairs(methods) do
        for i = 1, 16 do
            local item = turtle.getItemDetail(i)
            if item and valuable[item.name] then
                turtle.select(i)
                dropFn()
            end
        end
    end
    turtle.select(1)
end

function refuel()
    if turtle.getFuelLevel() < 100 then
        for i = 1, 16 do
            turtle.select(i)
            local item = turtle.getItemDetail()
            if item and (item.name:find("coal") or item.name:find("charcoal")) then
                if turtle.refuel(1) then
                    print("Refueled with " .. item.name)
                    break
                end
            end
        end
        turtle.select(1)
    end
end

-- 3x3 MINING FUNCTIONS
function digSides()
    turtle.turnLeft(); turtle.dig(); turtle.turnRight(); turtle.turnRight(); turtle.dig(); turtle.turnLeft()
end

function dig3x3Up()
    if checkLava() then return false end
    moveToLevel(2)
    turtle.dig(); safeForward(); digSides()
    safeDown(); digSides()
    safeDown(); digSides()
    placeTorch()
    return true
end

function dig3x3Down()
    if checkLava() then return false end
    moveToLevel(0)
    turtle.dig(); safeForward(); digSides()
    safeUp(); digSides()
    safeUp(); digSides()
    placeTorch()
    return true
end

-- RETURN LOGIC
function returnHome()
    moveToLevel(0)
    turtle.turnLeft(); turtle.turnLeft()
    for i = 1, depth do
        while turtle.detect() do turtle.dig(); sleep(0.4) end
        turtle.forward()
    end
    turtle.turnLeft(); turtle.turnLeft()
    depth = 0; currentLevel = 0
end

function returnToMine()
    for i = 1, depth do safeForward() end
end

-- MAIN LOOP
function startMining()
    print("Starting 3x3 Mining Operation")
    local i = 0
    while i < tunnelLength do
        refuel()
        manageInventory()

        if isInventoryFull() then
            print("Inventory full, depositing...")
            returnHome(); depositToChest(); sleep(1); returnToMine()
        end

        if turtle.getFuelLevel() < 50 then
            print("Low fuel, returning home...")
            returnHome(); return
        end

        local success = false
        if i % 2 == 0 then success = dig3x3Down() else success = dig3x3Up() end

        if not success then
            print("Section failed, returning home...")
            returnHome(); return
        end

        i = i + 1; mined = mined + 1
        if i % 10 == 0 then
            print("Progress: " .. i .. "/" .. tunnelLength .. " - Fuel: " .. turtle.getFuelLevel())
        end
    end
    returnHome(); depositToChest()
    print("Mining completed - Sections mined: " .. mined)
end

print("Place turtle at Y -16, facing tunnel direction. Torch in slot 16.")
sleep(3)
startMining()
