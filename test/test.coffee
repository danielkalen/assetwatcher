global.Promise = require 'bluebird'
fs = Promise.promisifyAll require 'fs-extra'
path = require 'path'
chai = require 'chai'
expect = chai.expect
should = chai.should()
execa = require 'execa'
chokidar = require 'chokidar'
fsOpts = encoding:'utf8'
testWatcher = null
customStdout = require('through')(null, null, autoDestroy:false)
customStderr = require('through')(null, null, autoDestroy:false)



SimplyWatch = (options)->
	options.execDelay = 1 unless options.execDelay
	options.stdout = customStdout
	options.stderr = customStderr
	
	clearRequireCache()
	require('../lib/simplywatch')(options)


clearRequireCache = ()->
	files = fs.readdirSync('lib')
	for file in files
		delete require.cache["#{process.cwd()}/lib/#{file}"]





triggerFileChange = (filePath, resultPath, timeoutLength=6000)->
	emptyResults = 'result':'', 'resultLines':['null']
	awaitWatcher = if resultPath then testWatcher.ready else Promise.resolve()
	READ_DELAY = if process.platform is 'darwin' then 0 else 200
	
	fs.readFileAsync(filePath, fsOpts).delay(READ_DELAY).then (contents)->
		awaitWatcher.then ()->
			if not resultPath
				fs.writeFileAsync(filePath, contents).then ()-> emptyResults
			else
				awaitChange = new Promise (emitChange)->
					testWatcher.on 'add', emitChange
					testWatcher.on 'change', emitChange
					testWatcher.add(resultPath)
					Promise.delay(timeoutLength).then(emitChange)
					
				fs.writeFileAsync(filePath, contents)
				awaitChange.then (file)-> #if not file or path.resolve(file) is path.resolve(resultPath)
					testWatcher.unwatch(resultPath)

					fs.readFileAsync(resultPath, fsOpts)
						.then (result)->
							resultLines = result.split('\n').filter (validLine)-> validLine
							return {result, resultLines}
						
						.catch ()->
							return emptyResults
















suite "SimplyWatch", ()->
	suiteTeardown ()-> fs.removeAsync('test/temp') unless process.env.KEEP
	suiteSetup ()-> fs.emptyDirAsync('test/temp').then ()->
		testWatcher = chokidar.watch 'test/temp/**',
			'cwd':process.cwd()
			'awaitWriteFinish': 'stabilityThreshold': if process.env.CI then 1000 else 1
		
		testWatcher.ready = new Promise (resolve)->
			testWatcher.on 'ready', resolve
			setTimeout resolve, 1000
		return



	suite "File handling", ()->
		suiteTeardown ()-> fs.emptyDirAsync 'test/temp' unless process.env.KEEP
		
		test "If a discovered import has no extension specified, various file extensions will be used to check for a valid file", ()->
			options = globs:['test/samples/sass/*'], command:'echo {{base}} >> test/temp/one'
			
			SimplyWatch(options).then (watcher)-> watcher.ready.then ()->
				triggerFileChange('test/samples/sass/nested/one.sass', 'test/temp/one', 7000).then ({result, resultLines})->
					if process.env.CI and result is ''
						expect(true).to.be.true
						return watcher.close()
					
					expect(result).to.include "main.sass"
					expect(result).to.include "main.copy.sass"
					expect(resultLines.length).to.equal 2

					watcher.close()

	














	suite "Watching & Command Execution", ()->
		suiteTeardown ()-> fs.emptyDirAsync 'test/temp' unless process.env.KEEP


		test "Will execute a given command on all matched files/dirs in a given glob upon change", ()->
			options = globs:['test/samples/js/**'], command:'echo {{base}} >> test/temp/one'
			
			SimplyWatch(options).then (watcher)-> watcher.ready.then ()->
				triggerFileChange('test/samples/js/mainCopy.js', 'test/temp/one').then ({result, resultLines})->
					expect(resultLines[0]).to.equal 'mainCopy.js'
					
					watcher.close()
		

		


		test "Will search for imports (SimplyImport syntax) and if an import changes only its dependents will get updated", ()-> if process.env.CI then @skip() else
			options = globs:['test/samples/js/**'], command:'echo {{base}} >> test/temp/two'
			
			SimplyWatch(options).then (watcher)-> watcher.ready.then ()->
				triggerFileChange('test/samples/js/nested/one.js', 'test/temp/two').then ({result, resultLines})->
					expect(result).not.to.include 'one.js'
					expect(result).to.include 'mainCopy.js'
					expect(result).to.include 'mainCopy2.js'
					
					watcher.close()
		

		

		test "Commands will only execute once if changed multiple times within the execDelay option", ()-> if process.env.CI then @skip() else
			options = globs:['test/samples/js/*'], command:'echo {{name}} >> test/temp/three', execDelay:5000
			
			SimplyWatch(options).then (watcher)-> watcher.ready.then ()->
				triggerFileChange('test/samples/js/mainCopy.js', 'test/temp/three').then ()->
					triggerFileChange('test/samples/js/mainCopy.js', 'test/temp/three.2', 500).then ()->
						fs.readFileAsync('test/temp/three', encoding:'utf8').then (result)->
							expect(result).to.equal "mainCopy\n"

							fs.readFileAsync('test/temp/three.2', encoding:'utf8').catch (err)->
								expect(err).to.be.an.error

								watcher.close()
				

			

		test "Error messages from commands will be outputted to the terminal as well", ()->
			options = globs:['test/samples/js/*'], command:'echo {{name}} > test/temp/three.5 && >&2 echo "{{name}}" && exit 2'
			stdout = ''
			customStdout.on 'data', (chunk)-> stdout+=chunk
			
			SimplyWatch(options).then (watcher)-> watcher.ready.then ()->
				triggerFileChange('test/samples/js/mainCopy.js', 'test/temp/three.5').then ()->
					expect(stdout).to.include "Error"
					expect(stdout).to.include "mainCopy"

					watcher.close()
			

			

		test "Error messages from commands will be treated as stdout if the command's exit code was 0", ()->
			options = globs:['test/samples/js/*'], command:'echo {{name}} > test/temp/three.5.5 && >&2 echo "{{name}}"'
			stdout = ''
			customStdout.on 'data', (chunk)-> stdout+=chunk
			
			SimplyWatch(options).then (watcher)-> watcher.ready.then ()->
				triggerFileChange('test/samples/js/mainCopy.js', 'test/temp/three.5.5').then ()->
					expect(stdout).not.to.include "Error"
					expect(stdout).to.include "mainCopy"

					watcher.close()
			

			

		test "If the command exits with a non-zero status code and there isn't any stdout, the actual error message will be written to the terminal", ()->
			options = globs:['test/samples/js/*'], command:'echo > test/temp/three.5.5.5 && exit 2'
			stdout = ''
			customStdout.on 'data', (chunk)-> stdout+=chunk
			
			SimplyWatch(options).then (watcher)-> watcher.ready.then ()->
				triggerFileChange('test/samples/js/mainCopy.js', 'test/temp/three.5.5.5').then ()->
					expect(stdout).to.include "Error: Command failed:"

					watcher.close()









		suite "Placeholders", ()->		
			test "Commands can have placeholders in them replaced by the file's values", ()->
				options = globs:['test/samples/js/**'], command:'echo "{{name}} {{ext}} {{base}} {{reldir}} {{path}} {{dir}}" >> test/temp/four'
				
				SimplyWatch(options).then (watcher)-> watcher.ready.then ()->
					triggerFileChange('test/samples/js/mainCopy.js', 'test/temp/four').then ({result, resultLines})->
						expect(resultLines[0]).to.equal "mainCopy .js mainCopy.js  test/samples/js/mainCopy.js #{__dirname}/samples/js"

						watcher.close()
			

			

			test "Placeholders can be denoted either with dual curly braces or just a hash+single curly braces", ()->
				options = globs:['test/samples/js/**'], command:'echo "#{name} #{ext} #{base} #{reldir} #{path} #{dir}" >> test/temp/five'
				
				SimplyWatch(options).then (watcher)-> watcher.ready.then ()->
					triggerFileChange('test/samples/js/mainCopy.js', 'test/temp/five').then ({result, resultLines})->
						expect(resultLines[0]).to.equal "mainCopy .js mainCopy.js  test/samples/js/mainCopy.js #{__dirname}/samples/js"

						watcher.close()
			

			

			test "Invalid placeholders will remain unreplaced", ()->
				options = globs:['test/samples/js/*'], command:'echo "{{name}} {{badPlaceholder}}" >> test/temp/six'
				
				SimplyWatch(options).then (watcher)-> watcher.ready.then ()->
					triggerFileChange('test/samples/js/mainCopy.js', 'test/temp/six').then ({result, resultLines})->
						expect(resultLines[0]).to.equal "mainCopy {{badPlaceholder}}"

						watcher.close()











		suite "Options", ()->
			test "If options.trim is set to a number, any output messages from commands will be trimmed to only the first X characters", ()->
				options = globs:['test/samples/js/*'], command:'echo {{name}} > test/temp/seven && echo {{name}}', trim:5
				stdout = ''
				customStdout.on 'data', (chunk)-> stdout+=chunk
				
				SimplyWatch(options).then (watcher)-> watcher.ready.then ()->
					triggerFileChange('test/samples/js/mainCopy.js', 'test/temp/seven').then ()->
						expect(stdout).to.include "mainC\n"
						watcher.close()
		


			test "If options.ignoreGlobs is provided, any file that matches the ignore glob (even partially) will not have a command executed for it, but if it is imported by a parent file then the parent will be processed", ()->
				options = globs:['./test/samples/js/**'], ignoreGlobs:['test/samples/js/nested'], command:'echo {{base}} >> test/temp/eight'
				
				SimplyWatch(options).then (watcher)-> watcher.ready.then ()->
					Promise.all([
						# triggerFileChange('test/samples/js/mainCopy2.js')
						triggerFileChange('test/samples/js/nested/one.js')
						triggerFileChange('test/samples/js/nested/three.js')
						triggerFileChange('test/samples/js/mainDiff.js', 'test/temp/eight').delay(100)
					]).then (resultArray)->
						result = resultArray[2].result
						resultLines = resultArray[2].resultLines

						expect(result).to.include 'mainDiff.js'
						expect(result).to.include 'mainCopy2.js'
						expect(result).to.include 'mainCopy.js'
						expect(resultLines.length).to.equal 3
						
						watcher.close()




			test "Files inside .git/ will autotomatically be ignored", ()->
				options = globs:['test/temp2/**'], command:'echo {{base}} >> test/temp/eight.5'
				
				Promise.all([
					fs.ensureFileAsync('test/temp2/.git/insideGit.js')
					fs.ensureFileAsync('test/temp2/git/outsideGit.js')
				]).then ()->
					SimplyWatch(options).then (watcher)-> watcher.ready.then ()->
						Promise.all([
							triggerFileChange('test/temp2/git/outsideGit.js', 'test/temp/eight.5')
							triggerFileChange('test/temp2/.git/insideGit.js')
						]).then (resultArray)->
							result = resultArray[0].result
							resultLines = resultArray[0].resultLines
							
							expect(resultLines.length).to.equal 1
							expect(resultLines[0]).to.equal 'outsideGit.js'
							
							fs.remove 'test/temp2', ()->
								watcher.close()


			
			test "If a command is provided for options.finalCommand, that command will be executed after each batch of file changes has been processed", ()->
				options = globs:['test/samples/js/**'], command:' ', finalCommand:'echo "Final command executed" > test/temp/nine && echo {{name}}', finalCommandDelay:1
				
				SimplyWatch(options).then (watcher)-> watcher.ready.then ()->
					triggerFileChange('test/samples/js/mainCopy.js', 'test/temp/nine').then ({result, resultLines})->
						expect(resultLines[0]).to.equal 'Final command executed'
						
						watcher.close()


			
			test "The final command will only execute once in a given delay (options.finalCommandDelay)", ()->
				options = globs:['test/samples/js/**'], command:' ', finalCommand:'echo "Final command executed" >> test/temp/ten', finalCommandDelay:500
				
				SimplyWatch(options).then (watcher)-> watcher.ready.then ()->
					triggerFileChange('test/samples/js/mainCopy.js').then ()->
						Promise.delay(350).then ()->
							triggerFileChange('test/samples/js/mainCopy2.js', 'test/temp/ten').then ({result, resultLines})->
								expect(resultLines.length).to.equal 1
								expect(resultLines[0]).to.equal 'Final command executed'
								
								watcher.close()
			

			

			test "If the final command exits with a non-zero status code the error message will be written to the terminal", ()-> if process.env.CI then @skip() else
				options = globs:['test/samples/js/**'], command:' ', finalCommand:'echo "Final command executed" >> test/temp/ten.5 && exit 2', finalCommandDelay:1
				stderr = ''
				customStderr.on 'data', (chunk)-> stderr+=chunk
				
				SimplyWatch(options).then (watcher)-> watcher.ready.then ()->
					triggerFileChange('test/samples/js/mainDiff.js', 'test/temp/ten.5').then ({result, resultLines})->
						expect(result).to.include 'Final command executed'
						expect(stderr).to.include "Error: Command failed:"

						watcher.close()
			

			

			test "If a command exists with a non-zero status the final command execution will be canceled", ()-> if process.env.CI then @skip() else
				options = globs:['test/samples/js/*'], command:'echo {{base}} > test/temp/ten.5.5 && exit 2', finalCommand:'echo "Final command executed"', finalCommandDelay:1
				stdout = ''
				customStdout.on 'data', (chunk)-> stdout+=chunk
				
				SimplyWatch(options).then (watcher)-> watcher.ready.then ()->
					triggerFileChange('test/samples/js/mainDiff.js', 'test/temp/ten.5.5').then ({result, resultLines})->
						expect(result).to.include "mainDiff.js"
						expect(stdout).to.include "Error: Command failed:"
						expect(stdout).to.include 'NOT'
						expect(stdout).to.include 'Executing Final Command'
						expect(stdout).to.include '(because some tasks failed)'

						watcher.close()






	suite "Errors", ()->
		test "An error will be thrown if no globs are provided", ()->
			expectation = (err)->
				expect(err).to.be.an.error
				expect(err.message).to.equal 'No globs were provided'
			SimplyWatch({command:'echo {{name}}'}).then expectation, expectation
		
		
	
		test "An error will be thrown if an empty globs array is provided", ()->
			expectation = (err)->
				expect(err).to.be.an.error
				expect(err.message).to.equal 'No globs were provided'
		
			SimplyWatch({globs:[], command:'echo {{name}}'}).then expectation, expectation
		
		
		
		test "An error will NOT be thrown if an a non-array value is used for the globs param", ()->
			expectation = (err)->
				expect(err).not.to.be.an.error
		
			SimplyWatch({globs:'*', command:'echo {{name}}'}).then expectation, expectation
		
		
	
		test "An error will be thrown if no command is given", ()->
			expectation = (err)->
				expect(err).to.be.an.error
				expect(err.message).to.equal 'Execution command not provided'
			
			SimplyWatch({globs:['*']}).then expectation, expectation
		












