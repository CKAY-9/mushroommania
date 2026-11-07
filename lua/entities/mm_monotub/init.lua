AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

local MM = MushroomMania

function ENT:SetFilterHP(i, v)
    local fn = self["SetFilterHP" .. i]
    if fn then fn(self, v) end
end

function ENT:OnInitialize(cfg)
    self:SetUses(cfg.Uses)
    self:SetFilters(0)
    self:ResetGrow()
    self.MM_LastThink = CurTime()
end

function ENT:ResetGrow()
    self:SetState(MM.TUB_EMPTY)
    self:SetClean(0)
    self:SetProgress(0)
    self:SetScore(100)
    self:SetHumidity(0)
    self:SetUnfiltered(0)
    self:SetPerfectMiss(0)
    self:SetContaminated(false)
    self:SetSpecies("")
    self:UpdateColor()
    self:UpdateBodygroups()
end

--------------------------------------------------------------------------------
-- Bodygroups (Config.MonoTub.Bodygroups). Safe to call any time: only changes
-- parts whose visibility differs, and ignores names the model doesn't have.
--------------------------------------------------------------------------------
function ENT:GetBodygroupIndex(name)
    if not name or name == "" then return -1 end
    self.MM_BGCache = self.MM_BGCache or {}
    local idx = self.MM_BGCache[name]
    if idx == nil then
        idx = self:FindBodygroupByName(name)
        self.MM_BGCache[name] = idx
    end
    return idx
end

function ENT:SetPartVisible(name, visible)
    local idx = self:GetBodygroupIndex(name)
    if idx < 0 then return end
    local value = visible and 1 or 0
    if self:GetBodygroup(idx) ~= value then self:SetBodygroup(idx, value) end
end

function ENT:UpdateBodygroups()
    local cfg = self:GetConfig()
    local bg = cfg.Bodygroups
    if not bg then return end

    local state   = self:GetState()
    local filters = self:GetFilters()
    local growing = state == MM.TUB_GROWING
    local ready   = state == MM.TUB_READY

    self:SetPartVisible(bg.Substrate, state ~= MM.TUB_EMPTY)
    self:SetPartVisible(bg.Filter1,   filters >= 1)
    self:SetPartVisible(bg.Filter2,   filters >= 2)
    self:SetPartVisible(bg.Pins,      growing or ready)
    self:SetPartVisible(bg.Lid,       growing or (ready and cfg.LidWhenReady))
end

function ENT:UpdateColor()
    local cfg = self:GetConfig()
    if self:GetContaminated() and cfg.ContaminatedColor then
        self:SetColor(cfg.ContaminatedColor)
    else
        self:SetColor(cfg.Color or color_white)
    end
end

--------------------------------------------------------------------------------
-- Combining
--------------------------------------------------------------------------------
function ENT:MM_Receive(item, ply)
    local ok, reason = self:ReceiveItem(item, ply)
    if ok then self:UpdateBodygroups() end
    return ok, reason
end

function ENT:ReceiveItem(item, ply)
    local kind  = item.MMKind
    local state = self:GetState()

    if kind == "substrate" then
        if state ~= MM.TUB_EMPTY then return false, "This MonoTub already has substrate." end
        self:SetState(MM.TUB_SUBSTRATE)
        MM.PlaySound(self, "Insert")
        MM.Notify(ply, "Substrate added. Fit filters, then pour in the cleaning agent.", 0)
        return true

    elseif kind == "filter" then
        local n = self:GetFilters()
        if n >= self:MaxFilters() then
            return false, "This MonoTub already has " .. n .. " filters."
        end
        self:SetFilterHP(n + 1, item:GetFilterHealth())
        self:SetFilters(n + 1)
        self:SetUnfiltered(0)
        MM.PlaySound(self, "Insert")
        return true

    elseif kind == "culture" then
        local sp = item:GetSpecies()
        if not sp then return false end

        if state == MM.TUB_EMPTY then return false, "Add substrate to the MonoTub first." end
        if state == MM.TUB_SUBSTRATE and MM.NeedsCleaning(sp) then
            return false, "Pour cleaning agent on the MonoTub first."
        end
        if state ~= MM.TUB_CLEAN and state ~= MM.TUB_SUBSTRATE then return false, "This MonoTub is already in use." end

        -- Strains that contaminate instantly without a filter would be ruined on the first tick
        if MM.NeedsFilters(sp) and self:GetFilters() == 0 and MM.SpeciesRule(sp, "UnfilteredContaminateTime") <= 0 then
            return false, sp.Name .. " needs a filter fitted before it goes in."
        end

        self:SetSpecies(item.Species)
        self:SetState(MM.TUB_GROWING)
        self:SetHumidity(MM.SpeciesRule(sp, "StartHumidity"))
        self:SetScore(100)
        self:SetProgress(0)
        self:SetUnfiltered(0)
        self:SetPerfectMiss(0)
        self.MM_LastThink = CurTime()
        MM.PlaySound(self, "InsertCulture")
        MM.Notify(ply, sp.Name .. " is growing. Keep it misted!", 0)
        return true
    end
end

-- Called by a pouring Cleaning Agent every tick its stream hits this tub
function ENT:AddCleaning(dt, ply)
    if self:GetState() ~= MM.TUB_SUBSTRATE then return false end

    local c = self:GetClean() + dt / math.max(MM.Config.CleaningAgent.CleanTime, 0.1)
    if c >= 1 then
        self:SetClean(1)
        self:SetState(MM.TUB_CLEAN)
        MM.PlaySound(self, "Cleaned")
        MM.Notify(ply, "MonoTub cleaned. Add a liquid culture.", 0)
    else
        self:SetClean(c)
    end
    return true
end

-- Called by the Spray Bottle
function ENT:Spray(amount)
    if self:GetState() ~= MM.TUB_GROWING then
        return false, "Only a growing MonoTub needs misting."
    end
    self:SetHumidity(math.min(100, self:GetHumidity() + amount))
    return true
end

--------------------------------------------------------------------------------
-- Growing
--------------------------------------------------------------------------------
function ENT:Contaminate()
    if self:GetContaminated() then return end
    self:SetContaminated(true)
    self:UpdateColor()
    MM.PlaySound(self, "Contaminated")
    MM.Notify(MM.GetOwner(self), "Your MonoTub got contaminated!", 1)
end

-- Drops dead filters and shifts the rest down
function ENT:CompactFilters()
    local n = self:GetFilters()
    local alive = {}
    for i = 1, n do
        local hp = self:GetFilterHP(i)
        if hp > 0 then alive[#alive + 1] = hp end
    end
    if #alive == n then return end

    for i = 1, self.MaxFilterSlots do
        self:SetFilterHP(i, alive[i] or 0)
    end
    self:SetFilters(#alive)
    MM.PlaySound(self, "FilterBroken")

    local msg = "A filter on your MonoTub wore out."
    local limit = self:GetRule("UnfilteredContaminateTime")
    if #alive == 0 and self:GetState() == MM.TUB_GROWING and not self:GetContaminated()
        and MM.NeedsFilters(self:GetSpeciesData()) and limit > 0 then
        msg = msg .. " Replace it within " .. limit .. "s or it'll be contaminated!"
    end
    MM.Notify(MM.GetOwner(self), msg, 1)
end

function ENT:GrowTick(dt)
    local F = MM.Config.Filter
    local sp = self:GetSpeciesData()

    -- Filters (strains that don't need them never wear them or contaminate)
    if MM.NeedsFilters(sp) then
        local n = self:GetFilters()
        local rate = F.DegradeRate or 0
        if n > 0 and rate > 0 then
            for i = 1, (F.WearAll and n or 1) do
                self:SetFilterHP(i, self:GetFilterHP(i) - rate * dt)
            end
            self:CompactFilters()
        end

        if self:GetFilters() == 0 and not self:GetContaminated() then
            local u = self:GetUnfiltered() + dt
            self:SetUnfiltered(u)
            if u >= self:GetRule("UnfilteredContaminateTime") then self:Contaminate() end
        end
    end

    -- Humidity
    local hum = math.max(0, self:GetHumidity() - self:GetRule("HumidityDecay") * dt)
    self:SetHumidity(hum)
    if hum < self:GetRule("IdealMin") or hum > self:GetRule("IdealMax") then
        self:SetScore(math.max(0, self:GetScore() - self:GetRule("QualityLoss") * dt))
    end

    local band = sp and sp.PerfectHumidity
    if band and (hum < band[1] or hum > band[2]) then
        local wasLost = self:PerfectLost()
        self:SetPerfectMiss(self:GetPerfectMiss() + dt)
        if not wasLost and self:PerfectLost() then
            MM.Notify(MM.GetOwner(self), string.format("Your %s left %d-%d%% humidity and can no longer be %s.",
                sp.Short or sp.Name, band[1], band[2], MM.Config.Qualities[1].Name), 1)
        end
    end

    -- Growth
    local p = self:GetProgress() + dt / math.max(self:GetGrowTime(), 1)
    if p >= 1 then
        self:SetProgress(1)
        self:SetState(MM.TUB_READY)
        MM.PlaySound(self, "Ready")
        local sp = MM.GetSpecies(self:GetSpecies())
        MM.Notify(MM.GetOwner(self), "Your " .. (sp and sp.Short or "mushroom") .. " MonoTub is ready to harvest.", 0)
    else
        self:SetProgress(p)
    end
end

function ENT:Think()
    local now = CurTime()
    local dt = now - (self.MM_LastThink or now)
    self.MM_LastThink = now

    if dt > 0 and self:GetState() == MM.TUB_GROWING then
        self:GrowTick(dt)
    end
    self:UpdateBodygroups()

    self:NextThink(now + 0.25)
    return true
end

--------------------------------------------------------------------------------
-- Harvest
--------------------------------------------------------------------------------
function ENT:Harvest(ply)
    local cfg = self:GetConfig()
    if cfg.OwnerOnlyHarvest and MM.GetOwner(self) ~= ply then
        MM.Notify(ply, "This isn't your MonoTub.", 1)
        return
    end

    local speciesId = self:GetSpecies()
    local sp = MM.GetSpecies(speciesId)
    local quality = self:GetCurrentQuality()
    local amount = sp and math.random(sp.Yield[1], sp.Yield[2]) or 1

    local mins, maxs = self:WorldSpaceAABB()
    local bag = ents.Create("mm_mushrooms")
    if IsValid(bag) then
        bag:SetPos(Vector((mins.x + maxs.x) * 0.5, (mins.y + maxs.y) * 0.5, maxs.z + 12))
        bag:SetAngles(Angle(0, ply:EyeAngles().y, 0))
        bag:Spawn()
        bag:Activate()
        bag:SetBatch(speciesId, quality, amount, false)
        MM.SetOwner(bag, ply)
    end

    MM.PlaySound(self, "Harvest")
    MM.Notify(ply, string.format("Harvested %d%s of %s (%s).", amount, MM.Config.Mushrooms.Unit,
        sp and sp.Short or "mushrooms", MM.GetQuality(quality).Name), 0)

    -- Filters wear a little each harvest (optional)
    local wear = MM.Config.Filter.WearPerHarvest or 0
    if wear > 0 then
        for i = 1, self:GetFilters() do
            self:SetFilterHP(i, self:GetFilterHP(i) - wear)
        end
        self:CompactFilters()
    end

    -- Substrate is used up
    self:ResetGrow()

    local uses = self:GetUses() - 1
    self:SetUses(uses)
    if uses <= 0 then
        MM.Notify(ply, "The MonoTub has worn out.", 1)
        MM.PlaySound(self, "TubBroken")
        local fx = EffectData()
        fx:SetOrigin(self:WorldSpaceCenter())
        util.Effect("GlassImpact", fx)
        self:Remove()
    end
end

function ENT:Use(ply)
    if not IsValid(ply) or not ply:IsPlayer() then return end
    if self:GetState() == MM.TUB_READY then
        self:Harvest(ply)
    else
        MM.Notify(ply, self:GetHint(), 3)
    end
end
