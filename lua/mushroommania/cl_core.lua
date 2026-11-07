--[[
    Mushroom Mania - Client core (fonts + floating 3D labels)
]]

local MM = MushroomMania

local function createFonts()
    local f = MM.Config.Theme.Font
    surface.CreateFont("MM.LabelTitle", { font = f, size = 40, weight = 800, antialias = true })
    surface.CreateFont("MM.LabelText",  { font = f, size = 28, weight = 500, antialias = true })
    surface.CreateFont("MM.LabelBar",   { font = f, size = 22, weight = 700, antialias = true })
    surface.CreateFont("MM.HUD",        { font = f, size = 22, weight = 600, antialias = true })
end
createFonts()
hook.Add("OnScreenSizeChanged", "MushroomMania.Fonts", createFonts)

--------------------------------------------------------------------------------
-- Species glow: a soft additive sprite behind the entity, so it shows as a halo
-- around the model's silhouette. glow = { Color, Alpha, Size } (see Config.Species)
--------------------------------------------------------------------------------
local GLOW_MAT  = Material("sprites/light_glow02_add")
local GLOW_DIST = 1500 * 1500

function MM.DrawGlow(ent, glow)
    local pos = ent:WorldSpaceCenter()
    if EyePos():DistToSqr(pos) > GLOW_DIST then return end

    local col = glow.Color or color_white
    local pulse = 0.85 + 0.15 * math.sin(CurTime() * 2 + ent:EntIndex())
    local size = ent:BoundingRadius() * 2.2 * (glow.Size or 1)

    render.SetMaterial(GLOW_MAT)
    render.DrawSprite(pos, size, size, Color(col.r, col.g, col.b, (glow.Alpha or 50) * pulse))
end

-- Glow settings for a species id, if it has any
function MM.SpeciesGlow(id)
    local sp = MM.GetSpecies(id or "")
    return sp and sp.Glow
end

local PAD     = 16
local TITLE_H = 42
local LINE_H  = 32
local BAR_H   = 26
local GAP     = 6
local MIN_W   = 300

local function lineHeight(line)
    return line.bar and (BAR_H + GAP) or LINE_H
end

local function drawBar(x, y, w, h, frac, col, text, font)
    local T = MM.Config.Theme
    draw.RoundedBox(4, x, y, w, h, T.BarBack)
    frac = math.Clamp(frac or 0, 0, 1)
    if frac > 0 then
        draw.RoundedBox(4, x, y, math.max(8, w * frac), h, col)
    end
    if text then
        draw.SimpleTextOutlined(text, font or "MM.LabelBar", x + w / 2, y + h / 2, T.Text,
            TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, Color(0, 0, 0, 160))
    end
end
MM.DrawBar = drawBar

--[[
    Draws a billboard label whose bottom edge sits at `pos`.
    lines = {
        { text = "Plain line", color = Color(...) },
        { bar = 0.5, text = "Text on the bar", color = Color(...) },
    }
]]
function MM.DrawLabel(pos, title, lines, maxDist, accent)
    local T = MM.Config.Theme
    maxDist = maxDist or 300

    local dist = EyePos():Distance(pos)
    if dist > maxDist then return end
    local fade = 1 - math.Clamp((dist - maxDist * 0.75) / (maxDist * 0.25), 0, 1)

    lines = lines or {}

    -- Measure
    surface.SetFont("MM.LabelTitle")
    local w = surface.GetTextSize(title)
    local h = PAD + TITLE_H + GAP
    surface.SetFont("MM.LabelText")
    for _, line in ipairs(lines) do
        if line.text and not line.bar then
            w = math.max(w, (surface.GetTextSize(line.text)))
        end
        h = h + lineHeight(line)
    end
    w = math.max(w, MIN_W) + PAD * 2
    h = h + PAD - GAP

    local ang = Angle(0, EyeAngles().y - 90, 90)

    surface.SetAlphaMultiplier(fade)
    cam.Start3D2D(pos, ang, T.LabelScale)
        local x, y = -w / 2, -h

        draw.RoundedBox(8, x, y, w, h, T.Background)
        draw.RoundedBoxEx(8, x, y, w, 5, accent or T.Accent, true, true, false, false)

        draw.SimpleText(title, "MM.LabelTitle", 0, y + PAD, T.Text, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)

        local cy = y + PAD + TITLE_H + GAP
        for _, line in ipairs(lines) do
            if line.bar then
                drawBar(x + PAD, cy, w - PAD * 2, BAR_H, line.bar, line.color or T.Accent, line.text)
            else
                draw.SimpleText(line.text or "", "MM.LabelText", 0, cy, line.color or T.TextDim, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
            end
            cy = cy + lineHeight(line)
        end
    cam.End3D2D()
    surface.SetAlphaMultiplier(1)
end
