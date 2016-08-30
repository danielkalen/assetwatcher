#!/usr/bin/env coffee
fs = require('fs')
glob = require('glob')
chalk = require('chalk')
path = require('path')
fireworm = require('fireworm')
exec = require('child_process').exec
regEx = require './regex'
yargs = require('yargs')
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


dirs = args.d || args.dir
ignore = args.i || args.ignore
ignoreWeak = args.I || args.ignoreweak
help = args.h || args.help
silent = args.s || args.silent
imports = args.t || args.imports
onlyExt = args.e || args.extension
runNow = args.n || args.now
commandToExecute = args.x || args.execute
finallyExecCommand = args.f || args.finally
execDelay = args.w || args.wait
finallyExecDelay = args.W || args.finallywait



if help
	process.stdout.write(yargs.help());
	process.exit(0)



if ignoreWeak
	ignoreWeak.forEach (globToIgnore)->
		glob globToIgnore, (err, files)->
			throw err if err

			# files = files.map (file)-> path.resolve(file)
			filesToIgnoreExecFor = filesToIgnoreExecFor.concat(files)






























passedStartDelay = ()-> Date.now() - startTime > 3000
passedExecDelay = (filePath)-> 
	if execHistory[filePath]? 
		passed = Date.now() - execHistory[filePath] > execDelay 
	else
		passed = true

	return passed





# Process ============> fireworm -> startProcessingFile[Added] -> processFile -> captureImports -> startExecutionFor -> executeCommandFor

startProcessingFileAdded = (watchedDir)-> return (filePath)-> processFile(filePath, watchedDir, 'added')
startProcessingFile = (watchedDir)-> return (filePath)-> processFile(filePath, watchedDir)

processFile = (filePath, watchedDir, eventType='changed')->	
	fs.stat filePath, (err, stats)->
		if err then console.log(err); return
		
		if stats.isFile()
			fs.readFile filePath, 'utf8', (err, data)->
				if err then console.log(err); return
	
				if not silent and passedStartDelay()
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
	return if not passedStartDelay() and not runNow

	if importHistory[filePath]? # Indicates this file is an import
		importingFiles = importHistory[filePath]
		importingFiles.forEach (file)-> startExecutionFor(file, watchedDir, eventType)
	else executeCommandFor(filePath, watchedDir, eventType)


executeCommandFor = (filePath, watchedDir, eventType)->
	return if not passedExecDelay(filePath) or filesToIgnoreExecFor.indexOf(filePath) isnt -1
	# return if Date.now() - execHistory[filePath] < execDelay
	pathParams = path.parse filePath
	pathParams.reldir = pathParams.dir.replace(watchedDir, '').slice(1)
	execHistory[filePath] = Date.now()

	command = commandToExecute.replace regEx.placeholder, (entire, placeholder)->
		if placeholder is 'path'
			return filePath
		
		else if pathParams[placeholder]?
			return pathParams[placeholder]
		
		else return entire


	exec command, (err, stdout, stderr)->
		unless silent
			if err then console.log(err)
			if stdout then console.log(stdout)
			if stderr then console.log(stderr)
			console.log "Finished executing command for \x1b[32m#{pathParams.base}\x1b[0m\n"
			
			clearTimeout(finallyTimeout) if finallyExecCommand
			finallyTimeout = setTimeout(execFinallyCommand, finallyExecDelay) if finallyExecCommand


execFinallyCommand = ()->
	exec finallyExecCommand, (err, stdout, stderr)->
		unless silent
			if err then console.log(err)
			if stdout then console.log(stdout)
			if stderr then console.log(stderr)
			console.log "Finished executing \x1b[35mfinal command\x1b[0m"








# ==== Start Watching =================================================================================
startTime = Date.now()

dirs.forEach (dir)->
	fw = fireworm dir

	if onlyExt
		onlyExt.forEach (ext)->
			fw.add("**/*.#{ext}")
	else
		fw.add("**/*")

	if ignore and ignore.length
		ignore.forEach (globToIgnore)-> fw.ignore(globToIgnore)

	dirName = if dir.charAt(dir.length-1) is '/' then dir.slice(0, dir.length-1) else dir
	# dirName = dir
	if dirName.charAt(0) is '.'
		dirName = dirName.slice(2)
	else if dirName.charAt(0) is '/'
		dirName = dirName.slice(1)
	

	fw.on('add', startProcessingFileAdded(dirName))
	fw.on('change', startProcessingFile(dirName))

	console.log "Started watching \x1b[36m#{dir}\x1b[0m"







