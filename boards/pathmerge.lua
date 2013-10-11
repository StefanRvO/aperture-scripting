local _M = {}

local math = require 'math'
local table = require 'table'

------------------------------------------------------------------------------

local function reverse_path(path)
	local reverse = {}
	for i=#path,1,-1 do
		if path[i].interpolated then
			-- we should recompute interpolated regions
			return nil
		end
		if i==1 and path[i].interpolation or i > 1 and path[i].interpolation~='linear' then
			-- interpolation flag actually touches two points, so 
			return nil
		end
		reverse[#path-i+1] = path[i]
	end
	reverse[1].interpolation = nil
	reverse[#reverse].interpolation = 'linear'
	reverse.extents = path.extents
	reverse.center_extents = path.center_extents
	return reverse
end

local function append_path(parent, child)
	local nparent = #parent
	for i=2,#child do
		parent[nparent+i-1] = child[i]
	end
	parent.extents = parent.extents + child.extents
	parent.center_extents = parent.center_extents + child.center_extents
end

local function prepend_path(parent, child)
	local nparent = #parent
	local nchild = #child
	for i=nparent+nchild-1,nchild,-1 do
		parent[i] = parent[i-(nchild-1)]
	end
	for i=1,nchild-1 do
		parent[i] = child[i]
	end
	parent.extents = parent.extents + child.extents
	parent.center_extents = parent.center_extents + child.center_extents
end

local function point_to_node(point, epsilon)
	local x = math.floor(point.x / epsilon)
	local y = math.floor(point.y / epsilon)
	return x..':'..y
end

local function merge_layer_paths(layer, epsilon)
	local layer_nodes = {}
	local merged = {}
	local indices = {}
	for ipath,path in ipairs(layer) do
		if #path >= 2 and path.aperture then
			indices[path] = ipath
			local a = point_to_node(path[1], epsilon)
			local b = point_to_node(path[#path], epsilon)
			if a==b then
				-- ignore closed paths
			else
				-- only connect paths with the same aperture
				local nodes = layer_nodes[path.aperture]
				if not nodes then
					nodes = {}
					layer_nodes[path.aperture] = nodes
				end
				-- find neighbours
				local left,la,lb = nodes[a]
				local right,ra,rb = nodes[b]
				nodes[a] = nil
				nodes[b] = nil
				-- find neighbour nodes
				if left then assert(indices[left]); la,lb = point_to_node(left[1], epsilon),point_to_node(left[#left], epsilon) end
				if right then assert(indices[right]); ra,rb = point_to_node(right[1], epsilon),point_to_node(right[#right], epsilon) end
				-- connect
				if left and right and left == right then
					-- this path closes another path
					if lb == a and b == la then
						-- la -> lb -> a -> b
						append_path(left, path)
						merged[path] = true
						-- path is closed, don't re-insert
					else
						-- la -> lb - b <- a
						local rpath = reverse_path(path)
						if rpath then
							-- la -> lb -> b -> a
							append_path(left, rpath)
							merged[path] = true
							-- path is closed, don't re-insert
						else
							local rleft = reverse_path(left)
							if rleft then
								-- a -> b -> lb -> la
								append_path(path, rleft)
								merged[left] = true
								-- path is closed, don't re-insert
							else
								-- unmergeable paths
								nodes[a] = left
								nodes[b] = right
								-- ignore new path
							end
						end
					end
				elseif left and right then
					-- this path connects two other paths
					assert(a==la or a==lb)
					assert(b==ra or b==rb)
					nodes[la],nodes[lb],nodes[ra],nodes[rb] = nil
					if lb == a and b == ra then
						-- la -> lb -> a -> b -> ra -> rb
						append_path(left, path)
						append_path(left, right)
						merged[path] = true
						merged[right] = true
						assert(indices[left])
						nodes[la] = left
						nodes[rb] = left
					elseif la == a and b == ra then
						-- lb <- la - a -> b -> ra -> rb
						local rleft = reverse_path(left)
						if rleft then
							-- lb -> la -> a -> b -> ra -> rb
							prepend_path(right, path)
							prepend_path(right, rleft)
							merged[path] = true
							merged[left] = true
							assert(indices[right])
							nodes[lb] = right
							nodes[rb] = right
						else
							local rpath,rright = reverse_path(path),reverse_path(right)
							if rpath and rright then
								-- rb -> ra -> b -> a -> la -> lb
								prepend_path(left, rpath)
								prepend_path(left, rright)
								merged[path] = true
								merged[right] = true
								assert(indices[left])
								nodes[rb] = left
								nodes[lb] = left
							else
								-- unmergeable paths
								nodes[la] = left
								nodes[lb] = left
								nodes[ra] = right
								nodes[rb] = right
								-- ignore new path
							end
						end
					elseif lb == a and b == rb then
						-- la -> lb -> a -> b - rb <- ra
						local rright = reverse_path(right)
						if rright then
							-- la -> lb -> a -> b -> rb -> ra
							append_path(left, path)
							append_path(left, rright)
							merged[path] = true
							merged[right] = true
							assert(indices[left])
							nodes[la] = left
							nodes[ra] = left
						else
							local rleft,rpath = reverse_path(left),reverse_path(path)
							if rleft and rpath then
								-- ra -> rb -> b -> a -> lb -> la
								append_path(right, rpath)
								append_path(right, rleft)
								merged[path] = true
								merged[left] = true
								assert(indices[right])
								nodes[ra] = right
								nodes[la] = right
							else
								-- unmergeable paths
								nodes[la] = left
								nodes[lb] = left
								nodes[ra] = right
								nodes[rb] = right
								-- ignore new path
							end
						end
					elseif la == a and b == rb then
						-- lb <- la - a -> b - rb <- ra
						local rpath = reverse_path(path)
						if rpath then
							-- ra -> rb -> b -> a -> la -> lb
							append_path(right, rpath)
							append_path(right, left)
							merged[path] = true
							merged[left] = true
							assert(indices[right])
							nodes[ra] = right
							nodes[lb] = right
						else
							local rleft,rright = reverse_path(left),reverse_path(right)
							if rleft and rright then
								-- lb -> la -> a -> b -> rb -> ra
								prepend_path(path, left)
								append_path(path, right)
								merged[left] = true
								merged[right] = true
								assert(indices[path])
								nodes[lb] = path
								nodes[ra] = path
							else
								-- unmergeable paths
								nodes[la] = left
								nodes[lb] = left
								nodes[ra] = right
								nodes[rb] = right
								-- ignore new path
							end
						end
					end
				elseif left then
					assert(a==la or a==lb)
					nodes[la],nodes[lb] = nil
					if lb==a then
						-- la -> lb -> a -> b
						append_path(left, path)
						merged[path] = true
						if la ~= b then
							assert(indices[left])
							nodes[la] = left
							nodes[b] = left
						end
					else
						-- lb <- la - a -> b
						local rpath = reverse_path(path)
						if rpath then
							-- b -> a -> la -> lb
							prepend_path(left, rpath)
							merged[path] = true
							if b ~= lb then
								assert(indices[left])
								nodes[b] = left
								nodes[lb] = left
							end
						else
							local rleft = reverse_path(left)
							if rleft then
								-- lb -> la -> a -> b
								prepend_path(path, rleft)
								merged[left] = true
								if lb ~= b then
									assert(indices[path])
									nodes[lb] = path
									nodes[b] = path
								end
							else
								-- unmergeable paths
								nodes[la] = left
								nodes[lb] = left
								-- ignore path
							end
						end
					end
				elseif right then
					assert(b==ra or b==rb)
					nodes[ra],nodes[rb] = nil
					if b==ra then
						-- a -> b -> ra -> rb
						append_path(path, right)
						merged[right] = true
						if ra ~= b then
							assert(indices[path])
							nodes[ra] = path
							nodes[b] = path
						end
					else
						-- a -> b - rb <- ra
						local rpath = reverse_path(path)
						if rpath then
							-- ra -> rb -> b -> a
							append_path(right, rpath)
							merged[path] = true
							if ra ~= a then
								assert(indices[right])
								nodes[ra] = right
								nodes[a] = right
							end
						else
							local rright = reverse_path(right)
							if rright then
								-- a -> b -> rb -> ra
								append_path(path, rright)
								merged[right] = true
								if a ~= ra then
									assert(indices[path])
									nodes[a] = path
									nodes[ra] = path
								end
							else
								-- unmergeable paths
								nodes[ra] = right
								nodes[rb] = right
								-- ignore path
							end
						end
					end
				else
					assert(indices[path])
					nodes[a] = path
					nodes[b] = path
				end
			end
		end
	end
	for i=#layer,1,-1 do
		if merged[layer[i]] then
			table.remove(layer, i)
		end
	end
end

function _M.merge_image_paths(image, epsilon)
	for _,layer in ipairs(image.layers) do
		merge_layer_paths(layer, epsilon)
	end
end

------------------------------------------------------------------------------

return _M
