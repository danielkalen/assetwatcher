Promise = require 'bluebird'
fs = require 'fs-jetpack'
Path = require 'path'
exec = require('child_process').exec
chalk = require 'chalk'
md5 = require 'md5'
debug = require 'debug'
SimplyImport = require 'simplyimport'
regEx = require './regex'
watcher = require './watcher'

File = (@filePath, @watchContext, @options)->
	@path = @filePath.replace process.cwd()+'/', ''
	@fileDirShort = Path.dirname(@path)
	@fileDir = Path.dirname(@filePath)
	@fileExt = @getExtension()
	@filePathNoExt = @fileDir+'/'+Path.basename(@filePath, @fileExt)
	@isCoffee = @fileExt is '.coffee'
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

	debug 'simplywatch:file', "New File object for #{chalk.dim @path}"
	return @process()




File::getExtension = ()->
	extension = Path.extname(@filePath)
	
	if extension
		return extension
	else
		try
			thisFileName = Path.basename(@filePath)
			files = fs.list(@fileDir).forEach (filePath)->
				fileExt = Path.extname(filePath)
				fileName = Path.basename(filePath, fileExt)
				extension = fileExt if fileName is thisFileName

		if extension
			@filePath += extension
			@path += extension
			fileInstances[@filePath] = @

		return extension or ''



File::process = (canSkipRescan)->
	return @ if canSkipRescan and @content
	
	@scanProcedure = Promise.bind(@)
		.then(@getContents)
		.then(@scanForImports)

	return @



File::getContents = ()->
	if not @fileExt
		Promise.resolve()
	else
		Promise.bind(@)
			.then ()-> fs.readAsync(@filePath)
			.then (content)-> @hash = md5(@content=content)
			.catch ()->


File::checkIfImportsFile = (targetFile, deepScan=true)->
	iteratedArrays = [@imports]
	
	checkArray = (importsArray)=>
		importsArray.includes(targetFile) or
		importsArray.find (currentFile)->
			if iteratedArrays.includes(currentFile.imports)
				return false
			else
				iteratedArrays.push(currentFile.imports)
				return if deepScan then checkArray(currentFile.imports) else false

	checkArray(@imports)


File::getImportsFromHistory = (targetHash)-> if not targetHash then


File::scanForImports = ()->
	if scannedHashes[@hash]
		@imports = scannedHashes[@hash].slice()
		return Promise.resolve()
	
	else if @canScanImports()
		@lastScanned = Date.now()
		@imports.length = 0
		debug 'simplywatch:imports', "Scanning #{@path}"
	
	else
		return Promise.resolve()
	
	
	@scanProcedure = SimplyImport.scanImports(@content or '', {@isCoffee, isStream:true, pathOnly:true, context:@fileDir}).then (imports)=>
		imports.forEach (childPath)=>
			debug 'simplywatch:imports', "Found #{@fileDirShort+'/'+childPath} in #{chalk.dim @path}"
			childPath = Path.resolve(@fileDir, childPath)
			childFile = getFile(childPath, @watchContext, @options)

			if not childFile.fileExt # Indicates provided childPath didn't have a file extension and has yet to be discovered. Delete from cache so that next time a discovery will be re-attempted
				badFilesDeps[childPath] ?= []
				badFilesDeps[childPath].push @
				delete fileInstances[childPath]

			watcher.add(childFile.filePath)
			@imports.push(childFile)
			childFile.deps.push(@) unless childFile.deps.includes(@) or childFile.checkIfImportsFile(@)

		scannedHashes[@hash] = @imports.slice()
		
		if @imports.length
			Promise.map @imports, (childFile)-> childFile.scanProcedure
		else
			debug 'simplywatch:imports', "0 imports found in #{chalk.dim @path}"




File::prepareCommandString = (command)->
	formattedCommand = command.replace regEx.placeholder, (entire, placeholder)=> switch
		when placeholder is 'path' then @path
		when @pathParams[placeholder]? then @pathParams[placeholder]
		else entire

	formattedCommand = "FORCE_COLOR=true #{formattedCommand}"



File::executeCommand = (command)-> @executingCommand = new Promise (resolve)=>
	command = @prepareCommandString(command)
	@lastProcessed = Date.now()

	exec command, (err, stdout, stderr)=>
		delete @executingCommand
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









scannedHashes = {}
fileInstances = {}
badFilesDeps = {} # For tracking deps of files that were provided without an extension and didn't exist in the referenced directory

module.exports = getFile = (filePath, watchContext, options, canSkipRescan)->
	fileInstances[filePath]?.process(canSkipRescan) or fileInstances[filePath] = new File(filePath, watchContext, options)
