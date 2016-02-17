#!/usr/bin/env node
options =
	'd': 
		alias: 'dir'
		describe: 'Specify all dirs to watch for in quotes, separated with commas. Syntax: -d "dirA" "dirB"'
		type: 'array'
		demand: true
	'i': 
		alias: 'ignore'
		describe: 'Specify all globs to ignore in quotes, separated with commas. Syntax: -s "globA" "globB"'
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


fs = require('fs')
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
	placeholder: /\#\{(\S+)\}/ig
importHistory = {}
execHistory = {}

dirs = args.d || args.dir
ignore = args.i || args.ignore
help = args.h || args.help
silent = args.s || args.silent
imports = args.t || args.imports
onlyExt = args.e || args.extension
commandToExecute = args.x || args.execute
runNow = args.n || args.now
execDelay = args.w || args.wait

if help
	process.stdout.write(yargs.help());
	process.exit(0)




# Process = 	fireworm -> startProcessingFile[Added] -> processFile -> captureImports -> startExecutionFor -> executeCommandFor

startProcessingFileAdded = (watchedDir)-> return (filePath)-> processFile(filePath, watchedDir, 'added')
startProcessingFile = (watchedDir)-> return (filePath)-> processFile(filePath, watchedDir)

processFile = (filePath, watchedDir, eventType='changed')->
	return if Date.now() - startTime < 3000 and !runNow
	fs.stat filePath, (err, stats)->
		if err then console.log(err); return
		if stats.isFile()
			fs.readFile filePath, 'utf8', (err, data)->
				if err then console.log(err); return

				captureImports(data, filePath)
				startExecutionFor(filePath, filePath, watchedDir, eventType)



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
				importHistory[resolvedMatch].push filePath

			try
				stats = fs.statSync resolvedMatch
				if stats.isFile()
					matchFileContent = fs.readFileSync resolvedMatch, 'utf8'
					captureImports(matchFileContent, resolvedMatch)

			return entire

		

startExecutionFor = (filePath, triggeringFile, watchedDir, eventType)->
	if importHistory[filePath]? # Indicates this file is an import
		importingFiles = importHistory[filePath]
		importingFiles.forEach (file)-> startExecutionFor(file, filePath, watchedDir, eventType)
	else executeCommandFor(filePath, triggeringFile or filePath, watchedDir, eventType)


executeCommandFor = (filePath, triggeringFile, watchedDir, eventType)->
	return if execHistory[filePath]? and Date.now() - execHistory[filePath] < execDelay
	pathParams = path.parse filePath
	pathParams.reldir = pathParams.dir.replace(watchedDir, '').slice(1)
	execHistory[filePath] = Date.now()

	unless silent then console.log "File #{eventType}: #{triggeringFile}"

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







