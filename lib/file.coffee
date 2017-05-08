Promise = require 'bluebird'
fs = require 'fs-jetpack'
Path = require 'path'
execa = require 'execa'
chalk = require 'chalk'
md5 = require 'md5'
debug = require 'debug'
stringToArgv = require 'string-argv'
promiseBreak = require 'p-break'
SimplyImport = require 'simplyimport'
regEx = require './regex'



class File extends require('events')
	@scans = Object.create(null)
	@badFilesDeps = Object.create(null) # For tracking deps of files that were provided without an extension and didn't exist in the referenced directory

	@get = ({filePath, watchContext, canSkipRescan}, settings)->
		settings.cache[filePath]?.process(canSkipRescan) or
		settings.cache[filePath] = new File(filePath, watchContext, settings)


	constructor: (@filePath, @watchContext, @settings)->
		super
		@path = @filePath.replace process.cwd()+'/', ''
		@dir = Path.dirname(@path)
		@fileDir = Path.dirname(@filePath)
		@fileExt = @resolveExtension()
		@filePathNoExt = @fileDir+'/'+Path.basename(@filePath, @fileExt)
		@isCoffee = @fileExt is '.coffee'
		@relDir = Path.dirname(@watchContext)
		@relDir = if @relDir[0] is '.' then @relDir.slice(1) else @relDir
		@relDir = @dir.replace @relDir, ''
		@pathParams = Path.parse @filePath
		@pathParams.reldir = @relDir.slice(1)
		@deps = File.badFilesDeps[@filePathNoExt] or []
		@imports = []
		@lastExecuted = null
		@lastScanned = null

		debug 'simplywatch:file', "New File object for #{chalk.dim @path}"
		return @process()


	process: (canSkipRescan)->
		return @ if canSkipRescan and @content
		
		@scanProcedure =
		Promise.bind(@)
			.then(@getContents)
			.then(@scanForImports)

		return @


	resolveExtension: ()->
		extension = Path.extname(@filePath)
		
		if extension
			return extension
		else
			try
				thisFileName = Path.basename(@filePath)
				files = fs.list(@fileDir)
				for filePath in files
					fileExt = Path.extname(filePath)
					fileName = Path.basename(filePath, fileExt)
					
					if fileName is thisFileName
						extension = fileExt
						break

			if extension
				@filePath += extension
				@path += extension
				@settings.cache[@filePath] = @

			return extension or ''


	getContents: ()->
		if not @fileExt
			Promise.resolve()
		else
			Promise.bind(@)
				.then ()-> fs.readAsync(@filePath)
				.then (content)-> @hash = md5(@content=content)
				.catch ()->


	checkIfImportsFile: (targetFile, deepScan=true)->
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



	scanForImports: ()->
		Promise.bind(@)
			.then ()->
				if File.scans[@hash]
					@imports = File.scans[@hash].slice()
					promiseBreak()
		
				else if @canScanImports
					@lastScanned = Date.now()
					@imports.length = 0
					debug 'simplywatch:imports', "Scanning #{@path}"
				
				else
					promiseBreak()

			.then ()->
				SimplyImport.scanImports(@content or '', {@isCoffee, isStream:true, pathOnly:true, context:@fileDir})
			
			.then (imports)->
				imports.forEach (childPath)=>
					debug 'simplywatch:imports', "Found #{@dir+'/'+childPath} in #{chalk.dim @path}"
					childPath = Path.resolve(@fileDir, childPath)
					childFile = File.get({filePath:childPath, @watchContext}, @settings)

					if not childFile.fileExt # Indicates provided childPath didn't have a file extension and has yet to be discovered. Delete from cache so that next time a discovery will be re-attempted
						File.badFilesDeps[childPath] ?= []
						File.badFilesDeps[childPath].push @
						delete @settings.cache[childPath]

					@emit('childFile', childFile)
					@imports.push(childFile)
					childFile.deps.push(@) unless childFile.deps.includes(@) or childFile.checkIfImportsFile(@)

			.then ()->
				File.scans[@hash] = @imports.slice()
				
				if @imports.length
					Promise.map @imports, (childFile)-> childFile.scanProcedure
				else
					debug 'simplywatch:imports', "0 imports found in #{chalk.dim @path}"

			.catch promiseBreak.end




	prepareCommandString: (command)->
		formattedCommand = command.replace regEx.placeholder, (entire, placeholder)=> switch
			when placeholder is 'path' then @path
			when @pathParams[placeholder]? then @pathParams[placeholder]
			else entire

		stringToArgv(formattedCommand)


	executeCommand: (command)->
		@executionTask =
		Promise.resolve(command).bind(@)
			.then (command)-> if typeof command is 'function' then command else @prepareCommandString(command)
			.then (command)->
				switch typeof command
					when 'function'
						command(@filePath, @pathParams)

					when 'array'
						execa array[0], array.slice(1), env:'FORCE_COLOR':'true'

			.then (result)-> result ||= {stdout:'', stderr:''}
			.tap ()-> delete @executionTask
			.tapCatch ()-> delete @executionTask


	canExecuteCommand: (invokeTime)->
		if @lastExecuted
			return invokeTime - @lastExecuted > @settings.execDelay
		else
			return true


	Object.defineProperties @::,
		canScanImports: get: ()->
			if @lastScanned
				return Date.now() - @lastScanned > 150
			else
				return true










module.exports = File