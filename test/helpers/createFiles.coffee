Promise = require 'bluebird'
extend = require 'smart-extend'
Path = require 'path'
fs = require 'fs-jetpack'


module.exports = (dest, files)->
	if dest and not files
		files = dest
		dest = Path.resolve 'test','samples'
	
	Promise.resolve(Object.keys(files))
		.map (fileName)->
			content = files[fileName]
			
			if Array.isArray(content)
				content = content[1](files[content[0]])
			
			if fileName[fileName.length-1] is '/'
				fs.dirAsync Path.join(dest, fileName)
			else
				fs.writeAsync Path.join(dest, fileName), content
		
		.return(dest)




