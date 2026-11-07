--[[
    Mushroom Mania - Base entity
    Every Mushroom Mania entity derives from this. It handles:
      - config-driven model / color / material / health  (ENT.ConfigKey -> MushroomMania.Config[key])
      - DarkRP ownership (owning_ent)
      - combining: an entity with ENT.MMKind set that touches an entity with
        ENT:MM_Receive(item) is offered to it (see init.lua)
      - floating 3D labels: define ENT:GetLabel() on the client (see cl_init.lua)

    Subclass hooks:
      ENT:SetupVars()          add NetworkVars (Entity slot 0 is taken by owning_ent)
      ENT:OnInitialize(cfg, restored)  server, after the model / physics are set up.
                               restored = re-created from the pocket / duplicator
      ENT:GetLabel()           client, returns title, lines, accentColor
]]

ENT.Type        = "anim"
ENT.Base        = "base_gmodentity"
ENT.PrintName   = "Mushroom Mania Base"
ENT.Author      = "Mushroom Mania"
ENT.Category    = "Mushroom Mania"
ENT.Spawnable   = false
ENT.RenderGroup = RENDERGROUP_BOTH

ENT.MMEntity    = true
ENT.ConfigKey   = nil   -- Key in MushroomMania.Config
ENT.MMKind      = nil   -- "substrate", "filter", "culture", "mushrooms" ... for combinable items
ENT.Pickupable  = false -- Allow E pickup even without an MMKind

function ENT:SetupDataTables()
    self:NetworkVar("Entity", 0, "owning_ent")
    -- True once initialised. Survives the DarkRP pocket / duplicator (they restore
    -- network vars before Spawn), so OnInitialize can tell a fresh entity from a
    -- re-created one. Bool slot 31 keeps slots 0+ free for subclasses.
    self:NetworkVar("Bool", 31, "MMInitialized")
    if self.SetupVars then self:SetupVars() end
end

function ENT:GetConfig()
    return MushroomMania.Config[self.ConfigKey or ""] or {}
end

-- Override to pick a model dynamically (e.g. per species)
function ENT:GetModelPath()
    return self:GetConfig().Model or "models/props_junk/cardboard_box004a.mdl"
end
