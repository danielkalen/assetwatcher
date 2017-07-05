module.exports = (path, settings)->
	path.includes('node_modules/') and
	not settings.watchModules