require('array-includes').shim()
require('object.values').shim()
Promise = require 'bluebird'; Promise.config cancellation:true
EventfulPromise = require 'eventful-promise'
Glob = Promise.promisify require 'glob'
Console = require('console').Console
absPath = require 'abs'
extend = require 'smart-extend'
chalk = require 'chalk'
debug = require 'debug'
defaults = require './defaults'
Watcher = require './watcher'
File = require './file'
Queue = require './queue'



class WatchTask
	constructor: (options)->
		@settings = extend.transform(
			'globs': (value)-> if Array.isArray(options.globs) then options.globs else [options.globs]
		).clone({cache:{}}, defaults, options)
		
		@logger = new Console(@settings.stdout, @settings.stderr)
		@queue = new Queue(@settings, @logger)
		@watcher = new Watcher

		if @settings.ignoreGlobs?.length
			@watcher.options.ignored.push(ignoreGlob) for ignoreGlob in options.ignoreGlobs

		if not options.globs.length or options.globs.some((glob)-> typeof glob isnt 'string')
			throw new Error "No/Invalid globs were provided"

		if not options.command
			throw new Error "Execution command not provided"

		if not ['string','function'].some((type)-> typeof options.command is type)
			throw new Error "Invalid execution command provided: only a string or a callback may be provided"

		if options.finalCommand and not ['string','function'].some((type)-> typeof options.finalCommand is type)
			throw new Error "Invalid final execution command provided: only a string or a callback may be provided"


	processGlob: (globToScan)->
		Promise.delay()
			.then ()-> Glob(globToScan, {nodir:true, dot:true})
			.each (filePath)->
				debug 'simplywatch:fsInit', filePath
				filePath = absPath(filePath)
			
				unless filePath.includes('.git')
					File.get({filePath, watchContext:globToScan}, @settings) # Initiliaze a file constructor for this file


	processFile: (watchContext, eventType)-> (filePath)=>
		filePath = absPath(filePath)
		file = File.get {filePath, watchContext, canSkipRescan: not eventType}, @settings
		file.on 'childFile', (childFile)=> @watcher.add childFile.filePath
		@queue.add(file, eventType)


	start: ()->
		Promise.all @settings.globs, (dirPath)=>
			@logger.log "#{chalk.bgYellow.black 'Watching'} #{chalk.dim dirPath}"
			@watcher.on 'add',		@processFile(dirPath, 'Added')
			@watcher.on 'change',	@processFile(dirPath, 'Changed')
			
			@watcher.add(dirPath)
			@processGlob(dirPath)


	stop: ()->
		@watcher.stop()








createWatchTask = (options)->
	task = new WatchTask(options)

	EventfulPromise.resolve(task.start())
		.then ()->
			task.watcher.on 'ready', ()=>
				debug 'simplywatch:watch', "WATCHER Ready"
				@emit('ready')
			
			task.watcher.on 'add', (file)=>
				debug 'simplywatch:watch', "ADD #{file}"
				@emit('add', file)
			
			task.watcher.on 'change', (file)=>
				debug 'simplywatch:watch', "CHANGE #{file}"
				@emit('change', file)
			
			task.watcher.on 'unlink', (file)=>
				debug 'simplywatch:watch', "DELETE #{file}"
				@emit('delete', file)
			
			task.watcher.on 'error', (file)=>
				debug 'simplywatch:watch', "ERROR #{file}"
				@emit('error', file)







module.exports = createWatchTask
module.exports.WatchTask = WatchTask