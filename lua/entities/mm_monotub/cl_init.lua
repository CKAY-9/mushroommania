include("shared.lua")

local MM = MushroomMania

function ENT:GetGlow()
    local state = self:GetState()
    if (state ~= MM.TUB_GROWING and state ~= MM.TUB_READY) or self:GetContaminated() then return end
    return MM.SpeciesGlow(self:GetSpecies())
end

function ENT:GetLabel()
    local C = MM.Config
    local T, F = C.Theme, C.Filter
    local state = self:GetState()
    local contaminated = self:GetContaminated()
    local growing = state == MM.TUB_GROWING
    local sp = MM.GetSpecies(self:GetSpecies())

    local lines = {}
    local function add(line) lines[#lines + 1] = line end

    add{ text = string.format("Uses left: %d / %d", self:GetUses(), C.MonoTub.Uses) }
    if contaminated then add{ text = "CONTAMINATED", color = T.Bad } end

    -- Status
    if state == MM.TUB_EMPTY then
        add{ text = "Needs substrate", color = T.Warn }
    elseif state == MM.TUB_SUBSTRATE then
        local c = self:GetClean()
        if c > 0 then
            add{ bar = c, text = string.format("Cleaning %d%%", math.floor(c * 100)), color = T.Water }
        else
            add{ text = "Needs cleaning agent", color = T.Warn }
        end
    elseif state == MM.TUB_CLEAN then
        add{ text = "Cleaned - add a liquid culture", color = T.Good }
    elseif growing then
        local p = self:GetProgress()
        add{ bar = p, color = sp and sp.Color or T.Accent,
             text = string.format("%s  %d%%  (%s)", sp and sp.Short or "Growing", math.floor(p * 100),
                MM.FormatTime((1 - p) * self:GetGrowTime())) }
    else
        add{ text = "Ready to harvest - Press E", color = T.Good }
    end

    -- Filters
    local n, maxF = self:GetFilters(), self:MaxFilters()
    local needsFilters = MM.NeedsFilters(sp)
    if n == 0 then
        local limit = self:GetRule("UnfilteredContaminateTime")
        if growing and not needsFilters then
            add{ text = "Filters: not needed", color = T.TextDim }
        elseif growing and not contaminated and limit > 0 then
            local left = limit - self:GetUnfiltered()
            add{ bar = left / limit, color = T.Bad,
                 text = string.format("NO FILTER - contaminated in %ds", math.ceil(left)) }
        else
            add{ text = string.format("Filters: 0 / %d", maxF), color = T.Warn }
        end
    else
        for i = 1, n do
            local hp = self:GetFilterHP(i)
            local frac = hp / F.Health
            local tag = ""
            if growing and not needsFilters then tag = "  (not needed)"
            elseif growing and not F.WearAll then tag = i == 1 and "  (in use)" or "  (spare)" end
            add{ bar = frac, color = frac > 0.3 and T.Good or T.Warn,
                 text = string.format("Filter %d  -  %ds%s", i, math.ceil(hp), tag) }
        end
        if n < maxF then add{ text = string.format("Filters: %d / %d", n, maxF) } end
    end

    -- Humidity & quality
    if growing then
        local hum = self:GetHumidity()
        local note = ""
        if hum < self:GetRule("IdealMin") then note = "  - too dry" elseif hum > self:GetRule("IdealMax") then note = "  - too wet" end
        add{ bar = hum / 100, color = note == "" and T.Water or T.Warn,
             text = string.format("Humidity %d%%%s", math.floor(hum), note) }

        local band = sp and sp.PerfectHumidity
        if band then
            local perfect = C.Qualities[1].Name
            if self:PerfectLost() then
                add{ text = perfect .. " lost (left " .. band[1] .. "-" .. band[2] .. "%)", color = T.Bad }
            else
                local inBand = hum >= band[1] and hum <= band[2]
                add{ text = string.format("%s needs %d-%d%%", perfect, band[1], band[2]), color = inBand and T.Good or T.Warn }
            end
        end
    end
    if growing or state == MM.TUB_READY then
        local q = MM.GetQuality(self:GetCurrentQuality())
        add{ text = "Quality: " .. q.Name, color = q.Color }
    end

    return "MonoTub", lines, sp and sp.Color
end
