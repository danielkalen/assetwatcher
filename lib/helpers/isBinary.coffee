Path = require 'path'

module.exports = (filePath)->
	extname = Path.extname(filePath) or Path.basename(filePath)
	extname = extname.slice(1)

	require('image-extensions').includes(extname) or
	require('binary-extensions').includes(extname) and extname isnt 'bin'