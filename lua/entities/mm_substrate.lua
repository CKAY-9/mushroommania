--[[
    Mushroom Mania - Substrate
    Drop into an empty MonoTub. Used up on harvest.
]]
AddCSLuaFile()

ENT.Type      = "anim"
ENT.Base      = "mm_base"
ENT.PrintName = "Substrate"
ENT.Category  = "Mushroom Mania"
ENT.Spawnable = true
ENT.ConfigKey = "Substrate"
ENT.MMKind    = "substrate"

if SERVER then return end

function ENT:GetLabel()
    return "Substrate", {
        { text = "Single use" },
        { text = "Drop into an empty MonoTub" },
    }
end
