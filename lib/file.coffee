Promise = require 'bluebird'
fs = require 'fs-jetpack'
Path = require 'path'
execa = require 'execa'
chalk = require 'chalk'
md5 = require 'md5'
promiseBreak = require 'p-break'
SimplyImport = require 'simplyimport'
debug =
	file: require('debug')('simplywatch:file')
	imports: require('debug')('simplywatch:imports')



class File extends require('events')
	@scans = Object.create(null)
	@badFilesDeps = Object.create(null) # For tracking deps of files that were provided without an extension and didn't exist in the referenced directory

	@get = ({filePath, watchContext, canSkipRescan}, settings, task)->
		settings.cache[filePath]?.process(canSkipRescan) or
		settings.cache[filePath] = new File(filePath, watchContext, settings, task)


	constructor: (@filePath, @watchContext, @settings, @task)->
		@path = @filePath.replace process.cwd()+'/', ''
		@pathDebug = chalk.dim @path
		@dir = Path.dirname(@path)
		@fileDir = Path.dirname(@filePath)
		@fileExt = @resolveExtension()
		@filePathNoExt = @fileDir+'/'+Path.basename(@filePath, @fileExt)
		@isCoffee = @fileExt is '.coffee'
		@relDir = Path.dirname(@watchContext)
		@relDir = if @relDir[0] is '.' then @relDir.slice(1) else @relDir
		@relDir = @dir.replace @relDir, ''
		@pathParams = Path.parse @filePath
		@pathParams.path = @filePath
		@pathParams.reldir = @relDir.slice(1)
		@deps = File.badFilesDeps[@filePathNoExt] or []
		@imports = []
		@lastExecuted = null
		@lastScanned = null

		debug.file "new file #{@pathDebug}"
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
					debug.imports "using cached scan #{@pathDebug}"
					@imports = File.scans[@hash].map (filePath)=>
						childFile = File.get({filePath, @watchContext}, @settings, @task)
						childFile.deps.push(@) unless childFile.deps.includes(@) or childFile.checkIfImportsFile(@)
						@task.emit('childFile', childFile)
						return childFile
					
					promiseBreak()
		
				else if @canScanImports
					debug.file "scanning #{@pathDebug}"
					@lastScanned = Date.now()
					@imports.length = 0
				
				else
					promiseBreak()

			.then ()->
				SimplyImport.scanImports(@content or '', {@isCoffee, isStream:true, pathOnly:true, context:@fileDir})
			
			.then (imports)->
				imports.forEach (childPath)=>
					debug.imports "found #{chalk.dim Path.join @dir,childPath} in #{@pathDebug}"
					childPath = Path.resolve(@fileDir, childPath)
					childFile = File.get({filePath:childPath, @watchContext}, @settings, @task)

					if not childFile.fileExt # Indicates provided childPath didn't have a file extension and has yet to be discovered. Delete from cache so that next time a discovery will be re-attempted
						File.badFilesDeps[childPath] ?= []
						File.badFilesDeps[childPath].push @
						delete @settings.cache[childPath]

					@task.emit('childFile', childFile)
					@imports.push(childFile)
					childFile.deps.push(@) unless childFile.deps.includes(@) or childFile.checkIfImportsFile(@)

			.then ()->
				File.scans[@hash] = @imports.map (childFile)-> childFile.filePath
				
				if @imports.length
					Promise.map @imports, (childFile)-> childFile.scanProcedure
				else
					debug.imports "0 imports found in #{@pathDebug}"

			.catch promiseBreak.end



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