--[[
    Mushroom Mania - Trips (shared)
    Trip state lives in NW2 vars on the player, so every client knows who is
    tripping (for the spirals / cloud) and the tripper's client can replay its
    cinematic from MM_TripStart on the same timeline the server uses.
      MM_TripStart      CurTime() the trip began
      MM_TripEnd        CurTime() it ends (afterglow included). 0 = not tripping
      MM_TripIntensity  Trip length multiplier (see MM.TripIntensity)
      MM_TripSpecies    Species id that was eaten
]]

local MM = MushroomMania

MM.TRIP_PHASES = { "onset", "white", "vision", "dim", "void", "black", "return", "buzz" }

-- Trip length multiplier for a batch. 0 = no trip (contaminated / non-tripping strain)
function MM.TripIntensity(speciesId, quality, dried)
    local m = MM.GetQuality(quality).Trip or 1
    if dried then m = m * (MM.Config.Trip.DriedMultiplier or 1) end
    local sp = MM.GetSpecies(speciesId or "")
    if sp and sp.TripMultiplier then m = m * sp.TripMultiplier end
    return math.max(0, m)
end

-- Phase name -> { start, finish } (seconds from the trip start), plus .cinematic and .total
function MM.TripTimeline(m)
    local P = MM.Config.Trip.Phases
    local tl, t = {}, 0
    local function add(name, dur)
        tl[name] = { t, t + dur }
        t = t + dur
    end
    add("onset",  P.Onset)
    add("white",  P.White * m)
    add("vision", math.max(P.Vision * m, P.VisionMin or 0))
    add("dim",    P.ToVoid)
    add("void",   P.Void * m)
    add("black",  P.BlackHold)
    add("return", P.Return)
    tl.cinematic = t
    add("buzz",   P.Buzz * m)
    tl.total = t
    return tl
end

function MM.IsTripping(ply)
    return IsValid(ply) and ply:GetNW2Float("MM_TripEnd", 0) > CurTime()
end

--------------------------------------------------------------------------------
-- Slow, floaty movement. Runs on both realms so prediction stays smooth.
--------------------------------------------------------------------------------
hook.Add("SetupMove", "MushroomMania.Trip", function(ply, mv)
    local cfg = MM.Config.Trip

    if not MM.IsTripping(ply) then
        if ply.MM_TripGravity then
            ply:SetGravity(ply.MM_TripGravity)
            ply.MM_TripGravity = nil
        end
        return
    end

    if not ply.MM_TripGravity then
        ply.MM_TripGravity = ply:GetGravity() -- Restored afterwards (0 = default)
        ply:SetGravity(cfg.Gravity)
    end

    local s = cfg.SpeedMultiplier
    mv:SetMaxClientSpeed(mv:GetMaxClientSpeed() * s)
    mv:SetMaxSpeed(mv:GetMaxSpeed() * s)
end)
