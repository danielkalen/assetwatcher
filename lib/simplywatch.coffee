require('object.values').shim()
Promise = require 'bluebird'; Promise.config cancellation:true
Glob = Promise.promisify require 'glob'
EventfulPromise = require 'eventful-promise'
Console = require('console').Console
absPath = require 'abs'
extend = require 'smart-extend'
chalk = require 'chalk'
watcher = require './watcher'
getFile = require './file'
defaults = require './defaults'
Queue = require './queue'
debug = require 'debug'



class WatchTask
	constructor: (options)->
		@options = extend.transform(
			'globs': (value)-> if Array.isArray(options.globs) then options.globs else [options.globs]
		).clone(defaults, options)
		
		@logger = new Console(options.stdout, options.stderr)
		@queue = new Queue(@options, @logger)

		if @options.ignoreGlobs?.length
			watcher.options.ignored.push(ignoreGlob) for ignoreGlob in options.ignoreGlobs

		throw new Error "No globs were provided" if not options.globs.length
		throw new Error "Execution command not provided" if not options.command


	processFile: (watchContext, eventType)-> (filePath)=>
		filePath = absPath(filePath)
		@queue.add(filePath, watchContext, eventType)


	scanInitial: (globToScan)->
		Glob(globToScan, {nodir:true, dot:true}).then (files)->
			for filePath in files
				debug 'simplywatch:fsInit', filePath
				filePath = absPath(filePath)
				getFile(filePath, globToScan, options) unless filePath.includes('.git')
			return


	isValidOutput: (output)->
		output and
		output isnt 'null' and
		(
			typeof output is 'string' and
			output.length >= 1 or typeof output is 'object'
		)


	formatOutputMessage: (message)->
		if @options.trim then message.slice(0, @options.trim) else message




createWatchTask = (options)->
	task = new WatchTask(options)

	EventfulPromise.resolve()
		.then ()-> options.globs
		.map (dirPath)->
			task.watcher.add(dirPath)
			@scanInitial(dirPath)

			

			task.watcher.on 'ready', 	(file)-> debug 'simplywatch:watch', "WATCHER Ready"
			task.watcher.on 'add', 		(file)-> debug 'simplywatch:watch', "ADD #{file}"
			task.watcher.on 'change', 	(file)-> debug 'simplywatch:watch', "CHANGE #{file}"
			task.watcher.on 'unlink', 	(file)-> debug 'simplywatch:watch', "DELETE #{file}"
			task.watcher.on 'error', 	(file)-> debug 'simplywatch:watch', "ERROR #{file}"
			task.watcher.on 'add', @processFile(dirPath, 'Added')
			task.watcher.on 'change', @processFile(dirPath, 'Changed')

			logger.log chalk.bgYellow.black('Watching')+' '+chalk.dim(dirPath)

		.then ()-> resolve(task.watcher)












module.exports = createWatchTask
module.exports.WatchTask = WatchTask