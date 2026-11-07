--[[
    Mushroom Mania - Server core
]]

local MM = MushroomMania

--------------------------------------------------------------------------------
-- Notifications (the same message to the same player is shown at most once per
-- NOTIFY_THROTTLE seconds, so items resting on a tub don't spam)
--------------------------------------------------------------------------------
local NOTIFY_THROTTLE = 1

-- kind: 0 = generic, 1 = error, 3 = hint, 4 = cleanup (DarkRP NOTIFY_* values)
function MM.Notify(ply, msg, kind, len)
    if not IsValid(ply) or not ply:IsPlayer() or not msg then return end

    local now = CurTime()
    local recent = ply.MM_Notified or {}
    ply.MM_Notified = recent
    if (recent[msg] or 0) > now then return end

    -- Forget expired messages so the table only ever holds the last second's worth
    for m, expires in pairs(recent) do
        if expires <= now then recent[m] = nil end
    end
    recent[msg] = now + NOTIFY_THROTTLE

    if DarkRP and DarkRP.notify then
        DarkRP.notify(ply, kind or 0, len or 4, msg)
    else
        ply:ChatPrint("[Mushroom Mania] " .. msg)
    end
end

function MM.PlaySound(ent, key, level, pitch)
    local snd = MM.Config.Sounds[key]
    if snd and snd ~= "" and IsValid(ent) then
        ent:EmitSound(snd, level or 65, pitch or 100)
    end
end

-- Player to blame / inform for an item: whoever last picked it up, else its owner
function MM.GetHandler(ent)
    if IsValid(ent.MM_LastHolder) then return ent.MM_LastHolder end
    return MM.GetOwner(ent)
end

function MM.SetOwner(ent, ply)
    if not IsValid(ent) or not IsValid(ply) then return end
    if ent.Setowning_ent then ent:Setowning_ent(ply) end
    if ent.CPPISetOwner then ent:CPPISetOwner(ply) end
    ent.SID = ply.SID
end

local function trackHolder(ply, ent)
    if IsValid(ent) and ent.MMEntity then ent.MM_LastHolder = ply end
end
hook.Add("OnPhysgunPickup", "MushroomMania.Holder", trackHolder)
hook.Add("GravGunOnPickedUp", "MushroomMania.Holder", trackHolder)
hook.Add("OnPlayerPhysicsPickup", "MushroomMania.Holder", trackHolder)

local function trackDrop(ply, ent)
    if IsValid(ent) and ent.MMEntity then ent.MM_DroppedAt = CurTime() end
end
hook.Add("PhysgunDrop", "MushroomMania.Holder", trackDrop)
hook.Add("GravGunOnDropped", "MushroomMania.Holder", trackDrop)
hook.Add("OnPlayerPhysicsDrop", "MushroomMania.Holder", trackDrop)

-- True while a player is carrying the item or just let go of it
function MM.IsBeingHandled(ent)
    return ent:IsPlayerHolding() or CurTime() - (ent.MM_DroppedAt or -100) < 3
end

-- Q-menu spawns get an owner too
hook.Add("PlayerSpawnedSENT", "MushroomMania.Owner", function(ply, ent)
    if ent.MMEntity then MM.SetOwner(ent, ply) end
end)

--------------------------------------------------------------------------------
-- Contamination rejection (kept by SteamID so rejoining doesn't clear it)
--------------------------------------------------------------------------------
MM.Rejections = MM.Rejections or {}

function MM.Reject(ply, seconds)
    local untilT = CurTime() + seconds
    MM.Rejections[ply:SteamID64() or ply:SteamID()] = untilT
    ply:SetNWFloat("MM_RejectUntil", untilT)
end

hook.Add("PlayerInitialSpawn", "MushroomMania.Reject", function(ply)
    local untilT = MM.Rejections[ply:SteamID64() or ply:SteamID()]
    if untilT and untilT > CurTime() then
        ply:SetNWFloat("MM_RejectUntil", untilT)
    end
end)

--------------------------------------------------------------------------------
-- Selling
--------------------------------------------------------------------------------
function MM.Sell(ply, npc)
    local cfg = MM.Config.Enthusiast

    local ok, reason = MM.CanSell(ply)
    if not ok then
        MM.Notify(ply, reason, 1)
        MM.PlaySound(npc, "Deny")
        return
    end

    local batches = {}
    for _, ent in ipairs(ents.FindInSphere(npc:GetPos(), cfg.SellRadius)) do
        if ent:GetClass() == "mm_mushrooms" and not ent.MM_Used
            and (not cfg.OwnerOnly or MM.GetOwner(ent) == ply) then
            batches[#batches + 1] = ent
        end
    end

    if #batches == 0 then
        MM.Notify(ply, "Bring your mushrooms closer and I'll take a look.", 3)
        return
    end

    local total, units, contaminated = 0, 0, false
    for _, ent in ipairs(batches) do
        total = total + ent:GetValue()
        units = units + ent:GetAmount()
        if ent:GetQuality() == MM.QUALITY_CONTAMINATED then contaminated = true end
        ent.MM_Used = true
        ent:Remove()
    end

    if ply.addMoney then ply:addMoney(total) end
    MM.PlaySound(npc, "Sell")
    MM.Notify(ply, string.format("Sold %d%s of mushrooms for %s.", units, MM.Config.Mushrooms.Unit, MM.FormatMoney(total)), 0)

    if contaminated then
        local t = MM.Config.Contaminated.RejectTime
        MM.Reject(ply, t)
        MM.Notify(ply, "These are contaminated! Mushroom Enthusiasts won't deal with you for " .. MM.FormatTime(t) .. ".", 1, 8)
    end
end

--------------------------------------------------------------------------------
-- Persistent Mushroom Enthusiasts
--   Spawn them from the Q menu, then run `mm_save_enthusiasts` (superadmin).
--------------------------------------------------------------------------------
local function savePath()
    return "mushroommania/enthusiasts_" .. game.GetMap() .. ".json"
end

function MM.SaveEnthusiasts()
    local out = {}
    for _, ent in ipairs(ents.FindByClass("mm_enthusiast")) do
        out[#out + 1] = { pos = ent:GetPos(), ang = ent:GetAngles() }
    end
    file.CreateDir("mushroommania")
    file.Write(savePath(), util.TableToJSON(out, true))
    return #out
end

function MM.SpawnEnthusiasts()
    local data = file.Read(savePath(), "DATA")
    if not data then return end
    local list = util.JSONToTable(data) or {}

    for _, ent in ipairs(ents.FindByClass("mm_enthusiast")) do ent:Remove() end
    for _, v in ipairs(list) do
        local ent = ents.Create("mm_enthusiast")
        if IsValid(ent) then
            ent:SetPos(v.pos)
            ent:SetAngles(v.ang)
            ent:Spawn()
            ent:Activate()
        end
    end
end

hook.Add("InitPostEntity", "MushroomMania.Enthusiasts", MM.SpawnEnthusiasts)
hook.Add("PostCleanupMap", "MushroomMania.Enthusiasts", MM.SpawnEnthusiasts)

concommand.Add("mm_save_enthusiasts", function(ply)
    if IsValid(ply) and not ply:IsSuperAdmin() then return end
    local n = MM.SaveEnthusiasts()
    local msg = "[Mushroom Mania] Saved " .. n .. " Mushroom Enthusiast(s) for " .. game.GetMap()
    if IsValid(ply) then ply:ChatPrint(msg) else print(msg) end
end)
