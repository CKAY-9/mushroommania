AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

local MM = MushroomMania

function ENT:OnInitialize()
    self.Batches = {} -- { species, quality, grams }, merged by species + quality
    self:SetState(self.IDLE)
    self:Sync()
    self:UpdateBodygroups()
end

-- Applies Config.FoodDrier.Bodygroups for the current state (only "running" while drying)
function ENT:UpdateBodygroups()
    local groups = self:GetConfig().Bodygroups
    if not groups then return end

    local running = self:GetState() == self.DRYING
    self.MM_BGCache = self.MM_BGCache or {}
    for name, values in pairs(groups) do
        local idx = self.MM_BGCache[name]
        if idx == nil then
            idx = self:FindBodygroupByName(name)
            self.MM_BGCache[name] = idx
        end
        local value = running and values.Running or values.Idle
        if idx >= 0 and value and self:GetBodygroup(idx) ~= value then
            self:SetBodygroup(idx, value)
        end
    end
end

function ENT:Sync()
    local total, parts = 0, {}
    for _, b in ipairs(self.Batches) do
        total = total + b.grams
        parts[#parts + 1] = b.species .. "|" .. b.quality .. "|" .. b.grams
    end
    self:SetStored(total)
    self:SetContents(table.concat(parts, ";"))
end

--------------------------------------------------------------------------------
-- Loading
--------------------------------------------------------------------------------
function ENT:MM_Receive(item)
    if item.MMKind ~= "mushrooms" then return false end

    local state = self:GetState()
    if state == self.DRYING then return false, "The Food Drier is running. Wait for it to finish." end
    if state == self.DONE then return false, "Collect the dried mushrooms first." end
    if item:GetDried() then return false, "Those mushrooms are already dried." end

    local grams = item:GetAmount()
    local room = self:Capacity() - self:GetStored()
    if grams > room then
        local unit = MM.Config.Mushrooms.Unit
        return false, string.format("Not enough room: %d%s free, that batch is %d%s.", room, unit, grams, unit)
    end

    local species, quality = item:GetSpecies(), item:GetQuality()
    local merged = false
    for _, b in ipairs(self.Batches) do
        if b.species == species and b.quality == quality then
            b.grams = b.grams + grams
            merged = true
            break
        end
    end
    if not merged then
        self.Batches[#self.Batches + 1] = { species = species, quality = quality, grams = grams }
    end

    self:Sync()
    MM.PlaySound(self, "Insert")
    return true
end

--------------------------------------------------------------------------------
-- Running
--------------------------------------------------------------------------------
function ENT:StartLoop()
    local cfg = self:GetConfig()
    if not cfg.LoopSound or cfg.LoopSound == "" then return end
    if not self.Loop then
        self.Loop = CreateSound(self, cfg.LoopSound)
        self.Loop:SetSoundLevel(cfg.SoundLevel or 90)
    end
    if not self.Loop:IsPlaying() then
        self.Loop:PlayEx(cfg.Volume or 1, cfg.Pitch or 100)
    end
end

function ENT:StopLoop()
    if self.Loop then self.Loop:Stop() end
end

function ENT:StartDrying(ply)
    local now = CurTime()
    self:SetState(self.DRYING)
    self:SetDryStart(now)
    self:SetDryEnd(now + math.max(1, self:GetConfig().DryTime or 120))
    self:UpdateBodygroups()
    MM.PlaySound(self, "DrierStart", 75)
    self:StartLoop()
    MM.Notify(ply, "Food Drier started. Back in " .. MM.FormatTime(self:GetTimeLeft()) .. ".", 0)
end

function ENT:FinishDrying()
    self:SetState(self.DONE)
    self:UpdateBodygroups()
    self:StopLoop()
    MM.PlaySound(self, "Dried", 75)
end

function ENT:Collect(ply)
    local mins, maxs = self:WorldSpaceAABB()
    for i, b in ipairs(self.Batches) do
        local bag = ents.Create("mm_mushrooms")
        if IsValid(bag) then
            bag:SetPos(Vector((mins.x + maxs.x) * 0.5, (mins.y + maxs.y) * 0.5, maxs.z + 8 + (i - 1) * 8))
            bag:SetAngles(Angle(0, ply:EyeAngles().y, 0))
            bag:Spawn()
            bag:Activate()
            bag:SetBatch(b.species, b.quality, b.grams, true)
            MM.SetOwner(bag, ply)
        end
    end

    local grams = self:GetStored()
    self.Batches = {}
    self:SetState(self.IDLE)
    self:SetDryStart(0)
    self:SetDryEnd(0)
    self:Sync()
    MM.PlaySound(self, "Harvest")
    MM.Notify(ply, string.format("Collected %d%s of dried mushrooms.", grams, MM.Config.Mushrooms.Unit), 0)
end

function ENT:Use(ply)
    if not IsValid(ply) or not ply:IsPlayer() then return end

    local state = self:GetState()
    if state == self.IDLE and self:GetStored() > 0 then
        self:StartDrying(ply)
    elseif state == self.DONE then
        self:Collect(ply)
    else
        MM.Notify(ply, self:GetHint(), 3)
    end
end

function ENT:Think()
    if self:GetState() == self.DRYING then
        if CurTime() >= self:GetDryEnd() then
            self:FinishDrying()
        else
            self:StartLoop() -- Restarts the sound if the file isn't a seamless loop
        end
    end
    self:NextThink(CurTime() + 0.5)
    return true
end

function ENT:OnRemove()
    self:StopLoop()
end
