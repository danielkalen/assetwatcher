Promise = require 'bluebird'
Promise.config cancellation:true
Glob = Promise.promisify require 'glob'
Path = require 'path'
exec = require('child_process').exec
absPath = require 'abs'
globMatch = require 'micromatch'
extend = require 'extend'
chalk = require 'chalk'
Listr = require '@danielkalen/listr'
regEx = require './regex'
watcher = require './watcher'
getFile = require './FileConstructor'
eventsLog = require './eventsLog'
defaultOptions = require './defaultOptions'








module.exports = (passedOptions)-> new Promise (resolve)->
	options = extend({}, defaultOptions, passedOptions)
	if typeof options.globs is 'string' then options.globs = [options.globs]
	if options.globs.length is 0 then throw new Error "No globs were provided"
	if not options.command then throw new Error "Execution command not provided"


	formatOutputMessage = (message)-> if options.trim then message.slice(0, options.trim) else message


	processFile = (watchContext, eventType)-> (filePath)->
		filePath = absPath(filePath)
		queue.add(filePath, watchContext, eventType)


	scanInitial = (globToScan)->
		Glob(globToScan, {nodir:true, dot:true}).then (files)->
			for filePath in files
				filePath = absPath(filePath)
				getFile(filePath, globToScan, options) unless filePath.includes('.git')
			return


	isIgnored = (path)->
		for glob in options.ignoreGlobs
			return true if globMatch.contains(path, glob)
		
		return false

	isValidOutput = (output)->
		output and output isnt 'null' and ( (typeof output is 'string' and output.length >= 1) or (typeof output is 'object') )







	queue = new ()->
		@list = {}
		@executionLogs = 'log':{}, 'error':{}
		@timeout = {process:null, final:null}
		@lastTasklist = Promise.resolve()
		
		@add = (filePath, watchContext, eventType)->
			file = getFile(filePath, watchContext, options)
			logEvent = ()->
				eventsLog.add chalk.bgGreen.bgGreen.black(eventType)+' '+chalk.dim(file.filePathShort)

			if eventType
				if not isIgnored(file.filePath)
					logEvent()
				else
					wasNotLogged = true
			
			file.scanProcedure.then ()=>
				fileDeps = file.deps
				if fileDeps.length
					fileDeps = file.deps.filter (depFile)-> not isIgnored(depFile.filePath)
				
				if fileDeps.length is 0
					unless isIgnored(file.filePath)
						@list[file.filePath] = file
						@beginProcess()
				else
					logEvent() if wasNotLogged
					@add(depFile.filePath, watchContext) for depFile in file.deps




		@beginProcess = ()->
			clearTimeout(@timeout.process)
			@timeout.process = setTimeout ()=>
				list = (file for filePath,file of @list)
				@list = {}
				
				@process(list)
			, 300		
		



		@process = (list)->
			logIteration = eventsLog.iteration++
			invokeTime = Date.now()
			
			@lastTasklist = @lastTasklist.then ()=> new Promise (resolve)=>
				eventsLog.output(logIteration, isIgnored)
				
				tasks = new Listr list.map((file)=>
					title: "Executing command: #{chalk.dim(file.filePathShort)}"

					skip: ()-> not file.canExecuteCommand(invokeTime)
					
					task: ()=> new Promise (resolve, reject)=>				
						file.executeCommand(options.command).then ({err, stdout, stderr})=>
							if isValidOutput(stdout) then @executionLogs.log[file.filePathShort] = stdout

							if isValidOutput(stderr) and not isValidOutput(err)
								@executionLogs.log[file.filePathShort] = stderr
							else if isValidOutput(err)
								@executionLogs.error[file.filePathShort] = stderr or err

							if isValidOutput(err) then reject() else resolve()

				), 'concurrent':true
				
				tasks.run().then ()=>
					@outputLogs()
					resolve()

			@processFinalCommand()
				




		@processFinalCommand = ()-> if options.finalCommand
			@timeout.final.cancel() if @timeout.final

			@timeout.final = @lastTasklist.then ()=>
				setTimeout ()=>
					@finalCommand()
				, options.finalCommandDelay




		@finalCommand = ()=>
			console.log "#{chalk.bgBlue.bold('Executing Final Command')}"
			
			exec "FORCE_COLOR=true #{options.finalCommand}", (err, stdout, stderr)=> if err then console.error(err) else
				output = (stdout or '') + (stderr or '')

				if output
					console.log chalk.blue.bold('Output')+' '+formatOutputMessage(output)



		@outputLogs = ()->
			logsCount = Object.keys(@executionLogs.log).length + Object.keys(@executionLogs.error).length
		
			if logsCount is 0 or options.silent
				process.stdout.write '\n'
			else
				lineCount = Math.floor require('window-size').width * 0.7
				divider = '-'.repeat(lineCount)
				
				process.stdout.write '\n\n'
				process.stdout.write divider.slice(0,5)+'COMMAND OUTPUT'+divider.slice(18)
				
				for file,message of @executionLogs.log
					process.stdout.write '\n'+chalk.bgWhite.black.bold("Output")+' '+chalk.dim(file)
					process.stdout.write '\n'+formatOutputMessage(message)+'\n'
					delete @executionLogs.log[file]
				
				for file,message of @executionLogs.error
					process.stdout.write '\n'+chalk.bgRed.white.bold("Error")+' '+chalk.dim(file)
					process.stdout.write '\n'+formatOutputMessage(message)+'\n'
					delete @executionLogs.error[file]
				
				process.stdout.write divider
				process.stdout.write '\n\n\n'

		
		return @

















	# ==== Start Watching =================================================================================
	Promise
		.map options.globs, (dirPath)->
			watcher.add(dirPath)
			scanInitial(dirPath)

			

			watcher.on 'add', processFile(dirPath, 'Added')
			watcher.on 'change', processFile(dirPath, 'Changed')

			console.log chalk.bgYellow.black('Watching')+' '+chalk.dim(dirPath)

		.then ()-> resolve(watcher)












