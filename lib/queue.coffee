Promise = require 'bluebird'
Listr = require '@danielkalen/listr'
chalk = require 'chalk'
debug = require 'debug'
globMatch = require 'micromatch'
exec = require('child_process').exec
regEx = require './regex'
resolveFile = require './file'
eventsLog = require './eventsLog'

class Queue
	constructor: (@options, @logger)->
		@list = {}
		@executionLogs = log:{}, error:{}
		@timeout = process:null, final:null
	
	
	add: (filePath, watchContext, eventType, depStack=[])->
		file = resolveFile(filePath, watchContext, @options, canSkipRescan=!eventType)
		depStack.push(file) unless depStack.includes(file)
		return if file.executingCommand

		logEvent = ()->
			notes = if not file.deps.length then '' else do ()->
				depNames = file.deps.map((file)-> file.pathParams.base).join(', ')
				return " [imported by #{depNames}]"

			eventsLog.add chalk.bgGreen.bgGreen.black(eventType)+' '+chalk.dim(file.path+notes)

		if eventType
			if @isIgnored(file.filePath)
				pendingLog = true
			else
				logEvent()


		Promise.resolve(file.scanProcedure).bind(@)
			.then ()-> file.deps.filter (depFile)=> not @isIgnored(depFile.filePath)
			.then (fileDeps)->			
				if fileDeps.length is 0
					unless @isIgnored(file.filePath)
						@list[file.filePath] = file
						@beginProcess()
				
				else
					logEvent() if pendingLog
					
					for depFile in file.deps when not depStack.includes(depFile)
						@add(depFile.filePath, watchContext, null, depStack)
					return 




	beginProcess: ()->
		debug 'simplywatch:process', "Add process to queue"
		clearTimeout(@timeout.process)

		@timeout.process = setTimeout ()=>
			list = Object.values(@list)
			@list = {}
			
			@process(list)
		, 300
	



	process: (list)->
		debug 'simplywatch:process', "Process Prep"
		logIteration = eventsLog.iteration++
		startTime = Date.now()
		
		@lastTasklist = 
		Promise.resolve(@lastTasklist).bind(@)
			.tap ()-> debug 'simplywatch:process', "Process Start"
			.tap ()-> eventsLog.output(logIteration, @logger)
			.then ()->
				hasFailedTasks = false
				
				tasks = new Listr list.map((file)=>
					title: "Executing command: #{chalk.dim file.path}"

					skip: ()-> not file.canExecuteCommand(startTime)
					
					task: ()=> file.executeCommand(@options.command).then ({err, stdout, stderr}={})=>
						if isValidOutput(stdout) then @executionLogs.log[file.path] = stdout

						if isValidOutput(stderr) and not isValidOutput(err)
							@executionLogs.log[file.path] = stderr
						else if isValidOutput(err)
							@executionLogs.error[file.path] = stderr or err

						if isValidOutput(err) then Promise.reject(hasFailedTasks=true) else Promise.resolve()

				), 'concurrent':true
				
				tasks.run().then ()=>
					debug 'simplywatch:process', "Process End"
					@outputLogs()
					@processFinalCommand(hasFailedTasks)
					Promise.resolve()

			




	processFinalCommand: (hasFailedTasks)-> if @options.finalCommand
		@timeout.final.cancel() if @timeout.final and not @timeout.final._isCancelled()
		if hasFailedTasks
			@logger.log "#{chalk.bgRed.bold('NOT')} #{chalk.bgBlue.bold('Executing Final Command')} #{chalk.dim('(because some tasks failed)')}"
		else
			@timeout.final = @lastTasklist.delay(@options.finalCommandDelay)
				.then ()=> @finalCommand()




	finalCommand: ()->
		@logger.log "#{chalk.bgBlue.bold('Executing Final Command')}"
		
		exec "FORCE_COLOR=true #{@options.finalCommand}", (err, stdout, stderr)=> if err then @logger.error(err) else
			output = (stdout or '') + (stderr or '')

			if output
				@logger.log chalk.blue.bold('Output')+' '+@formatOutputMessage(output)



	outputLogs: ()->
		logsCount = Object.keys(@executionLogs.log).length + Object.keys(@executionLogs.error).length
	
		if logsCount is 0 or @options.silent
			@options.stdout.write '\n'
		else
			lineCount = Math.floor require('window-size').width * 0.7
			divider = '-'.repeat(lineCount)
			
			@options.stdout.write '\n\n'
			@options.stdout.write divider.slice(0,5)+'COMMAND OUTPUT'+divider.slice(18)
			
			for file,message of @executionLogs.log
				@options.stdout.write '\n'+chalk.bgWhite.black.bold("Output")+' '+chalk.dim(file)
				@options.stdout.write '\n'+@formatOutputMessage(message)+'\n'
				delete @executionLogs.log[file]
			
			for file,message of @executionLogs.error
				@options.stdout.write '\n'+chalk.bgRed.white.bold("Error")+' '+chalk.dim(file)
				@options.stdout.write '\n'+@formatOutputMessage(message)+'\n'
				delete @executionLogs.error[file]
			
			@options.stdout.write divider
			@options.stdout.write '\n\n\n'



	isIgnored: (path)->
		for glob in @options.ignoreGlobs when globMatch.contains(path, glob)
			debug 'simplywatch:ignored', path
			return true
		
		return false
	







