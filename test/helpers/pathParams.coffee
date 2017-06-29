path = require 'path'

module.exports = (target)->
	params = path.parse(target)
	params.path = path.resolve(target)
	params.dir = path.resolve(params.dir)
	return params