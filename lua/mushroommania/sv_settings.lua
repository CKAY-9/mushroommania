--[[
    Mushroom Mania - In-game settings (server)
]]

local MM = MushroomMania

util.AddNetworkString(MM.NET_SETTINGS)

local SAVE_PATH = "mushroommania/settings.json"

-- Client -> server actions
local REQ_SYNC   = 0
local REQ_UPDATE = 1
local REQ_RESET  = 2

-- CAMI privilege check, falling back to the MinAccess usergroup
function MM.CanEditSettings(ply)
    if not IsValid(ply) then return false end
    local cfg = MM.Config.Settings

    MM.RegisterPrivilege() -- no-op once registered
    if CAMI and CAMI.PlayerHasAccess then
        local result
        CAMI.PlayerHasAccess(ply, cfg.Privilege, function(allowed) result = allowed end)
        if result ~= nil then return result and true or false end
    end

    if cfg.MinAccess == "superadmin" then return ply:IsSuperAdmin() end
    if cfg.MinAccess == "user" then return true end
    return ply:IsAdmin() -- true for superadmins too
end

local function load()
    local data = file.Read(SAVE_PATH, "DATA")
    local s = data and util.JSONToTable(data)
    if s then MM.ApplySettings(s) end
end

local function save()
    file.CreateDir("mushroommania")
    file.Write(SAVE_PATH, util.TableToJSON(MM.GetSettings(), true))
end

-- Each player also learns whether they may edit (drives the Q menu panel)
local function send(target)
    local s = MM.GetSettings()
    for _, ply in ipairs(target and { target } or player.GetHumans()) do
        net.Start(MM.NET_SETTINGS)
        net.WriteBool(MM.CanEditSettings(ply))
        net.WriteTable(s)
        net.Send(ply)
    end
end

-- Not throttled like MM.Notify: repeated saves should each confirm
local function notify(ply, msg, isError)
    if DarkRP and DarkRP.notify then
        DarkRP.notify(ply, isError and 1 or 0, 4, msg)
    else
        ply:ChatPrint("[Mushroom Mania] " .. msg)
    end
end

net.Receive(MM.NET_SETTINGS, function(len, ply)
    local action = net.ReadUInt(2)

    -- Syncs and edits are throttled separately so a sync never eats a save
    if action == REQ_SYNC then
        if (ply.MM_NextSettingsSync or 0) > CurTime() then return end
        ply.MM_NextSettingsSync = CurTime() + 0.5
        send(ply)
        return
    end

    local allowed = MM.CanEditSettings(ply)

    if (ply.MM_NextSettings or 0) > CurTime() then
        -- Tell admins their change was dropped instead of failing silently
        if allowed then notify(ply, "Saving too fast - wait a moment and try again.", true) end
        return
    end
    ply.MM_NextSettings = CurTime() + 0.5

    if not allowed then
        notify(ply, "You don't have permission to change Mushroom Mania settings.", true)
        return
    end

    local wasRegistered = MM.Config.Shop.Register

    if action == REQ_UPDATE then
        if len > 64 * 1024 then return end
        MM.ApplySettings(net.ReadTable())
    elseif action == REQ_RESET then
        MM.ApplySettings(table.Copy(MM.SettingsDefaults))
    else
        return
    end

    save()
    send()
    notify(ply, action == REQ_RESET and "Mushroom Mania settings reset to defaults." or "Mushroom Mania settings saved.")

    if MM.Config.Shop.Register ~= wasRegistered and not MM.SyncDarkRP() then
        local msg = "The Mushroom Mania F4 items couldn't be " .. (MM.Config.Shop.Register and "added" or "removed")
            .. " live. Change the map or restart the server to apply it."
        notify(ply, msg, true)
        ply:ChatPrint("[Mushroom Mania] " .. msg)
    end
    ServerLog(string.format("[Mushroom Mania] %s (%s) %s settings\n", ply:Nick(), ply:SteamID(),
        action == REQ_RESET and "reset" or "updated"))
end)

-- Push the new permission straight away when someone's rank changes
hook.Add("CAMI.PlayerUsergroupChanged", "MushroomMania.Settings", function(ply)
    timer.Simple(0, function()
        if IsValid(ply) then send(ply) end
    end)
end)

load()
