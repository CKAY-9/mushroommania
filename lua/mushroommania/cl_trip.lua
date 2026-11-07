--[[
    Mushroom Mania - Trips (client)

    The tripper's cinematic, driven by the NW2 state in sh_trip.lua:
      onset   world gets brighter and blooms out to pure white
      white   pure white
      vision  a lamp switches on and projects a mosaic on the floor; the
              Mushroom Enthusiast walks out of the white and says a line
      dim     white fades to black
      void    out of body: the camera floats up above you in a black void
      black   pure black
      return  fade back into reality
      buzz    afterglow: subtle colour shifts until the trip ends

    The white room and the void replace the whole scene (RenderScene hook), so
    nothing else is drawn - the "world" there is a few client-side models.

    Everyone also sees, on any tripping player: spirals over their eyes and a
    faint tinted cloud around their head.
]]

local MM = MushroomMania

MM.Trip = MM.Trip or {}
local Trip = MM.Trip
if Trip.Stop then Trip.Stop() end -- Lua refresh: clean up the old trip
hook.Remove("CalcView", "MushroomMania.TripVision")        -- From an older version
hook.Remove("PostDrawEffects", "MushroomMania.TripVision")

local function cfg() return MM.Config.Trip end

local function smooth(x)
    x = math.Clamp(x, 0, 1)
    return x * x * (3 - 2 * x)
end

local function frac(t, a, b)
    if b <= a then return t >= b and 1 or 0 end
    return math.Clamp((t - a) / (b - a), 0, 1)
end

local UP = Vector(0, 0, 1)

--------------------------------------------------------------------------------
-- Materials
--------------------------------------------------------------------------------
local function pngTexture(path)
    return Material(path, "smooth mips"):GetTexture("$basetexture")
end

local function unlit(name, extra)
    local kv = { ["$vertexcolor"] = 1, ["$vertexalpha"] = 1, ["$nocull"] = 1 }
    for k, v in pairs(extra or {}) do kv[k] = v end
    return CreateMaterial(name, "UnlitGeneric", kv)
end

local MAT_SPIRAL = unlit("mm_trip_spiral", { ["$translucent"] = 1 })
MAT_SPIRAL:SetTexture("$basetexture", pngTexture("mushroommania/spiral.png"))

-- Black with a soft round alpha falloff: darkens the floor under the light
local MAT_SHADOW = unlit("mm_trip_shadow", { ["$translucent"] = 1 })
MAT_SHADOW:SetTexture("$basetexture", pngTexture("mushroommania/shadowdisk.png"))

-- The lamp's mosaic, added on top. Flashlight textures already fade to black at the edge
local MAT_MOSAIC = unlit("mm_trip_mosaic", { ["$additive"] = 1 })

local MAT_GLOW   = Material("sprites/light_glow02_add")
local SMOKE      = "particle/particle_smokegrenade"

local function createFonts()
    surface.CreateFont("MM.TripSubtitle", { font = MM.Config.Theme.Font, size = 34, weight = 600, antialias = true })
end
createFonts()
hook.Add("OnScreenSizeChanged", "MushroomMania.TripFonts", createFonts)

--------------------------------------------------------------------------------
-- State
--------------------------------------------------------------------------------
local S -- The local player's active trip, or nil

local function phaseAt(t)
    for _, name in ipairs(MM.TRIP_PHASES) do
        local p = S.tl[name]
        if t < p[2] then return name, t - p[1], p[2] - p[1] end
    end
    local p = S.tl.buzz
    return "buzz", t - p[1], p[2] - p[1]
end

local function setDSP(id)
    local lp = LocalPlayer()
    if IsValid(lp) and lp.SetDSP then lp:SetDSP(id or 0, false) end
end

local function loop(path, vol, pitch)
    if not path or path == "" then return end
    local snd = CreateSound(LocalPlayer(), path)
    snd:PlayEx(vol, pitch)
    return snd
end

local function stopSound(snd, fade)
    if not snd then return end
    if fade and fade > 0 then snd:FadeOut(fade) else snd:Stop() end
end

local function removeModel(ent)
    if IsValid(ent) then ent:Remove() end
end

function Trip.Stop()
    if not S then return end
    stopSound(S.heartbeat)
    stopSound(S.onsetDrone)
    stopSound(S.voidDrone)
    removeModel(S.npc)
    setDSP(0)
    S = nil
end

local function pickLine(m)
    local tier
    for _, v in ipairs(cfg().Voicelines) do
        if m >= (v.MinIntensity or 0) and (not tier or (v.MinIntensity or 0) >= (tier.MinIntensity or 0)) then
            tier = v
        end
    end
    if tier and #tier.Lines > 0 then return tier.Lines[math.random(#tier.Lines)] end
end

local function lookupFlex(ent, name)
    local id = ent:GetFlexIDByName(name)
    return id and id >= 0 and id or nil
end

-- Builds the white room in front of wherever the player is looking. Nothing
-- else is drawn there, so it sits around the world origin.
local function buildVision()
    local V = cfg().Vision
    local yaw = EyeAngles().y
    local fwd = Angle(0, yaw, 0):Forward()
    local right = Angle(0, yaw, 0):Right()

    local sc = { eye = Vector(0, 0, 64) }
    sc.stop = fwd * V.StopDistance
    sc.pool = fwd * (V.StopDistance + 10)
    sc.from = sc.stop + fwd * V.WalkDistance + right * 40
    S.scene = sc

    removeModel(S.npc)
    local npc = ClientsideModel(MM.Config.Enthusiast.Model, RENDERGROUP_OPAQUE)
    S.npc = npc
    if not IsValid(npc) then return end
    npc:SetNoDraw(true)
    npc:SetPos(sc.from)

    local walk = npc:SelectWeightedSequence(ACT_WALK)
    if walk < 0 then walk = npc:LookupSequence("walk_all") end
    local idle = npc:LookupSequence(MM.Config.Enthusiast.Sequence or "")
    if idle < 0 then idle = npc:SelectWeightedSequence(ACT_IDLE) end
    S.walkSeq, S.idleSeq = math.max(walk, 0), math.max(idle, 0)
    S.walkDur = math.max(npc:SequenceDuration(S.walkSeq), 0.1)
    S.idleDur = math.max(npc:SequenceDuration(S.idleSeq), 0.1)
    S.groundSpeed = npc:GetSequenceGroundSpeed(S.walkSeq)
    if not S.groundSpeed or S.groundSpeed <= 0 then S.groundSpeed = 60 end
    npc:ResetSequence(S.walkSeq)

    S.jaw   = lookupFlex(npc, "jaw_drop")
    S.smile = { lookupFlex(npc, "right_corner_puller"), lookupFlex(npc, "left_corner_puller") }
    local smile = V.Smile or 0
    for _, id in pairs(S.smile) do npc:SetFlexWeight(id, smile) end
end

local function buildVoid()
    local n = cfg().Void.Motes or 0
    S.motes = {}
    for i = 1, n do
        S.motes[i] = {
            offset = VectorRand():GetNormalized() * math.Rand(60, 240) + UP * math.Rand(-20, 80),
            spin   = math.Rand(-12, 12),
            bob    = math.Rand(0, 6.28),
            size   = math.Rand(4, 12),
            hue    = math.Rand(0, 360),
        }
    end
    S.voidYaw = EyeAngles().y
    S.voidPitch = math.Clamp(EyeAngles().p, -30, 60)
end

-- One-shot actions when the trip reaches a phase (skipped phases are skipped)
local ENTER = {
    onset = function()
        local snd = cfg().Sounds
        S.onsetDrone = loop(snd.OnsetDrone, 0.05, 60)
        if S.onsetDrone then
            S.onsetDrone:ChangeVolume(0.6, S.tl.onset[2] - S.tl.onset[1])
            S.onsetDrone:ChangePitch(150, S.tl.onset[2] - S.tl.onset[1])
        end
        -- The heartbeat wav loops on its own: one patch, sped up through the onset
        local onset = S.tl.onset[2] - S.tl.onset[1]
        S.heartbeat = loop(snd.Heartbeat, 0.9, 90)
        if S.heartbeat then S.heartbeat:ChangePitch(140, onset) end
    end,
    white = function()
        stopSound(S.heartbeat, 0.5)
        S.heartbeat = nil
        setDSP(cfg().VisionDSP)
        if S.onsetDrone then
            S.onsetDrone:ChangeVolume(0.2, 1.5)
            S.onsetDrone:ChangePitch(100, 1.5)
        end
    end,
    vision = function()
        buildVision()
        S.poolBuilt = false
        local snd = cfg().Sounds.LampOn
        if snd ~= "" then surface.PlaySound(snd) end
    end,
    dim = function()
        if S.onsetDrone then S.onsetDrone:ChangeVolume(0, S.tl.dim[2] - S.tl.dim[1]) end
    end,
    void = function()
        stopSound(S.onsetDrone)
        S.onsetDrone = nil
        removeModel(S.npc)
        S.subtitle = nil
        setDSP(cfg().VoidDSP)
        buildVoid()
        S.voidDrone = loop(cfg().Sounds.VoidDrone, 0, 70)
        if S.voidDrone then S.voidDrone:ChangeVolume(0.5, 2) end
    end,
    black = function()
        stopSound(S.voidDrone, S.tl.black[2] - S.tl.black[1])
        S.voidDrone = nil
    end,
    ["return"] = function()
        setDSP(0)
        stopSound(S.heartbeat)
        stopSound(S.onsetDrone)
        stopSound(S.voidDrone)
        S.onsetDrone, S.voidDrone = nil, nil
    end,
}

local function begin(start, m, species)
    Trip.Stop()
    S = {
        start   = start,
        m       = m,
        species = species,
        tl      = MM.TripTimeline(m),
        phase   = nil,
    }
end

--------------------------------------------------------------------------------
-- Per-frame update (sounds, the Enthusiast's walk and speech)
--------------------------------------------------------------------------------
local function updateNPC(t)
    local V, sc, npc = cfg().Vision, S.scene, S.npc
    if not IsValid(npc) then return end

    local walkT = t - V.WalkDelay
    local pos, yaw
    if walkT < V.WalkTime then
        local f = math.max(walkT, 0) / V.WalkTime
        pos = LerpVector(f, sc.from, sc.stop)
        yaw = (sc.stop - sc.from):Angle().y
        if npc:GetSequence() ~= S.walkSeq then npc:ResetSequence(S.walkSeq) end
        -- Match the animation to how fast he actually moves so the feet don't slide
        local speed = sc.from:Distance(sc.stop) / V.WalkTime
        npc:SetCycle((math.max(walkT, 0) * speed / S.groundSpeed / S.walkDur) % 1)
    else
        local idleT = walkT - V.WalkTime
        pos = sc.stop
        local walkYaw = (sc.stop - sc.from):Angle().y
        local faceYaw = (Vector(sc.eye.x, sc.eye.y, 0) - Vector(pos.x, pos.y, 0)):Angle().y
        yaw = Lerp(smooth(idleT / 0.6), walkYaw, walkYaw + math.AngleDifference(faceYaw, walkYaw))
        if npc:GetSequence() ~= S.idleSeq then npc:ResetSequence(S.idleSeq) end
        npc:SetCycle((idleT / S.idleDur) % 1)

        if not S.spoke and idleT >= V.SpeakDelay then
            S.spoke = true
            local line = pickLine(S.m)
            if line then
                surface.PlaySound(line[1])
                local dur = SoundDuration(line[1])
                if not dur or dur <= 0 then dur = 2.5 end
                S.speakEnd = CurTime() + dur
                S.subtitle = line[2]
                S.subtitleEnd = CurTime() + dur + 1.5
            end
        end
    end

    npc:SetPos(pos)
    npc:SetAngles(Angle(0, yaw, 0))
    npc:SetEyeTarget(sc.eye)

    if S.jaw then
        local w = 0
        if S.speakEnd and CurTime() < S.speakEnd then
            local rt = RealTime()
            w = 0.15 + 0.55 * math.abs(math.sin(rt * 13)) * (0.6 + 0.4 * math.sin(rt * 5.3))
        end
        npc:SetFlexWeight(S.jaw, w)
    end
end

hook.Add("Think", "MushroomMania.Trip", function()
    local lp = LocalPlayer()
    if not IsValid(lp) then return end

    if MM.IsTripping(lp) then
        local start = lp:GetNW2Float("MM_TripStart", 0)
        if not S or S.start ~= start then
            begin(start, lp:GetNW2Float("MM_TripIntensity", 1), lp:GetNW2String("MM_TripSpecies", ""))
        end
    elseif S then
        Trip.Stop()
    end
    if not S then return end

    local t = CurTime() - S.start
    local phase, pt = phaseAt(t)
    S.t, S.phaseName, S.pt = t, phase, pt

    if phase ~= S.phase then
        -- Run the enter action for the phase we're in (late joins skip earlier ones)
        S.phase = phase
        if ENTER[phase] then ENTER[phase]() end
    end

    if phase == "vision" or phase == "dim" then
        updateNPC(t - S.tl.vision[1])
    end
end)

--------------------------------------------------------------------------------
-- Drawing the tripper's own view
--------------------------------------------------------------------------------
local function overlay(r, g, b, a)
    if a <= 0 then return end
    surface.SetDrawColor(r, g, b, math.Clamp(a, 0, 1) * 255)
    surface.DrawRect(0, 0, ScrW(), ScrH())
end

local function drawSubtitle()
    if not S.subtitle or CurTime() > (S.subtitleEnd or 0) then return end
    local T = MM.Config.Theme
    local a = math.Clamp((S.subtitleEnd - CurTime()) / 0.5, 0, 1)
    surface.SetFont("MM.TripSubtitle")
    local w, h = surface.GetTextSize(S.subtitle)
    local x, y = ScrW() / 2, ScrH() * 0.82
    local bg = T.Background
    draw.RoundedBox(8, x - w / 2 - 18, y - 10, w + 36, h + 20, Color(bg.r, bg.g, bg.b, bg.a * a))
    draw.SimpleText(S.subtitle, "MM.TripSubtitle", x, y, Color(T.Text.r, T.Text.g, T.Text.b, 255 * a), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
end

local function drawVision(t, angles, fov)
    local V, sc = cfg().Vision, S.scene
    render.Clear(255, 255, 255, 255, true, true)
    if not sc then return end

    MAT_MOSAIC:SetTexture("$basetexture", V.LampTexture)

    -- The lamp flickers on, then stays lit
    local on = t < 0.6 and ((math.sin(t * 70) > -0.2) and smooth(t / 0.15) or 0.25) or 1
    local rot = t * V.PoolSpin
    local tint = HSVToColor((CurTime() * V.HueSpeed) % 360, V.HueSat, 1)
    local walkIn = smooth((t - V.WalkDelay + 0.5) / 1.5)

    cam.Start3D(sc.eye, angles, fov)
        -- Floor: darken a soft circle, then add the mosaic on top of it
        cam.IgnoreZ(true)
        render.SetMaterial(MAT_SHADOW)
        render.DrawQuadEasy(sc.pool, UP, V.PoolSize * 1.1, V.PoolSize * 1.1, Color(255, 255, 255, V.PoolDarken * on * 255), rot)
        if IsValid(S.npc) then
            -- Contact shadow so he stands on something
            render.DrawQuadEasy(S.npc:GetPos() + UP * 0.2, UP, 70, 70, Color(255, 255, 255, 110 * walkIn), 0)
        end

        render.SetMaterial(MAT_MOSAIC)
        render.DrawQuadEasy(sc.pool + UP * 0.4, UP, V.PoolSize, V.PoolSize,
            Color(tint.r * on, tint.g * on, tint.b * on), rot)
        cam.IgnoreZ(false)

        -- The Enthusiast: flat bright lighting, out of white fog
        render.SuppressEngineLighting(true)
        render.FogMode(MATERIAL_FOG_LINEAR)
        render.FogStart(V.FogStart)
        render.FogEnd(V.FogEnd)
        render.FogMaxDensity(1)
        render.FogColor(255, 255, 255)
        render.ResetModelLighting(0.6, 0.6, 0.62)
        render.SetModelLighting(BOX_TOP, 1.15, 1.15, 1.15)

        if IsValid(S.npc) and walkIn > 0 then
            render.SetBlend(walkIn)
            S.npc:InvalidateBoneCache()
            S.npc:DrawModel()
            render.SetBlend(1)
        end

        render.FogMode(MATERIAL_FOG_NONE)
        render.SuppressEngineLighting(false)
    cam.End3D()

    cam.Start2D()
        drawSubtitle()
    cam.End2D()
end

local function drawVoid(t, dur, fov)
    local V = cfg().Void
    local lp = LocalPlayer()
    render.Clear(0, 0, 0, 255, true, true)

    local body = lp:GetPos()
    local f = smooth(t / math.max(dur * 0.75, 0.1))
    local from = lp:EyePos() + UP * 14 -- Follows the body if it moves
    local pos = LerpVector(f, from, body + UP * (64 + V.Height))
    local ang = Angle(Lerp(f, S.voidPitch, 89), S.voidYaw + t * V.Spin, math.sin(t * 0.7) * 4)

    local tint = MM.Trip.CloudColor(S.species, 0)

    cam.Start3D(pos, ang, fov)
        -- Aura + drifting specks of light
        render.SetMaterial(MAT_GLOW)
        render.DrawSprite(body + UP * 36, 180, 180, Color(tint.r, tint.g, tint.b, 40))
        for _, mote in ipairs(S.motes or {}) do
            local o = Vector(mote.offset)
            o:Rotate(Angle(0, t * mote.spin, 0))
            o.z = o.z + math.sin(t * 0.8 + mote.bob) * 10
            local c = HSVToColor((mote.hue + t * 20) % 360, 0.4, 1)
            local a = 120 + 80 * math.sin(t * 2 + mote.bob)
            render.DrawSprite(body + o, mote.size, mote.size, Color(c.r, c.g, c.b, a))
        end

        render.SuppressEngineLighting(true)
        render.ResetModelLighting(0.12, 0.12, 0.15)
        render.SetModelLighting(BOX_TOP, 0.95, 0.95, 1)
        render.SetModelLighting(BOX_BOTTOM, tint.r / 255 * 0.5, tint.g / 255 * 0.5, tint.b / 255 * 0.5)
        lp:DrawModel()
        local wep = lp:GetActiveWeapon()
        if IsValid(wep) then wep:DrawModel() end
        render.SuppressEngineLighting(false)
    cam.End3D()
end

hook.Add("RenderScene", "MushroomMania.Trip", function(origin, angles, fov)
    if not S or not S.phaseName then return end
    local phase, t = S.phaseName, S.pt
    local p = S.tl[phase]
    local dur = p[2] - p[1]

    if phase == "white" then
        local w = 245 + 10 * math.sin(CurTime() * 1.5)
        render.Clear(w, w, w, 255, true, true)
        return true
    elseif phase == "vision" then
        drawVision(t, angles, fov)
        return true
    elseif phase == "dim" then
        -- Camera shake that builds up towards the cut to black
        local f = t / dur
        local amp = (cfg().Shake or 0) * smooth(f / 0.7)
        local rt = RealTime()
        local shaken = Angle(
            angles.p + amp * (math.sin(rt * 31) * 0.6 + math.sin(rt * 47 + 1) * 0.4),
            angles.y + amp * (math.sin(rt * 27 + 2) * 0.6 + math.sin(rt * 53 + 3) * 0.4),
            angles.r + amp * 0.8 * math.sin(rt * 19 + 4))
        drawVision(S.t - S.tl.vision[1], shaken, fov)
        -- To white, then down to black
        local c = 255 * (1 - smooth((f - 0.35) / 0.65))
        cam.Start2D()
            overlay(c, c, c, f / 0.35)
        cam.End2D()
        return true
    elseif phase == "void" then
        drawVoid(t, dur, fov)
        cam.Start2D()
            overlay(0, 0, 0, math.max(1 - t / 1.5, frac(t, dur - 2, dur)))
        cam.End2D()
        return true
    elseif phase == "black" then
        render.Clear(0, 0, 0, 255, true, true)
        return true
    end
end)

-- Your own body is drawn in the void
hook.Add("ShouldDrawLocalPlayer", "MushroomMania.Trip", function()
    if S and S.phaseName == "void" then return true end
end)

local function colorMod(brightness, contrast, colour, ar, ag, ab)
    DrawColorModify({
        ["$pp_colour_addr"]       = ar or 0,
        ["$pp_colour_addg"]       = ag or 0,
        ["$pp_colour_addb"]       = ab or 0,
        ["$pp_colour_brightness"] = brightness,
        ["$pp_colour_contrast"]   = contrast,
        ["$pp_colour_colour"]     = colour,
        ["$pp_colour_mulr"]       = 0,
        ["$pp_colour_mulg"]       = 0,
        ["$pp_colour_mulb"]       = 0,
    })
end

hook.Add("RenderScreenspaceEffects", "MushroomMania.Trip", function()
    if not S or not S.phaseName then return end
    local phase, t = S.phaseName, S.pt

    if phase == "onset" then
        local f = t / (S.tl.onset[2] - S.tl.onset[1])
        colorMod(f * f * 0.7, 1 + f * 0.8, 1 + f * 1.6, f * 0.06, f * 0.03, f * 0.08)
        DrawBloom(0.65 - f * 0.6, f * 3, 9, 9, 2, 2, 1, 1, 1)
        DrawMotionBlur(0.25, f * 0.8, 0.01)
    elseif phase == "return" or phase == "buzz" then
        local buzzT = S.t - S.tl["return"][1]
        local buzzDur = S.tl.buzz[2] - S.tl["return"][1]
        local k = smooth(buzzT / 3) * (1 - smooth(frac(buzzT, buzzDur * 0.7, buzzDur)))
        if k <= 0 then return end
        local rt = CurTime()
        colorMod(0, 1 + 0.08 * k, 1 + 0.6 * k,
            0.04 * k * math.sin(rt * 0.9), 0.04 * k * math.sin(rt * 1.3 + 2), 0.04 * k * math.sin(rt * 1.1 + 4))
        DrawMotionBlur(0.35, 0.45 * k, 0.01)
    end
end)

-- Fades drawn over the HUD on the phases that use the normal view
hook.Add("PostDrawHUD", "MushroomMania.Trip", function()
    if not S or not S.phaseName then return end
    local phase, t = S.phaseName, S.pt
    local p = S.tl[phase]
    local dur = p[2] - p[1]

    cam.Start2D()
    if phase == "onset" then
        overlay(255, 255, 255, smooth(frac(t, dur * 0.55, dur)))
    elseif phase == "return" then
        overlay(0, 0, 0, 1 - smooth(t / dur))
    end
    cam.End2D()
end)

--------------------------------------------------------------------------------
-- What everyone sees on a tripper: spirals over the eyes + a cloud around the head
--------------------------------------------------------------------------------
function Trip.CloudColor(speciesId, offset)
    local sp = MM.GetSpecies(speciesId or "")
    if sp and sp.TripColor then return sp.TripColor end
    return HSVToColor((CurTime() * 40 + (offset or 0)) % 360, cfg().Cloud.Saturation, 1)
end

-- 0..1: fades in at the start of a trip and out at the end
local function tripFade(ply)
    local now = CurTime()
    local start, finish = ply:GetNW2Float("MM_TripStart", 0), ply:GetNW2Float("MM_TripEnd", 0)
    return math.min(smooth((now - start) / 1.5), smooth((finish - now) / 2))
end

hook.Add("PostPlayerDraw", "MushroomMania.TripSpirals", function(ply)
    local Sp = cfg().Spirals
    if not Sp.Enabled or not MM.IsTripping(ply) then return end
    if EyePos():DistToSqr(ply:EyePos()) > Sp.Distance * Sp.Distance then return end

    local id = ply:LookupAttachment("eyes")
    local att = id and id > 0 and ply:GetAttachment(id)
    if not att then return end

    local a = tripFade(ply)
    if a <= 0 then return end

    local fwd, right = att.Ang:Forward(), att.Ang:Right()
    local rot = (CurTime() * Sp.Spin) % 360
    render.SetMaterial(MAT_SPIRAL)
    for side = -1, 1, 2 do
        local pos = att.Pos + right * (side * Sp.Spacing) + fwd * Sp.Forward
        render.DrawQuadEasy(pos, fwd, Sp.Size, Sp.Size, Color(255, 255, 255, 255 * a), rot)
    end
end)

local emitters = {}

local function headPos(ply)
    local bone = ply:LookupBone("ValveBiped.Bip01_Head1")
    local pos = bone and ply:GetBonePosition(bone)
    if not pos or pos == ply:GetPos() then pos = ply:EyePos() end
    return pos
end

hook.Add("Think", "MushroomMania.TripCloud", function()
    local Cl = cfg().Cloud
    local lp = LocalPlayer()
    local dt = FrameTime()

    for ply, em in pairs(emitters) do
        if not IsValid(ply) or not MM.IsTripping(ply) then
            em:Finish()
            emitters[ply] = nil
        end
    end
    if not Cl.Enabled or dt <= 0 then return end

    local eye = EyePos()
    local maxDist = Cl.Distance * Cl.Distance
    for _, ply in ipairs(player.GetAll()) do
        if MM.IsTripping(ply) and ply:Alive() and not ply:IsDormant()
            and (ply ~= lp or lp:ShouldDrawLocalPlayer())
            and eye:DistToSqr(ply:GetPos()) <= maxDist then

            -- Fractional puffs carry over between frames
            ply.MM_CloudAcc = (ply.MM_CloudAcc or 0) + Cl.Rate * dt * tripFade(ply)
            if ply.MM_CloudAcc >= 1 then
                local head = headPos(ply)
                local em = emitters[ply]
                if not em then
                    em = ParticleEmitter(head)
                    emitters[ply] = em
                end
                em:SetPos(head)
                local species = ply:GetNW2String("MM_TripSpecies", "")

                while ply.MM_CloudAcc >= 1 do
                    ply.MM_CloudAcc = ply.MM_CloudAcc - 1
                    local p = em:Add(SMOKE, head + VectorRand() * 6)
                    if p then
                        local c = Trip.CloudColor(species, math.Rand(0, 120))
                        p:SetVelocity(VectorRand() * 6 + UP * 3)
                        p:SetDieTime(math.Rand(1.8, 2.6))
                        p:SetStartAlpha(Cl.Alpha)
                        p:SetEndAlpha(0)
                        p:SetStartSize(Cl.Size[1])
                        p:SetEndSize(Cl.Size[2] * math.Rand(0.8, 1.1))
                        p:SetRoll(math.Rand(0, 360))
                        p:SetRollDelta(math.Rand(-0.5, 0.5))
                        p:SetColor(c.r, c.g, c.b)
                        p:SetAirResistance(20)
                        p:SetGravity(UP * 2)
                        p:SetLighting(false)
                    end
                end
            end
        end
    end
end)
