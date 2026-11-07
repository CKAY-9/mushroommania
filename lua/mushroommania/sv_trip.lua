--[[
    Mushroom Mania - Trips (server)
    Eating a dose, starting / stopping trips. The visuals are all client-side
    (cl_trip.lua); the server only sets the NW2 state described in sh_trip.lua.
]]

local MM = MushroomMania

function MM.StartTrip(ply, m, speciesId)
    if not IsValid(ply) or m <= 0 then return end
    local now = CurTime()
    ply:SetNW2Float("MM_TripIntensity", m)
    ply:SetNW2String("MM_TripSpecies", speciesId or "")
    ply:SetNW2Float("MM_TripEnd", now + MM.TripTimeline(m).total)
    ply:SetNW2Float("MM_TripStart", now)
end

function MM.StopTrip(ply)
    if not IsValid(ply) or ply:GetNW2Float("MM_TripEnd", 0) == 0 then return end
    ply:SetNW2Float("MM_TripEnd", 0)
    ply:SetNW2Float("MM_TripStart", 0)
end

-- E on a mushroom batch
function MM.Eat(ply, ent)
    local cfg = MM.Config.Trip
    if ent.MM_Used or ent:GetAmount() <= 0 then return end

    if cfg.OwnerOnly and MM.GetOwner(ent) ~= ply then
        MM.Notify(ply, "Those aren't yours.", 1)
        return
    end
    if MM.IsTripping(ply) then
        MM.Notify(ply, "You're still tripping.", 1)
        return
    end

    local species, quality, dried = ent:GetSpecies(), ent:GetQuality(), ent:GetDried()
    local dose = math.min(math.max(1, cfg.Dose or 1), ent:GetAmount())
    local left = ent:GetAmount() - dose
    if left <= 0 then
        ent.MM_Used = true
        ent:Remove()
    else
        ent:SetAmount(left)
    end

    if cfg.Sounds.Eat ~= "" then ply:EmitSound(cfg.Sounds.Eat, 60, math.random(95, 110)) end

    local m = MM.TripIntensity(species, quality, dried)
    local sp = MM.GetSpecies(species)
    local name = sp and sp.Name or "mushrooms"

    if m <= 0 then
        local sick = cfg.Sick
        if (sick.Damage or 0) > 0 then
            local dmg = DamageInfo()
            dmg:SetDamage(sick.Damage)
            dmg:SetDamageType(DMG_GENERIC)
            dmg:SetAttacker(ply)
            dmg:SetInflictor(game.GetWorld())
            ply:TakeDamageInfo(dmg)
        end
        if cfg.Sounds.Sick ~= "" then ply:EmitSound(cfg.Sounds.Sick, 60) end
        MM.Notify(ply, sick.Message, 1)
        return
    end

    MM.Notify(ply, string.format("You ate %d%s of %s%s...", dose, MM.Config.Mushrooms.Unit,
        dried and "dried " or "", name), 0)
    MM.StartTrip(ply, m, species)
end

hook.Add("PlayerDeath", "MushroomMania.Trip", MM.StopTrip)
hook.Add("PlayerSilentDeath", "MushroomMania.Trip", MM.StopTrip)
hook.Add("OnPlayerChangedTeam", "MushroomMania.Trip", MM.StopTrip)

-- Testing: mm_trip [multiplier] [species] / mm_trip_stop  (superadmin)
concommand.Add("mm_trip", function(ply, _, args)
    if not IsValid(ply) or not ply:IsSuperAdmin() then return end
    local m = math.Clamp(tonumber(args[1]) or 1, 0.1, 5)
    MM.StopTrip(ply)
    MM.StartTrip(ply, m, args[2] or "")
end)

concommand.Add("mm_trip_stop", function(ply)
    if not IsValid(ply) or not ply:IsSuperAdmin() then return end
    MM.StopTrip(ply)
end)
