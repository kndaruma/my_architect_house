QBCore = nil

-- ระบบ Auto-Detect ค้นหา QBCore อัตโนมัติ (ป้องกันค่า NIL จากการโหลดสคริปต์ไวเกินไป)
Citizen.CreateThread(function()
    while QBCore == nil do
        pcall(function()
            QBCore = exports['qb-core']:GetCoreObject()
        end)
        if QBCore then 
            print("^2[Housing System] เชื่อมต่อ QBCore สำเร็จ! (ด้วยระบบ Modern Export)^7") 
            break 
        end
        Citizen.Wait(1000)
    end
end)

-- ระบบตรวจสอบเงินและอนุมัติการเสกเฟอร์นิเจอร์
RegisterNetEvent('housing:server:checkMoneyAndBuy', function(modelName, price)
    local src = source
    if QBCore == nil then return end 
    
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local itemPrice = tonumber(price) or 0
    local playerCash = Player.Functions.GetMoney('cash')

    if playerCash >= itemPrice then
        Player.Functions.RemoveMoney('cash', itemPrice, "furniture-bought")
        TriggerClientEvent('housing:client:spawnFurniture', src, modelName)
    else
        -- แก้ไขชื่อ Event แจ้งเตือนให้ตรงกับมาตรฐาน QBCore
        TriggerClientEvent('QBCore:Notify', src, "คุณไม่มีเงินสดเพียงพอสำหรับไอเทมชิ้นนี้!", "error")
    end
end)

-- บันทึกข้อมูลพรอพลง Database
RegisterNetEvent('housing:server:saveFurniture', function(houseId, model, coords, rot, collision)
    local src = source
    if QBCore == nil then return end
    
    -- [Debug] แสดงLog บนจอดำ Server ว่าข้อมูลส่งมาถึงไหม
    print(string.format("^3[Save Debug] กำลังบันทึกพรอพลงบ้าน: %s | Model: %s^7", tostring(houseId), tostring(model)))

    local collisionVal = collision and 1 or 0

    MySQL.insert('INSERT INTO house_furniture (house_id, model, x, y, z, rx, ry, rz, collision) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)', {
        houseId, model, coords.x, coords.y, coords.z, rot.x, rot.y, rot.z, collisionVal
    }, function(id)
        if id then
            print("^2[Save Debug] บันทึกสำเร็จ! ID ในระบบ: " .. tostring(id) .. " | กำลังสั่งให้ Client โหลดของ...^7")
            TriggerClientEvent('QBCore:Notify', src, "บันทึกและติดตั้งเฟอร์นิเจอร์เสร็จสิ้น!", "success")
            
            -- [แก้ไขสำคัญ] แนบค่า src ไปด้วยเพื่อให้ฟังก์ชันข้างล่างรู้ว่าต้องส่งไปหาผู้เล่นคนไหน!
            TriggerEvent('housing:server:requestFurniture', houseId, src)
        else
            print("^1[Save Debug] บันทึกล้มเหลว (เกิดข้อผิดพลาดในการเขียนลง Database)^7")
        end
    end)
end)

-- ดึงข้อมูลพรอพทั้งหมดมาโหลดแสดงผลในบ้าน
RegisterNetEvent('housing:server:requestFurniture', function(houseId, targetSrc)
    -- [แก้ไขสำคัญ] รับ targetSrc มาใช้ (ถ้าไม่มีให้ใช้ source เดิม) ป้องกันค่าเป็น nil เวลา Server สั่งรันกันเอง
    local src = targetSrc or source 
    if QBCore == nil then return end

    print(string.format("^3[Load Debug] กำลังดึงข้อมูลพรอพของบ้าน %s เพื่อส่งไปที่ผู้เล่นไอดี %s^7", tostring(houseId), tostring(src)))

    MySQL.query('SELECT * FROM house_furniture WHERE house_id = ?', {houseId}, function(results)
        if results then
            print("^2[Load Debug] ดึงข้อมูลสำเร็จ! พบพรอพจำนวน: " .. tostring(#results) .. " ชิ้น^7")
            TriggerClientEvent('housing:client:loadHouseFurniture', src, results)
        else
            print("^1[Load Debug] ไม่พบข้อมูลในฐานข้อมูล^7")
        end
    end)
end)

-- =========================================================
-- ระบบลบเฟอร์นิเจอร์ + โอนเงินสดขายคืนให้ผู้เล่น
-- =========================================================
RegisterNetEvent('housing:server:deleteFurnitureById', function(id)
    if QBCore == nil or not id then return end
    print("^3[Delete] ร้องขอลบพรอพ ID: " .. tostring(id) .. " ออกจาก Database^7")
    
    -- ลบตาม ID แม่นยำ 100% ไม่มีพลาด
    MySQL.query('DELETE FROM house_furniture WHERE id = ? LIMIT 1', {id})
end)

RegisterNetEvent('housing:server:sellFurnitureRefundById', function(id, price)
    local src = source
    if QBCore == nil or not id then return end
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    
    local refundAmount = tonumber(price) or 0

    MySQL.query('DELETE FROM house_furniture WHERE id = ? LIMIT 1', {id}, function(result)
        if result and result.affectedRows > 0 then
            Player.Functions.AddMoney('cash', refundAmount, "furniture-sold")
            TriggerClientEvent('QBCore:Notify', src, string.format("ขายคืนระบบสำเร็จ! ได้รับเงินคืน $%s", tostring(refundAmount)), "success")
        end
    end)
end)