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
filesToIgnore = []
finallyTimeout = null
startTime = Date.now()
options = 
	'dirs': args.d or args.dir or args._[0]
	'ignoreList': args.i or args.ignore
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









passedStartDelay = ()-> Date.now() - startTime > 3000
passedExecDelay = (filePath)-> 
	if execHistory[filePath]? 
		passed = Date.now() - execHistory[filePath] > options.execDelay 
	else
		passed = true

	return passed





# Process ============> chokidar -> startProcessingFile[Added] -> processFile -> captureImports -> startExecutionFor -> executeCommandFor

startProcessingFileAdded = (watchedDir)-> (filePath)-> processFile(filePath, watchedDir, 'Added')
startProcessingFile = (watchedDir)-> (filePath)-> processFile(filePath, watchedDir, 'Changed')

processFile = (filePath, watchedDir, type)->	
	fs.stat filePath, (err, stats)-> if err then console.error(err) else if stats.isFile()
		fs.readFile filePath, 'utf8', (err, data)-> if err then console.error(err) else
			if not options.silent
				console.log chalk.bgGreen.bgGreen.black(type)+' '+chalk.dim(filePath)

			captureImports(data, filePath)
			startExecutionFor(filePath, watchedDir, type)



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

		

startExecutionFor = (filePath, watchedDir, type)->
	return if not passedStartDelay() and not options.runNow

	if importHistory[filePath]? # Indicates this file is an import
		importingFiles = importHistory[filePath]
		importingFiles.forEach (file)-> startExecutionFor(file, watchedDir, eventType)
	else executeCommandFor(filePath, watchedDir, eventType)


executeCommandFor = (filePath, watchedDir, eventType)->
	return if not passedExecDelay(filePath) or filesToIgnore[filePath]?
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
if options.ignoreList then options.ignoreList.forEach (ignoreGlob)->
	glob ignoreGlob, (err, files)-> if err then throw err else
		filesToIgnore = filesToIgnore.concat(files)


options.dirs.forEach (dirPath)->
	watcher = chokidar.watch(dirPath, cwd:process.cwd())

	if not options.specificExts
		watcher.add("#{dirPath}/**/*")
	else
		watcher.add("#{dirPath}/**/*.#{ext}") for ext in options.specificExts


	dirName = if dirPath.slice(-1)[0] is '/' then dirPath.slice(0,-1) else dirPath

	if dirName[0] is '.'
		dirName = dirName.slice(2)
	else if dirName[0] is '/'
		dirName = dirName.slice(1)
	

	watcher.on('add', startProcessingFileAdded dirName)
	watcher.on('change', startProcessingFile dirName)

	console.log chalk.bgYellow.black('Watching')+' '+chalk.dim(dirPath)







