#!/usr/bin/env coffee
fs = require 'fs'
glob = require 'glob'
chalk = require 'chalk'
path = require 'path'
chokidar = require 'chokidar'
exec = require('child_process').exec
regEx = require './regex'
yargs = require 'yargs'
yargs
	.usage("#{chalk.bgYellow.black('Usage')} simplywatch -d <directory globs> -s <globs to skip> -i")
	.options(require './cliOptions')
	.help('h')
	.version()
	.wrap(yargs.terminalWidth())
args = yargs.argv


importHistory = {}
execHistory = {}
filesToIgnoreExecFor = []
finallyTimeout = null

options = 
	'dirs': args.d or args.dir# or args._[0]
	'ignoreList': args.i or args.ignore
	'ignoreWeakList': args.I or args.ignoreweak
	'help': args.h or args.help
	'silent': args.s or args.silent
	'imports': args.t or args.imports
	'specificExts': args.e or args.extension
	'runNow': args.n or args.now
	'command': args.x or args.execute
	'finalCommand': args.f or args.finally
	'execDelay': args.w or args.wait
	'finalExecDelay': args.W or args.finallywait



if options.help
	process.stdout.write(yargs.help());
	process.exit(0)



if options.ignoreWeakList
	options.ignoreWeakList.forEach (globToIgnore)->
		glob globToIgnore, (err, files)->
			throw err if err

			# files = files.map (file)-> path.resolve(file)
			filesToIgnoreExecFor = filesToIgnoreExecFor.concat(files)






























passedStartDelay = ()-> Date.now() - startTime > 3000
passedExecDelay = (filePath)-> 
	if execHistory[filePath]? 
		passed = Date.now() - execHistory[filePath] > options.execDelay 
	else
		passed = true

	return passed





# Process ============> chokidar -> startProcessingFile[Added] -> processFile -> captureImports -> startExecutionFor -> executeCommandFor

startProcessingFileAdded = (watchedDir)-> return (filePath)-> processFile(filePath, watchedDir, 'added')
startProcessingFile = (watchedDir)-> return (filePath)-> processFile(filePath, watchedDir)

processFile = (filePath, watchedDir, eventType='changed')->	
	fs.stat filePath, (err, stats)->
		if err then console.log(err); return
		
		if stats.isFile()
			fs.readFile filePath, 'utf8', (err, data)->
				if err then console.log(err); return
	
				if not options.silent and passedStartDelay()
					console.log "File #{eventType}: #{filePath}"

				captureImports(data, filePath)
				startExecutionFor(filePath, watchedDir, eventType)



captureImports = (fileContent, filePath)->
	if typeof fileContent isnt 'string' then return fileContent
	else
		extName = path.extname(filePath)
		dirPath = path.dirname(filePath)

		fileContent.replace regEx.import, (entire, match)->
			match = match.replace /'/g, '' # Removes quotes if present
			hasExt = regEx.ext.test(match)
			match += extName if not hasExt
			resolvedMatch = path.normalize(dirPath+'/'+match)

			if !importHistory[resolvedMatch]?
				importHistory[resolvedMatch] = [filePath]
			else
				importHistory[resolvedMatch].push filePath unless importHistory[resolvedMatch].indexOf(filePath) isnt -1

			try
				stats = fs.statSync resolvedMatch
				if stats.isFile()
					matchFileContent = fs.readFileSync resolvedMatch, 'utf8'
					captureImports(matchFileContent, resolvedMatch)

			return entire

		

startExecutionFor = (filePath, watchedDir, eventType)->
	return if not passedStartDelay() and not options.runNow

	if importHistory[filePath]? # Indicates this file is an import
		importingFiles = importHistory[filePath]
		importingFiles.forEach (file)-> startExecutionFor(file, watchedDir, eventType)
	else executeCommandFor(filePath, watchedDir, eventType)


executeCommandFor = (filePath, watchedDir, eventType)->
	return if not passedExecDelay(filePath) or filesToIgnoreExecFor.indexOf(filePath) isnt -1
	# return if Date.now() - execHistory[filePath] < options.execDelay
	pathParams = path.parse filePath
	pathParams.reldir = pathParams.dir.replace(watchedDir, '').slice(1)
	execHistory[filePath] = Date.now()

	command = options.command.replace regEx.placeholder, (entire, placeholder)->
		if placeholder is 'path'
			return filePath
		
		else if pathParams[placeholder]?
			return pathParams[placeholder]
		
		else return entire


	exec command, (err, stdout, stderr)->
		unless options.silent
			if err then console.log(err)
			if stdout then console.log(stdout)
			if stderr then console.log(stderr)
			console.log "Finished executing command for \x1b[32m#{pathParams.base}\x1b[0m\n"
			
			clearTimeout(finallyTimeout) if options.finalCommand
			finallyTimeout = setTimeout(execFinallyCommand, options.finalExecDelay) if options.finalCommand


execFinallyCommand = ()->
	exec options.finalCommand, (err, stdout, stderr)->
		unless options.silent
			if err then console.log(err)
			if stdout then console.log(stdout)
			if stderr then console.log(stderr)
			console.log "Finished executing \x1b[35mfinal command\x1b[0m"








# ==== Start Watching =================================================================================
startTime = Date.now()

options.dirs.forEach (dirPath)->
	watcher = chokidar.watch(dirPath)

	if options.ignoreList?.length
		watcher.ignore(globToIgnore) for ignoreGlob in options.ignoreList
	

	if not options.specificExts
		watcher.add("**/*")
	else
		watcher.add("**/*.#{ext}") for ext in options.specificExts


	dirName = if dirPath.slice(-1)[0] is '/' then dirPath.slice(0,-1) else dirPath

	if dirName[0] is '.'
		dirName = dirName.slice(2)
	else if dirName[0] is '/'
		dirName = dirName.slice(1)
	

	watcher.on('add', startProcessingFileAdded dirName)
	watcher.on('change', startProcessingFile dirName)

	console.log chalk.bgGreen.black('Watching')+' '+chalk.dim(dirPath)







