#!/usr/bin/env coffee
Promise = require 'bluebird'
glob = require 'glob'
chalk = require 'chalk'
chokidar = require 'chokidar'
exec = require('child_process').exec
regEx = require './regex'
getFile = require './FileConstructor'
progressBar = require './progressBar'
yargs = require 'yargs'
yargs
	.usage("#{chalk.bgYellow.black('Usage')} simplywatch -d <directory globs> -s <globs to skip> -i")
	.options(require './cliOptions')
	.help('h')
	.version()
	.wrap(yargs.terminalWidth())
args = yargs.argv
filesToIgnore = []
finallyTimeout = null
startTime = Date.now()
options = 
	'dirs': args.d or args.dir
	'command': args.x or args.execute
	'ignoreList': args.i or args.ignore
	'help': args.h or args.help
	'silent': args.s or args.silent
	'imports': args.t or args.imports
	'runNow': args.n or args.now
	'finalCommand': args.f or args.finally
	'execDelay': args.w or args.wait or 250
	'finalExecDelay': args.W or args.finallywait

if options.help
	process.stdout.write(yargs.help());
	process.exit(0)










queue = new ()->
	@list = {}
	@executionLogs = 'info':{}, 'warn':{}, 'error':{}
	@timeout = null
	
	@add = (filePath, dirContext)->
		file = getFile(filePath, dirContext, options)
		file.scanProcedure.then ()=>
			@list[file.filePath] = file

			for childFile in file.imports
				watcher.add(childFile.filePath)

			if file.deps.length is 0
				@beginProcess()
			else
				Promise
					.map file.deps, (depFile)=>
						@list[depFile.filePath] = depFile
						return depFile.scanProcedure
					
					.then ()=> @beginProcess()



	@beginProcess = ()->
		clearTimeout(@timeout)
		@timeout = setTimeout @process.bind(@), 200		
	


	@process = ()->
		list = (file for filePath,file of @list)
		
		Promise.map(list, (file)=> new Promise (resolve)=>
			delete @list[file.filePath]
			file.executeCommand(options.command).then ({err, stdout, stderr})=>
				switch
					when err then @executionLogs.warn[file.filePath] = err
					when stdout then @executionLogs.info[file.filePath] = stdout
					when stderr then @executionLogs.error[file.filePath] = stderr

				resolve()

		).then ()=> @outputLogs()


	@outputLogs = ()->
		if Object.keys(@executionLogs.info) or Object.keys(@executionLogs.warn) or Object.keys(@executionLogs.error)
			lineCount = Math.floor require('window-size').width * 0.7
			divider = '-'.repeat(lineCount)
			
			process.stdout.write '\n\n'
			console.log divider.slice(0,5)+'COMMAND OUTPUT'+divider.slice(18)
			
			for file,message of @executionLogs.info
				console.log chalk.bgWhite.black.bold.underline("Output")+' '+chalk.dim(file)
				console.log message
				delete @executionLogs.info[file]
			
			for file,message of @executionLogs.warn
				console.log chalk.bgYellow.white.bold.underline("Error")+' '+chalk.dim(file)
				console.warn message
				delete @executionLogs.warn[file]
			
			for file,message of @executionLogs.error
				console.log chalk.bgRed.white.bold.underline("Error Output")+' '+chalk.dim(file)
				console.error message
				delete @executionLogs.error[file]
			
			console.log divider
			process.stdout.write '\n\n'
		return

	return @




processFile = (dirContext)-> (filePath)-> queue.add(filePath, dirContext)






# passedExecDelay = (filePath)-> 
# 	if execHistory[filePath]? 
# 		passed = Date.now() - execHistory[filePath] > options.execDelay 
# 	else
# 		passed = true

# 	return passed





# # Process ============> chokidar -> startProcessingFile[Add] -> processFile -> captureImports -> startExecutionFor -> executeCommandFor

# startProcessingFileAdd = (watchedDir)-> (filePath)-> processFile(filePath, watchedDir, 'Added')
# startProcessingFileChange = (watchedDir)-> (filePath)-> processFile(filePath, watchedDir, 'Changed')

# processFile = (filePath, watchedDir, type)->	
# 	fs.stat filePath, (err, stats)-> if err then console.error(err) else if stats.isFile()
# 		fs.readFile filePath, 'utf8', (err, data)-> if err then console.error(err) else
# 			if not options.silent
# 				console.log chalk.bgGreen.bgGreen.black(type)+' '+chalk.dim(filePath)

# 			captureImports(data, filePath)
# 			startExecutionFor(filePath, watchedDir, type)



# captureImports = (fileContent, filePath)->
# 	if typeof fileContent isnt 'string' then return fileContent
# 	else
# 		extName = path.extname(filePath)
# 		dirPath = path.dirname(filePath)

# 		fileContent.replace regEx.import, (entire, match)->
# 			match = match.replace /'/g, '' # Removes quotes if present
# 			hasExt = regEx.fileExt.test(match)
# 			match += extName if not hasExt
# 			resolvedMatch = path.normalize(dirPath+'/'+match)

# 			if !importHistory[resolvedMatch]?
# 				importHistory[resolvedMatch] = [filePath]
# 			else
# 				importHistory[resolvedMatch].push filePath unless importHistory[resolvedMatch].indexOf(filePath) isnt -1

# 			try
# 				stats = fs.statSync resolvedMatch
# 				if stats.isFile()
# 					matchFileContent = fs.readFileSync resolvedMatch, 'utf8'
# 					captureImports(matchFileContent, resolvedMatch)

# 			return entire

		

# startExecutionFor = (filePath, watchedDir, type)->
# 	return if not passedStartDelay() and not options.runNow

# 	if importHistory[filePath]? # Indicates this file is an import
# 		importingFiles = importHistory[filePath]
# 		importingFiles.forEach (file)-> startExecutionFor(file, watchedDir, eventType)
# 	else executeCommandFor(filePath, watchedDir, eventType)


# executeCommandFor = (filePath, watchedDir, eventType)->
# 	return if not passedExecDelay(filePath) or filesToIgnore[filePath]?
# 	pathParams = path.parse filePath
# 	pathParams.reldir = pathParams.dir.replace(watchedDir, '').slice(1)
# 	execHistory[filePath] = Date.now()

# 	command = options.command.replace regEx.placeholder, (entire, placeholder)->
# 		if placeholder is 'path'
# 			return filePath
		
# 		else if pathParams[placeholder]?
# 			return pathParams[placeholder]
		
# 		else return entire


# 	exec command, (err, stdout, stderr)->
# 		unless options.silent
# 			if err then console.log(err)
# 			if stdout then console.log(stdout)
# 			if stderr then console.log(stderr)
# 			console.log "Finished executing command for \x1b[32m#{pathParams.base}\x1b[0m\n"
			
# 			clearTimeout(finallyTimeout) if options.finalCommand
# 			finallyTimeout = setTimeout(execFinallyCommand, options.finalExecDelay) if options.finalCommand


# execFinallyCommand = ()->
# 	exec options.finalCommand, (err, stdout, stderr)->
# 		unless options.silent
# 			if err then console.log(err)
# 			if stdout then console.log(stdout)
# 			if stderr then console.log(stderr)
# 			console.log "Finished executing \x1b[35mfinal command\x1b[0m"








# ==== Start Watching =================================================================================
if options.ignoreList then options.ignoreList.forEach (ignoreGlob)->
	glob ignoreGlob, (err, files)-> if err then throw err else
		filesToIgnore = filesToIgnore.concat(files)


watcher = chokidar.watch([], 'cwd':process.cwd(), 'ignoreInitial':!options.runNow)
options.dirs.forEach (dirPath)->
	watcher.add dirPath


	dirName = if dirPath.slice(-1)[0] is '/' then dirPath.slice(0,-1) else dirPath

	if dirName[0] is '.'
		dirName = dirName.slice(2)
	else if dirName[0] is '/'
		dirName = dirName.slice(1)
	

	watcher.on 'add', processFile(dirPath).bind(@)
	watcher.on 'change', processFile(dirPath).bind(@)

	console.log chalk.bgYellow.black('Watching')+' '+chalk.dim(dirPath)







