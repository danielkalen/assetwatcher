#!/usr/bin/env node
options =
	'd': 
		alias: 'dir'
		describe: 'Specify all dirs to watch for in quotes, separated with commas. Syntax: -d "dirA" "dirB"'
		type: 'array'
		demand: true
	'i': 
		alias: 'ignore'
		describe: 'Specify all globs to ignore in quotes, separated with commas. Changes to matching files will NOT trigger any executions even if imported by another file. Syntax: -s "globA" "globB"'
		type: 'array'
	'I': 
		alias: 'ignoreweak'
		describe: 'Specify all globs to weakly ignore in quotes, separated with commas. Changes to matching files WILL trigger an execution if imported by another file. Syntax: -s "globA" "globB"'
		type: 'array'
	'e': 
		alias: 'extension'
		describe: 'Only watch files that have a specific extension. Syntax: -e "ext1" "ext2"'
		type: 'array'
	'x': 
		alias: 'execute'
		describe: 'Command to execute upon file addition/change'
		type: 'string'
		demand: true
	'f': 
		alias: 'finally'
		describe: 'Command to execute X ms (default: 3000) after the addition/change of the last file. For example if some file change triggered a command to be run for 10 files, after 3 seconds this "finally" command will be run once.'
		type: 'string'
	's': 
		alias: 'silent'
		describe: 'Suppress any output from the executing command'
		type: 'boolean'
		default: false
	'n': 
		alias: 'now'
		describe: 'Execute the command for all files matched immediatly on startup'
		type: 'boolean'
		default: false
	't': 
		alias: 'imports'
		describe: 'Optionally compile files that are imported by other files.'
		type: 'boolean'
		default: false
	'w': 
		alias: 'wait'
		describe: 'Execution delay, i.e. how long should the assetwatcher wait before re-executing the command. If the watched file changes rapidly, the command will execute only once every X ms.'
		type: 'number'
		default: 1500
	'W': 
		alias: 'finallywait'
		describe: 'The amount of milliseconds to wait before executing the finally command (if passed).'
		type: 'number'
		default: 3000


fs = require('fs')
glob = require('glob')
path = require('path')
fireworm = require('fireworm')
exec = require('child_process').exec
yargs = require('yargs')
		.usage("Usage: assetwatcher -d <directory globs> -s <globs to skip> -i")
		.options(options)
		.help('h')
		.alias('h', 'help')
args = yargs.argv


regEx =
	ext: /.+\.(sass|scss|js|coffee)$/i
	import: /@import\s*(.+)/ig
	placeholder: /\#\{([^\/\}]+)\}/ig
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







