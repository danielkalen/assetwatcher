Promise = require 'bluebird'
chokidar = require '@danielkalen/chokidar'
chalk = require 'chalk'
debug = require('debug')('simplywatch:watch')

class Watcher
	constructor: ()->
		debug 'creating watcher'
		@watchedFiles = []
		@_watcher = chokidar.watch [],
			'cwd': process.cwd()
			'ignoreInitial': true
			'ignored': /(?:\.git|node_modules|.+\.log)/
			'bypassIgnore': @watchedFiles

		@ready = new Promise (resolve)=>
			@_watcher.on 'ready', resolve
			setTimeout resolve, 1000

		if process.platform is 'darwin' and not @_watcher.options.useFsEvents
			console.error "
				#{chalk.bgRed.white.bold('Error')} FSEvents is not being used!
				Falling back to unefficient manual polling method -
				expect high CPU Usage for large directories. Run 'npm install fsevents' and re-run SimplyWatch
			"


	add: (path)-> unless @watchedFiles.includes(path)
		debug "add #{chalk.dim path} to watchlist"
		@watchedFiles.push(path)
		@_watcher.add(path)

	stop: ()->
		debug 'closing watcher'
		@_watcher.close()

	on: (event, callback)->
		@_watcher.on event, callback

	Object.defineProperties @::,
		options: get: -> @_watcher.options
		# on: get: -> @_watcher.on


	
module.exports = Watcher
