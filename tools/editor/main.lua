package.path = "/engine/?.lua"
require "bootstrap"
import_package "ant.window".start {
    feature = {
        "ant.render",
        "tools.editor",
        "ant.anim_ctrl",
        "ant.animation",
        "ant.daynight",
        "ant.efk",
        "ant.landform",
        "ant.modifier",
        "ant.motion_sampler",
        "ant.objcontroller|pickup",
        "ant.objcontroller|pickup_detect",
        "ant.objcontroller|screen_3dobj",
        "ant.rmlui",
        "ant.imgui",
        "ant.sky|sky",
    }
}
