Promise = require 'bluebird'
fs = Promise.promisifyAll require 'fs'
Path = require 'path'
exec = require('child_process').exec
chalk = require 'chalk'
SimplyImport = require 'simplyimport'
regEx = require './regex'
watcher = require './watcher'
eventsLog = require './eventsLog'

File = (@filePath, @watchContext, @options, eventType)->
	@filePathShort = @filePath.replace process.cwd()+'/', ''
	@fileDirShort = Path.dirname(@filePathShort)
	@fileDir = Path.dirname(@filePath)
	@fileExt = @getExtension()
	@relDir = Path.dirname(@watchContext)
	@relDir = if @relDir[0] is '.' then @relDir.slice(1) else @relDir
	@relDir = @fileDirShort.replace @relDir, ''
	@pathParams = Path.parse @filePath
	@pathParams.reldir = @relDir.slice(1)
	@deps = []
	@imports = []
	@lastProcessed = null
	@lastScanned = null
	@execCount = 1

	return @process(eventType)




File::getExtension = ()->
	extension = Path.extname(@filePath)
	
	if extension
		return extension
	else
		pathsToTry = ["#{@filePath}.js", "#{@filePath}.coffee", "#{@filePath}.sass", "#{@filePath}.scss"]

		for path in pathsToTry then try
			fs.statSync(path) # Will throw an error (an not execute the code below) if it doesn't exist
			extension = Path.extname(path)
			break

		if extension
			@filePath += extension
			@filePathShort += extension
			fileInstances[@filePath] = @
		
		return extension or ''



File::process = (eventType)->
	unless eventType is 'scan' or not eventType
		eventsLog.add chalk.bgGreen.bgGreen.black(eventType)+' '+chalk.dim(@filePathShort)

	
	if @canScanImports()
		@lastScanned = Date.now()
		@scanProcedure = Promise.bind(@).then(@getContents).then(@scanForImports)

	return @



File::getContents = ()-> new Promise (resolve)=>
	if not @fileExt then resolve()
	else
		fs.readFileAsync(@filePath, {encoding:'utf8'})
			.then (@content)=> resolve()
			.catch(resolve)






File::scanForImports = ()-> new Promise (resolve)=>
	@imports.length = 0
	
	SimplyImport.scanImports(@content or '', true, true)
		.forEach (childPath)=>
			childPath = Path.normalize("#{@fileDir}/#{childPath}")
			childFile = getFile(childPath, @watchContext, @options, 'scan')

			watcher.add(childFile.filePath)
			@imports.push(childFile)
			childFile.deps.push(@) unless childFile.deps.includes(@)

	if @imports.length is 0
		resolve()
	else
		Promise
			.map @imports, (childFile)-> childFile.scanProcedure
			.then ()-> resolve()




File::prepareCommandString = (command)->
	formattedCommand = command.replace regEx.placeholder, (entire, placeholder)=> switch
		when placeholder is 'path' then @filePathShort
		when @pathParams[placeholder]? then @pathParams[placeholder]
		else entire

	formattedCommand = "FORCE_COLOR=true #{formattedCommand}"



File::executeCommand = (command)-> new Promise (resolve)=> #if not @canExecuteCommand(invokeTime) then resolve({}) else
	command = @prepareCommandString(command)
	@lastProcessed = Date.now()

	exec command, (err, stdout, stderr)=>
		resolve({err, stdout, stderr})



File::canExecuteCommand = (invokeTime)->
	if @lastProcessed?
		return invokeTime - @lastProcessed > @options.execDelay
	else
		return true


File::canScanImports = ()->
	if @lastScanned?
		return Date.now() - @lastScanned > 150
	else
		return true










fileInstances = {}
module.exports = getFile = (filePath, watchContext, options, eventType)->
	fileInstances[filePath]?.process(eventType) or fileInstances[filePath] = new File(filePath, watchContext, options, eventType)
