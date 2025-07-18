-- ========================================
-- ADVANCED MINING TURTLE SCRIPT v1.0
-- Optimal Branch Mining with Smart Torch System
-- ========================================
--
-- SETUP TALİMATLARI:
-- 1. Turtle'ı Y=12 seviyesine yerleştirin (örn: surface'dan 52 blok aşağı)
-- 2. Home chest'i turtle'ın ALTINA yerleştirin (items buraya aktarılacak)
-- 3. Inventory setup:
--    Slot 1: Torch'lar (64 adet önerilir)
--    Slot 15: Fuel items (coal, wood, charcoal - otomatik kullanılır)
--    Slot 16: Spare chest (geçici drops için)  
--    Slot 2-14: Boş (mining loot için)
-- 4. Script'i çalıştırın: lua mining.lua
-- 5. Script otomatik olarak:
--    - 3-kat mining yapacak (Y=11, Y=12, Y=13)
--    - Torch'ları Y=11'e yerleştirecek (turtle Y=12'de kalır)
--    - Branch mining pattern başlatacak
--    - Inventory dolunca home'a dönüp boşaltacak
--    - Geri dönerken torch'lara ÇARPMAYACAK (farklı seviyede!)
--    - Mining tamamlandığında tüm items'ları home chest'e aktaracak
--
-- ÖZELLİKLER:
-- ✅ 2x1 Diamond Level Branch Mining (Y=11-12)
-- ✅ Smart Torch Placement (geri dönerken engel olmaz)
-- ✅ Auto Inventory Management (home'a dönüp boşaltır)
-- ✅ Position Tracking & Return Home System
-- ✅ Fuel & Lava Safety Controls
-- ✅ Progress Reporting & Error Handling
-- ========================================

-- GLOBAL SETTINGS
local CONFIG = {
    TORCH_INTERVAL = 8,        -- Her 8 blokta bir torch
    TUNNEL_LENGTH = 50,        -- Ana tünel uzunluğu
    BRANCH_LENGTH = 30,        -- Yan dal uzunluğu  
    BRANCH_SPACING = 4,        -- Dallar arası mesafe
    MINING_LEVEL = 12,         -- Y koordinatı (turtle pozisyonu - orta seviye)
    TUNNEL_HEIGHT = 3,         -- Tünel yüksekliği (3=üç kat: Y=11,12,13)
    FUEL_MIN = 1000,          -- Minimum fuel kontrolü
    FUEL_EMERGENCY = 200,     -- Acil durum fuel limiti (home'a dönmek için)
    TORCH_SLOT = 1,           -- Torch slot numarası
    CHEST_SLOT = 16,          -- Geri dönüş chest slot
    FUEL_SLOT = 15            -- Fuel items slot (coal, wood, etc.)
}

-- DIRECTION CONSTANTS
local NORTH, EAST, SOUTH, WEST = 0, 1, 2, 3
local direction = NORTH

-- POSITION TRACKING
local pos = {x = 0, y = 0, z = 0}
local home_pos = {x = 0, y = 0, z = 0}
local mining_path = {} -- Mining rotası kayıt

-- ========================================
-- UTILITY FUNCTIONS
-- ========================================

function log(message)
    print("[" .. os.date("%H:%M:%S") .. "] " .. message)
end

function checkFuel()
    local current_fuel = turtle.getFuelLevel()
    
    if current_fuel < CONFIG.FUEL_EMERGENCY then
        log("🚨 ACIL DURUM: Fuel kritik seviyede! (" .. current_fuel .. ")")
        log("🏠 Acilen home'a dönülüyor...")
        return false
    elseif current_fuel < CONFIG.FUEL_MIN then
        log("⚠️  UYARI: Fuel azalıyor! (" .. current_fuel .. ")")
        -- Otomatik fuel eklemeye çalış
        if autoRefuel() then
            log("✅ Otomatik fuel eklendi")
            return true
        else
            log("❌ Fuel bulunamadı, mining durduruluyor")
            return false
        end
    end
    return true
end

function autoRefuel()
    local initial_fuel = turtle.getFuelLevel()
    
    -- Fuel slot'undaki item'ları kullan
    if selectItem(CONFIG.FUEL_SLOT) then
        local item_count = turtle.getItemCount(CONFIG.FUEL_SLOT)
        if item_count > 0 then
            turtle.refuel(item_count)
            log("⛽ " .. item_count .. " adet fuel item kullanıldı")
        end
    end
    
    -- Mining sırasında bulunan coal'ları kullan
    for slot = 2, 14 do
        if turtle.getItemCount(slot) > 0 then
            turtle.select(slot)
            local success, data = turtle.getItemDetail()
            if success and data.name then
                -- Coal, wood, charcoal vs. kontrol et
                if string.find(data.name, "coal") or 
                   string.find(data.name, "wood") or
                   string.find(data.name, "log") or
                   string.find(data.name, "plank") then
                    
                    local refuel_amount = math.min(data.count, 10) -- En fazla 10 adet
                    turtle.refuel(refuel_amount)
                    log("⛽ " .. refuel_amount .. " adet " .. data.name .. " fuel olarak kullanıldı")
                    break
                end
            end
        end
    end
    
    local gained_fuel = turtle.getFuelLevel() - initial_fuel
    return gained_fuel > 0
end

function calculateFuelNeeded()
    -- 3-kat mining için gereken fuel'i hesapla
    local tunnel_moves = CONFIG.TUNNEL_LENGTH * 2 -- İleri gidip geri gel
    local branch_moves = CONFIG.BRANCH_LENGTH * 2 * (CONFIG.TUNNEL_LENGTH / CONFIG.BRANCH_SPACING) * 2 -- Tüm dallar
    local home_distance = getDistanceToHome() * 2 -- Home'a gidip gelme
    
    -- 3-kat mining daha fazla fuel tüketir (daha fazla kazma işlemi)
    local mining_bonus = CONFIG.TUNNEL_HEIGHT * 100 -- Kat başına ekstra fuel
    
    local total_moves = tunnel_moves + branch_moves + home_distance + mining_bonus + 500 -- Safety margin
    
    log("📊 Tahmini fuel ihtiyacı: " .. total_moves .. " (" .. CONFIG.TUNNEL_HEIGHT .. "-kat mining)")
    return total_moves
end

function selectItem(slot)
    if turtle.getItemCount(slot) > 0 then
        turtle.select(slot)
        return true
    end
    return false
end

-- ========================================
-- MOVEMENT FUNCTIONS WITH POSITION TRACKING
-- ========================================

function updatePosition(dx, dy, dz)
    pos.x = pos.x + dx
    pos.y = pos.y + dy  
    pos.z = pos.z + dz
    
    -- Mining path'e ekle (geri dönüş için)
    table.insert(mining_path, {x = pos.x, y = pos.y, z = pos.z, dir = direction})
end

function setHomePosition()
    home_pos.x = pos.x
    home_pos.y = pos.y
    home_pos.z = pos.z
    log("🏠 Home pozisyonu kaydedildi: (" .. home_pos.x .. ", " .. home_pos.y .. ", " .. home_pos.z .. ")")
end

function getDistanceToHome()
    local dx = math.abs(pos.x - home_pos.x)
    local dy = math.abs(pos.y - home_pos.y) 
    local dz = math.abs(pos.z - home_pos.z)
    return dx + dy + dz -- Manhattan distance
end

function moveForward()
    while not turtle.forward() do
        if turtle.detect() then
            turtle.dig()
        else
            turtle.attack()
        end
        sleep(0.1)
    end
    if direction == NORTH then updatePosition(0, 0, -1)
    elseif direction == EAST then updatePosition(1, 0, 0)
    elseif direction == SOUTH then updatePosition(0, 0, 1)
    elseif direction == WEST then updatePosition(-1, 0, 0)
    end
    return true
end

function safeForward(digDown)
    -- Bu fonksiyon artık sadece blok kırma işlemini yapacak.
    return digTunnelSection(digDown)
end

function digTunnelSection(digDown)
    -- Önce önündeki bloku kaz (Y=12 - turtle seviyesi)
    while turtle.detect() do
        turtle.dig()
        sleep(0.1)
    end
    
    -- 3 kat mining için üst bloku da kaz (Y=13)
    if CONFIG.TUNNEL_HEIGHT >= 2 then
        while turtle.detectUp() do
            turtle.digUp()
            sleep(0.1)
        end
    end
    
    -- 3 kat mining için alt bloku da kaz (Y=11)
    if CONFIG.TUNNEL_HEIGHT >= 3 and digDown then
        -- GÜVENLİK: Eğer başlangıç pozisyonundaysak, alt bloğu (sandığı) kazma!
        if pos.x == home_pos.x and pos.y == home_pos.y and pos.z == home_pos.z then
            log("🛡️ Başlangıç pozisyonu, alt blok (sandık) kazılmadı.")
        else
            if turtle.detectDown() then
                local success, data = turtle.inspectDown()
                if success and data.name then
                    if string.find(data.name, "lava") or string.find(data.name, "water") then
                        log("🚨 TEHLIKE: " .. data.name .. " tespit edildi Y=" .. (pos.y - 1) .. " seviyesinde!")
                        return false
                    end
                end
                -- Güvenliyse alt bloku kaz (Y=11)
                while turtle.detectDown() do
                    turtle.digDown()
                    sleep(0.1)
                end
            end
        end
    end
    
    return true
end

function safeUp()
    while not turtle.up() do
        if turtle.detectUp() then
            turtle.digUp()
        else
            turtle.attackUp()
        end
        sleep(0.1)
    end
    updatePosition(0, 1, 0)
end

function safeDown()
    while not turtle.down() do
        if turtle.detectDown() then
            turtle.digDown()
        else
            turtle.attackDown()
        end
        sleep(0.1)
    end
    updatePosition(0, -1, 0)
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
    turnRight()
    turnRight()
end

-- ========================================
-- SIMPLE GROUND TORCH SYSTEM
-- ========================================

function placeGroundTorch(steps_taken)
    -- 3-kat mining torch sistemi:
    -- 1. Turtle Y=12'de hareket ediyor
    -- 2. Torch Y=11'e (aşağıya) yerleştir  
    -- 3. Geri dönerken turtle Y=12'de kalır = ÇARPIŞMA YOK!
    
    if steps_taken % CONFIG.TORCH_INTERVAL ~= 0 then return false end
    if not selectItem(CONFIG.TORCH_SLOT) then return false end
    
    -- Alt seviyeye torch yerleştir (Y=11)
    if turtle.placeDown() then
        log("🔥 Torch yerleştirildi Y=" .. (pos.y - 1) .. " (turtle Y=" .. pos.y .. ") - step: " .. steps_taken)
        log("   ✅ Geri dönerken çarpışma riski YOK!")
        return true
    else
        log("⚠️  Alt seviyeye torch yerleştirilemedi")
        return false
    end
end

-- ========================================
-- INVENTORY MANAGEMENT  
-- ========================================

function isInventoryFull()
    for slot = 2, 15 do -- Slot 1 torch, slot 16 chest için ayrılmış
        if turtle.getItemCount(slot) == 0 then
            return false
        end
    end
    return true
end

function dropItems()
    log("📦 Inventory dolu, home'a dönülüyor...")
    local mining_position = {x = pos.x, y = pos.y, z = pos.z, dir = direction}
    
    -- Home'a git
    if not returnToHome() then
        log("❌ Home'a dönüş başarısız!")
        return false
    end
    
    -- Home chest'e items aktar
    if not depositItemsAtHome() then
        log("❌ Items aktarımı başarısız!")
        return false  
    end
    
    -- Mining pozisyonuna geri dön
    if not returnToMiningPosition(mining_position) then
        log("❌ Mining pozisyonuna dönüş başarısız!")
        return false
    end
    
    log("✅ Inventory boşaltıldı ve mining'e devam ediliyor")
    return true
end

function returnToHome()
    log("🏠 Home'a dönülüyor... Mesafe: " .. getDistanceToHome())
    
    local max_steps = 1000
    local steps = 0
    
    -- Basit pathfinding - X, Z, Y sırasında
    while pos.x ~= home_pos.x or pos.z ~= home_pos.z or pos.y ~= home_pos.y do
        steps = steps + 1
        if steps > max_steps then
            log("❌ Home'a dönüş sırasında sonsuz döngü tespit edildi!")
            return false
        end
        -- X ekseni
        if pos.x < home_pos.x then
            faceDirection(EAST)
            if not safeForward() then return false end
        elseif pos.x > home_pos.x then
            faceDirection(WEST) 
            if not safeForward() then return false end
        -- Z ekseni
        elseif pos.z < home_pos.z then
            faceDirection(SOUTH)
            if not safeForward() then return false end
        elseif pos.z > home_pos.z then
            faceDirection(NORTH)
            if not safeForward() then return false end
        -- Y ekseni
        elseif pos.y < home_pos.y then
            safeUp()
        elseif pos.y > home_pos.y then
            safeDown()
        end
        
        -- Fuel kontrolü
        if not checkFuel() then
            log("⛽ Fuel bitti! Acil durum!")
            return false
        end
    end
    
    log("✅ Home'a varıldı")
    return true
end

function faceDirection(target_dir)
    local attempts = 0
    while direction ~= target_dir and attempts < 4 do
        turnLeft()
        attempts = attempts + 1
    end
    if direction ~= target_dir then
        log("⚠️  faceDirection: Hedef yöne dönülemedi!")
    end
end

function depositItemsAtHome() 
    log("📥 Home chest'e items aktarılıyor...")
    
    -- Chest'in home'da olduğunu varsayıyoruz (üstünde, altında veya önünde)
    local chest_found = false
    
    -- Önce altına bak
    if turtle.detectDown() then
        for slot = 2, 15 do
            if turtle.getItemCount(slot) > 0 then
                turtle.select(slot)
                if turtle.dropDown() then
                    chest_found = true
                else
                    break -- Chest dolu veya yok
                end
            end
        end
    end
    
    -- Alt chest yoksa, geçici chest yerleştir
    if not chest_found then
        if selectItem(CONFIG.CHEST_SLOT) then
            turtle.placeDown()
            
            for slot = 2, 15 do
                if turtle.getItemCount(slot) > 0 then
                    turtle.select(slot)
                    turtle.dropDown()
                end
            end
            
            log("⚠️  Geçici chest yerleştirildi (Home'da ana chest bulunamadı)")
        else
            log("❌ Ne home chest'i ne de spare chest bulunamadı!")
            return false
        end
    end
    
    log("✅ Items başarıyla aktarıldı")
    return true
end

function returnToMiningPosition(target_pos)
    log("⛏️  Mining pozisyonuna dönülüyor...")
    
    local max_steps = 1000
    local steps = 0
    
    -- Target pozisyonuna git
    while pos.x ~= target_pos.x or pos.z ~= target_pos.z or pos.y ~= target_pos.y do
        steps = steps + 1
        if steps > max_steps then
            log("❌ Mining pozisyonuna dönüş sırasında sonsuz döngü tespit edildi!")
            return false
        end
        -- X ekseni
        if pos.x < target_pos.x then
            faceDirection(EAST)
            if not safeForward() then return false end
        elseif pos.x > target_pos.x then
            faceDirection(WEST)
            if not safeForward() then return false end
        -- Z ekseni  
        elseif pos.z < target_pos.z then
            faceDirection(SOUTH)
            if not safeForward() then return false end
        elseif pos.z > target_pos.z then
            faceDirection(NORTH)
            if not safeForward() then return false end
        -- Y ekseni
        elseif pos.y < target_pos.y then
            safeUp()
        elseif pos.y > target_pos.y then
            safeDown()
        end
    end
    
    -- Orijinal yönüne dön
    faceDirection(target_pos.dir)
    
    log("✅ Mining pozisyonuna varıldı")
    return true
end

-- ========================================
-- MINING ALGORITHMS
-- ========================================

function mineForward(steps, place_torches)
    place_torches = place_torches or false
    for step = 1, steps do
        if not checkFuel() then
            log("⛽ Fuel azaldı, mining durduruluyor")
            return false
        end
        if isInventoryFull() then
            log("🎒 Inventory dolu, items boşaltılıyor")
            if not dropItems() then
                return false
            end
        end

        -- 1. Önce blokları kır
        if not safeForward(place_torches) then
            log("❌ Güvenlik riski nedeniyle mining durduruluyor")
            return false
        end

        -- 2. Sonra, ilerlemeden ÖNCE torch koy
        if place_torches then
            placeGroundTorch(step)
        end

        -- 3. En son ilerle
        if not moveForward() then
            log("❌ İleri hareket başarısız")
            return false
        end

        if step % 10 == 0 then
            log("🔨 Mining: " .. step .. "/" .. steps .. " blocks")
        end
    end
    return true
end

function mineBranch(length, return_back)
    if return_back == nil then return_back = true end
    log("🌿 Yan dal kazılıyor: " .. length .. " blok")
    if not mineForward(length, true) then
        return false
    end
    if return_back then
        turnAround()
        mineForward(length, false) -- Geri dönerken torch ve alt blok kazma yok
        turnAround()
    end
    return true
end

function branchMining()
    log("🚀 Branch Mining başlatılıyor...")
    log("📍 Hedef Level: Y=" .. CONFIG.MINING_LEVEL .. " (Tünel Yüksekliği: " .. CONFIG.TUNNEL_HEIGHT .. ")")
    
    if CONFIG.TUNNEL_HEIGHT == 3 then
        log("💎 3-KAT ULTRA Tünel Modu:")
        log("   📍 Y=" .. (CONFIG.MINING_LEVEL - 1) .. " (alt kat - torch seviyesi)")
        log("   📍 Y=" .. CONFIG.MINING_LEVEL .. " (orta kat - turtle seviyesi)")  
        log("   📍 Y=" .. (CONFIG.MINING_LEVEL + 1) .. " (üst kat)")
        log("   🔥 Torch Y=" .. (CONFIG.MINING_LEVEL - 1) .. "'e yerleştirilecek")
        log("   ✅ Geri dönerken çarpışma riski YOK!")
    elseif CONFIG.TUNNEL_HEIGHT == 2 then
        log("💎 2x1 Tünel Modu: Y=" .. CONFIG.MINING_LEVEL .. " ve Y=" .. (CONFIG.MINING_LEVEL + 1) .. " kazılacak")
    else
        log("📏 1x1 Tünel Modu: Sadece Y=" .. CONFIG.MINING_LEVEL .. " kazılacak")
    end
    
    -- Ana tüneli kaz
    log("🛤️  Ana tünel kazılıyor...")
    mineForward(CONFIG.TUNNEL_LENGTH, true)
    
    -- Geri dön ana tünelin başına
    turnAround()
    mineForward(CONFIG.TUNNEL_LENGTH, false)
    turnAround()
    
    -- Yan dalları kaz
    local branches_made = 0
    for i = CONFIG.BRANCH_SPACING, CONFIG.TUNNEL_LENGTH, CONFIG.BRANCH_SPACING do
        -- Pozisyona git
        mineForward(CONFIG.BRANCH_SPACING, false)
        
        -- Sol dal
        turnLeft()
        log("🌿 Sol dal #" .. (branches_made + 1))
        mineBranch(CONFIG.BRANCH_LENGTH, true)
        turnRight() -- Ana tünele dön
        
        -- Sağ dal  
        turnRight()
        log("🌿 Sağ dal #" .. (branches_made + 2))
        mineBranch(CONFIG.BRANCH_LENGTH, true)
        turnLeft() -- Ana tünele dön
        
        branches_made = branches_made + 2
        log("✅ Toplam " .. branches_made .. " dal tamamlandı")
    end
    
    log("🎉 Branch Mining tamamlandı!")
    log("📊 Toplam dal sayısı: " .. branches_made)
    log("🔥 3-kat torch sistemi: Y=" .. (CONFIG.MINING_LEVEL - 1) .. " seviyesine her " .. CONFIG.TORCH_INTERVAL .. " blokta bir torch yerleştirildi")
end

-- ========================================
-- MAIN FUNCTION
-- ========================================

function main()
    log("🔥 ADVANCED MINING TURTLE v1.0")
    log("================================")
    
    -- Başlangıç kontrolleri
    local current_fuel = turtle.getFuelLevel()
    local needed_fuel = calculateFuelNeeded()
    
    log("⛽ Mevcut fuel: " .. current_fuel)
    log("📊 Tahmini ihtiyaç: " .. needed_fuel)
    
    if current_fuel < needed_fuel then
        log("⚠️  Fuel yetersiz olabilir! Otomatik fuel deneniyor...")
        autoRefuel()
        current_fuel = turtle.getFuelLevel()
        
        if current_fuel < CONFIG.FUEL_EMERGENCY then
            log("❌ Kritik fuel eksikliği! Mining başlatılamıyor")
            log("💡 Öneriler:")
            log("   - Slot " .. CONFIG.FUEL_SLOT .. "'a coal/wood ekleyin")
            log("   - Turtle'ı fuel source yakınına götürün")
            return
        end
    end
    
    if not selectItem(CONFIG.TORCH_SLOT) then
        log("❌ Slot " .. CONFIG.TORCH_SLOT .. "'ta torch bulunamadı!")
        return
    end
    
    if not selectItem(CONFIG.CHEST_SLOT) then
        log("❌ Slot " .. CONFIG.CHEST_SLOT .. "'ta chest bulunamadı!")
        return
    end
    
    log("✅ Tüm kontroller başarılı")
    log("🎯 Hedef Level: Y=" .. CONFIG.MINING_LEVEL .. " (Yükseklik: " .. CONFIG.TUNNEL_HEIGHT .. ")")
    
    -- Home pozisyonunu kaydet
    setHomePosition()
    
    -- Mining başlat
    branchMining()
    
    -- Mining bittiğinde home'a dön ve final deposit yap
    log("🏠 Mining tamamlandı, home'a dönülüyor...")
    if returnToHome() then
        depositItemsAtHome()
        log("✨ Tüm items home chest'e aktarıldı!")
    else
        log("⚠️  Home'a dönüş başarısız, items turtle'da kaldı")
    end
    
    log("🎉 Mining işlemi tamamlandı!")
end

-- SCRIPT'İ BAŞLAT
main()
