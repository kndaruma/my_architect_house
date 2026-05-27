QBCore = nil

-- ระบบค้นหา QBCore อัตโนมัติ
Citizen.CreateThread(function()
    while QBCore == nil do
        pcall(function() QBCore = exports['qb-core']:GetCoreObject() end)
        if QBCore == nil then TriggerEvent('QBCore:GetObject', function(obj) QBCore = obj end) end
        Citizen.Wait(200)
    end
end)

local currentObj = nil
local currentModelName = nil 
local isMoving = false
local hasCollision = true
local spawnedFurniture = {}

local propertyLimit = 100 
local isPropertyLocked = true 

local copiedCoords = nil
local copiedRotation = nil

local pendingDuplicateCoords = nil 
local pendingDuplicateRot = nil

-- [เพิ่มใหม่] ตัวแปรศูนย์กลางที่เก็บพิกัดและองศาแบบแม่นยำ 100% (ไม่โดนตัวเกมปัดเศษ)
local activeCoords = nil
local activeRot = nil

-- =========================================================
-- คำสั่งเปิดเมนูจัดการบ้าน /manageproperty
-- =========================================================
RegisterCommand('manageproperty', function()
    TriggerEvent('housing:client:openManageProperty')
end, false)

RegisterNetEvent('housing:client:openManageProperty', function()
    local currentCount = #spawnedFurniture
    local lockText = isPropertyLocked and "🔓 ปลดล็อคประตู" or "🔒 ล็อคประตู"
    local lockDesc = isPropertyLocked and "สถานะปัจจุบัน: ล็อค" or "สถานะปัจจุบัน: เปิดให้เข้า"

    local menu = {
        { header = "🏢 จัดการอสังหาริมทรัพย์", isMenuHeader = true },
        {
            header = "🛋️ จัดการเฟอร์นิเจอร์",
            txt = string.format("วางไปแล้ว: %d / %d ชิ้น", currentCount, propertyLimit),
            params = { type = "client", event = "housing:client:manageFurnitureList" }
        },
        {
            header = lockText,
            txt = lockDesc,
            params = { type = "client", event = "housing:client:toggleLock" }
        },
        {
            header = "🔑 จัดการกุญแจ",
            txt = "รายชื่อผู้ถือครองสิทธิ์และจัดการกุญแจ",
            params = { type = "client", event = "housing:client:manageKeys" }
        },
        {
            header = "💰 ขายอสังหาริมทรัพย์",
            txt = "ขายคืนสู่ระบบ (ไม่สามารถกู้คืนได้)",
            params = { type = "client", event = "housing:client:sellPropertyConfirm" }
        },
        { header = "❌ ปิดเมนู", params = { type = "client", event = "qb-menu:client:closeMenu" } }
    }
    exports['qb-menu']:openMenu(menu)
end)

-- หน้าย่อย: จัดการเฟอร์นิเจอร์ที่วางไปแล้ว
RegisterNetEvent('housing:client:manageFurnitureList', function()
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)

    local menu = {
        { header = string.format("🛋️ รายการเฟอร์นิเจอร์ (%d/%d)", #spawnedFurniture, propertyLimit), isMenuHeader = true },
        { header = "⬅️ ย้อนกลับ", params = { type = "client", event = "housing:client:openManageProperty" } }
    }

    if #spawnedFurniture == 0 then
        table.insert(menu, { header = "ยังไม่มีสิ่งของถูกจัดวาง", isMenuHeader = true })
    else
        local propDataList = {}

        for i, item in ipairs(spawnedFurniture) do
            if type(item) == "table" and DoesEntityExist(item.entity) then
                local objCoords = GetEntityCoords(item.entity)
                local distance = #(playerCoords - objCoords)
                local propName = "ไม่ทราบชื่อ (Unknown)"

                if Config.FurnitureList then
                    for _, cats in pairs(Config.FurnitureList) do
                        for _, furn in ipairs(cats) do
                            if GetHashKey(furn.model) == item.hash then
                                propName = furn.label
                                break
                            end
                        end
                    end
                end

                table.insert(propDataList, {
                    entity = item.entity, index = i, name = propName, 
                    distance = distance, hash = item.hash, dbId = item.id,
                    collision = item.collision
                })
            end
        end

        table.sort(propDataList, function(a, b) return a.distance < b.distance end)

        for _, data in ipairs(propDataList) do
            table.insert(menu, {
                header = string.format("📦 %s", data.name),
                txt = string.format("📍 ห่างจากคุณ: %.1f เมตร", data.distance),
                params = {
                    type = "client", event = "housing:client:furnitureAction",
                    args = { entity = data.entity, index = data.index, name = data.name, hash = data.hash, dbId = data.dbId, collision = data.collision }
                }
            })
        end
    end
    
    exports['qb-menu']:openMenu(menu)
end)

RegisterNetEvent('housing:client:furnitureAction', function(data)
    local price = 0
    local modelString = ""
    
    if Config.FurnitureList then
        for _, items in pairs(Config.FurnitureList) do
            for _, item in ipairs(items) do
                if GetHashKey(item.model) == data.hash then
                    price = item.price
                    modelString = item.model
                    break
                end
            end
        end
    end

    local menu = {
        { header = "⚙️ จัดการ: " .. data.name, isMenuHeader = true },
        { 
            header = "🎮 เมนูควบคุม (Manage Object)", 
            txt = "หยิบวัตถุชิ้นนี้ขึ้นมาปรับพิกัด / หมุนองศาใหม่อีกครั้ง",
            params = { 
                type = "client", event = "housing:client:pickupToManage", 
                args = { entity = data.entity, index = data.index, model = modelString, hash = data.hash, name = data.name, dbId = data.dbId, collision = data.collision } 
            } 
        },
        { 
            header = "❌ ลบเฟอร์นิเจอร์ชิ้นนี้", 
            txt = "ลบวัตถุนี้ออกจากห้องและฐานข้อมูล (ไม่มีการคืนเงิน)",
            params = { type = "client", event = "housing:client:deleteFurnitureItem", args = data } 
        },
        { 
            header = "💰 ขายคืนเฟอร์นิเจอร์", 
            txt = string.format("ลบสิ่งของออกจากพื้นที่และรับเงินคืน (ราคาซื้อ: $%s)", tostring(price)),
            params = { type = "client", event = "housing:client:sellFurnitureItem", args = { entity = data.entity, index = data.index, hash = data.hash, name = data.name, price = price, dbId = data.dbId } } 
        },
        { header = "⬅️ ย้อนกลับ", params = { type = "client", event = "housing:client:manageFurnitureList" } }
    }
    exports['qb-menu']:openMenu(menu)
end)

RegisterNetEvent('housing:client:deleteFurnitureItem', function(data)
    if DoesEntityExist(data.entity) then
        DeleteEntity(data.entity)
        table.remove(spawnedFurniture, data.index)
        TriggerServerEvent('housing:server:deleteFurnitureById', data.dbId)
        TriggerEvent('QBCore:Notify', "ลบ " .. data.name .. " ออกจากพื้นที่แล้ว", "success")
    end
    TriggerEvent('housing:client:manageFurnitureList')
end)

RegisterNetEvent('housing:client:pickupToManage', function(data)
    if DoesEntityExist(data.entity) then
        currentObj = data.entity
        currentModelName = data.model
        hasCollision = data.collision
        if hasCollision == nil then hasCollision = true end
        
        -- ดึงค่าจริงจากเกมมากำหนดเป็นจุดศูนย์กลางใหม่
        activeCoords = GetEntityCoords(currentObj)
        activeRot = GetEntityRotation(currentObj, 2)
        
        FreezeEntityPosition(currentObj, true) 
        SetEntityAlpha(currentObj, 200, false)
        SetEntityCollision(currentObj, hasCollision, hasCollision)
        
        table.remove(spawnedFurniture, data.index)
        TriggerServerEvent('housing:server:deleteFurnitureById', data.dbId)
        
        exports['qb-menu']:closeMenu()
        Wait(100)
        OpenFurnitureMenu()
        TriggerEvent('QBCore:Notify', "หยิบ " .. data.name .. " ขึ้นมาแก้ไขแล้ว", "primary")
    else
        TriggerEvent('QBCore:Notify', "ไม่พบวัตถุนี้ในพื้นที่แล้ว", "error")
        TriggerEvent('housing:client:manageFurnitureList')
    end
end)

RegisterNetEvent('housing:client:sellFurnitureItem', function(data)
    if DoesEntityExist(data.entity) then
        DeleteEntity(data.entity)
        table.remove(spawnedFurniture, data.index)
        TriggerServerEvent('housing:server:sellFurnitureRefundById', data.dbId, data.price)
    else
        TriggerEvent('QBCore:Notify', "ไม่พบวัตถุชิ้นนี้", "error")
    end
    TriggerEvent('housing:client:manageFurnitureList')
end)

RegisterNetEvent('housing:client:manageKeys', function()
    local menu = {
        { header = "🔑 ระบบจัดการกุญแจ", isMenuHeader = true },
        { header = "➕ มอบกุญแจให้ผู้เล่นใกล้เคียง", txt = "เพิ่มสิทธิ์ให้เข้าพื้นที่และร่วมแต่งบ้านได้", params = { type = "client", event = "housing:client:giveKey" } },
        { header = "📋 ดูรายชื่อคนที่มีกุญแจ", txt = "จัดการสิทธิ์หรือดึงกุญแจคืน", params = { type = "client", event = "housing:client:viewKeys" } },
        { header = "⬅️ ย้อนกลับ", params = { type = "client", event = "housing:client:openManageProperty" } }
    }
    exports['qb-menu']:openMenu(menu)
end)

RegisterNetEvent('housing:client:sellPropertyConfirm', function()
    local menu = {
        { header = "⚠️ คุณแน่ใจหรือไม่ว่าจะขายสถานที่นี้?", isMenuHeader = true },
        { header = "✅ ยืนยันการขาย", txt = "เฟอร์นิเจอร์และสิทธิ์ทั้งหมดจะถูกลบถาวร", params = { type = "client", event = "housing:client:sellProperty" } },
        { header = "❌ ยกเลิก", params = { type = "client", event = "housing:client:openManageProperty" } }
    }
    exports['qb-menu']:openMenu(menu)
end)

RegisterNetEvent('housing:client:toggleLock', function()
    isPropertyLocked = not isPropertyLocked
    local msg = isPropertyLocked and "ประตูล็อคแล้ว" or "ปลดล็อคประตูแล้ว"
    local msgType = isPropertyLocked and "error" or "success"
    TriggerEvent('QBCore:Notify', msg, msgType)
    TriggerEvent('housing:client:openManageProperty') 
end)

-- =========================================================
-- ระบบจัดซื้อเฟอร์นิเจอร์และเสกโมเดล
-- =========================================================

RegisterCommand(Config.CommandName, function() TriggerEvent('housing:client:openFurnitureCategory') end, false)
RegisterCommand('bf', function() TriggerEvent('housing:client:openFurnitureCategory') end, false)

RegisterNetEvent('housing:client:openFurnitureCategory', function()
    local categoryMenu = { { header = "🛋️ เมนูจัดซื้อเฟอร์นิเจอร์แต่งบ้าน", isMenuHeader = true } }

    for category, _ in pairs(Config.FurnitureList) do
        table.insert(categoryMenu, { header = category, txt = "ดูสิ่งของในหมวดหมู่นี้", params = { type = "client", event = "housing:client:openFurnitureList", args = category } })
    end
    table.insert(categoryMenu, { header = "🔄 โหลดเฟอร์นิเจอร์ในบ้านใหม่", txt = "กรณีของในบ้านไม่แสดงผล", params = { type = "client", event = "housing:client:requestLoadHome" } })
    exports['qb-menu']:openMenu(categoryMenu)
end)

RegisterNetEvent('housing:client:openFurnitureList', function(category)
    local items = Config.FurnitureList[category]
    local itemsMenu = {
        { header = "รายการสิ่งของ: " .. category, isMenuHeader = true },
        { header = "⬅️ ย้อนกลับ", params = { type = "client", event = "housing:client:openFurnitureCategory" } }
    }

    for _, data in ipairs(items) do
        table.insert(itemsMenu, { header = data.label, txt = string.format("ราคา: $%s", data.price), params = { type = "client", event = "housing:client:buyAndSpawn", args = data.model } })
    end
    exports['qb-menu']:openMenu(itemsMenu)
end)

RegisterNetEvent('housing:client:buyAndSpawn', function(modelName)
    if #spawnedFurniture >= propertyLimit then
        TriggerEvent('QBCore:Notify', "พื้นที่จัดวางเต็มแล้ว! (วางของครบขีดจำกัด " .. propertyLimit .. " ชิ้นแล้ว)", "error")
        return
    end

    pendingDuplicateCoords = nil
    pendingDuplicateRot = nil

    if type(modelName) == "table" then modelName = modelName.model or modelName[1] end
    
    local price = 0
    if Config.FurnitureList then
        for _, items in pairs(Config.FurnitureList) do
            for _, item in ipairs(items) do
                if item.model == modelName then
                    price = item.price
                    break
                end
            end
        end
    end
    TriggerServerEvent('housing:server:checkMoneyAndBuy', modelName, price)
end)

RegisterNetEvent('housing:client:spawnFurniture', function(modelName)
    local playerPed = PlayerPedId()
    local modelHash = GetHashKey(modelName)

    RequestModel(modelHash)
    local timeout = 0
    while not HasModelLoaded(modelHash) do 
        Wait(10) 
        timeout = timeout + 1
        if timeout > 300 then 
            TriggerEvent('QBCore:Notify', "ดาวน์โหลดโมเดลล้มเหลว หรือโมเดลเสีย", "error")
            return
        end
    end

    if pendingDuplicateCoords and pendingDuplicateRot then
        activeCoords = pendingDuplicateCoords
        activeRot = pendingDuplicateRot
        pendingDuplicateCoords = nil
        pendingDuplicateRot = nil
    else
        local coords = GetEntityCoords(playerPed)
        local heading = GetEntityHeading(playerPed)
        local forward = GetEntityForwardVector(playerPed)
        activeCoords = coords + (forward * 1.5)
        activeRot = vector3(0.0, 0.0, heading)
    end

    hasCollision = true 

    currentObj = CreateObject(modelHash, activeCoords.x, activeCoords.y, activeCoords.z, true, true, false)
    currentModelName = modelName 
    
    SetEntityCoordsNoOffset(currentObj, activeCoords.x, activeCoords.y, activeCoords.z, false, false, false)
    FreezeEntityPosition(currentObj, true) 
    SetEntityRotation(currentObj, activeRot.x, activeRot.y, activeRot.z, 2, true)
    
    SetEntityAlpha(currentObj, 200, false)
    SetEntityCollision(currentObj, hasCollision, hasCollision)
    
    OpenFurnitureMenu()
end)

function OpenFurnitureMenu()
    if not currentObj then return end
    
    local colText = hasCollision and "✅ ON (ชนได้)" or "❌ OFF (เดินทะลุ)" 
    local objName = currentModelName and tostring(currentModelName) or "Object"

    local furnitureMenu = {
        { header = "Manage " .. objName, isMenuHeader = true },
        { header = "1 - Move " .. objName, params = { type = "client", event = "housing:client:controlMode" } },
        { header = "2 - Duplicate " .. objName, params = { type = "client", event = "housing:client:duplicateObject" } },
        { header = "3 - Copy Position " .. objName, params = { type = "client", event = "housing:client:copyData", args = "position" } },
        { header = "4 - Paste Position " .. objName, params = { type = "client", event = "housing:client:pasteData", args = "position" } },
        { header = "5 - Copy Rotation " .. objName, params = { type = "client", event = "housing:client:copyData", args = "rotation" } },
        { header = "6 - Paste Rotation " .. objName, params = { type = "client", event = "housing:client:pasteData", args = "rotation" } },
        -- เมนูเดิมที่แยกออกไปเป็น Sub-menu
        { header = "7 - Flatten Rotation " .. objName, params = { type = "client", event = "housing:client:openFlattenMenu" } },
        { header = "8 - Sharp Rotation " .. objName, params = { type = "client", event = "housing:client:openSharpMenu" } },
        { header = "9 - Collision: " .. colText .. " " .. objName, params = { type = "client", event = "housing:client:toggleCollision" } },
        { header = "💾 ยืนยันการบันทึกข้อมูล " .. objName, params = { type = "client", event = "housing:client:saveFurniture" } },
        { header = "❌ ยกเลิกและลบทิ้ง " .. objName, params = { type = "client", event = "housing:client:cancelFurniture" } }
    }
    exports['qb-menu']:openMenu(furnitureMenu)
end

-- เมนูย่อย Flatten
RegisterNetEvent('housing:client:openFlattenMenu', function()
    local objName = currentModelName or "Object"
    local menu = {
        { header = "Flatten Options: " .. objName, isMenuHeader = true },
        { header = "1 - Flatten X Rotation", params = { type = "client", event = "housing:client:rotate", args = "flatten_x" } },
        { header = "2 - Flatten Y Rotation", params = { type = "client", event = "housing:client:rotate", args = "flatten_y" } },
        { header = "3 - Flatten Z Rotation", params = { type = "client", event = "housing:client:rotate", args = "flatten_z" } },
        { header = "4 - Back", params = { type = "client", event = "housing:client:openMainFurnitureMenu" } }
    }
    exports['qb-menu']:openMenu(menu)
end)

-- เมนูย่อย Sharp
RegisterNetEvent('housing:client:openSharpMenu', function()
    local objName = currentModelName or "Object"
    local menu = {
        { header = "Sharp Options: " .. objName, isMenuHeader = true },
        { header = "1 - Sharp X Rotation", params = { type = "client", event = "housing:client:rotate", args = "sharp_x" } },
        { header = "2 - Sharp Y Rotation", params = { type = "client", event = "housing:client:rotate", args = "sharp_y" } },
        { header = "3 - Sharp Z Rotation", params = { type = "client", event = "housing:client:rotate", args = "sharp_z" } },
        { header = "4 - Back", params = { type = "client", event = "housing:client:openMainFurnitureMenu" } }
    }
    exports['qb-menu']:openMenu(menu)
end)

-- Event ช่วยเรียกกลับหน้าเมนูหลัก
RegisterNetEvent('housing:client:openMainFurnitureMenu', function()
    OpenFurnitureMenu()
end)

-- =========================================================
-- ระบบประมวลผล Copy / Paste / Duplicate คีย์บอร์ดและเมาส์
-- =========================================================

RegisterNetEvent('housing:client:copyData', function(dataType)
    if not currentObj then return end
    if dataType == "position" then
        copiedCoords = activeCoords
        TriggerEvent('QBCore:Notify', "คัดลอกพิกัดตำแหน่งสำเร็จ!", "success")
    elseif dataType == "rotation" then
        copiedRotation = activeRot
        TriggerEvent('QBCore:Notify', "คัดลอกองศาหมุนสำเร็จ!", "success")
    end
    OpenFurnitureMenu()
end)

RegisterNetEvent('housing:client:pasteData', function(dataType)
    if not currentObj then return end
    if dataType == "position" and copiedCoords then
        activeCoords = vector3(copiedCoords.x, copiedCoords.y, copiedCoords.z)
        SetEntityCoordsNoOffset(currentObj, activeCoords.x, activeCoords.y, activeCoords.z, false, false, false)
        TriggerEvent('QBCore:Notify', "วางพิกัดตำแหน่งเรียบร้อย!", "success")
    elseif dataType == "rotation" and copiedRotation then
        activeRot = vector3(copiedRotation.x, copiedRotation.y, copiedRotation.z)
        SetEntityRotation(currentObj, activeRot.x, activeRot.y, activeRot.z, 2, true)
        TriggerEvent('QBCore:Notify', "วางองศาการหมุนเรียบร้อย!", "success")
    else
        TriggerEvent('QBCore:Notify', "ยังไม่มีการคัดลอกข้อมูลชิ้นงานนี้!", "error")
    end
    OpenFurnitureMenu()
end)

RegisterNetEvent('housing:client:duplicateObject', function()
    if not currentObj or not currentModelName then return end

    if #spawnedFurniture >= propertyLimit then
        TriggerEvent('QBCore:Notify', "ไม่สามารถ Duplicate ได้ ของแต่งเต็มขีดจำกัดแล้ว!", "error")
        return
    end

    local price = 0
    if Config.FurnitureList then
        for _, items in pairs(Config.FurnitureList) do
            for _, item in ipairs(items) do
                if item.model == currentModelName then
                    price = item.price
                    break
                end
            end
        end
    end

    pendingDuplicateCoords = activeCoords
    pendingDuplicateRot = activeRot

    TriggerEvent('housing:client:saveFurniture')

    Citizen.SetTimeout(500, function()
        TriggerServerEvent('housing:server:checkMoneyAndBuy', currentModelName, price)
    end)
end)

RegisterNetEvent('housing:client:controlMode', function()
    if not currentObj or not activeCoords or not activeRot then return end
    isMoving = true
    exports['qb-menu']:closeMenu()
    
    local playerPed = PlayerPedId()
    FreezeEntityPosition(playerPed, true)
    SetEntityAlpha(currentObj, 255, false)
    ResetEntityAlpha(currentObj)

    SendNUIMessage({ action = "open" })

    CreateThread(function()
        local editMode = "Position"
        local speeds = {0.0001, 0.0005, 0.001, 0.005, 0.01, 0.05, 0.1, 0.25, 0.5, 1.0, 2.5}
        local speedIndex = 7 
        local isFrozen = false
        local lastUpdateStr = ""

        while isMoving do
            Wait(0)
            DisableControlAction(0, 24, true)  
            DisableControlAction(0, 25, true)  
            DisableControlAction(0, 140, true) 
            DisableControlAction(0, 141, true) 
            DisableControlAction(0, 142, true) 
            DisableControlAction(0, 257, true) 
            DisableControlAction(0, 45, true)  
            DisableControlAction(0, 23, true)  
            DisableControlAction(0, 83, true) 
            DisableControlAction(0, 118, true) 

            if isFrozen then
                for i = 30, 35 do EnableControlAction(0, i, true) end
            else
                for i = 30, 35 do DisableControlAction(0, i, true) end
            end
            
            local currentSpeed = speeds[speedIndex]

            local currentUpdateStr = string.format("%.4f%.4f%.4f%.4f%.4f%.4f%s%s%s", activeCoords.x, activeCoords.y, activeCoords.z, activeRot.x, activeRot.y, activeRot.z, editMode, tostring(currentSpeed), tostring(isFrozen))
            if currentUpdateStr ~= lastUpdateStr then
                SendNUIMessage({
                    action = "update", mode = editMode, speed = currentSpeed,
                    x = activeCoords.x, y = activeCoords.y, z = activeCoords.z, rx = activeRot.x, ry = activeRot.y, rz = activeRot.z, freeze = isFrozen
                })
                lastUpdateStr = currentUpdateStr
            end

            if not isFrozen then
                if editMode == "Position" then
                    -- คำนวณทิศทางจากองศาที่แม่นยำ 100% ภายใน Lua เท่านั้น (เลิกพึ่งพาตัวเกม)
                    local pitch = math.rad(activeRot.x)
                    local yaw = math.rad(activeRot.z)
                    local num3 = math.abs(math.cos(pitch))
                    
                    local fVec = vector3(-math.sin(yaw) * num3, math.cos(yaw) * num3, math.sin(pitch))
                    local rVec = vector3(math.cos(yaw), math.sin(yaw), 0.0)

                    if IsControlPressed(0, 172) then activeCoords = activeCoords + (fVec * currentSpeed) end
                    if IsControlPressed(0, 173) then activeCoords = activeCoords - (fVec * currentSpeed) end
                    if IsControlPressed(0, 174) then activeCoords = activeCoords - (rVec * currentSpeed) end
                    if IsControlPressed(0, 175) then activeCoords = activeCoords + (rVec * currentSpeed) end
                    if IsDisabledControlPressed(0, 32) then activeCoords = vector3(activeCoords.x, activeCoords.y, activeCoords.z + currentSpeed) end
                    if IsDisabledControlPressed(0, 33) then activeCoords = vector3(activeCoords.x, activeCoords.y, activeCoords.z - currentSpeed) end
                
                elseif editMode == "Rotation" then
                    if IsControlPressed(0, 174) then activeRot = vector3(activeRot.x, activeRot.y, activeRot.z + (currentSpeed * 15.0)) end
                    if IsControlPressed(0, 175) then activeRot = vector3(activeRot.x, activeRot.y, activeRot.z - (currentSpeed * 15.0)) end
                    if IsControlPressed(0, 172) then activeRot = vector3(activeRot.x, activeRot.y + (currentSpeed * 15.0), activeRot.z) end
                    if IsControlPressed(0, 173) then activeRot = vector3(activeRot.x, activeRot.y - (currentSpeed * 15.0), activeRot.z) end
                    if IsDisabledControlPressed(0, 32) then activeRot = vector3(activeRot.x + (currentSpeed * 15.0), activeRot.y, activeRot.z) end
                    if IsDisabledControlPressed(0, 33) then activeRot = vector3(activeRot.x - (currentSpeed * 15.0), activeRot.y, activeRot.z) end
                end
            end

            -- บังคับนำคณิตศาสตร์ที่แม่นยำไปใช้กับตัวเกม
            SetEntityCoordsNoOffset(currentObj, activeCoords.x, activeCoords.y, activeCoords.z, false, false, false)
            SetEntityRotation(currentObj, activeRot.x, activeRot.y, activeRot.z, 2, true)

            if IsDisabledControlJustPressed(0, 45) then editMode = (editMode == "Position") and "Rotation" or "Position" end
            if IsDisabledControlJustPressed(0, 83) then
                speedIndex = (speedIndex == #speeds) and 1 or #speeds
                TriggerEvent('QBCore:Notify', "สลับความเร็ว: " .. tostring(speeds[speedIndex]), "primary")
            end
            
            if IsDisabledControlJustPressed(0, 118) then 
                hasCollision = not hasCollision
                SetEntityCollision(currentObj, hasCollision, hasCollision)
                TriggerEvent('QBCore:Notify', hasCollision and "Collision: ON (เปิดการชน)" or "Collision: OFF (เดินทะลุได้)", hasCollision and "success" or "error")
            end

            if IsDisabledControlJustPressed(0, 23) then
                isFrozen = not isFrozen
                FreezeEntityPosition(playerPed, not isFrozen)
                TriggerEvent('QBCore:Notify', isFrozen and "เดินเล็งระยะได้อิสระ" or "เปิดโหมดควบคุม (ล็อคขา)", isFrozen and "primary" or "success")
            end

            if IsControlJustPressed(0, 10) or IsControlJustPressed(0, 213) then if speedIndex < #speeds then speedIndex = speedIndex + 1 end end
            if IsControlJustPressed(0, 11) or IsControlJustPressed(0, 212) then if speedIndex > 1 then speedIndex = speedIndex - 1 end end

            if IsControlJustPressed(0, 191) then 
                isMoving = false
                FreezeEntityPosition(playerPed, false)
                SendNUIMessage({ action = "close" })
                OpenFurnitureMenu()
            end
            if IsControlJustPressed(0, 178) then 
                isMoving = false
                FreezeEntityPosition(playerPed, false)
                SendNUIMessage({ action = "close" })
                DeleteEntity(currentObj)
                currentObj = nil
                hasCollision = true
                activeCoords = nil
                activeRot = nil
                TriggerEvent('QBCore:Notify', "ยกเลิกการจัดวาง", "error")
            end
        end
    end)
end)

local function UpdateNuiCoords()
    if not currentObj or not activeCoords or not activeRot then return end
    SendNUIMessage({ action = "update", coords = { x = activeCoords.x, y = activeCoords.y, z = activeCoords.z, rz = activeRot.z } })
end

RegisterNUICallback('move', function(data, cb)
    if not currentObj or not activeCoords then return cb('ok') end
    local moveSpeed = tonumber(data.multiplier) or 0.1
    local dir = tonumber(data.dir) or 1
    local amount = moveSpeed * dir

    if data.axis == 'x' then activeCoords = vector3(activeCoords.x + amount, activeCoords.y, activeCoords.z)
    elseif data.axis == 'y' then activeCoords = vector3(activeCoords.x, activeCoords.y + amount, activeCoords.z)
    elseif data.axis == 'z' then activeCoords = vector3(activeCoords.x, activeCoords.y, activeCoords.z + amount) end
    
    SetEntityCoordsNoOffset(currentObj, activeCoords.x, activeCoords.y, activeCoords.z, false, false, false)
    UpdateNuiCoords()
    cb('ok')
end)

RegisterNUICallback('rotate', function(data, cb)
    if not currentObj or not activeRot then return cb('ok') end
    local moveSpeed = tonumber(data.multiplier) or 0.1
    local dir = tonumber(data.dir) or 1
    local newZ = activeRot.z + ((moveSpeed * 50) * dir) 
    
    activeRot = vector3(activeRot.x, activeRot.y, newZ)
    SetEntityRotation(currentObj, activeRot.x, activeRot.y, activeRot.z, 2, true)
    UpdateNuiCoords()
    cb('ok')
end)

RegisterNUICallback('resetRot', function(data, cb)
    if not currentObj or not activeRot then return cb('ok') end
    activeRot = vector3(0.0, 0.0, 0.0)
    SetEntityRotation(currentObj, 0.0, 0.0, 0.0, 2, true)
    UpdateNuiCoords()
    cb('ok')
end)

RegisterNUICallback('confirm', function(data, cb)
    SetNuiFocus(false, false)
    SendNUIMessage({ action = "close" })
    isMoving = false
    TriggerEvent('housing:client:saveFurniture')
    cb('ok')
end)

RegisterNUICallback('cancel', function(data, cb)
    SetNuiFocus(false, false)
    SendNUIMessage({ action = "close" })
    isMoving = false
    TriggerEvent('housing:client:cancelFurniture')
    TriggerEvent('QBCore:Notify', "ยกเลิกและลบวัตถุออกแล้ว", "error")
    cb('ok')
end)

RegisterNetEvent('housing:client:rotate', function(type)
    if not currentObj or not activeRot then return end
    
    if type == "sharp_x" then
        activeRot = vector3((activeRot.x + 90.0) % 360.0, activeRot.y, activeRot.z)
        OpenFurnitureMenu() -- หลังจากหมุนเสร็จ กลับไปหน้าเมนูหลัก
    elseif type == "sharp_y" then
        activeRot = vector3(activeRot.x, (activeRot.y + 90.0) % 360.0, activeRot.z)
        OpenFurnitureMenu()
    elseif type == "sharp_z" then
        activeRot = vector3(activeRot.x, activeRot.y, (activeRot.z + 90.0) % 360.0)
        OpenFurnitureMenu()
    elseif type == "flatten_x" then
        activeRot = vector3(0.0, activeRot.y, activeRot.z)
        OpenFurnitureMenu()
    elseif type == "flatten_y" then
        activeRot = vector3(activeRot.x, 0.0, activeRot.z)
        OpenFurnitureMenu()
    elseif type == "flatten_z" then
        activeRot = vector3(activeRot.x, activeRot.y, 0.0)
        OpenFurnitureMenu()
    end
    
    SetEntityRotation(currentObj, activeRot.x, activeRot.y, activeRot.z, 2, true)
end)

RegisterNetEvent('housing:client:toggleCollision', function()
    if not currentObj then return end
    hasCollision = not hasCollision
    SetEntityCollision(currentObj, hasCollision, hasCollision)
    TriggerEvent('QBCore:Notify', hasCollision and "Collision: ON (เปิดการชน)" or "Collision: OFF (เดินทะลุได้)", hasCollision and "success" or "error")
    OpenFurnitureMenu()
end)

RegisterNetEvent('housing:client:cancelFurniture', function()
    if currentObj then
        DeleteEntity(currentObj)
        currentObj = nil
        currentModelName = nil
        hasCollision = true
        activeCoords = nil
        activeRot = nil
    end
end)

RegisterNetEvent('housing:client:saveFurniture', function()
    if not currentObj or not activeCoords or not activeRot then return end
    local model = GetEntityModel(currentObj)

    TriggerServerEvent('housing:server:saveFurniture', Config.DefaultHouseId, model, activeCoords, activeRot, hasCollision)
    
    DeleteEntity(currentObj)
    currentObj = nil
    hasCollision = true
    activeCoords = nil
    activeRot = nil
end)

RegisterNetEvent('housing:client:requestLoadHome', function()
    TriggerServerEvent('housing:server:requestFurniture', Config.DefaultHouseId)
end)

RegisterNetEvent('housing:client:loadHouseFurniture', function(furnitureData)
    for _, item in ipairs(spawnedFurniture) do
        local entity = type(item) == "table" and item.entity or item
        if DoesEntityExist(entity) then DeleteEntity(entity) end
    end
    spawnedFurniture = {}

    for _, data in ipairs(furnitureData) do
        local modelHash = tonumber(data.model) or GetHashKey(data.model)
        RequestModel(modelHash)
        while not HasModelLoaded(modelHash) do Wait(10) end

        local obj = CreateObject(modelHash, data.x, data.y, data.z, false, false, false)
        
        SetEntityCoordsNoOffset(obj, data.x, data.y, data.z, false, false, false)
        SetEntityRotation(obj, data.rx, data.ry, data.rz, 2, true)
        FreezeEntityPosition(obj, true)
        
        local col = true
        if data.collision == 0 or data.collision == false or data.collision == "0" then col = false end
        SetEntityCollision(obj, col, col)

        table.insert(spawnedFurniture, {
            entity = obj,
            id = data.id,
            hash = modelHash,
            collision = col
        })
    end
end)