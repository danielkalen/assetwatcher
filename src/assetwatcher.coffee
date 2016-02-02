#!/usr/bin/env node
options =
	'd': 
		alias: 'dir'
		describe: 'Specify all dirs to watch for in quotes, separated with commas. Syntax: -d "dirA", "dirB"'
		type: 'array'
		demand: true
	'i': 
		alias: 'ignore'
		describe: 'Specify all globs to ignore in quotes, separated with commas. Syntax: -s "globA", "globB"'
		type: 'array'
	'e': 
		alias: 'extension'
		describe: 'Only watch files that have a specific extension'
		type: 'string'
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
	't': 
		alias: 'imports'
		describe: 'Optionally compile files that are imported by other files.'
		type: 'boolean'
		default: false


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
	placeholder: /#\{(.+)\}/ig
importHistory = {}
execHistory = {}

dirs = args.d || args.dir
ignore = args.i || args.ignore
help = args.h || args.help
silent = args.s || args.silent
imports = args.t || args.imports
onlyExt = args.e || args.extension
commandToExecute = args.x || args.execute

if help
	process.stdout.write(yargs.help());
	process.exit(0)



captureImports = (fileContent, filePath)->
	if typeof fileContent isnt 'string' then return fileContent
	else
		extName = path.extname(filePath)
		dirPath = path.dirname(filePath)

		fileContent.replace regEx.import, (entire, match)->
			match = match.replace /'/g, '' # Removes quotes if present
			hasExt = regEx.ext.test(match)
			match += extName if not hasExt
			resolvedMatch = dirPath+'/'+path.normalize(match)

			if !importHistory[resolvedMatch]?
				importHistory[resolvedMatch] = [filePath]
			else
				importHistory[resolvedMatch].push filePath

			fs.readFile resolvedMatch, 'utf8', (err, data)->
				if err then console.log(err); return
				captureImports(data, resolvedMatch)

			return entire



processFile = (filePath)->
	fs.readFile filePath, 'utf8', (err, data)->
		if err then console.log(err); return
		
		captureImports(data, filePath)
		startExecutionFor(filePath)
		

startExecutionFor = (filePath)->
	if importHistory[filePath]? # Indicates this file is an import
		importingFiles = importHistory[filePath]
		importingFiles.forEach (file)-> startExecutionFor(file)
	else executeCommandFor(filePath)


executeCommandFor = (filePath)->
	return if execHistory[filePath]? and Date.now() - execHistory[filePath] < 1500
	pathParams = path.parse filePath
	execHistory[filePath] = Date.now()

	unless silent then console.log "File changed: #{filePath}"

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




# ==== Start Watching =================================================================================
dirs.forEach (dir)->
	fw = fireworm(dir)

	if onlyExt
		fw.add("*.#{onlyExt}")
		fw.add("**/*.#{onlyExt}")
	else
		fw.add("*")
		fw.add("**/*")

	if ignore and ignore.length
		ignore.forEach (globToIgnore)-> fw.ignore(globToIgnore)

	fw.on('add', processFile)
	fw.on('change', processFile)







