local imgui     = require "imgui"
local assetmgr  = import_package "ant.asset"
local fs        = require "filesystem"
local lfs       = require "filesystem.local"
local vfs       = require "vfs"
local cr        = import_package "ant.compile_resource"
local datalist  = require "datalist"
local stringify = import_package "ant.serialize".stringify
local utils         = require "common.utils"
local uiutils       = require "widget.utils"
local math3d        = require "math3d"
local uiproperty    = require "widget.uiproperty"
local BaseView      = require "widget.view_class".BaseView
local MaterialView  = require "widget.view_class".MaterialView
local world
local imaterial

local mtldata_list = {

}

local surfacetype = {
    "foreground",
    "opaticy",
    "background",
    "translucent",
    "decal",
    "ui"
}

function MaterialView:_init()
    BaseView._init(self)
    self.mat_file       = uiproperty.ResourcePath({label = "File", extension = ".material"})
    self.vs_file        = uiproperty.ResourcePath({label = "VS", extension = ".sc", readonly = true})
    self.fs_file        = uiproperty.ResourcePath({label = "FS", extension = ".sc", readonly = true})
    self.save_mat       = uiproperty.Button({label = "Save"})
    self.save_as_mat    = uiproperty.Button({label = "SaveAs"})
    self.surfacetype    = uiproperty.Combo({label = "surfacetype", options = surfacetype},{})
    self.samplers       = {}
    self.uniforms       = {}
    self.float_uniforms = {}
    self.color_uniforms = {}
    self.sampler_num    = 0
    self.float_uniform_num  = 0
    self.color_uniform_num  = 0
    --
    self.mat_file:set_getter(function() return self:on_get_mat() end)
    self.mat_file:set_setter(function(value) self:on_set_mat(value) end)
    self.vs_file:set_getter(function() return self:on_get_vs() end)
    self.vs_file:set_setter(function(value) self:on_set_vs(value) end)
    self.fs_file:set_getter(function() return self:on_get_fs() end)
    self.fs_file:set_setter(function(value) self:on_set_fs(value) end)
    self.save_mat:set_click(function() self:on_save_mat() end)
    self.save_as_mat:set_click(function() self:on_saveas_mat() end)
    self.surfacetype:set_setter(function(value) self:on_set_surfacetype(value) end)      
    self.surfacetype:set_getter(function() return self:on_get_surfacetype() end)
    --
    self.ui_surfacetype = {text = "opaticy"}
    self.ui_lighting = {true}
    self.ui_shadow_receive = {false}
    self.ui_shadow_cast = {false}
    self.ui_postprocess = {false}
end
local gd = require "common.global_data"
function MaterialView:on_set_mat(value)
    -- local origin_path = fs.path(value)
    -- local relative_path = tostring(origin_path)
    -- if origin_path:is_absolute() then
    --     relative_path = tostring(fs.relative(fs.path(value), gd.project_root))
    -- end
    local new_eid = prefab_mgr:update_material(self.eid, value)
    self:set_model(new_eid)
end
function MaterialView:on_get_mat()
    return tostring(world[self.eid].material)
end
function MaterialView:on_set_vs(value)
    mtldata_list[self.eid].tdata.fx.vs = value
end
function MaterialView:on_get_vs()
    return mtldata_list[self.eid].tdata.fx.vs
end
function MaterialView:on_set_fs(value)
    mtldata_list[self.eid].tdata.fx.fs = value
end
function MaterialView:on_get_fs()
    return mtldata_list[self.eid].tdata.fx.fs
end
function MaterialView:on_set_surfacetype(value)
    mtldata_list[self.eid].tdata.fx.setting.surfacetype = value
end
function MaterialView:on_get_surfacetype()
    return mtldata_list[self.eid].tdata.fx.setting.surfacetype or "opaticy"
end

local function convert_path(path, current_path)
    if fs.path(path):is_absolute() then return path end
    local pretty = tostring(lfs.path(path))
    if string.sub(path, 1, 2) == "./" then
        pretty = string.sub(path, 3)
    end
    return current_path .. pretty
end

local do_save = function(eid, path)
    local mtl_path = tostring(fs.path(mtldata_list[eid].filename):remove_filename())
    local tempt = {}
    local tdata = mtldata_list[eid].tdata
    local properties = tdata.properties
    for k, v in pairs(properties) do
        if v.tdata then
            tempt[k] = v.tdata
            if v.texture then
                v.texture = convert_path(v.texture, mtl_path)
            end
            v.tdata = nil
        end
    end
    utils.write_file(path, stringify(tdata))
    for k, v in pairs(properties) do
        if tempt[k] then
            v.tdata = tempt[k]
        end
    end
end

function MaterialView:clear()
    if not self.eid then return end
    mtldata_list[self.eid] = nil
end

function MaterialView:on_save_mat()
    local path = self.mat_file:get_path()
    do_save(self.eid, path)
    assetmgr.unload(path)
end
function MaterialView:on_saveas_mat()
    local path = uiutils.get_saveas_path("Material", ".material")
    if path then
        do_save(self.eid, path)
        local vpath = "/" .. tostring(vfs.virtualpath(fs.path(path)))
        if vpath == self.mat_file:get_path() then
            assetmgr.unload(vpath)
        end
    end
end

local function is_sampler(str)
    return string.find(str,"s") == 1 and string.find(str,"_") == 2 
end

local function is_uniform(str)
    return string.find(str,"u") == 1 and string.find(str,"_") == 2
end

function MaterialView:get_sampler_property()
    self.sampler_num = self.sampler_num + 1
    if self.sampler_num > #self.samplers then
        self.samplers[#self.samplers + 1] = uiproperty.TextureResource({label = ""}, {})
    end
    return self.samplers[self.sampler_num]
end

function MaterialView:get_float_uniform_property()
    self.float_uniform_num = self.float_uniform_num + 1
    if self.float_uniform_num > #self.float_uniforms then
        self.float_uniforms[#self.float_uniforms + 1] = uiproperty.Float({label = "", dim = 4, speed = 0.01, min = 0, max = 1}, {})
    end
    return self.float_uniforms[self.float_uniform_num]
end

function MaterialView:get_color_uniform_property()
    self.color_uniform_num = self.color_uniform_num + 1
    if self.color_uniform_num > #self.color_uniforms then
        self.color_uniforms[#self.color_uniforms + 1] = uiproperty.Color({label = "", dim = 4}, {})
    end
    return self.color_uniforms[self.color_uniform_num]
end

local texture_used_idx = {
    ["s_basecolor"] = 1,
    ["s_normal"]    = 2,
    ["s_emissive"]  = 3,
    ["s_metallic_roughness"] = 4,
}

function MaterialView:set_model(eid)
    if not BaseView.set_model(self, eid) then return false end

    if not mtldata_list[eid] then
        --self.samplers = {}
        local mtl_filename = tostring(world[eid].material)
        local md = {filename = mtl_filename, tdata = datalist.parse(cr.read_file(mtl_filename))}
        local mtl_path = cr.compile(mtl_filename):remove_filename()
        for k, v in pairs(md.tdata.properties) do
            if is_sampler(k) then
                local absolute_path
                if fs.path(v.texture):is_absolute() then
                    print(v.texture)
                    absolute_path = tostring(cr.compile_path(v.texture))
                    print(absolute_path)
                else
                    absolute_path = tostring(mtl_path) .. v.texture 
                end
                v.tdata = utils.readtable(absolute_path)
            end
        end
        
        local setting = md.tdata.fx.setting
        self.ui_lighting[1] = setting.lighting and setting.lighting == "on"
        self.ui_shadow_receive[1] = setting.shadow_receive and setting.shadow_receive == "on"
        self.ui_shadow_cast[1] = setting.shadow_cast and setting.shadow_cast == "on"
        self.ui_postprocess[1] = setting.bloom and setting.bloom == "on"
        self.ui_surfacetype.text = setting.surfacetype or "opaticy"
        mtldata_list[eid] = md
    end

    self.sampler_num = 0
    self.uniforms = {}
    self.float_uniform_num = 0
    self.color_uniform_num = 0
    for k, v in pairs(mtldata_list[eid].tdata.properties) do
        if is_sampler(k) then
            local pro = self:get_sampler_property()
            pro:set_label(k)
            pro:set_getter(
                function()
                    local prop = imaterial.get_property(eid, k)
                    return prop and tostring(prop.value.texture) or ""
                end
            )
            pro:set_setter(
                function(value)
                    local runtime_tex = assetmgr.resource(value)
                    local tdata = mtldata_list[eid].tdata
                    local used_flags = tdata.properties.u_texture_flags
                    used_flags[texture_used_idx[k]] = 1
                    imaterial.set_property(eid, "u_texture_flags", used_flags)
                    local prop = imaterial.get_property(eid, k)
                    local mtl_filename = tostring(world[eid].material)
                    --local relative_path = lfs.relative(lfs.path(value), lfs.path(mtl_filename):remove_filename())
                    tdata.properties[k].texture = value--relative_path:string()
                    imaterial.set_property(eid, k, {stage = prop.value.stage, texture = {handle = runtime_tex._data.handle}})
                end
            )
        elseif is_uniform(k) then
            local pro
            if k == "u_color" then
                pro = self:get_color_uniform_property()
            else
                pro = self:get_float_uniform_property()
            end
            pro:set_label(k)
            pro:set_getter(
                function()
                    local prop = imaterial.get_property(eid, k)
                    return prop and math3d.totable(prop.value) or {0, 0, 0, 0}
                end
            )
            pro:set_setter(
                function(v)
                    local tdata = mtldata_list[eid].tdata
                    tdata.properties[k] = v
                    imaterial.set_property(eid, k, v)
                end
            )
            self.uniforms[#self.uniforms + 1] = pro
        end
    end
    table.sort(self.samplers, function(a, b) return a.label < b.label end)
    self:update()
    return true
end

function MaterialView:update()
    if not self.eid then return end
    BaseView.update(self)
    self.mat_file:update()
    self.vs_file:update()
    self.fs_file:update()
    self.surfacetype:update()
    for i = 1, self.sampler_num do
        self.samplers[i]:update()
    end
    for i = 1, #self.uniforms do
        self.uniforms[i]:update()
    end
end


function MaterialView:show()
    if not self.eid then return end
    BaseView.show(self)
    if imgui.widget.TreeNode("Material", imgui.flags.TreeNode { "DefaultOpen" }) then
        self.mat_file:show()
        self.save_mat:show()
        imgui.cursor.SameLine()
        self.save_as_mat:show()
        self.surfacetype:show()
        imgui.widget.PropertyLabel("lighting")
        local setting = mtldata_list[self.eid].tdata.fx.setting
        if imgui.widget.Checkbox("##lighting", self.ui_lighting) then
            if self.ui_lighting[1] then
                setting.lighting = "on"
            else
                setting.lighting = "off"
            end
        end
        imgui.widget.PropertyLabel("shadow_receive")
        if imgui.widget.Checkbox("##shadow_receive", self.ui_shadow_receive) then
            if self.ui_shadow_receive[1] then
                setting.shadow_receive = "on"
            else
                setting.shadow_receive = "off"
            end
        end
        imgui.widget.PropertyLabel("shadow_cast")
        if imgui.widget.Checkbox("##shadow_cast", self.ui_shadow_cast) then
            if self.ui_shadow_cast[1] then
                setting.shadow_cast = "on"
            else
                setting.shadow_cast = "off"
            end
        end
        imgui.widget.PropertyLabel("postprocess")
        if imgui.widget.Checkbox("##postprocess", self.ui_postprocess) then
            if self.ui_postprocess[1] then
                setting.bloom = "on"
            else
                setting.bloom = "off"
            end
        end
        for i = 1, self.sampler_num do
            self.samplers[i]:show()
        end
        for i = 1, #self.uniforms do
            self.uniforms[i]:show()
        end
        imgui.widget.TreePop()
    end
end

return function(w)
    world       = w
    imaterial   = world:interface "ant.asset|imaterial"
    prefab_mgr  = require "prefab_manager"(world)
    require "widget.base_view"(world)
    return MaterialView
end