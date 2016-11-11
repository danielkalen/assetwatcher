chokidar = require 'chokidar'

watchedFiles = []
watcher = chokidar.watch [],
	'cwd':process.cwd()
	'ignoreInitial': true
	'ignored': /(?:\.git|node_modules)/

watcher.ready = new Promise (resolve)->
	watcher.on 'ready', resolve
	setTimeout resolve, 200


watcherAdd = watcher.add.bind(watcher)
watcher.add = (path)-> unless watchedFiles.includes(path)
	watchedFiles.push(path)
	watcherAdd(path)

	
module.exports = watcher
