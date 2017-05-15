Promise = require 'bluebird'
execa = require 'execa'
extend = require 'smart-extend'
placeholderRegex = /(?:\#\{|\{\{)([^\/\}]+)(?:\}\}|\})/ig
defaultResult = {stdout:'', stderr:''}

class CommandExecution
	constructor: (@command, @path, @params)->
		return new CommandExecution(@command, @path, @params) if @constructor isnt CommandExecution
		@status = 'pending'
		
		if typeof @command is 'string' and @params
			@command = @command.replace placeholderRegex, (entire, placeholder)=>
				if @params[placeholder]? then @params[placeholder] else entire

	start: ()->
		@task =
		Promise.resolve(@command)
			.then (command)=>
				@_task = switch typeof command
					when 'function'
						command(@path, @params)
					
					when 'string'
						execa.shell command, env:extend({'FORCE_COLOR':'true'}, process.env)

			.then (result)-> result ||= defaultResult
			.then (@result)=> @status = 'success'
			.tapCatch (err)-> err.stack = err.message if err.message.includes('Command failed:')
			.catch (@result)=> @status = 'failure'
			.then ()=> @result


	then: (cb)->
		@task.then cb

	catch: (cb)->
		@task.catch cb

	cancel: ()->
		@task._fulfill(@result=defaultResult)
		
		if typeof @command is 'string'
			@_task?.kill()
		
		else if @_task.isCancellable?()
			@_task.cancel()
		
		@status = 'cancel'


module.exports = CommandExecution