local _M = {}

------------------------------------------------------------------------------

_M.default_template = {
	patterns = {
		top_copper = '%.gtl',
		top_soldermask = '%.gts',
		top_silkscreen = '%.gto',
		top_paste = '%.gtp',
		bottom_copper = '%.gbl',
		bottom_soldermask = '%.gbs',
		bottom_silkscreen = '%.gbo',
		bottom_paste = '%.gbp',
		milling = {'%.gml', '%.gm1'},
		outline = {'%.oln', '%.out'},
		drill = {'%.drd', '%.txt'},
		bom = '%-bom.txt',
	},
	bom = {
		scale = {
			dimension = 1e9,
			angle = 1,
		},
		fields = {
			package = '3D Model',
			x = 'X',
			y = 'Y',
			angle = 'Angle',
			side = 'Side',
			name = 'Part',
		},
	},
}

------------------------------------------------------------------------------

return _M
