Config = Config or {}

Config.CommandName = "buyfurniture" -- คำสั่งพิมพ์ในแชทเพื่อเปิดร้านค้า (เช่น /แต่งบ้าน)
Config.CommandName = "bf" -- คำสั่งพิมพ์ในแชทเพื่อเปิดร้านค้า (เช่น /แต่งบ้าน)
Config.DefaultHouseId = "house_test_1" -- ID บ้านจำลอง (สามารถปรับเชื่อมกับระบบบ้านหลักของคุณได้ในอนาคต)

Config.FurnitureList = {
    ["Glass"] = { -- แยกเป็นหมวดหมู่ตามใจชอบ
        { label = "Club Glass", model = "ba_prop_club_glass_opaque", price = 1 }, -- สมมุติโมเดลทดแทน
        { label = "cs2_01_frameparent0001", model = "cs2_01_frameparent0001", price = 1 },
        { label = "hei_prop_yah_glass_05", model = "hei_prop_yah_glass_05", price = 1 },
    },
    ["Wall"] = {
        { label = "Wall01", model = "wall01", price = 1 },
        { label = "Wall02", model = "wall02", price = 1 },
        { label = "Wall03", model = "wall03", price = 1 },
        { label = "Wall04", model = "wall04", price = 1 },
        { label = "Wall05", model = "wall05", price = 1 },
        { label = "Wall06", model = "wall06", price = 1 },
        { label = "Wall07", model = "wall07", price = 1 },
        { label = "Wall08", model = "wall08", price = 1 },
        { label = "Wall09", model = "wall09", price = 1 },
        { label = "Wall10", model = "wall10", price = 1 },
        { label = "Wall11", model = "wall11", price = 1 },
        { label = "Wall12", model = "wall12", price = 1 },
        { label = "Wall13", model = "wall13", price = 1 },
    },
    ["Floor"] = {
        { label = "Floor01", model = "floor01", price = 1 },
        { label = "Floor02", model = "floor02", price = 1 },
        { label = "Floor03", model = "floor03", price = 1 },
        { label = "Floor04", model = "floor04", price = 1 },
        { label = "Floor05", model = "floor05", price = 1 },
        { label = "Floor06", model = "floor06", price = 1 },
        { label = "Floor07", model = "floor07", price = 1 },
        { label = "Floor08", model = "floor08", price = 1 },
        { label = "Floor09", model = "floor09", price = 1 },
        { label = "Floor10", model = "floor10", price = 1 },
        { label = "Floor11", model = "floor11", price = 1 },
    },
    ["Sofa"] = {
        { label = "sf_mp_h_yacht_sofa_02", model = "sf_mp_h_yacht_sofa_02", price = 1 },
    },
}