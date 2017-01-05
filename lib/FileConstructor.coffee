Promise = require 'bluebird'
fs = Promise.promisifyAll require 'fs'
Path = require 'path'
exec = require('child_process').exec
chalk = require 'chalk'
SimplyImport = require 'simplyimport'
regEx = require './regex'
watcher = require './watcher'
debug = require './debugLog'

File = (@filePath, @watchContext, @options)->
	@filePathShort = @filePath.replace process.cwd()+'/', ''
	@fileDirShort = Path.dirname(@filePathShort)
	@fileDir = Path.dirname(@filePath)
	@fileExt = @getExtension()
	@filePathNoExt = @fileDir+'/'+Path.basename(@filePath, @fileExt)
	@relDir = Path.dirname(@watchContext)
	@relDir = if @relDir[0] is '.' then @relDir.slice(1) else @relDir
	@relDir = @fileDirShort.replace @relDir, ''
	@pathParams = Path.parse @filePath
	@pathParams.reldir = @relDir.slice(1)
	@deps = badFilesDeps[@filePathNoExt] or []
	@imports = []
	@lastProcessed = null
	@lastScanned = null
	@execCount = 1

	debug.file "New File object for #{chalk.dim @filePathShort}"
	return @process()




File::getExtension = ()->
	extension = Path.extname(@filePath)
	
	if extension
		return extension
	else
		try
			thisFileName = Path.basename(@filePath)
			files = fs.readdirSync(@fileDir).forEach (filePath)->
				fileExt = Path.extname(filePath)
				fileName = Path.basename(filePath, fileExt)
				extension = fileExt if fileName is thisFileName

		if extension
			@filePath += extension
			@filePathShort += extension
			fileInstances[@filePath] = @

		return extension or ''



File::process = ()->
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






File::scanForImports = ()-> #new Promise (resolve)=>
	@imports.length = 0
	
	debug.imports "Scanning #{@filePathShort}"
	SimplyImport.scanImports(@content or '', {isStream:true, pathOnly:true, context:@fileDir}).then (imports)=>
		imports.forEach (childPath)=>
			debug.imports "Found #{@fileDirShort+'/'+childPath} in #{chalk.dim @filePathShort}"
			childPath = Path.normalize("#{@fileDir}/#{childPath}")
			childFile = getFile(childPath, @watchContext, @options)

			if not childFile.fileExt # Indicates provided childPath didn't have a file extension and has yet to be discovered. Delete from cache so that next time a discovery will be re-attempted
				badFilesDeps[childPath] ?= []
				badFilesDeps[childPath].push @
				delete fileInstances[childPath]

			watcher.add(childFile.filePath)
			@imports.push(childFile)
			childFile.deps.push(@) unless childFile.deps.includes(@)


		if @imports.length
			Promise.map @imports, (childFile)-> childFile.scanProcedure
		else
			debug.imports "0 imports found in #{chalk.dim @filePathShort}"




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
	if @lastProcessed
		return invokeTime - @lastProcessed > @options.execDelay
	else
		return true


File::canScanImports = ()->
	if @lastScanned
		return Date.now() - @lastScanned > 150
	else
		return true










fileInstances = {}
badFilesDeps = {} # For tracking deps of files that were provided without an extension and didn't exist in the referenced directory

module.exports = getFile = (filePath, watchContext, options)->
	fileInstances[filePath]?.process() or fileInstances[filePath] = new File(filePath, watchContext, options)
