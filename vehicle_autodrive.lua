-- Vehicle Autodrive
-- Created By Jackz
local SCRIPT = "vehicle_autodrive"
local VERSION = "1.0.2"
local CHANGELOG_PATH = filesystem.stand_dir() .. "/Cache/changelog_" .. SCRIPT .. ".txt"
-- Check for updates & auto-update: 
-- Remove these lines if you want to disable update-checks & auto-updates: (7-54)
util.async_http_get("jackz.me", "/stand/updatecheck.php?ucv=2&script=" .. SCRIPT .. "&v=" .. VERSION, function(result)
    chunks = {}
    for substring in string.gmatch(result, "%S+") do
        table.insert(chunks, substring)
    end
    if chunks[1] == "OUTDATED" then
        -- Remove this block (lines 15-31) to disable auto updates
        util.async_http_get("jackz.me", "/stand/changelog.php?raw=1&script=" .. SCRIPT .. "&since=" .. VERSION, function(result)
            local file = io.open(CHANGELOG_PATH, "w")
            io.output(file)
            io.write(result:gsub("\r", "") .. "\n") -- have to strip out \r for some reason, or it makes two lines. ty windows
            io.close(file)
        end)
        util.async_http_get("jackz.me", "/stand/lua/" .. SCRIPT .. ".lua", function(result)
            local file = io.open(filesystem.scripts_dir() .. "/" .. SCRIPT .. ".lua", "w")
            io.output(file)
            io.write(result:gsub("\r", "") .. "\n") -- have to strip out \r for some reason, or it makes two lines. ty windows
            io.close(file)

            util.toast(SCRIPT .. " was automatically updated to V" .. chunks[2] .. "\nRestart script to load new update.", TOAST_ALL)
        end, function(e)
            util.toast(SCRIPT .. ": Failed to automatically update to V" .. chunks[2] .. ".\nPlease download latest update manually.\nhttps://jackz.me/stand/get-latest-zip", 2)
            util.stop_script()
        end)
    end
end)

local WaitingLibsDownload = false
function try_load_lib(lib)
    local status = pcall(require, lib)
    if not status then
        WaitingLibsDownload = true
        util.async_http_get("jackz.me", "/stand/libs/" .. lib .. ".lua", function(result)
            local file = io.open(filesystem.scripts_dir() .. "/lib/" .. lib .. ".lua", "w")
            io.output(file)
            io.write(result)
            io.close(file)
            WaitingLibsDownload = false
            util.toast(SCRIPT .. ": Automatically downloaded missing lib '" .. lib .. ".lua'")
            require(lib)
        end, function(e)
            util.toast(SCRIPT .. " cannot load: Library files are missing. (" .. lib .. ")", 10)
            util.stop_script()
        end)
    end
end
try_load_lib("natives-1627063482")

while WaitingLibsDownload do
    util.yield()
end
-- Check if there is any changelogs (just auto-updated)
if filesystem.exists(CHANGELOG_PATH) then
    local file = io.open(CHANGELOG_PATH, "r")
    io.input(file)
    local text = io.read("*all")
    util.toast("Changelog for " .. SCRIPT .. ": \n" .. text)
    io.close(file)
    os.remove(CHANGELOG_PATH)
end

-- TODO: Spawn ped to drive

local drive_speed = 50.0
local drive_style = 0
local is_driving = false

local DRIVING_STYLES = {
    { 786603,       "Normal" },
    { 6,            "Avoid Extremely" },
    { 5,            "Sometimes Overtake" },
    { 1074528293,   "Rushed" },
    { 2883621,      "Ignore Lights" },
    { 786468,       "Avoid Traffic" },
    { 1076,         "Reversed" },
    { 8388614,      "Supposedly Good Driving" }
}

local styleMenu = menu.list(menu.my_root(), "Driving Style", {}, "Sets how the ai will drive")

for _, style in pairs(DRIVING_STYLES) do
    menu.action(styleMenu, style[2], { }, "Sets driving style to " .. style[2], function(v) 
        driving_mode = style[1]
        if is_driving then
            local ped = PLAYER.GET_PLAYER_PED_SCRIPT_INDEX(players.user())
            TASK.SET_DRIVE_TASK_DRIVING_STYLE(ped, style[1])
        end
        util.toast("Set driving style to " .. style[2])
    end)
end

menu.slider(menu.my_root(), "Driving Speed", {"setaispeed"}, "", 0, 200, drive_speed, 5.0, function(speed, prev)
    drive_speed = speed
end)

menu.divider(menu.my_root(), "Drive Actions")

menu.action(menu.my_root(), "Drive to Waypoint", {"aiwaypoint"}, "", function(v)
    local ped = PLAYER.GET_PLAYER_PED_SCRIPT_INDEX(players.user())
    local vehicle = util.get_vehicle()
    is_driving = true

    local vehicleModel = ENTITY.GET_ENTITY_MODEL(vehicle)
    if HUD.IS_WAYPOINT_ACTIVE() then
        local blip = HUD.GET_FIRST_BLIP_INFO_ID(8)
        local pos = HUD.GET_BLIP_COORDS(blip)
        TASK.TASK_VEHICLE_DRIVE_TO_COORD(ped, vehicle, pos.x, pos.y, pos.z, drive_speed, 1.0, vehicleModel, drive_mode, 5.0, 1.0)
    else
        util.toast("You have no waypoint to drive to")
    end
end)

menu.action(menu.my_root(), "Wander", {"aiwander"}, "", function(v)
    local ped = PLAYER.GET_PLAYER_PED_SCRIPT_INDEX(players.user())
    local vehicle = util.get_vehicle()
    is_driving = true

    TASK.TASK_VEHICLE_DRIVE_WANDER(ped, vehicle, drive_speed, drive_style)
end)

menu.action(menu.my_root(), "Stop Driving", {"aistop"}, "", function(v)
    local ped = PLAYER.GET_PLAYER_PED_SCRIPT_INDEX(players.user())
    is_driving = false

    TASK.CLEAR_PED_TASKS(ped)
end)

util.on_stop(function()
    local ped = PLAYER.GET_PLAYER_PED_SCRIPT_INDEX(players.user())
    local vehicle = util.get_vehicle()

    TASK.CLEAR_PED_TASKS(ped)
    TASK._CLEAR_VEHICLE_TASKS(vehicle)
end)

while true do
    util.yield()
end

