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
-- DIAMOND HUNTER PRO SYSTEM
-- ========================================

local DIAMOND_HUNTER = {
    state_file = "diamond_hunter_state.dat",
    diamond_log = "diamond_locations.dat",
    current_area = {x = 0, z = 0},
    mined_areas = {},
    diamond_locations = {},
    diamonds_found_this_session = 0
}

function loadDiamondHunterState()
    -- Önceki mining durumunu yükle
    if fs.exists(DIAMOND_HUNTER.state_file) then
        local file = fs.open(DIAMOND_HUNTER.state_file, "r")
        if file then
            local data = file.readAll()
            file.close()
            
            if data and data ~= "" then
                local state = textutils.unserialize(data)
                if state then
                    DIAMOND_HUNTER.current_area = state.current_area or {x = 0, z = 0}
                    DIAMOND_HUNTER.mined_areas = state.mined_areas or {}
                    log("📂 Önceki mining durumu yüklendi")
                    log("🏗️ Mevcut alan: X=" .. DIAMOND_HUNTER.current_area.x .. ", Z=" .. DIAMOND_HUNTER.current_area.z)
                    log("📊 Toplam kazılmış alan sayısı: " .. #DIAMOND_HUNTER.mined_areas)
                    return true
                end
            end
        end
    end
    log("🆕 Yeni Diamond Hunter Pro session başlatılıyor")
    return false
end

function saveDiamondHunterState()
    -- Mining durumunu kaydet
    local state = {
        current_area = DIAMOND_HUNTER.current_area,
        mined_areas = DIAMOND_HUNTER.mined_areas,
        last_update = os.time()
    }
    
    local file = fs.open(DIAMOND_HUNTER.state_file, "w")
    if file then
        file.write(textutils.serialize(state))
        file.close()
        return true
    end
    return false
end

function loadDiamondLocations()
    -- Diamond lokasyonlarını yükle
    if fs.exists(DIAMOND_HUNTER.diamond_log) then
        local file = fs.open(DIAMOND_HUNTER.diamond_log, "r")
        if file then
            local data = file.readAll()
            file.close()
            
            if data and data ~= "" then
                local diamonds = textutils.unserialize(data)
                if diamonds then
                    DIAMOND_HUNTER.diamond_locations = diamonds
                    log("💎 Önceki diamond kayıtları yüklendi: " .. #diamonds .. " lokasyon")
                    return true
                end
            end
        end
    end
    DIAMOND_HUNTER.diamond_locations = {}
    return false
end

function saveDiamondLocation(x, y, z)
    -- Yeni diamond lokasyonunu kaydet
    local diamond_loc = {
        x = x, y = y, z = z,
        area_x = DIAMOND_HUNTER.current_area.x,
        area_z = DIAMOND_HUNTER.current_area.z,
        timestamp = os.time()
    }
    
    table.insert(DIAMOND_HUNTER.diamond_locations, diamond_loc)
    DIAMOND_HUNTER.diamonds_found_this_session = DIAMOND_HUNTER.diamonds_found_this_session + 1
    
    -- Dosyaya kaydet
    local file = fs.open(DIAMOND_HUNTER.diamond_log, "w")
    if file then
        file.write(textutils.serialize(DIAMOND_HUNTER.diamond_locations))
        file.close()
    end
    
    log("💎 YENİ DIAMOND! Lokasyon: (" .. x .. ", " .. y .. ", " .. z .. ")")
    log("🎉 Bu session'da bulunan diamond: " .. DIAMOND_HUNTER.diamonds_found_this_session)
end

function calculateNextArea()
    -- Bir sonraki mining alanını hesapla
    local area_size = CONFIG.TUNNEL_LENGTH + 10 -- Buffer ekle
    local current_x = DIAMOND_HUNTER.current_area.x
    local current_z = DIAMOND_HUNTER.current_area.z
    
    -- Spiral pattern ile genişle (daha verimli coverage)
    -- X pozitif yönde 3 alan, sonra Z pozitif yönde 3 alan, vs.
    local completed_areas = #DIAMOND_HUNTER.mined_areas
    local cycle = math.floor(completed_areas / 8) -- Her 8 alanda bir cycle
    local position_in_cycle = completed_areas % 8
    
    local next_x, next_z = current_x, current_z
    
    if position_in_cycle == 0 then -- Sağa git
        next_x = current_x + area_size
    elseif position_in_cycle == 1 then -- Yukarı git  
        next_z = current_z + area_size
    elseif position_in_cycle == 2 then -- Sola git
        next_x = current_x - area_size
    elseif position_in_cycle == 3 then -- Aşağı git
        next_z = current_z - area_size
    elseif position_in_cycle == 4 then -- Sağa git (genişletilmiş)
        next_x = current_x + area_size
    elseif position_in_cycle == 5 then -- Yukarı git (genişletilmiş)
        next_z = current_z + area_size
    elseif position_in_cycle == 6 then -- Sola git (genişletilmiş)
        next_x = current_x - area_size  
    else -- position_in_cycle == 7, Aşağı git (genişletilmiş)
        next_z = current_z - area_size
    end
    
    return {x = next_x, z = next_z}
end

function moveToNewArea(target_area)
    -- Yeni mining alanına git
    log("🚀 Yeni mining alanına gidiliyor: X=" .. target_area.x .. ", Z=" .. target_area.z)
    
    -- Home'a dön önce (güvenli)
    if not returnToHome() then
        log("❌ Yeni alana gitmek için önce home'a dönülemedi")
        return false
    end
    
    -- Target pozisyona git
    local target_x = target_area.x
    local target_z = target_area.z
    
    while pos.x ~= target_x or pos.z ~= target_z do
        if pos.x < target_x then
            faceDirection(EAST)
            if not moveForward() then return false end
        elseif pos.x > target_x then
            faceDirection(WEST)
            if not moveForward() then return false end
        elseif pos.z < target_z then
            faceDirection(SOUTH)
            if not moveForward() then return false end
        elseif pos.z > target_z then
            faceDirection(NORTH)
            if not moveForward() then return false end
        end
    end
    
    -- Yeni home pozisyonunu ayarla
    setHomePosition()
    
    log("✅ Yeni alan başlangıcına varıldı: (" .. pos.x .. ", " .. pos.z .. ")")
    return true
end

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
        if turtle.dig() then
            checkForDiamond("front", pos.x, pos.y, pos.z)
        end
        sleep(0.1)
    end
    
    -- 3 kat mining için üst bloku da kaz (Y=13)
    if CONFIG.TUNNEL_HEIGHT >= 2 then
        while turtle.detectUp() do
            if turtle.digUp() then
                checkForDiamond("up", pos.x, pos.y + 1, pos.z)
            end
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
                    if turtle.digDown() then
                        checkForDiamond("down", pos.x, pos.y - 1, pos.z)
                    end
                    sleep(0.1)
                end
            end
        end
    end
    
    return true
end

function checkForDiamond(direction, x, y, z)
    -- Son kazılmış blokun diamond olup olmadığını kontrol et
    local slot_start = turtle.getSelectedSlot()
    
    -- Inventory'yi tara, yeni eklenen diamond var mı?
    for slot = 1, 16 do
        if turtle.getItemCount(slot) > 0 then
            turtle.select(slot)
            local success, data = turtle.getItemDetail()
            if success and data.name then
                if string.find(data.name, "diamond") and not string.find(data.name, "ore") then
                    -- Ham diamond bulundu! (diamond ore değil)
                    saveDiamondLocation(x, y, z)
                    
                    -- Bu alanı özel işaretle (diamond expansion için)
                    markAreaForExpansion(x, y, z)
                    break
                elseif string.find(data.name, "diamond_ore") then
                    -- Diamond ore bulundu!
                    saveDiamondLocation(x, y, z)
                    
                    -- Bu alanı özel işaretle (diamond expansion için)
                    markAreaForExpansion(x, y, z)
                    break
                end
            end
        end
    end
    
    -- Orijinal slot'a geri dön
    turtle.select(slot_start)
end

function markAreaForExpansion(x, y, z)
    -- Diamond bulunan alanı gelecekte 3x3 expansion için işaretle
    local expansion_marker = {
        x = x, y = y, z = z,
        area_x = DIAMOND_HUNTER.current_area.x,
        area_z = DIAMOND_HUNTER.current_area.z,
        expansion_needed = true,
        priority = "high"
    }
    
    -- Bu alanın zaten işaretli olup olmadığını kontrol et
    for _, existing in pairs(DIAMOND_HUNTER.diamond_locations) do
        if existing.x == x and existing.y == y and existing.z == z then
            existing.expansion_needed = true
            existing.priority = "high"
            return -- Zaten var, tekrar ekleme
        end
    end
    
    log("🎯 Alan expansion için işaretlendi: (" .. x .. ", " .. y .. ", " .. z .. ")")
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
    if steps_taken % CONFIG.TORCH_INTERVAL ~= 0 then
        return true -- Torch koyma zamanı değil, bu bir hata değil.
    end
    
    if not selectItem(CONFIG.TORCH_SLOT) then
        log("🚨 KRİTİK: Torch bitti! Eve dönülüyor.")
        return false -- Hata: Torch kalmadı.
    end
    
    if turtle.placeDown() then
        log("🔥 Torch yerleştirildi Y=" .. (pos.y - 1))
        return true
    else
        log("⚠️ Alt seviyeye torch yerleştirilemedi.")
        return false -- Hata: Yerleştirilemedi.
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
            if not moveForward() then return false end
        elseif pos.x > home_pos.x then
            faceDirection(WEST) 
            if not moveForward() then return false end
        -- Z ekseni
        elseif pos.z < home_pos.z then
            faceDirection(SOUTH)
            if not moveForward() then return false end
        elseif pos.z > home_pos.z then
            faceDirection(NORTH)
            if not moveForward() then return false end
        -- Y ekseni
        elseif pos.y < home_pos.y then
            safeUp()
        elseif pos.y > home_pos.y then
            safeDown()
        end

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
            if not moveForward() then return false end
        elseif pos.x > target_pos.x then
            faceDirection(WEST)
            if not moveForward() then return false end
        -- Z ekseni  
        elseif pos.z < target_pos.z then
            faceDirection(SOUTH)
            if not moveForward() then return false end
        elseif pos.z > target_pos.z then
            faceDirection(NORTH)
            if not moveForward() then return false end
        -- Y ekseni
        elseif pos.y < target_pos.y then
            safeUp()
        elseif pos.y > target_pos.y then
            safeDown()
        end
    end

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
        if not checkFuel() then return false end
        if isInventoryFull() then
            if not dropItems() then return false end
        end
        if not safeForward(place_torches) then return false end
        if place_torches then
            if not placeGroundTorch(step) then return false end
        end
        if not moveForward() then return false end
        if step % 10 == 0 then log("🔨 Mining: " .. step .. "/" .. steps .. " blocks") end
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
    log("💎 Diamond Hunter Pro aktif! Otomatik diamond detection çalışıyor.")
    
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
    if not mineForward(CONFIG.TUNNEL_LENGTH, true) then
        return false
    end
    
    -- Geri dön ana tünelin başına
    turnAround()
    if not mineForward(CONFIG.TUNNEL_LENGTH, false) then
        return false
    end
    turnAround()
    
    -- Yan dalları kaz
    local branches_made = 0
    for i = CONFIG.BRANCH_SPACING, CONFIG.TUNNEL_LENGTH, CONFIG.BRANCH_SPACING do
        -- Pozisyona git
        if not mineForward(CONFIG.BRANCH_SPACING, false) then
            return false
        end
        
        -- Sol dal
        turnLeft()
        log("🌿 Sol dal #" .. (branches_made + 1))
        if not mineBranch(CONFIG.BRANCH_LENGTH, true) then
            return false
        end
        turnRight() -- Ana tünele dön
        
        -- Sağ dal  
        turnRight()
        log("🌿 Sağ dal #" .. (branches_made + 2))
        if not mineBranch(CONFIG.BRANCH_LENGTH, true) then
            return false
        end
        turnLeft() -- Ana tünele dön
        
        branches_made = branches_made + 2
        log("✅ Toplam " .. branches_made .. " dal tamamlandı")
    end
    
    -- Mining tamamlandı, bu alanı kaydet
    table.insert(DIAMOND_HUNTER.mined_areas, {
        x = DIAMOND_HUNTER.current_area.x,
        z = DIAMOND_HUNTER.current_area.z,
        completed_time = os.time(),
        branches_count = branches_made,
        diamonds_found = DIAMOND_HUNTER.diamonds_found_this_session
    })
    
    log("🎉 Branch Mining tamamlandı!")
    log("📊 Toplam dal sayısı: " .. branches_made)
    log("💎 Bu alanda bulunan diamond: " .. DIAMOND_HUNTER.diamonds_found_this_session)
    log("🔥 3-kat torch sistemi: Y=" .. (CONFIG.MINING_LEVEL - 1) .. " seviyesine her " .. CONFIG.TORCH_INTERVAL .. " blokta bir torch yerleştirildi")
    
    return true
end

function diamondHunterMain()
    log("💎 DIAMOND HUNTER PRO v1.0 BAŞLATILIYOR")
    log("========================================")
    
    -- Diamond Hunter durumunu yükle
    loadDiamondHunterState()
    loadDiamondLocations()
    
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
            return false
        end
    end
    
    if not selectItem(CONFIG.TORCH_SLOT) then
        log("❌ Slot " .. CONFIG.TORCH_SLOT .. "'ta torch bulunamadı!")
        return false
    end
    
    if not selectItem(CONFIG.CHEST_SLOT) then
        log("❌ Slot " .. CONFIG.CHEST_SLOT .. "'ta chest bulunamadı!")
        return false
    end
    
    log("✅ Tüm kontroller başarılı")
    log("🎯 Hedef Level: Y=" .. CONFIG.MINING_LEVEL .. " (Yükseklik: " .. CONFIG.TUNNEL_HEIGHT .. ")")
    log("💎 Diamond Hunter Pro aktif!")
    
    -- İlk kez çalışıyorsa home pozisyon ayarla
    if DIAMOND_HUNTER.current_area.x == 0 and DIAMOND_HUNTER.current_area.z == 0 then
        setHomePosition()
    end
    
    local mining_success = branchMining()
    
    if not mining_success then
        log("⚠️ Mining görevi tamamlanamadı (yakıt/torch bitti veya bir sorun oluştu).")
    else
        log("✅ Bu alan mining'i başarıyla tamamlandı.")
        
        -- State'i kaydet
        saveDiamondHunterState()
        
        -- Otomatik area expansion
        log("🔄 Bir sonraki mining alanı hesaplanıyor...")
        local next_area = calculateNextArea()
        DIAMOND_HUNTER.current_area = next_area
        
        log("🚀 Bir sonraki alan: X=" .. next_area.x .. ", Z=" .. next_area.z)
        log("💡 Devam etmek için 'main()' komutunu tekrar çalıştırın!")
    end
    
    -- Her durumda eve dön ve items'ları boşalt
    log("🏠 Görev sonrası eve dönülüyor...")
    if returnToHome() then
        depositItemsAtHome()
        log("✅ Tüm items home chest'e aktarıldı!")
    else
        log("⚠️ Eve dönüş başarısız, items turtle'da kaldı")
    end
    
    -- Diamond Hunter istatistikleri
    log("📊 DIAMOND HUNTER İSTATİSTİKLERİ:")
    log("   🏗️ Toplam kazılmış alan: " .. #DIAMOND_HUNTER.mined_areas)
    log("   💎 Toplam bulunan diamond: " .. #DIAMOND_HUNTER.diamond_locations)
    log("   🎯 Bu session diamond: " .. DIAMOND_HUNTER.diamonds_found_this_session)
    
    log("🎉 Diamond Hunter Pro mining tamamlandı!")
    return mining_success
end

function main()
    return diamondHunterMain()
end

-- ========================================
-- DIAMOND HUNTER PRO KULLANICI ARAYÜZÜ
-- ========================================

-- Fuel helper fonksiyonlarını global yap
_G.showFuelStatus = showFuelStatus
_G.refuelNow = refuelNow
_G.quickFuelCheck = quickFuelCheck

-- Diamond Hunter Pro komutları
_G.main = main
_G.diamondStats = function()
    loadDiamondHunterState()
    loadDiamondLocations()
    
    print("💎 DIAMOND HUNTER PRO İSTATİSTİKLERİ")
    print("=====================================")
    print("🏗️ Toplam kazılmış alan: " .. #DIAMOND_HUNTER.mined_areas)
    print("💎 Toplam bulunan diamond: " .. #DIAMOND_HUNTER.diamond_locations)
    print("📍 Mevcut alan: X=" .. DIAMOND_HUNTER.current_area.x .. ", Z=" .. DIAMOND_HUNTER.current_area.z)
    
    if #DIAMOND_HUNTER.diamond_locations > 0 then
        print("🎯 Son 5 diamond lokasyonu:")
        local recent_count = math.min(5, #DIAMOND_HUNTER.diamond_locations)
        for i = #DIAMOND_HUNTER.diamond_locations - recent_count + 1, #DIAMOND_HUNTER.diamond_locations do
            local diamond = DIAMOND_HUNTER.diamond_locations[i]
            print("   💎 (" .. diamond.x .. ", " .. diamond.y .. ", " .. diamond.z .. ")")
        end
    end
end

_G.resetDiamondHunter = function()
    if fs.exists(DIAMOND_HUNTER.state_file) then
        fs.delete(DIAMOND_HUNTER.state_file)
    end
    if fs.exists(DIAMOND_HUNTER.diamond_log) then
        fs.delete(DIAMOND_HUNTER.diamond_log)
    end
    DIAMOND_HUNTER.current_area = {x = 0, z = 0}
    DIAMOND_HUNTER.mined_areas = {}
    DIAMOND_HUNTER.diamond_locations = {}
    DIAMOND_HUNTER.diamonds_found_this_session = 0
    print("🔄 Diamond Hunter Pro sıfırlandı. Yeni mining session başlatılabilir.")
end

-- Başlangıç mesajları
print()
print("💎 DIAMOND HUNTER PRO v1.0 HAZIR!")
print("===================================")
print()
print("🎯 KOMUTLAR:")
print("   main()              - Diamond mining başlat")
print("   diamondStats()      - İstatistikleri göster")  
print("   resetDiamondHunter() - Sistemi sıfırla")
print()
print("⚙️  YARDIMCI KOMUTLAR:")
print("   refuelNow()         - Fuel doldur")
print("   showFuelStatus()    - Fuel durumu")
print()
print("🚀 BAŞLATMAK İÇİN: 'main()' yazın")
print()

-- İlk fuel kontrolü
if turtle.getFuelLevel() < CONFIG.FUEL_MIN then
    print("⚠️  Fuel azaldı! Önce 'refuelNow()' çalıştırın.")
else
    print("✅ Fuel durumu iyi: " .. turtle.getFuelLevel())
end

-- Diamond Hunter durumunu göster
loadDiamondHunterState()
if #DIAMOND_HUNTER.mined_areas > 0 then
    print("📂 Önceki session bulundu: " .. #DIAMOND_HUNTER.mined_areas .. " alan kazılmış")
    print("🎯 Sonraki alan: X=" .. DIAMOND_HUNTER.current_area.x .. ", Z=" .. DIAMOND_HUNTER.current_area.z)
else
    print("🆕 Yeni Diamond Hunter Pro session")
end

print()
print("💡 Diamond Hunter Pro ile sonsuz diamond empire kurabilirsiniz!")
print("   Her 'main()' komutu yeni bir alan kazacak ve otomatik genişleyecek.")

-- ========================================
-- OTOMATIK BAŞLATMA
-- ========================================

print()
print("🔥 DIAMOND HUNTER PRO OTOMATİK BAŞLATIYOR...")
print("⚡ 3 saniye içinde mining başlayacak!")
print("💡 Durdurmak için Ctrl+T basın")
print()

-- 3 saniye bekle, kullanıcı durdurma şansı versin
for i = 3, 1, -1 do
    print("🚀 Başlatma: " .. i .. " saniye...")
    sleep(1)
end

print()
print("💎 DIAMOND MINING BAŞLIYOR!")
print("=============================")

-- Otomatik olarak main() fonksiyonunu çağır
main()
