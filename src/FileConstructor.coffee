Promise = require 'bluebird'
fs = Promise.promisifyAll require 'fs'
Path = require 'path'
exec = require('child_process').exec
ora = require 'ora'
chalk = require 'chalk'
SimplyImport = require 'simplyimport'
regEx = require './regex'
progressBar = require './progressBar'

File = (@filePath, @context, @options, scanOnly)->
	@fileExt = Path.extname(@filePath)
	@fileDir = Path.dirname(@filePath)
	@pathParams = Path.parse @filePath
	@pathParams.reldir = @pathParams.dir.replace(@context, '').slice(1)
	@deps = []
	@imports = []
	@lastProcessed = null

	return @process(true, scanOnly)




File::process = (isFirstTime, scanOnly)->
	unless scanOnly
		eventType = if isFirstTime then 'Added' else 'Changed'
		console.log chalk.bgGreen.bgGreen.black(eventType)+' '+chalk.dim(@filePath)
	
	@scanProcedure = Promise.bind(@).then(@getContents).then(@scanForImports)
	return @



File::getContents = ()-> new Promise (finalResolve)=>
	if @fileExt
		pathsToTry = [@filePath, @filePath]
	else
		pathsToTry = ["#{@filePath}.js", "#{@filePath}.coffee", "#{@filePath}.sass", "#{@filePath}.scss"]

	Promise.reduce(pathsToTry, (t,path)-> new Promise (resolve, reject)->
		# process.count ?= 0
		# if process.count++ < 3 then console.log t,path
		fs.readFileAsync(path, {encoding:'utf8'}).then(reject, resolve)
	).catch (@content)=> finalResolve()





File::scanForImports = ()-> if typeof @content is 'string'
	SimplyImport.scanImports(@content, true, true, true)
		.forEach (childPath)=>
			childPath = Path.normalize("#{@fileDir}/#{childPath}")
			childFile = getFile(childPath, @context, @options, true)
		
			@imports.push(childFile) unless @imports.includes(childFile)
			childFile.deps.push(@) unless childFile.deps.includes(@)



File::canExecuteCommand = ()->
	if @lastProcessed?
		return Date.now() - @lastProcessed > @options.execDelay
	else
		return true



File::prepareCommandString = (command)->
	command.replace regEx.placeholder, (entire, placeholder)=> switch
		when placeholder is 'path' then @filePath
		when @pathParams[placeholder]? then @pathParams[placeholder]
		else entire



File::executeCommand = (command)-> new Promise (resolve)=> if @canExecuteCommand()
	command = @prepareCommandString(command)
	@lastProcessed = Date.now()
	@spinner = ora("Executing command: #{chalk.dim(@filePath)}").start()


	exec command, (err, stdout, stderr)=>
		if err then @spinner.fail() else @spinner.succeed()
		resolve({err, stdout, stderr})











fileInstances = {}
module.exports = getFile = (filePath, context, options, scanOnly)->
	fileInstances[filePath]?.process(null, scanOnly) or fileInstances[filePath] = new File(filePath, context, options, scanOnly)
