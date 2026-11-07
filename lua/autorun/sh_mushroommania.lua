--[[
    Mushroom Mania - DarkRP mushroom cultivation addon
    Loader
]]

MushroomMania = MushroomMania or {}

local function shared(path)
    if SERVER then AddCSLuaFile(path) end
    include(path)
end

local function client(path)
    if SERVER then AddCSLuaFile(path) else include(path) end
end

local function server(path)
    if SERVER then include(path) end
end

shared("mushroommania/sh_config.lua")
shared("mushroommania/sh_core.lua")
shared("mushroommania/sh_settings.lua")
server("mushroommania/sv_core.lua")
server("mushroommania/sv_settings.lua")
server("mushroommania/sv_resources.lua")
client("mushroommania/cl_core.lua")
client("mushroommania/cl_settings.lua")
