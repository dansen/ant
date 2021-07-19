local ecs = ...
local world = ecs.world

local math3d = require "math3d"

local ientity = world:interface "ant.render|entity"
local ies = world:interface "ant.scene|ientity_state"
local init_loader_sys = ecs.system 'init_loader_system'
local imaterial = world:interface "ant.asset|imaterial"
local mathpkg = import_package"ant.math"
local mc, mu = mathpkg.constant, mathpkg.util

local camerapkg = import_package"ant.camera"
local split_frustum = camerapkg.split_frustum

local geo = import_package "ant.geometry".geometry

local function create_plane_test()
    local planes = {
        {
            srt = {s ={50, 1, 50}},
            color = {0.8, 0.8, 0.8, 1},
            material = "/pkg/ant.resources/materials/mesh_shadow.material",
        },
    }

    for _, p in ipairs(planes) do
        local eid = ientity.create_plane_entity(
            p.srt,
            p.material,
            "test shadow plane",
            {
                ["ant.collision|collider_policy"] = {
                    collider = {
                        box = {{
                            origin = { 0, 0, 0, 1 },
                            size = {50, 0.001, 50},
                        }}
                    },
                },
                ["ant.render|debug_mesh_bounding"] = {
                    debug_mesh_bounding = true,
                }
            })
        imaterial.set_property(eid, "u_basecolor_factor", p.color)
    end
end

local icamera = world:interface "ant.camera|camera"
local iom = world:interface "ant.objcontroller|obj_motion"

local function target_lock_test()
    local eid = world:create_entity{
        policy = {
            "ant.general|name",
            "ant.render|render",
        },
        data = {
            name = "lock_target",
            state = ies.create_state "visible",
            transform =  {
                s = {2, 1, 2, 0},
                t = {16, 1, 6},
            },
            mesh = "/pkg/ant.resources/meshes/sphere.mesh",
            material = "/pkg/ant.resources/materials/singlecolor.material",
            scene_entity = true,
        }
    }

    local lock_eid = world:create_entity {
        policy = {
            "ant.general|name",
            "ant.render|render",
            "ant.scene|hierarchy_policy",
            "ant.scene|lock_target_policy",
        },
        data = {
            name = "lock_obj",
            state = ies.create_state "visible",
            transform =  {t={0, 0, -6}},
            lock_target = {
                type = "ignore_scale",
                offset = {0, 0, 3},
            },
            mesh = "/pkg/ant.resources/meshes/cube.mesh",
            material = "/pkg/ant.resources/materials/singlecolor.material",
            scene_entity = true,
        },
        action = {
            mount = eid,
        }
    }
end

local function find_entity(name, whichtype)
    for _, eid in world:each(whichtype) do
        if world[eid].name:match(name) then
            return eid
        end
    end
end

local function point_light_test()
    local pl_pos = {
        {  1, 0, 1},
        { -1, 0, 1},
        { -1, 0,-1},
        {  1, 0,-1},
        {  1, 2, 1},
        { -1, 2, 1},
        { -1, 2,-1},
        {  1, 2,-1},

        {  3, 0, 3},
        { -3, 0, 3},
        { -3, 0,-3},
        {  3, 0,-3},
        {  3, 2, 3},
        { -3, 2, 3},
        { -3, 2,-3},
        {  3, 2,-3},
    }

    local  lighteid = world:instance "/pkg/ant.test.features/assets/entities/light_point.prefab"[1]
    iom.set_position(lighteid, {0, 1, 0, 1})

    -- for _, p in ipairs(pl_pos) do
    --     local  lighteid = world:instance "/pkg/ant.test.features/assets/entities/light_point.prefab"[1]
    --     iom.set_position(lighteid, p)
    -- end

    -- local cubeeid = world:instance "/pkg/ant.test.features/assets/entities/pbr_cube.prefab"[1]
    -- iom.set_position(cubeeid, {0, 0, 0, 1})

    local eid = world:instance "/pkg/ant.test.features/assets/entities/light_directional.prefab"[1]

    -- for _, r in ipairs{
    --     math3d.quaternion{2.4, 0, 0},
    --     math3d.quaternion{-2.4, 0, 0},
    --     math3d.quaternion{0, 1, 0},
    -- } do
    --     local eid = world:instance "/pkg/ant.test.features/assets/entities/light_directional.prefab"[1]
    --     iom.set_rotation(eid, r)
    -- end
end

local icc = world:interface "ant.test.features|icamera_controller"
local iccqs = world:interface "ant.quad_sphere|icamera_controller"

function init_loader_sys:init()
    --point_light_test()
    ientity.create_grid_entity("polyline_grid", 64, 64, 1, 5)

    --world:instance "/pkg/ant.test.features/assets/entities/font_tt.prefab"
    --world:instance "/pkg/ant.resources.binary/meshes/female/female.glb|mesh.prefab"

    --ientity.create_procedural_sky()
    --target_lock_test()

    --ientity.create_skybox()
    --world:instance "/pkg/ant.test.features/assets/glb/Duck.glb|mesh.prefab"

    world:create_entity{
        policy = {
            "ant.render|render",
            "ant.heightmap|auto_heightmap",
            "ant.general|name",
        },
        data = {
            auto_heightmap = true,
            transform = {},
            material = "/pkg/ant.test.features/assets/glb/Duck.glb|materials/blinn3-fx_CW.material",
            mesh = "/pkg/ant.test.features/assets/glb/Duck.glb|meshes/LOD3spShape_P1.meshbin",
            state = 1,
            scene_entity = true,
            name = "test_auot_heightmap",
        }
    }

    world:pub{"fetch_heightmap"}

    --world:instance "/pkg/ant.resources.binary/meshes/cloud_run.glb|mesh.prefab"
    --world:instance "/pkg/ant.test.features/assets/CloudTestRun.glb|mesh.prefab"

    -- local eid = world:create_entity {
    --     policy = {
    --         "ant.general|name",
    --         "ant.render|render",
    --         "ant.scene|transform_policy",
    --     },
    --     data = {
    --         name = "collider",
    --         scene_entity = true,
    --         transform = {s=100},
    --         --color = {1.0, 0.5, 0.5, 0.5},
    --         state = ies.create_state "visible|selectable",
    --         material = "/pkg/ant.resources/materials/singlecolor.material",
    --         mesh = "/pkg/ant.resources.binary/meshes/base/cube.glb|meshes/pCube1_P1.meshbin",
    --     }
    -- }

    icc.create()
    iccqs.create()
end

local camera_cache = {
    icc = {
        pos = math3d.ref(math3d.vector()),
        dir = math3d.ref(math3d.vector()),
        updir = math3d.ref(math3d.vector()),
    },
    iccqs = {
        pos = math3d.ref(math3d.vector()),
        dir = math3d.ref(math3d.vector()),
        updir = math3d.ref(math3d.vector()),
    }
}

function init_loader_sys:post_init()
    local mq = world:singleton_entity "main_queue"

    local eid = world:instance "/pkg/ant.test.features/assets/entities/cube.prefab"[1]
    iom.set_scale(eid, 0.1)

    icc.attach(mq.camera_eid)
    iccqs.attach(mq.camera_eid)
    icamera.controller(mq.camera_eid, icc.get())

    camera_cache.icc.pos.v = {-10.5, 10, -5.5, 1}
    camera_cache.icc.dir.v = math3d.sub(mc.ZERO_PT, camera_cache.icc.pos)
    camera_cache.icc.updir.v = mc.YAXIS
    icamera.lookto(mq.camera_eid, camera_cache.icc.pos, camera_cache.icc.dir)

    iom.set_rotation(mq.camera_eid, math3d.quaternion(0.3893,0.1568,-0.0674,0.9052))
    -- icamera.set_dof(mq.camera_eid, {
    --     -- aperture_fstop      = 2.8,
    --     -- aperture_blades     = 0,
    --     -- aperture_rotation   = 0,
    --     -- aperture_ratio      = 1,
    --     -- sensor_size         = 100,
    --     -- focus_distance      = 5,
    --     -- focal_len           = 84,
    --     focuseid            = world:create_entity {
    --         policy = {
    --             "ant.render|simplerender"
    --         },
    --         data = {
    --             transform = {},
    --             simplemesh = {},
    --             state = "",
    --         }
    --     },
    --     enable              = true,
    -- })
    -- local dir = {0, 0, 1, 0}
    -- icamera.lookto(mq.camera_eid, {0, 0, -8, 1}, dir)
    -- local ipl = world:interface "ant.render|ipolyline"
    -- ipl.add_strip_lines({
    --     {0, 0, 0}, {0.5, 0, 1}, {1, 0, 0},
    -- }, 15, {1.0, 1.0, 0.0, 1.0})
end


local function sphere_closest_pt_to_aabb(center, aabb)
    local q = {}
    -- For each coordinate axis, if the point coordinate value is
    -- outside box, clamp it to the box, else keep it as is
    for i=1, 3 do
        q[i] = mu.limit(center[i], aabb.minv[i], aabb.maxv[i])
    end
    return math3d.dot(q, q);

    -- local function calc_op(a, b, op)
    --     local t = {}
    --     for i=1, 3 do
    --         t[i] = op(a[i], b[i])
    --     end
    --     return t
    -- end
    -- local closest = calc_op(aabb.minv, calc_op(center, aabb.maxv, math.min), math.max)
    -- local d = math3d.sub(closest, center)
    -- return math3d.dot(d, d)
end

local function interset_aabb(l, aabb, viewmat)
    local r = l.range
    local center = math3d.transform(viewmat, l.pos, 1.0);
    local sq_dist = sphere_closest_pt_to_aabb(math3d.tovalue(center), aabb);
    return sq_dist <= (r * r);
end

local kb_mb = world:sub{"keyboard"}
function init_loader_sys:data_changed()
    for _, key, press, status in kb_mb:unpack() do
        if key == "X" and press == 0 then
            local mq = world:singleton_entity "main_queue"

            local isicc = icc.get() == icamera.controller(mq.camera_eid)
            local c = isicc and camera_cache.icc or camera_cache.iccqs
            c.pos.v = iom.get_position(mq.camera_eid)
            c.dir.v = iom.get_direction(mq.camera_eid)
            c.updir.v = iom.get_updir(mq.camera_eid)

            local uc = isicc and camera_cache.iccqs or camera_cache.icc

            iom.lookto(mq.camera_eid, uc.pos, uc.dir, uc.updir)
            icamera.controller(mq.camera_eid, isicc and iccqs.get() or icc.get())
        end

        local function light_entity()
            for _, eid in world:each "light_type" do
                return eid
            end
        end
        local function move_light(delta)
            local lighteid = light_entity()
            local p = iom.get_position(lighteid)
            p = math3d.add(p, delta)
            iom.set_position(lighteid, p)
        end

        local function enlarge_light(delta)
            local ilight = world:interface "ant.render|light"
            local lighteid = light_entity()
            local range = ilight.range(lighteid)
            ilight.set_range(lighteid, range+delta)
        end
        if key == "UP" and press == 0 then
            move_light{0.0, 0.5, 0.0}
        elseif key == "DOWN" and press == 0 then
            move_light{0.0, -0.5, 0.0}
        elseif key == "LEFT" and press == 0 then
            enlarge_light(-0.5)
        elseif key == "RIGHT" and press == 0 then
            enlarge_light(0.5)
        end

        if key == "SPACE" and press == 0 then
            local lighteid = light_entity()
            local le = world[lighteid]
            local ilight = world:interface "ant.render|light"
            local l = {
                range = ilight.range(lighteid),
                pos = iom.get_position(lighteid),
            }
            local mq = world:singleton_entity "main_queue"
            local cameraeid = mq.camera_eid
            local viewmat = icamera.calc_viewmat(cameraeid)
            local frustum = icamera.get_frustum(cameraeid)
            local near, far = frustum.n, frustum.f

            local aabb = {
                minv = {-0.15881, 0.11909, 0.25},
                maxv = {-0.1042, 0.17866, 0.33338},
            }
            local screensize = {mq.render_target.view_rect.w, mq.render_target.view_rect.h}

            local pt = {0, 1, 0, 1}
            local projmat = icamera.calc_projmat(cameraeid)
            local ptClip = math3d.transform(projmat, math3d.transform(viewmat, pt, 1), 1)
            local ptNDC = math3d.mul(ptClip, 1.0/math3d.index(ptClip, 4))
            local sx, sy = math3d.index(math3d.muladd(ptNDC, 0.5, math3d.vector(0.5, 0.5, 0.0, 0.0)), 1, 2)
            local ptScreen = {sx * screensize[1], sy * screensize[2], math3d.index(ptNDC, 3)}
            ptScreen = {626.50, 272.50, 0.98326, 14.10878}

            local function scale_bias(near, far, num_depth_slices)
                local log_farnear = math.log(far/near, 2)
                local log_near = math.log(near, 2)

                return num_depth_slices / log_farnear, -num_depth_slices * log_near / log_farnear
            end

            local scale, bias = scale_bias(near, far, 24)
            local clusteridx, clusterid = split_frustum.which_cluster(ptScreen, screensize, near, far, scale, bias)

            do
                local screenpts = {
                    {0.5, 0.5, 0.0},
                    {1280/2-0.5, 720/2-0.5, 0.0},
                    {1280/2+0.5, 720/2+0.5, 0.0},
                    {1280-0.5, 720-0.5, 0.0},
                    {1280-0.5, 720-0.5, 0.5},
                    {1280-0.5, 720-0.5, 0.6},
                    {1280-0.5, 720-0.5, 0.7},
                    {1280-0.5, 720-0.5, 0.9999999999},
                    {1280-0.5, 720-0.5, 1.0},
                }

                local clusters = {}
                for _, pt in ipairs(screenpts) do
                    local idx, id = split_frustum.which_cluster(pt, screensize, near, far, scale, bias)
                    clusters[#clusters+1] = {idx, id}
                end

                print ""
            end

            local depth = {}
            local depthinidces = {}
            for i=0, 24 do
                local z = split_frustum.which_z(near, far, i, 24)
                depth[#depth+1] = z
                local ptVS = {0, 0, z}
                local ptClip = math3d.transform(projmat, ptVS, 1)
                local ptNDC = math3d.mul(ptClip, 1.0/math3d.index(ptClip, 4))
                local d = math3d.index(ptNDC, 3)
                local depthidx = split_frustum.which_cluster_Z(d, near, far, scale, bias)
                depthinidces[#depthinidces+1] = depthidx
            end

            do
                local aabbs = {}
                for _, id in ipairs{
                    {0, 0, 0},
                    {7, 0, 0},
                    {8, 0, 0},
                    {7, 4, 0},
                    {7, 5, 0},
                    {8, 4, 0},
                    {8, 5, 0},
                    {0, 0, 1},
                    {7, 0, 1},
                    {8, 0, 1},
                    {7, 4, 1},
                    {7, 5, 1},
                    {8, 4, 1},
                    {8, 5, 1},
                    {0, 0, 2},
                    {7, 0, 2},
                    {8, 0, 2},
                    {7, 4, 2},
                    {7, 5, 2},
                    {8, 4, 2},
                    {8, 5, 2},
                } do
                    aabbs[#aabbs+1] = split_frustum.build(id, screensize, near, far, math3d.inverse(projmat))
                end

                print ""
            end

            local aabb1 = split_frustum.build(clusterid, screensize, near, far, math3d.inverse(projmat))
            local is = interset_aabb(l, aabb1, viewmat)
            print("interset_aabb:", is and "true" or "false")
        end

        if key == 'T' and press == 0 then
            local clusterid = {8, 3, 11}
            local mq = world:singleton_entity "main_queue"
            local screensize = {mq.render_target.view_rect.w, mq.render_target.view_rect.h}
            local frustum = icamera.get_frustum(mq.camera_eid)
            local near, far = frustum.n, frustum.f
            local invproj = math3d.inverse(icamera.calc_projmat(mq.camera_eid))
            
            local v_posWS = {0.36984, 0.75826, -0.30619, 1.0}
            local xsize, ysize, zsize = 16, 9, 24
            local id1
            local viewmat = icamera.calc_viewmat(mq.camera_eid)
            local posVS = math3d.transform(viewmat, v_posWS, 1)
            for z=1, zsize do
                for y=1, ysize do
                    for x=1, xsize do
                        local id = {x-1, y-1, z-1}
                        local aabb = split_frustum.build(id, screensize, near, far, invproj, {xsize, ysize, zsize})
                        if math3d.aabb_test_point(math3d.aabb(aabb.minv, aabb.maxv), posVS) then
                            id1 = id
                            break
                        end
                    end
                end
            end

            print(id1)
            local aabb1 = split_frustum.build(clusterid, screensize, near, far, invproj)
            print(aabb1)
        end

        if key == 'F' and press == 0 then
            local mq = world:singleton_entity "main_queue"
            local screensize = {mq.render_target.view_rect.w, mq.render_target.view_rect.h}
            local frustum = icamera.get_frustum(mq.camera_eid)
            local u_nearZ, u_farZ = frustum.n, frustum.f
            local invproj = math3d.inverse(icamera.calc_projmat(mq.camera_eid))
            local invview = math3d.inverse(icamera.calc_viewmat(mq.camera_eid))
            local vb = {}
            local ib = {}
            local function add_frustum_wireframe(ib, offset)
                local lib<const> = {
                    0, 1, 2, 3, 4, 5, 6, 7,
                    0, 2, 2, 6, 6, 4, 4, 0,
                    1, 3, 3, 7, 7, 5, 5, 1,
                }
                for _, v in ipairs(lib) do
                    ib[#ib+1] = v + offset
                end
            end
            local xsize, ysize, zsize = 16, 9, 24
            local allpoints = {}
            for z=1, zsize do
                for y=1, ysize do
                    for x=1, xsize do
                        local id = {x-1, y-1, z-1}
                        
                        local points = split_frustum.build_frustum_points(id, screensize, u_nearZ, u_farZ, invproj, {xsize, ysize, zsize})
                        add_frustum_wireframe(ib, #vb/3)
                        allpoints[#allpoints+1] = points
                        for _, p in ipairs(points) do
                            local v = math3d.tovalue(math3d.transform(invview, p, 1))
                            for i=1, 3 do
                                vb[#vb+1] = v[i]
                            end
                        end
                    end
                end
            end

            local mesh = ientity.create_mesh({"p3", vb}, ib)
            local eid = ientity.create_simple_render_entity(
                "frustum",
                "/pkg/ant.resources/materials/line_color.material",
                mesh)
            
            imaterial.set_property(eid, "u_color", {0.8, 0.8, 0.0, 1.0})
        end
    end


end
