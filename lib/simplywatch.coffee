require('array-includes').shim()
require('object.values').shim()
Promise = require 'bluebird'
Path = require 'path'
EventfulPromise = require 'eventful-promise'; EventfulPromise.Promise = Promise
Glob = Promise.promisify require 'glob'
Console = require('console').Console
absPath = require 'abs'
extend = require 'smart-extend'
chalk = require 'chalk'
defaults = require './defaults'
Watcher = require './watcher'
File = require './file'
Queue = require './queue'
isModule = require './helpers/isModule'
debug =
	init: require('debug')('simplywatch:init')
	watch: require('debug')('simplywatch:watch')
	instance: require('debug')('simplywatch:instance')

### istanbul ignore next ###
do ()-> 
	try Promise.config cancellation:true
	process.on 'warning', (e)-> console.warn(e.stack)
	process.on 'unhandledRejection', (err)-> throw err

coerceToArray = (value)-> if Array.isArray(value) then value else [value]
coerceToNumber = (value)-> if typeof value is 'number' then not isNaN(value) else true


class WatchTask extends require('events')
	constructor: (options)->
		super()
		@settings = extend.allowNull.transform(
			'globs': coerceToArray
			'ignoreGlobs': coerceToArray
		).filter(
			'finalCommandDelay': coerceToNumber
			'execDelay': coerceToNumber
			'trim': coerceToNumber
		)({fileCache:Object.create(null), scanCache:Object.create(null)}, defaults, options)

		switch
			when not @settings.globs.length or @settings.globs.some((glob)-> typeof glob isnt 'string')
				throw new Error "No/Invalid globs were provided"

			when not @settings.command
				throw new Error "Execution command not provided"

			when not ['string','function'].some((type)=> typeof @settings.command is type)
				throw new Error "Invalid execution command provided: only a string or a callback may be provided"

			when @settings.finalCommand and not ['string','function'].some((type)=> typeof @settings.finalCommand is type)
				throw new Error "Invalid final execution command provided: only a string or a callback may be provided"
		
		@logger = new Console(@settings.stdout, @settings.stderr)
		@queue = new Queue(@settings, @)
		@watcher = new Watcher(@settings.useFsEvents)

		if @settings.ignoreGlobs?.length
			@watcher.options.ignored.push(glob) for glob in @settings.ignoreGlobs

		@.on 'childFile', (childFile)=> @watcher.add childFile.filePath, childFile.path



	processGlob: (globToScan)->
		debug.instance "scanning #{chalk.dim globToScan}"

		Promise.delay()
			.then ()-> Glob(globToScan, {nodir:true, dot:true})
			.filter (filePath)=> not @queue.isIgnored(filePath)
			.map (filePath)=>
				debug.init filePath
				filePath = absPath(filePath)
			
				unless filePath.includes('.git')
					File.get({filePath, watchContext:globToScan}, @settings, @) # Initiliaze a file constructor for this file
						.scanProcedure
		
			.then ()-> debug.instance "scan complete #{chalk.dim globToScan}"


	processFile: (watchContext, eventType)-> (filePath)=>
		filePath = absPath(filePath)
		return if isModule(filePath, @settings)
		file = File.get {filePath, watchContext, canSkipRescan: not eventType}, @settings, @
		@queue.add(file, eventType)


	start: ()->
		debug.instance 'start'
		
		Promise.map @settings.globs, (dirPath)=>
			@watcher.on 'add',		@processFile(dirPath, 'Added')
			@watcher.on 'change',	@processFile(dirPath, 'Changed')
			
			@watcher.add(dirPath, dirPath)
			@processGlob(dirPath)


	stop: ()->
		@queue.stop()
		@watcher.stop()








createWatchTask = (options)->
	debug.instance 'creating watch task'
	task = new WatchTask(options)

	EventfulPromise.resolve(task.start())
		.then ()->
			task.watcher.on 'ready', ()=>
				debug.watch "WATCHER Ready"
				@emit('ready')
			
			task.watcher.on 'add', (file)=>
				debug.watch "ADD #{chalk.dim file}"
				@emit('add', file)
			
			task.watcher.on 'change', (file)=>
				debug.watch "CHANGE #{chalk.dim file}"
				@emit('change', file)
			
			task.watcher.on 'unlink', (file)=>
				debug.watch "DELETE #{chalk.dim file}"
				@emit('delete', file)
			
			task.watcher.on 'error', (file)=>
				debug.watch "ERROR #{chalk.dim file}"
				@emit('error', file)

		.then ()-> task.watcher.ready
		.return(task)






module.exports = createWatchTask
module.exports.WatchTask = WatchTask