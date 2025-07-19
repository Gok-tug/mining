-- ========================================
-- DIAMOND MINING TURTLE v2.1 - REFINED
-- Efficient Diamond Strip Mining
-- by Gemini AI & Expert User
-- ========================================
--
-- KURULUM:
-- 1. Turtle'ı Y=12 seviyesine yerleştirin.
-- 2. Eşya depolaması için sandığı turtle'ın BİR BLOK ALTINA yerleştirin (Y=11).
-- 3. Envanter:
--    Slot 1: Meşale (64'lük bir stack önerilir)
--    Slot 15: Yakıt (kömür/odun)
--    Slot 16: Yedek sandık
-- 4. Çalıştır: lua mining.lua
--
-- ÖZELLİKLER:
-- ✅ Y=11 Elmas seviyesinde güvenli madencilik.
-- ✅ 3x1 Tüneller (Y=11,12,13) ile maksimum verim.
-- ✅ Akıllı meşale yerleşimi.
-- ✅ Akıllı envanter yönetimi ve eve dönüş.
-- ✅ Yakıt güvenliği ve otomatik doldurma.
-- ========================================

local CONFIG = {
    TORCH_INTERVAL = 12,      -- Her 12 blokta bir meşale
    TUNNEL_LENGTH = 64,       -- Ana tünel uzunluğu
    BRANCH_LENGTH = 32,       -- Yan tünel uzunluğu
    BRANCH_SPACING = 3,       -- Yan tüneller arası 3 blok boşluk (elmas için ideal)
    FUEL_MIN = 500,           -- Minimum yakıt seviyesi kontrolü
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

-- YARDIMCI FONKSİYONLAR
function log(msg)
    print("[" .. os.date("%H:%M:%S") .. "] " .. msg)
end

function checkFuel()
    local fuel = turtle.getFuelLevel()
    if fuel < CONFIG.FUEL_MIN then
        log("⛽ Düşük yakıt: " .. fuel .. ", yakıt dolduruluyor...")
        return autoRefuel()
    end
    return true
end

function autoRefuel()
    if turtle.getItemCount(CONFIG.FUEL_SLOT) > 0 then
        turtle.select(CONFIG.FUEL_SLOT)
        turtle.refuel()
        log("✅ Yakıt dolduruldu. Yeni seviye: " .. turtle.getFuelLevel())
        return true
    end
    
    -- Bulunan kömürleri kullan
    for slot = 2, 14 do
        turtle.select(slot)
        local success, data = turtle.getItemDetail()
        if success and data.name and string.find(data.name, "coal") then
            turtle.refuel(math.min(data.count, 5))
            log("✅ Bulunan kömürler kullanıldı. Yeni seviye: " .. turtle.getFuelLevel())
            return true
        end
    end
    log("❌ Yakıt kaynağı bulunamadı!")
    return false
end

function selectItem(slot)
    return turtle.getItemCount(slot) > 0 and turtle.select(slot)
end

-- HAREKET FONKSİYONLARI
function updatePos(dx, dy, dz)
    pos.x, pos.y, pos.z = pos.x + dx, pos.y + dy, pos.z + dz
end

function setHome()
    home_pos = {x = pos.x, y = pos.y, z = pos.z}
    log("🏠 Ev ayarlandı: " .. pos.x .. "," .. pos.y .. "," .. pos.z)
end

---[[ DÜZELTME 1: digAndMove fonksiyonu yeniden düzenlendi. ]] ---
-- Artık önce önünü ve üstünü kazıyor, ileri gidiyor, SONRA altını kazıyor.
-- Bu, turtle'ın her zaman sağlam bir zeminde durmasını sağlar ve meşale koymayı mümkün kılar.
function digAndMove()
    -- Önce önü (Y=12) ve üstü (Y=13) kaz
    while turtle.detect() do turtle.dig() end
    while turtle.detectUp() do turtle.digUp() end

    -- Elmas kontrolü (Y=12)
    local success, data = turtle.inspect()
    if success and data.name and string.find(data.name, "diamond") then
        diamonds_found = diamonds_found + 1
        log("💎 ELMAS BULUNDU (Y=12)! Toplam: " .. diamonds_found)
    end
    
    -- İleri git
    while not turtle.forward() do
        log("⚠️ İleri hareket engellendi, tekrar kazılıyor...")
        turtle.dig()
        turtle.attack() -- Mob varsa saldır
        sleep(0.5)
    end
    
    -- Pozisyonu güncelle
    if direction == NORTH then updatePos(0, 0, -1)
    elseif direction == EAST then updatePos(1, 0, 0)
    elseif direction == SOUTH then updatePos(0, 0, 1)
    elseif direction == WEST then updatePos(-1, 0, 0) end
    
    -- ŞİMDİ altını (Y=11) güvenle kaz
    if turtle.detectDown() then
        local success, data = turtle.inspectDown()
        if success and data.name then
            if string.find(data.name, "lava") then
                log("🚨 LAVA TESPİT EDİLDİ (Y=10)! Alt blok kazılmıyor.")
            else
                if string.find(data.name, "diamond") then
                    diamonds_found = diamonds_found + 1
                    log("💎 ELMAS BULUNDU (Y=11)! Toplam: " .. diamonds_found)
                end
                turtle.digDown()
            end
        else
            turtle.digDown() -- Bilinmeyen bloğu kaz
        end
    end
end

function turnLeft()
    turtle.turnLeft()
    direction = (direction - 1 + 4) % 4
end

function turnRight()
    turtle.turnRight()
    direction = (direction + 1) % 4
end

function turnAround()
    turtle.turnRight()
    turtle.turnRight()
end

-- MEŞALE SİSTEMİ
---[[ DÜZELTME 2: Meşale yerleştirme mantığı basitleştirildi. ]] ---
-- digAndMove sonrası çağrıldığında, turtle'ın altı artık kazılmış ve boştur.
-- placeDown komutu, turtle'ın altındaki bloğun üzerine meşale koyar (yani Y=10'daki bloğun üzerine, Y=11'e).
function placeTorch()
    if selectItem(CONFIG.TORCH_SLOT) then
        if turtle.placeDown() then
            log("🔥 Meşale yerleştirildi.")
        else
            log("⚠️ Meşale yerleştirilemedi.")
        end
    end
end

-- ENVANTER YÖNETİMİ
function isInventoryFull()
    for slot = 2, 14 do -- Slot 1 (meşale) ve 15-16'yı (yakıt/sandık) hariç tut
        if turtle.getItemCount(slot) == 0 then return false end
    end
    log("📦 Envanter doldu.")
    return true
end

---[[ DÜZELTME 3: Geri dönüşlerde sadece ileri hareket et. ]] ---
-- Geri dönüşlerde kazma işlemi yapmaya gerek yok, çünkü tünel zaten açık.
-- Bu, meşalelerin kırılmasını önler ve yakıttan tasarruf sağlar.
function moveForward(steps)
    for i = 1, steps do
        if not checkFuel() then
            log("❌ Eve dönerken yakıt bitti!")
            return false -- Görevi sonlandır
        end
        while not turtle.forward() do
            log("...Geri dönüşte yol tıkalı, temizleniyor...")
            turtle.dig() -- Nadir durumlar için (örneğin gravel düşmesi)
        end
        -- Eve dönerken pozisyonu güncellemeye gerek yok, bu daha hızlı.
    end
    return true
end

function returnHome()
    log("🏠 Eve dönülüyor...")
    
    -- Önce başlangıç yönüne (NORTH) dön
    faceDirection(NORTH)
    
    -- Geri dön (Z ekseni)
    local z_dist = home_pos.z - pos.z
    if z_dist > 0 then
        faceDirection(SOUTH)
        moveForward(z_dist)
        pos.z = home_pos.z
    end
    
    -- Ana tünelin başlangıcına dön (X ekseni)
    local x_dist = home_pos.x - pos.x
    if x_dist > 0 then
        faceDirection(EAST)
        moveForward(x_dist)
        pos.x = home_pos.x
    elseif x_dist < 0 then
        faceDirection(WEST)
        moveForward(-x_dist)
        pos.x = home_pos.x
    end
    
    faceDirection(NORTH) -- Son olarak kuzeye bak
    log("✅ Eve varıldı.")
end

function faceDirection(target)
    while direction ~= target do
        turnLeft()
    end
end

function depositItems()
    log("📦 Eşyalar sandığa bırakılıyor...")
    if not turtle.detectDown() then
        log("⚠️ Altında sandık yok! Yedek sandık yerleştiriliyor...")
        if selectItem(CONFIG.CHEST_SLOT) then
            turtle.placeDown()
        else
            log("❌ Yedek sandık yok! Eşyalar bırakılamadı.")
            return false
        end
    end
    
    for slot = 2, 14 do
        if turtle.getItemCount(slot) > 0 then
            turtle.select(slot)
            turtle.dropDown()
        end
    end
    log("✅ Eşyalar bırakıldı.")
    return true
end

-- MADEN FONKSİYONLARI
function mineStrip(length)
    for step = 1, length do
        if isInventoryFull() then
            local current_pos = {x = pos.x, y = pos.y, z = pos.z}
            local current_dir = direction
            returnHome()
            if depositItems() then
                log("🔄 Maden pozisyonuna geri dönülüyor...")
                -- Kaydedilen pozisyona geri git (sadece ileri giderek)
                faceDirection(current_dir) -- Kaldığı yöne bak
                local dist_to_travel = math.abs(current_pos.z - pos.z) + math.abs(current_pos.x - pos.x)
                moveForward(dist_to_travel)
                pos = current_pos -- Pozisyonu manuel olarak güncelle
                log("✅ Madenciliğe devam ediliyor.")
            else
                log("❌ Eşyalar bırakılamadı, görev iptal ediliyor.")
                return false
            end
        end
        
        if not checkFuel() then
            log("❌ Yakıt bitti, görev iptal ediliyor.")
            return false
        end
        
        digAndMove()
        
        if step % CONFIG.TORCH_INTERVAL == 0 then
            placeTorch()
        end
        
        if step % 16 == 0 then
            log("⛏️ " .. length .. " blokluk tünelin " .. step .. ". bloğu kazıldı.")
        end
    end
    return true
end

function stripMining()
    log("🚀 Elmas Madenciliği Başlatılıyor (Y=11)")
    
    ---[[ DÜZELTME 4: Sandığı korumak için ilk hareketi yap. ]] ---
    -- Madenciliğe başlamadan önce bir blok ileri giderek sandığın olduğu alanı güvene al.
    log("🛡️ Başlangıç sandığı korunuyor, bir blok ileri gidiliyor...")
    digAndMove()
    setHome() -- Evi, başlangıç noktasının BİR BLOK ilerisi olarak ayarla.

    -- Yan tünelleri kaz
    local numBranches = math.floor(CONFIG.TUNNEL_LENGTH / CONFIG.BRANCH_SPACING)
    for b = 1, numBranches do
        log("🌿 Dal #" .. b .. " için hazırlanılıyor.")
        
        -- Bir sonraki dal noktasına git
        if not mineStrip(CONFIG.BRANCH_SPACING) then return end
        
        -- SOL dal
        turnLeft()
        log("   Mining left branch...")
        if not mineStrip(CONFIG.BRANCH_LENGTH) then return end
        turnAround()
        moveForward(CONFIG.BRANCH_LENGTH) -- Geri dönerken sadece ileri git
        turnLeft() -- Ana tünele dön

        -- SAĞ dal
        turnRight()
        log("   Mining right branch...")
        if not mineStrip(CONFIG.BRANCH_LENGTH) then return end
        turnAround()
        moveForward(CONFIG.BRANCH_LENGTH) -- Geri dönerken sadece ileri git
        turnRight() -- Ana tünele dön
        
        log("✅ Dal " .. b .. "/" .. numBranches .. " tamamlandı.")
    end

    log("🎉 Madencilik tamamlandı! Bulunan elmas: " .. diamonds_found)
end

-- ANA FONKSİYON
function main()
    log("💎 DIAMOND MINING TURTLE v2.1")
    log("==============================")
    
    -- Başlangıç kontrolleri
    if not selectItem(CONFIG.TORCH_SLOT) then log("❌ Slot 1'de meşale yok!"); return end
    if turtle.getItemCount(CONFIG.CHEST_SLOT) == 0 then log("❌ Slot 16'da yedek sandık yok!"); return end
    if not checkFuel() then log("❌ Yakıt yok veya doldurulamadı!"); return end
    
    log("✅ Kurulum tamamlandı.")
    log("🎯 Hedef: Y=11 Elmas Seviyesi")
    
    stripMining()
    
    -- Son dönüş ve eşyaları bırakma
    log("🏠 Son kez eve dönülüyor ve eşyalar bırakılıyor...")
    returnHome()
    depositItems()
    
    log("🏆 Görev başarıyla tamamlandı!")
    log("💎 Toplam bulunan elmas: " .. diamonds_found)
end

-- SCRİPTİ BAŞLAT
main()
