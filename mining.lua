-- ========================================
-- ADVANCED STRIP MINING TURTLE SCRIPT
-- ========================================
-- Özellikler:
-- * 3x3 strip mining
-- * 12 blokta bir torch yerleştirme
-- * Sandığı kırmaz
-- * Torch'ları kırmaz
-- * Envanter ve yakıt yönetimi

-- ===================
-- 🔧 Ayarlar
-- ===================
local CONFIG = {
    TUNNEL_LENGTH = 50,
    TUNNEL_COUNT = 20,
    SPACING = 2,
    TORCH_SLOT = 15,
    TORCH_INTERVAL = 12,
    FUEL_SLOT = 1
}

-- ===================
-- 📍 Konum Takibi
-- ===================
local pos = { x = 0, y = 0, z = 0 }
local direction = 0
local NORTH, EAST, SOUTH, WEST = 0, 1, 2, 3

function updatePos()
    if direction == NORTH then pos.z = pos.z - 1
    elseif direction == SOUTH then pos.z = pos.z + 1
    elseif direction == EAST then pos.x = pos.x + 1
    elseif direction == WEST then pos.x = pos.x - 1 end
end

function turnLeft()
    turtle.turnLeft()
    direction = (direction - 1) % 4
end

function turnRight()
    turtle.turnRight()
    direction = (direction + 1) % 4
end

function turnAround()
    turnLeft()
    turnLeft()
end

function faceDirection(target)
    while direction ~= target do
        turnRight()
    end
end

-- ===================
-- 🔐 Güvenli Kazma
-- ===================
function isTorch(name)
    return name and string.find(name, "torch") ~= nil
end

function isChest(name)
    return name and string.find(name, "chest") ~= nil
end

function safeDig()
    local success, data = turtle.inspect()
    if success and not isTorch(data.name) then
        turtle.dig()
    end
end

function safeDigDown()
    local success, data = turtle.inspectDown()
    if success and not isChest(data.name) then
        turtle.digDown()
    end
end

function safeMove()
    safeDig()
    while not turtle.forward() do
        sleep(0.4)
    end
    updatePos()
end

-- ===================
-- 🪔 Torch Sistemi
-- ===================
function placeTorch(step)
    if step % CONFIG.TORCH_INTERVAL == 0 then
        if not turtle.detectDown() then
            turtle.select(CONFIG.TORCH_SLOT)
            turtle.placeDown()
            turtle.select(1)
        end
    end
end

-- ===================
-- ⛏️ Maden Fonksiyonları
-- ===================
function digTunnel(length)
    for i = 1, length do
        safeMove()
        placeTorch(i)
    end
end

function mineStrip()
    local startPos = { x = pos.x, y = pos.y, z = pos.z }
    local startDir = direction

    digTunnel(CONFIG.TUNNEL_LENGTH)

    turnAround()
    digTunnel(CONFIG.TUNNEL_LENGTH)

    faceDirection(startDir)
    pos.x = startPos.x
    pos.z = startPos.z
end

-- ===================
-- 📦 Envanter Yönetimi
-- ===================
function isInventoryFull()
    for i = 2, 16 do
        if turtle.getItemCount(i) == 0 then return false end
    end
    return true
end

function returnHome()
    -- Yatay dönüş
    faceDirection(NORTH)
    while pos.z > 0 do
        safeMove()
    end
    faceDirection(WEST)
    while pos.x > 0 do
        safeMove()
    end
    -- Dikey dönüş
    while pos.y > 0 do
        if not turtle.down() then
            turtle.digDown()
        end
        pos.y = pos.y - 1
    end

    -- Sandığa boşalt
    for i = 2, 16 do
        turtle.select(i)
        turtle.dropDown()
    end
    turtle.select(1)
end

-- ===================
-- ⛽ Yakıt Yönetimi
-- ===================
function refuelIfNeeded()
    if turtle.getFuelLevel() < 100 then
        turtle.select(CONFIG.FUEL_SLOT)
        turtle.refuel(1)
        turtle.select(1)
    end
end

-- ===================
-- 🚀 Ana Başlatıcı
-- ===================
function main()
    -- Başlangıçta sandığın üstünde başlıyor
    turtle.down()
    pos.y = 0

    for i = 1, CONFIG.TUNNEL_COUNT do
        refuelIfNeeded()

        mineStrip()

        if isInventoryFull() then
            returnHome()
            turtle.up() -- sandığın üstüne çık
            pos.y = pos.y + 1
            returnHome() -- tekrar yerine gel
            turtle.down()
            pos.y = pos.y - 1
        end

        -- Tünel arası geçiş
        if i < CONFIG.TUNNEL_COUNT then
            turnRight()
            for j = 1, CONFIG.SPACING + 1 do
                safeMove()
            end
            turnLeft()
        end
    end

    -- Bittiğinde eve dön
    returnHome()
end

main()
