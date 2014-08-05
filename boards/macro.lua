local _M = {}

local math = require 'math'
local table = require 'table'
local path = require 'boards.path'

local exterior = path.exterior

------------------------------------------------------------------------------

local config = {}
local macro_primitives = {}

local function argcheck(f, i, t, ...)
	local v = select(i, ...)
	local tv = select('#', ...) < i and 'none' or type(v)
	if tv==t then
		return v
	else
		error("invalid argument #"..i.." to '"..f.."' ("..t.." expected, got "..tv..")")
	end
end

-- Circle, primitive code 1
function macro_primitives.circle(...)
	local exposure = argcheck('circle', 1, 'number', ...)
	local diameter = argcheck('circle', 2, 'number', ...)
	local x = argcheck('circle', 3, 'number', ...)
	local y = argcheck('circle', 4, 'number', ...)
	return macro_primitives.polygon(exposure, config.circle_steps, x, y, diameter, 0)
end

local function rotate(point, rotation)
	local a = math.rad(rotation)
	local c = math.cos(a)
	local s = math.sin(a)
	return {
		x = point.x * c - point.y * s,
		y = point.x * s + point.y * c,
	}
end

-- Vector Line, primitive code 2 or 20
function macro_primitives.line(...)
	local exposure = argcheck('vector line', 1, 'number', ...)
	local line_width = argcheck('vector line', 2, 'number', ...)
	local x0 = argcheck('vector line', 3, 'number', ...)
	local y0 = argcheck('vector line', 4, 'number', ...)
	local x1 = argcheck('vector line', 5, 'number', ...)
	local y1 = argcheck('vector line', 6, 'number', ...)
	local rotation = argcheck('vector line', 7, 'number', ...)
	local dx = x1 - x0
	local dy = y1 - y0
	local n = math.sqrt(dx*dx + dy*dy)
	if n == 0 then
		return nil -- empty primitive
	end
	local lx = line_width / 2 * dx / n
	local ly = line_width / 2 * dy / n
	local path = {}
	table.insert(path, rotate({x=x0-ly, y=y0+lx}, rotation))
	table.insert(path, rotate({x=x0+ly, y=y0-lx}, rotation))
	table.insert(path, rotate({x=x1+ly, y=y1-lx}, rotation))
	table.insert(path, rotate({x=x1-ly, y=y1+lx}, rotation))
	table.insert(path, rotate({x=x0-ly, y=y0+lx}, rotation))
	local hole
	if exposure==0 then
		hole = true
	end
	return { hole=hole, path }
end
macro_primitives.rectangle_ends = macro_primitives.line

-- Center Line, primitive code 21
function macro_primitives.rectangle_center(...)
	local exposure = argcheck('center line', 1, 'number', ...)
	local width = argcheck('center line', 2, 'number', ...)
	local height = argcheck('center line', 3, 'number', ...)
	local x = argcheck('center line', 4, 'number', ...)
	local y = argcheck('center line', 5, 'number', ...)
	local rotation = argcheck('center line', 6, 'number', ...)
	local dx = width / 2
	local dy = height / 2
	local path = {}
	table.insert(path, rotate({x=x-dx, y=y-dy}, rotation))
	table.insert(path, rotate({x=x+dx, y=y-dy}, rotation))
	table.insert(path, rotate({x=x+dx, y=y+dy}, rotation))
	table.insert(path, rotate({x=x-dx, y=y+dy}, rotation))
	table.insert(path, rotate({x=x-dx, y=y-dy}, rotation))
	local hole
	if exposure==0 then
		hole = true
	end
	return { hole=hole, path }
end

-- Lower Left Line, primitive code 22
function macro_primitives.rectangle_corner(...)
	local exposure = argcheck('lower left line', 1, 'number', ...)
	local width = argcheck('lower left line', 2, 'number', ...)
	local height = argcheck('lower left line', 3, 'number', ...)
	local x = argcheck('lower left line', 4, 'number', ...)
	local y = argcheck('lower left line', 5, 'number', ...)
	local rotation = argcheck('lower left line', 6, 'number', ...)
	local dx = width
	local dy = height
	local path = {}
	table.insert(path, rotate({x=x   , y=y   }, rotation))
	table.insert(path, rotate({x=x+dx, y=y   }, rotation))
	table.insert(path, rotate({x=x+dx, y=y+dy}, rotation))
	table.insert(path, rotate({x=x   , y=y+dy}, rotation))
	table.insert(path, rotate({x=x   , y=y   }, rotation))
	local hole
	if exposure==0 then
		hole = true
	end
	return { hole=hole, path }
end

-- Outline, primitive code 4
function macro_primitives.outline(...)
	local exposure = argcheck('outline', 1, 'number', ...)
	local points = argcheck('outline', 2, 'number', ...)
	local path = {}
	for i=0,points do
		local x,y = select(i*2+3, ...)
		assert(type(x)=='number')
		assert(type(y)=='number')
		table.insert(path, {x=x, y=y})
	end
	assert(#path >= 3)
	assert(path[1].x == path[#path].x)
	assert(path[1].y == path[#path].y)
	local rotation = select((points+1)*2+3, ...)
	assert(type(rotation)=='number')
	for i=1,#path do
		path[i] = rotate(path[i], rotation)
	end
	if not exterior(path) then
		local t = {}
		for i=1,#path do
			t[i] = path[#path+1-i]
		end
		path = t
	end
	local hole
	if exposure==0 then
		hole = true
	end
	return { hole=hole, path }
end

-- Polygon, primitive code 5
function macro_primitives.polygon(...)
	local exposure = argcheck('polygon', 1, 'number', ...)
	local vertices = argcheck('polygon', 2, 'number', ...)
	local x = argcheck('polygon', 3, 'number', ...)
	local y = argcheck('polygon', 4, 'number', ...)
	local diameter = argcheck('polygon', 5, 'number', ...)
	local rotation = argcheck('polygon', 6, 'number', ...)
	assert(x==0 and y==0 or rotation==0, "rotation is only allowed if the center point is on the origin")
	if diameter < 0 then
		print("warning: negative polygon diameter in macro")
		diameter = -diameter
	end
	if diameter == 0 then
		return {}
	end
	local r = diameter / 2
	rotation = math.rad(rotation)
	local path = {}
	for i=0,vertices do
		local a
		-- :KLUDGE: we force last vertex on the first, since sin(x) is not always equal to sin(x+2*pi)
		if i==vertices then i = 0 end
		local a = rotation + math.pi * 2 * (i / vertices)
		table.insert(path, {
			x = x + r * math.cos(a),
			y = y + r * math.sin(a),
		})
	end
	local hole
	if exposure==0 then
		hole = true
	end
	return { hole=hole, path }
end

-- helper function for moiré
local function quadrant_point(path, quadrant, x, y, offset)
	if quadrant==0 then
		table.insert(path, { x = x + offset.x, y = y + offset.y })
	elseif quadrant==1 then
		table.insert(path, { x = x - offset.y, y = y + offset.x })
	elseif quadrant==2 then
		table.insert(path, { x = x - offset.x, y = y - offset.y })
	elseif quadrant==3 then
		table.insert(path, { x = x + offset.y, y = y - offset.x })
	end
end

-- Moiré, primitive code 6
function macro_primitives.moire(...)
	local x = argcheck('outline', 1, 'number', ...)
	local y = argcheck('outline', 2, 'number', ...)
	local outer_diameter = argcheck('outline', 3, 'number', ...)
	local ring_thickness = argcheck('outline', 4, 'number', ...)
	local ring_gap = argcheck('outline', 5, 'number', ...)
	local max_rings = argcheck('outline', 6, 'number', ...)
	local cross_hair_thickness = argcheck('outline', 7, 'number', ...)
	local cross_hair_length = argcheck('outline', 8, 'number', ...)
	local rotation = argcheck('outline', 9, 'number', ...)
	assert(x==0 and y==0 or rotation==0, "rotation is only allowed if the center point is on the origin")
	assert(cross_hair_length >= outer_diameter, "unsupported moiré configuration") -- :TODO: this is a hard beast to tackle
	assert(cross_hair_thickness > 0, "unsupported moiré configuration") -- :FIXME: this is just concentric rings
	if outer_diameter < 0 then
		print("warning: negative moiré diameter in macro")
		outer_diameter = -outer_diameter
	end
	assert(outer_diameter > 0, "unsupported moiré configuration") -- :FIXME: this is just a cross
	local r = outer_diameter / 2
	rotation = math.rad(rotation)
	local circle_steps = config.circle_steps
	local quadrant_steps = math.ceil(circle_steps / 4)
	
	local paths = {}
	
	-- draw exterior
	local path = {}
	-- start with right cross hair
	do
		local i = cross_hair_length / 2
		local j = -cross_hair_thickness / 2
		local c = math.cos(rotation)
		local s = math.sin(rotation)
		quadrant_point(path, 0, x, y, {
			x = c * i - s * j,
			y = c * j + s * i,
		})
	end
	for q=0,3 do
		local c = math.cos(rotation)
		local s = math.sin(rotation)
		-- cross hair end
		local i = cross_hair_length / 2
		local j = cross_hair_thickness / 2
		quadrant_point(path, q, x, y, {
			x = c * i - s * j,
			y = c * j + s * i,
		})
		-- intersection with outer circle
		local a0 = math.asin(cross_hair_thickness / 2 / r)
		local a1 = math.pi/2 - a0
		-- draw a quadrant
		for i=0,quadrant_steps do
			local a = rotation + a0 + (a1 - a0) * i / quadrant_steps
			quadrant_point(path, q, x, y, {
				x = r * math.cos(a),
				y = r * math.sin(a),
			})
		end
		-- straight segment to cross hair end
		local i = cross_hair_thickness / 2
		local j = cross_hair_length / 2
		quadrant_point(path, q, x, y, {
			x = c * i - s * j,
			y = c * j + s * i,
		})
	end
	table.insert(paths, path)
	
	-- cut out internal rings
	for q=0,3 do
		local minr = math.sqrt(2) * cross_hair_thickness / 2
		local rings = 0
		local r0 = r - ring_thickness
		while r0 > minr do
			rings = rings + 1
			local path = {}
			-- outer edge
			do
				local a0 = math.asin(cross_hair_thickness / 2 / r0)
				local a1 = math.pi/2 - a0
				for i=0,quadrant_steps do
					local a = rotation + a1 + (a0 - a1) * i / quadrant_steps
					quadrant_point(path, q, x, y, {
						x = r0 * math.cos(a),
						y = r0 * math.sin(a),
					})
				end
			end
			-- inner edge
			local r1
			if rings >= max_rings then
				r1 = minr
			else
				r1 = r0 - ring_gap
			end
			if r1 <= minr then
				-- corner case
				local a = rotation + math.pi / 4
				local r = math.sqrt(2) * cross_hair_thickness / 2
				quadrant_point(path, q, x, y, {
					x = r * math.cos(a),
					y = r * math.sin(a),
				})
			else
				local a0 = math.asin(cross_hair_thickness / 2 / r1)
				local a1 = math.pi/2 - a0
				for i=0,quadrant_steps do
					local a = rotation + a0 + (a1 - a0) * i / quadrant_steps
					quadrant_point(path, q, x, y, {
						x = r1 * math.cos(a),
						y = r1 * math.sin(a),
					})
				end
			end
			-- close the path
			table.insert(path, {x=path[1].x, y=path[1].y})
			table.insert(paths, path)
			
			r0 = r1 - ring_thickness
		end
	end
	
	return paths
end

-- Thermal, primitive code 7
function macro_primitives.thermal(x, y, outer_diameter, inner_diameter, gap_thickness, rotation)
	assert(type(x)=='number')
	assert(type(y)=='number')
	assert(type(outer_diameter)=='number')
	assert(type(inner_diameter)=='number')
	assert(type(gap_thickness)=='number')
	assert(type(rotation)=='number')
	assert(x==0 and y==0 or rotation==0, "rotation is only allowed if the center point is on the origin")
	assert(gap_thickness > 0, "unsupported thermal configuration") -- :FIXME: this is just a ring
	if outer_diameter < inner_diameter then
		print("warning: thermal outer diameter is smaller than inner diameter")
		outer_diameter,inner_diameter = inner_diameter,outer_diameter
	end
	if outer_diameter == inner_diameter then
		return {}
	end
	if gap_thickness > outer_diameter then
		return {}
	end
	local circle_steps = config.circle_steps
	local quadrant_steps = math.ceil(circle_steps / 4)
	local r0 = outer_diameter / 2
	local r1 = inner_diameter / 2
	local minr = math.sqrt(2) * gap_thickness / 2
	rotation = math.rad(rotation)
	
	local paths = {}
	
	-- the whole thermal is like one moiré ring
	for q=0,3 do
		local path = {}
		-- outer edge
		do
			local a0 = math.asin(gap_thickness / 2 / r0)
			local a1 = math.pi/2 - a0
			for i=0,quadrant_steps do
				local a = rotation + a0 + (a1 - a0) * i / quadrant_steps
				quadrant_point(path, q, x, y, {
					x = r0 * math.cos(a),
					y = r0 * math.sin(a),
				})
			end
		end
		-- inner edge
		if r1 <= minr then
			-- corner case
			local a = rotation + math.pi/4
			local r = math.sqrt(2) * gap_thickness / 2
			quadrant_point(path, q, x, y, {
				x = r * math.cos(a),
				y = r * math.sin(a),
			})
		else
			local a0 = math.asin(gap_thickness / 2 / r1)
			local a1 = math.pi/2 - a0
			for i=0,quadrant_steps do
				local a = rotation + a1 + (a0 - a1) * i / quadrant_steps
				quadrant_point(path, q, x, y, {
					x = r1 * math.cos(a),
					y = r1 * math.sin(a),
				})
			end
		end
		-- close the path
		table.insert(path, {x=path[1].x, y=path[1].y})
		
		table.insert(paths, path)
	end
	
	return paths
end

local function compile_expression(expression)
	if type(expression)=='number' then
		return expression
	else
		return expression
			:gsub('[xX]', '*')
			:gsub('%$(%d+)', function(n) return "_VARS["..n.."]" end)
			:gsub('%$(%a%w*)', function(k) return "_VARS['"..k.."']" end)
	end
end
assert(compile_expression("1.08239x$1")=="1.08239*_VARS[1]")
assert(compile_expression("$YX2")=="_VARS['Y']*2")

------------------------------------------------------------------------------

function _M.compile(macro, circle_steps)
	local script = macro.script
	local source = {}
	local function write(s) table.insert(source, s) end
	write("local _VARS = {...}\n")
	for _,instruction in ipairs(script) do
		if instruction.type=='comment' then
			-- ignore
		elseif instruction.type=='variable' then
			if type(instruction.name)=='number' then
				write("_VARS["..instruction.name.."]")
			else
				write("_VARS['"..instruction.name.."']")
			end
			write(" = "..compile_expression(instruction.expression).."\n")
		elseif instruction.type=='primitive' then
			write(instruction.shape.."(")
			for i,expression in ipairs(instruction.parameters) do
				if i > 1 then write(", ") end
				write(compile_expression(expression))
			end
			write(")\n")
		else
			error("unsupported macro instruction type "..tostring(instruction.type))
		end
	end
	source = table.concat(source)
	local buffer
	local env = setmetatable({}, {
		__index=function(_, k)
			return function(...)
				local gpc = require 'gpc'
				local primitive = assert(macro_primitives[k], "no generator function for primitive "..tostring(k))(...)
				-- build up a primitive polygon
				local primpoly = gpc.new()
				for _,path in ipairs(primitive) do
					local c = {}
					for i=1,#path-1 do
						table.insert(c, path[i].x)
						table.insert(c, path[i].y)
					end
					if exterior(path) then
						primpoly = primpoly + gpc.new():add(c)
					else
						primpoly = primpoly - gpc.new():add(c)
					end
				end
				-- add it to the aperture
				if primitive.hole then
					buffer = buffer - primpoly
				else
					buffer = buffer + primpoly
				end
			end
		end,
		__newindex=function(_, k, v)
			error("macro script is trying to write a global")
		end,
	})
	local rawchunk
	if _VERSION == 'Lua 5.2' then
		rawchunk = assert(load(source, nil, 't', env))
	elseif _VERSION == 'Lua 5.1' then
		rawchunk = assert(loadstring(source))
		setfenv(rawchunk, env)
	end
	local chunk = function(...)
		local gpc = require 'gpc'
		-- setup
		buffer = gpc.new()
		config.circle_steps = circle_steps
		-- run macro
		rawchunk(...)
		-- cleanup
		config.circle_steps = nil
		local paths = {}
		for c=1,buffer:get() do
			local path = {}
			local n,h = buffer:get(c)
			for i=1,n do
				local x,y = buffer:get(c, i)
				path[i] = {x=x, y=y}
			end
			path[n+1] = {x=path[1].x, y=path[1].y}
			if h == exterior(path) then
				local t = {}
				for i=1,#path do
					t[i] = path[#path+1-i]
				end
				path = t
			end
			table.insert(paths, path)
		end
		buffer = nil
		-- return data
		return paths
	end
	return chunk
end

return _M
