local ecs   = ...
local world = ecs.world
local w     = world.w

local iuvm = ecs.interface "iuv_motion"
local iqm = ecs.import.interface "ant.render|iqueue_materials"

function iuvm.set_speed(e, speed)
    iqm.set_property(e, "u_motion_speed", {speed[1], speed[2], 0.0, 0.0})
end