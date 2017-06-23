Promise = require 'bluebird'
Path = require 'path'
ActionBuffer = require 'actionbuffer'
cliTruncate = require 'cli-truncate'
promiseBreak = require 'p-break'
extend = require 'smart-extend'
symbols = require 'log-symbols'
stringify = require 'json-stringify-safe'
spinner = require('ora')()
uniq = require 'uniq'
chalk = require 'chalk'
globMatch = require 'micromatch'
CommandExecution = require './commandExec'
debug =
	ignored: require('debug')('simplywatch:ignored')
	tasklist: require('debug')('simplywatch:tasklist')
	instance: require('debug')('simplywatch:instance')

class Queue
	constructor: (@settings, @watchTask)->
		debug.instance 'creating queue'
		watchPaths = @settings.globs.map((glob)-> Path.relative(process.cwd(),glob)).join(', ')
		@cycles = @finalCycles = 0
		@logHeader = "#{chalk.bgYellow.black 'Watching'} #{chalk.dim watchPaths}"
		@logBuffer = before:[], after:[], history:[]
		@logUpdate = require('log-update').create(@settings.stdout)
		@finalCommandSpinner = require('ora')(stream:@settings.stdout) if @settings.finalCommand
		@buffer = new ActionBuffer (list)=>
			@process uniq(list)
		, @settings.bufferTimeout

		@logRender()
	
	
	add: (file, eventType, depStack=[])->
		depStack.push(file) unless depStack.includes(file)

		Promise.resolve().bind(@)
			.then ()->
				if file.commandExecution
					file.commandExecution.cancel() if @settings.haltSerial
					return file.commandExecution

			.then ()->	
				logEvent = ()=>
					notes = if not file.deps.length then '' else do ()->
						depNames = file.deps.map((file)-> file.pathParams.base).join(', ')
						return " [imported by #{depNames}]"

					@log chalk.bgGreen.bgGreen.black(eventType)+' '+chalk.dim(file.path+notes)

				if eventType
					logEvent() unless isIgnored=@isIgnored(file.filePath)


				Promise.resolve(file.scanProcedure).bind(@)
					.then ()-> file.deps.filter (depFile)=> not @isIgnored(depFile.filePath)
					.then (fileDeps)->
						if fileDeps.length is 0
							@buffer.push(file) unless @isIgnored(file.filePath)
						else
							if isIgnored
								logEvent()
							else
								@buffer.push(file) if @settings.processImports
							
							for depFile in file.deps when not depStack.includes(depFile)
								@add(depFile, null, depStack)
							return 



	process: (list)->
		debug.tasklist "prep #{list.length} files"
		if @finalCommandPromise and not @finalCommandPromise.cancelled
			@finalCommandPromise.cancelled = true
			debug.tasklist 'final command - aborting previous'
		
		@taskListPromise = 
		Promise.all([@taskListPromise, @finalCommandExecPromise]).bind(@)
			.tap ()-> debug.tasklist "start #{list.length} files"
			.return @settings.command
			.then (command)->
				@running = new ()->
					for file in list
						@[file.path] = file.commandExecution =
						CommandExecution(command, file.path, file.pathParams)
					return @
				
				@logStart()
				return list
	
			.map (file)->
				file.commandExecution.start()

			.then ()->
				finalOutput = []
				
				for filePath,report of @running
					fileOutput = ''
					fileOutput += report.result.stdout if @isValidOutput(report.result.stdout)
					fileOutput += report.result.stderr if @isValidOutput(report.result.stderr)
					
					if report.status is 'cancel'
						finalOutput.push "#{symbols.warning} #{chalk.dim filePath} (cancelled)"

					if report.status is 'failure' and not fileOutput
						fileOutput =
							if report.result instanceof Error
								report.result.message
							else
								try stringify(report.result) catch then String(report.result)

					if fileOutput
						fileOutput = cliTruncate(fileOutput, @settings.trim, position:'end') if @settings.trim
						icon = if report.status is 'success' then symbols.success else symbols.error
						finalOutput.push "#{icon} #{chalk.dim filePath}\n#{@formatOutput fileOutput}"


				failedItems = Object.keys(@running).filter (item)=> @running[item].status is 'failure'
				return [finalOutput, failedItems]

			.spread (finalOutput, failedItems)->
				debug.tasklist "end #{failedItems.length} failures"
				@watchTask.emit 'cycle', ++@cycles
				@logHeader = "#{chalk.bgYellow.black 'Watching'} #{chalk.dim @settings.globs.join(', ')} #{chalk.dim "(x#{@cycles})"}"
				@logStop()
				@logRender(finalOutput)
				@logBuffer.history.push finalOutput... if finalOutput.length
				
				@startFinalCommand failedItems.length if @settings.finalCommand
				
				@running = false


			




	startFinalCommand: (hasFailedTasks)->	
		if hasFailedTasks
			setTimeout ()=>
				@log "#{chalk.blue.bold 'Final Command'} #{chalk.red.bold 'Aborted'} #{chalk.dim '(because some tasks failed)'}"
		else
			@finalCommandPromise = thisPromise =
			Promise.bind(@)
				.delay @settings.finalCommandDelay
				.then ()-> promiseBreak('aborted') if @running or @finalCommandPromise?.cancelled or thisPromise.cancelled
				.then ()-> @executeFinalCommand()
				.then ()-> @watchTask.emit 'finalCycle', ++@finalCycles
				.catch promiseBreak.end
				.then (reason)->
					if reason is 'aborted' then debug.tasklist 'final command - aborted'
					delete @finalCommandPromise if thisPromise is @finalCommandPromise



	executeFinalCommand: ()->
		debug.tasklist 'final command - running'
		@finalCommandSpinner.start().text = "#{chalk.blue.bold('Final Command')}"
		commandExec = CommandExecution(@settings.finalCommand)
		
		Promise.bind(@)
			.then ()-> @finalCommandExecPromise = commandExec.start()
			.then (result)->
				output = ''
				output += result.stdout if @isValidOutput(result.stdout)
				output += result.stderr if @isValidOutput(result.stderr)
				output = result.stack if result instanceof Error and not output
				output = cliTruncate(output, @settings.trim, position:'end') if @settings.trim

				if output
					status = if commandExec.status is 'success' then 'succeed' else 'fail'
					@finalCommandSpinner[status] "#{@finalCommandSpinner.text}\n#{@formatOutput output}"
				else
					@finalCommandSpinner.stop()

				debug.tasklist 'final command - finish'




	isIgnored: (path)->
		for glob in @settings.ignoreGlobs when globMatch.contains(path, glob)
			debug.ignored path
			return true
		
		return false
	

	isValidOutput: (output)->
		output and
		output isnt 'null' and
		(
			typeof output is 'string' and output.length >= 1 or
			typeof output is 'object'
		)


	formatOutput: (output)->
		output = output.replace /\n+$/, ''
		return output+'\n'


	log: (item)->
		if @running
			@logBuffer.after.push(item)
		else
			@logBuffer.before.push(item)
			@logRender()

	logStart: ()->
		@logRender()
		@logInterval = setInterval ()=>
			@logRender()
		, 50

	logStop: ()->
		clearInterval(@logInterval)
		@logBuffer.before = @logBuffer.after
		@logBuffer.after = []
		@logUpdate.clear()

		@logUpdate @logBuffer.before.join('\n') if @logBuffer.before.length

	logRender: (output)->
		if output
			if @settings.retainHistory
				output = @logBuffer.history.concat(output, @logHeader)
			else
				output.unshift @logHeader
		else
			output = if @settings.retainHistory then @logBuffer.history.slice() else []
			output.push @logHeader
			output.push @logBuffer.before...

			if @running
				pendingFrame = spinner.frame()
				for filePath,report of @running
					reason = if report.status is 'cancel' then ' (cancelled)' else ''
					icon = switch report.status
						when 'pending' then pendingFrame
						when 'success' then symbols.success+' '
						when 'failure' then symbols.error+' '
						when 'cancel' then symbols.warning+' '

					output.push "#{icon}#{chalk.dim filePath}#{reason}"

			output.push @logBuffer.after...
		
		@logUpdate output.join('\n')


	stop: ()->
		debug.instance 'destroying queue'
		@logBuffer.before.length = 0
		@logBuffer.after.length = 0
		@logStop()
		@buffer.stop()






module.exports = Queue