local gltfutil  = require "editor.model.glTF.util"
local renderpkg = import_package "ant.render"
local declmgr   = renderpkg.declmgr
local math3d    = require "math3d"
local utility   = require "editor.model.utility"

local function get_layout(name, accessor)
	local shortname, channel = declmgr.parse_attri_name(name)
	local comptype_name = gltfutil.comptype_name_mapper[accessor.componentType]

	return 	shortname .. 
			tostring(gltfutil.type_count_mapper[accessor.type]) .. 
			tostring(channel) .. 
			(accessor.normalized and "n" or "N") .. 
			"I" .. 
			gltfutil.decl_comptype_mapper[comptype_name]
end

local function attrib_data(desc, iv, bin)
	local buf_offset = desc.bv_offset + iv * desc.stride + desc.acc_offset
	return bin:sub(buf_offset+1, buf_offset+desc.elemsize)
end

local function to_ib(indexbin, flag, count)
	return {
		memory 	= {indexbin, 1, #indexbin},
		flag 	= flag,
		start 	= 0,
		num 	= count,
	}
end

local function fetch_ib_buffer(gltfscene, gltfbin, index_accessor)
	local bufferViews = gltfscene.bufferViews

	local bvidx = index_accessor.bufferView+1
	local bv = bufferViews[bvidx]
	local elemsize = gltfutil.accessor_elemsize(index_accessor)
	local class = {
		acc_offset = index_accessor.byteOffset or 0,
		bv_offset = bv.byteOffset or 0,
		elemsize = elemsize,
		stride = bv.byteStride or elemsize,
	}

	assert(elemsize == 2 or elemsize == 4)
	local offset = class.acc_offset + class.bv_offset
	local n = index_accessor.count
	local size = n * elemsize

	local indexbin = gltfbin:sub(offset+1, offset+size)
	local num_triangles = n // 3

	local buffer = {}
	local fmt = elemsize == 4 and "III" or "HHH"
	for tri=0, num_triangles-1 do
		local buffer_offset = tri * elemsize * 3
		local v0, v1, v2 = fmt:unpack(indexbin, buffer_offset+1)
		local s = fmt:pack(v0, v2, v1)
		buffer[#buffer+1] = s
	end

	indexbin = table.concat(buffer, "")

	return to_ib(indexbin, elemsize == 4 and 'd' or '', index_accessor.count)
end

local function gen_ib(num_vertex)
	local faceindices = {}
	local fmt = num_vertex > 65535 and "III" or "HHH"
	for f=0, num_vertex-1, 3 do
		faceindices[#faceindices+1] = fmt:pack(f, f+2, f+1)
	end
	local ibbin = table.concat(faceindices, '')
	return to_ib(ibbin, fmt == "III" and 'd' or '', num_vertex)
end

local function create_prim_bounding(meshscene, prim)	
	local posacc = meshscene.accessors[assert(prim.attributes.POSITION)+1]
	local minv = posacc.min
	if minv then
		local maxv = posacc.max
		assert(#minv == 3)
		assert(#maxv == 3)

		local nminv, nmaxv = math3d.minmax{
			{minv[1], minv[2], -minv[3]},
			{maxv[1], maxv[2], -maxv[3]},
		}
		local bounding = {
			aabb = {math3d.tovalue(nminv), math3d.tovalue(nmaxv)}
		}
		prim.bounding = bounding
		return bounding
	end
end

local function fetch_skininfo(gltfscene, skin, bindata)
	local ibm_idx 	= skin.inverseBindMatrices
	local ibm 		= gltfscene.accessors[ibm_idx+1]
	local ibm_bv 	= gltfscene.bufferViews[ibm.bufferView+1]

	local start_offset = ibm_bv.byteOffset + 1
	local end_offset = start_offset + ibm_bv.byteLength

	return {
		inverse_bind_matrices = {
			num		= ibm.count,
			value 	= bindata:sub(start_offset, end_offset-1),
		},
		joints 	= skin.joints,
	}
end

local function get_obj_name(obj, idx, defname)
	if obj.name then
		return obj.name
	end

	return defname .. idx
end

local default_layouts<const> = {
	POSITION = 1,
	NORMAL = 1,
	TANGENT = 1,
	BITANGENT = 1,

	COLOR_0 = 3,
	COLOR_1 = 3,
	COLOR_2 = 3,
	COLOR_3 = 3,
	TEXCOORD_0 = 3,
	TEXCOORD_1 = 3,
	TEXCOORD_2 = 3,
	TEXCOORD_3 = 3,
	TEXCOORD_4 = 3,
	TEXCOORD_5 = 3,
	TEXCOORD_6 = 3,
	TEXCOORD_7 = 3,
	JOINTS_0 = 2,
	WEIGHTS_0 = 2,
}

local LAYOUT_NAMES<const> = {
	"POSITION",
	"NORMAL",
	"TANGENT",
	"BITANGENT",
	"COLOR_0",
	"COLOR_1",
	"COLOR_2",
	"COLOR_3",
	"TEXCOORD_0",
	"TEXCOORD_1",
	"TEXCOORD_2",
	"TEXCOORD_3",
	"TEXCOORD_4",
	"TEXCOORD_5",
	"TEXCOORD_6",
	"TEXCOORD_7",
	"JOINTS_0",
	"WEIGHTS_0",
}

local jointidx_fmt<const> = "HHHH"

-- change from right hand to left hand
-- left hand define as: 
-- 		x: -left, +right
-- 		y: +up, -down
--		z: -point2user, +point2screen
-- right hand define as:
-- 		x: -left, +right
-- 		y: +up, -down
--		z: +point2user, -point2screen
local function r2l_vec(v, l)
	local t = l:sub(6, 6)
	local n = tonumber(l:sub(2, 2))
	if t == 'f' and n > 2 then
		local fmt = ('f'):rep(n)
		local x,y,z,w = fmt:unpack(v)
		return fmt:pack(x, y, -z, w)
	end

	assert(("not support layout:%s, type:%s must be 'float', attribute number:%d should be large than 2"):format(l, t, n))
end

local function fetch_vb_buffers(gltfscene, gltfbin, prim)
	assert(prim.mode == nil or prim.mode == 4)
	local attributes = prim.attributes

	local accessors, bufferViews, buffers = gltfscene.accessors, gltfscene.bufferViews, gltfscene.buffers
	local layoutdesc = {}
	local layouts = {}

	for _, attribname in ipairs(LAYOUT_NAMES) do
		local accidx = attributes[attribname]
		if accidx then
			local acc = accessors[accidx+1]
			local bvidx = acc.bufferView+1
			local bv = bufferViews[bvidx]
			layouts[#layouts+1] = get_layout(attribname, accessors[accidx+1])
			local elemsize = gltfutil.accessor_elemsize(acc)
			layoutdesc[#layoutdesc+1] = {
				acc_offset = acc.byteOffset or 0,
			 	bv_offset = bv.byteOffset or 0,
				elemsize = elemsize,
			 	stride = bv.byteStride or elemsize,
			}
		end
	end

	local buffer = {}
	local numv = gltfutil.num_vertices(prim, gltfscene)

	local change_index_attrib = -1
	for iv=0, numv-1 do
		for idx, d in ipairs(layoutdesc) do
			local l = layouts[idx]
			local v = attrib_data(d, iv, gltfbin)

			local t = l:sub(1, 1)
			if t == 'p' or t == 'n' or t == 'T' or t == 'b' then
				v = r2l_vec(v, l)
			elseif t == 'i' then
				if l:sub(6, 6) == 'u' then
					v = jointidx_fmt:pack(v:byte(1), v:byte(2), v:byte(3), v:byte(4))
					change_index_attrib = idx
				end
			end
			buffer[#buffer+1] = v
		end
	end

	if change_index_attrib ~= -1 then
		layouts[change_index_attrib] = layouts[change_index_attrib]:sub(1, 5) .. 'i'
	end

	local bindata = table.concat(buffer, "")
	return {
		declname = table.concat(layouts, '|'),
		memory = {bindata, 1, #bindata},
		start = 0,
		num = numv,
	}
end

local function find_skin_root_idx(skin, nodetree)
	local joints = skin.joints
	if joints == nil or #joints == 0 then
		return
	end

	if skin.skeleton then
		return skin.skeleton
	end

	local root = joints[1]
	while true do
		local p = nodetree[root]
		if p == nil then
			break
		end

		root = p
	end
	return root
end

local joint_trees = {}

local function redirect_skin_joints(gltfscene, skin, joint_index, scenetree)
	local skeleton_nodeidx = find_skin_root_idx(skin, scenetree)

	if skeleton_nodeidx then
		local mapper = joint_trees[skeleton_nodeidx]
		if mapper == nil then
			mapper = {}
			-- follow with ozz-animation:SkeletonBuilder, IterateJointsDF
			local function iterate_hierarchy_DF(nodes)
				for _, nidx in ipairs(nodes) do
					mapper[nidx] = joint_index
					joint_index = joint_index + 1
					local node = gltfscene.nodes[nidx+1]
					local c = node.children
					if c then
						iterate_hierarchy_DF(c)
					end
				end
			end
			iterate_hierarchy_DF{skeleton_nodeidx}

			joint_trees[skeleton_nodeidx] = mapper
		end

		local joints = skin.joints
		for i=1, #joints do
			local joint_nodeidx = joints[i]
			joints[i] = assert(mapper[joint_nodeidx])
		end
	end

	return joint_index
end

local function export_skinbin(gltfscene, bindata, exports)
	exports.skin = {}
	local skins = gltfscene.skins
	if skins == nil then
		return
	end
	local joint_index = 0
	for skinidx, skin in ipairs(gltfscene.skins) do
		joint_index = redirect_skin_joints(gltfscene, skin, joint_index, exports.scenetree)
		local skinname = get_obj_name(skin, skinidx, "skin")
		local resname = "./meshes/"..skinname .. ".skinbin"
		utility.save_bin_file(resname, fetch_skininfo(gltfscene, skin, bindata))
		exports.skin[skinidx] = resname
	end

	local nodejoints = {}
	for root_nodeidx, t in pairs(joint_trees) do
		assert(t[root_nodeidx])
		for nodeidx, jointidx in pairs(t) do
			nodejoints[nodeidx] = jointidx
		end
	end
	exports.node_joints = nodejoints
end

-- local function check_front_face(vb, ib)
-- 	local function read_memory(m, fmt, offset)
-- 		offset = offset or 1
-- 		local d, o = m[1], m[2]
-- 		return fmt:unpack(d, offset)
-- 	end

	
-- 	local i1, i2, i3
-- 	if ib then
-- 		local fmt = ib.flag == '' and "HHH" or "III"
-- 		i1, i2, i3 = read_memory(ib.memory, fmt)
-- 	else
-- 		i1, i2, i3 = 1, 2, 3
-- 	end

-- 	assert(#vb == 1 and vb[1].declname:match "p")
-- 	local b = vb[1]
	

-- 	local stride_offset = 0
-- 	local fmt
-- 	do
-- 		for d in b.declname:gmatch "[^|]" do
-- 			if d:sub(1, 1) == 'p' then
-- 				local t = d:sub(6, 6)
-- 				local m<const> = {
-- 					['f'] = 'f',
-- 					['u'] = 'B',
-- 					['i'] = 'h',
-- 				}
-- 				local n = math.floor(tonumber(d:sub(2, 2)))
-- 				fmt = m[t]:rep(n)
-- 				break
-- 			end

-- 			stride_offset = stride_offset + declmgr.elem_size(d)
-- 		end
-- 	end

-- 	local stride = declmgr.layout_stride(b.declname)
-- 	if fmt == nil then
-- 		error "invalid vertex buffer"
-- 	end

-- 	local function vertex_offset(idx)
-- 		return idx * stride + stride_offset
-- 	end
-- 	local v1 = {read_memory(b.memory, fmt, vertex_offset(i1))}
-- 	local v2 = {read_memory(b.memory, fmt, vertex_offset(i2))}
-- 	local v3 = {read_memory(b.memory, fmt, vertex_offset(i3))}

-- 	--left hand check
-- 	v1[3] = 0.0
-- 	v2[3] = 0.0
-- 	v3[3] = 0.0
-- 	local e1 = math3d.sub(v2, v1)
-- 	local e2 = math3d.sub(v3, v1)
-- 	math3d.cross(e1, e2)

-- end

local function save_meshbin_files(resname, meshgroup)
	local cfgname = ("./meshes/%s.meshbin"):format(resname)

	local function write_bin_file(fn, bin)
		utility.save_file("./meshes/" .. fn, bin)
		return fn
	end

	local vb = assert(meshgroup.vb)
	vb.memory[1] = write_bin_file(resname .. ".vbbin", vb.memory[1])
	local ib = meshgroup.ib
	if ib then
		ib.memory[1] = write_bin_file(resname .. ".ibbin", ib.memory[1])
	end

	utility.save_txt_file(cfgname, meshgroup)
	return cfgname
end


local function export_meshbin(gltfscene, bindata, exports)
	exports.mesh = {}
	local meshes = gltfscene.meshes
	if meshes == nil then
		return
	end
	for meshidx, mesh in ipairs(meshes) do
		local meshname = get_obj_name(mesh, meshidx, "mesh")
		local meshaabb = math3d.aabb()
		exports.mesh[meshidx] = {}
		for primidx, prim in ipairs(mesh.primitives) do
			local group = {}
			group.vb = fetch_vb_buffers(gltfscene, bindata, prim)
			local indices_accidx = prim.indices
			group.ib = indices_accidx and
				fetch_ib_buffer(gltfscene, bindata, gltfscene.accessors[indices_accidx+1]) or
				gen_ib(group.vb.num)

			local bb = create_prim_bounding(gltfscene, prim)
			if bb then
				local aabb = math3d.aabb(bb.aabb[1], bb.aabb[2])
				if math3d.aabb_isvalid(aabb) then
					group.bounding = bb
					meshaabb = math3d.aabb_merge(meshaabb, aabb)
				end
			end

			local stemname = ("%s_P%d"):format(meshname, primidx)
			exports.mesh[meshidx][primidx] = save_meshbin_files(stemname, group)
		end
	end
end

return function (_, glbdata, exports)
	joint_trees = {}
	export_meshbin(glbdata.info, glbdata.bin, exports)
	export_skinbin(glbdata.info, glbdata.bin, exports)
	return exports
end