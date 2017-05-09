global.Promise = require 'bluebird'; Promise.config longStackTraces:true if process.env.CI
promiseWait = require 'p-wait-for'
_ = require 'lodash'
fs = require 'fs-jetpack'
path = require 'path'
absPath = require 'abs'
chai = require 'chai'
expect = chai.expect
should = chai.should()
execa = require 'execa'
extend = require 'smart-extend'
retry = require 'promise-retry'
testWatcher = require('@danielkalen/chokidar').watch([], {ignoreInitial:true})
customStdout = require('through')(null, null, autoDestroy:false)
customStderr = require('through')(null, null, autoDestroy:false)
_SimplyWatch = require('../lib/simplywatch')

SimplyWatch = (options, awaitInitialScan)->
	options.silent = true unless options.silent?
	options.bufferTimeout = 1 unless options.bufferTimeout
	options.stdout = customStdout
	options.stderr = customStderr
	# options.useFsEvents = false
	
	_SimplyWatch(options, awaitInitialScan)

randSample = ()-> rand=!rand; if rand=!rand then 'test/samples/js/sampleA.js' else 'test/samples/js/sampleB.js'
sample = ()-> path.join __dirname,'samples',arguments...
pathParams = (target)->
	params = path.parse(target)
	params.path = path.resolve(target)
	params.dir = path.resolve(params.dir)
	return params


triggerFileChange = (filePath)->
	actualChange = new Promise (resolve)-> testWatcher.once 'change', resolve
	
	Promise.resolve()
		.then ()-> testWatcher.add(filePath)
		.then ()-> fs.readAsync(filePath)
		.delay(0)
		# .delay if process.platform is 'darwin' then 0 else 200
		# .then (contents)-> fs.writeAsync(filePath, contents)
		
		.then (contents)->
			retry (tryAgain)->
				fs.writeAsync(filePath, contents)
				new Promise (resolve, reject)->
					actualChange.then(resolve)
					setTimeout (-> reject new Error),300
				.catch(tryAgain)
			, {retries:200, minTimeout:100}

		.timeout(3000)
		.catch Promise.TimeoutError, ()->;

			
runWatchTask = (options)->
	watchTask = null
	results = []
	options.timeout ?= 4000
	options.targetChange = options.glob if not options.targetChange
	options.targetChange = [options.targetChange] if not Array.isArray(options.targetChange)
	options = extend.deep(
		{expected:0, expectedTarget:'results', opts: {globs:[options.glob], command:(file, params)-> results.push(params)}}
		options
	)
	
	Promise.resolve()
		.then ()-> SimplyWatch options.opts
		.then ()-> watchTask = arguments[0]
		.then ()-> Promise.map options.targetChange, (item)->
			if typeof item is 'string' then triggerFileChange(item) else Promise.delay(item[0]).then ()-> triggerFileChange(item[1])
		
		.then ()-> promiseWait ()-> 
			switch options.expectedTarget
				when 'results'
					results.length >= options.expected

				when 'command'
					watchTask.queue.cycles >= options.expected

				when 'finalCommand'
					watchTask.queue.finalCycles >= options.expected

				when 'delay'
					Promise.delay(options.expected).return(true)

				when 'file'
					fs.existsAsync(options.expected).then (exists)->
						results = fs.read(options.expected) if exists
						return !!exists
		
		.timeout(options.timeout).catch Promise.TimeoutError, ()->;
		.then ()-> results = _.sortBy(results, options.sort) if options.sort
		.then ()-> [results, watchTask]










suite "SimplyWatch", ()->
	suiteTeardown ()-> fs.removeAsync('test/temp') unless process.env.KEEP
	suiteSetup ()-> Promise.all [
		fs.dirAsync('test/temp', empty:true)
		fs.fileAsync('test/samples/js/sampleA.js')
		fs.fileAsync('test/samples/js/sampleB.js')
	]



	suite "File handling", ()->
		test "If a discovered import has no extension specified, various file extensions will be used to check for a valid file", ()->
			runWatchTask(
				expected:2
				glob: 'test/samples/sass/*'
				targetChange: sample('sass/nested/one.sass')
				sort: 'base'
			).spread (results, watchTask)->
				expect(results.length).to.equal(2)
				expect(results[0].base).to.equal "main.copy.sass"
				expect(results[1].base).to.equal "main.sass"

				watchTask.stop()






	suite "Watching & Command Execution", ()->
		test "Will execute a given command on all matched files/dirs in a given glob upon change", ()->
			runWatchTask(
				expected:1
				glob: 'test/samples/js/*'
				targetChange: targetFile=randSample()
			).spread (results, watchTask)->
				expect(results.length).to.equal(1)
				expect(results[0].base).to.equal path.basename(targetFile)

				watchTask.stop()
		

		test "Will search for imports and if an import changes only its dependents will get updated", ()->
			runWatchTask(
				expected:2
				glob: 'test/samples/js/**'
				targetChange: sample('js/nested/one.js')
				sort: 'base'
			).spread (results, watchTask)->
				expect(results.length).to.equal(2)
				expect(results[0].base).to.equal "mainCopy.js"
				expect(results[1].base).to.equal "mainCopy2.js"

				watchTask.stop()
		

		test.skip "Commands will only execute once if changed multiple times within the execDelay option", ()->
			options = globs:['test/samples/js/*'], command:'echo {{name}} >> test/temp/three', execDelay:5000
			
			SimplyWatch(options).then (watcher)-> watcher.ready.then ()->
				triggerFileChange('test/samples/js/mainCopy.js', 'test/temp/three').then ()->
					triggerFileChange('test/samples/js/mainCopy.js', 'test/temp/three.2', 500).then ()->
						fs.readAsync('test/temp/three', encoding:'utf8').then (result)->
							expect(result).to.equal "mainCopy\n"

							fs.readAsync('test/temp/three.2', encoding:'utf8').catch (err)->
								expect(err).to.be.an.error

								watcher.close()
				
		

		test "Error messages from string commands will be outputted to the terminal as well", ()->
			stdout = ''
			customStdout.on 'data', (chunk)-> stdout+=chunk

			runWatchTask(
				expected:1
				expectedTarget: 'command'
				silent: false
				glob: targetFile = randSample()
				opts:
					command: '>&2 echo "theError" && exit 2'
			).spread (results, watchTask)->
				expect(stdout).to.include path.basename(targetFile)
				expect(stdout).to.include "theError"

				watchTask.stop()
		


		test "Error messages from commands will be treated as stdout if the command's exit code was 0", ()->
			stdout = ''
			customStdout.on 'data', (chunk)-> stdout+=chunk
			
			runWatchTask(
				expected:1
				expectedTarget: 'command'
				silent: false
				glob: targetFile = randSample()
				opts:
					command: '>&2 echo "stdErr"'
			).spread (results, watchTask)->
				expect(stdout).to.include path.basename(targetFile)
				expect(stdout).to.include "stdErr"

				watchTask.stop()
		


		test "If the command exits with a non-zero status code and there isn't any stdout, the actual error message will be written to the terminal", ()->
			stdout = ''
			customStdout.on 'data', (chunk)-> stdout+=chunk
			
			runWatchTask(
				expected:1
				expectedTarget: 'command'
				silent: false
				glob: targetFile = randSample()
				opts:
					command: 'exit 1'
			).spread (results, watchTask)->
				expect(stdout).to.include path.basename(targetFile)
				expect(stdout).to.include "Command failed:"

				watchTask.stop()







	suite "Placeholders", ()->
		test "function commands can have placeholders in them replaced by the file's values", ()->
			runWatchTask(
				expected:1
				glob: targetFile = randSample()
			).spread (results, watchTask)->
				expect(results.length).to.equal 1
				params = pathParams(targetFile)
				expect(results[0]).to.eql
					name: params.name
					ext: params.ext
					base: params.base
					reldir: ''
					path: params.path
					dir: params.dir
					root: '/'

				watchTask.stop()


		test "Commands can have placeholders in them replaced by the file's values", ()->
			runWatchTask(
				expected:'test/temp/four'
				expectedTarget:'file'
				glob: targetFile = randSample()
				opts:
					command: 'echo "{{name}} {{ext}} {{base}} {{reldir}} {{path}} {{dir}}" >> test/temp/four'
			).spread (results, watchTask)->
				results = results.split '\n'
				params = pathParams(targetFile)
				expect(results[0]).to.equal "#{params.name} #{params.ext} #{params.base}  #{params.path} #{params.dir}"

				watchTask.stop()
		

		test "Placeholders can be denoted either with dual curly braces or just a hash+single curly braces", ()->
			runWatchTask(
				expected:'test/temp/five'
				expectedTarget:'file'
				glob: targetFile = randSample()
				opts:
					command: 'echo "#{name} #{ext} #{base} #{reldir} #{path} #{dir}" >> test/temp/five'
			).spread (results, watchTask)->
				results = results.split '\n'
				params = pathParams(targetFile)
				expect(results[0]).to.equal "#{params.name} #{params.ext} #{params.base}  #{params.path} #{params.dir}"

				watchTask.stop()
		

		test "Invalid placeholders will remain unreplaced", ()->
			runWatchTask(
				expected:'test/temp/six'
				expectedTarget:'file'
				glob: targetFile = randSample()
				opts:
					command: 'echo "{{name}} {{badPlaceholder}}" >> test/temp/six'
			).spread (results, watchTask)->
				results = results.split '\n'
				params = pathParams(targetFile)
				expect(results[0]).to.equal "#{params.name} {{badPlaceholder}}"

				watchTask.stop()			







	suite "Options", ()->
		test "If options.trim is set to a number, any output messages from commands will be trimmed to only the first X characters", ()->
			stdout = ''
			customStdout.on 'data', (chunk)-> stdout+=chunk
			
			runWatchTask(
				expected:1
				expectedTarget: 'command'
				silent: false
				glob: 'test/samples/js/**'
				targetChange: sample('js/mainCopy.js')
				opts:
					command: 'echo {{name}}'
					trim: 6
			).spread (results, watchTask)->
				expect(stdout).to.include 'js/mainCopy.js'
				expect(stdout).to.include "mainC…"

				watchTask.stop()
		


		test "If options.ignoreGlobs is provided, any file that matches the ignore glob (even partially) will not have a command executed for it, but if it is imported by a parent file then the parent will be processed", ()->
			runWatchTask(
				expected:3
				glob: 'test/samples/js/**'
				timeout: 1500
				targetChange: [sample('js/nested/one.js'), sample('js/nested/three.js'), sample('js/mainDiff.js')]
				sort: 'base'
				opts:
					# bufferTimeout: 150
					ignoreGlobs: 'test/samples/js/nested'
			).spread (results, watchTask)->
				expect(results.length).to.equal(3)
				expect(results[0].base).to.equal "mainCopy.js"
				expect(results[1].base).to.equal "mainCopy2.js"
				expect(results[2].base).to.equal "mainDiff.js"

				watchTask.stop()
		


		test "Files inside .git/ will autotomatically be ignored", ()->
			Promise.all([
				fs.fileAsync('test/temp2/.git/insideGit.js')
				fs.fileAsync('test/temp2/git/outsideGit.js')
			]).then ()->
				runWatchTask(
					expected:1
					glob: 'test/temp2/**'
					targetChange: ['test/temp2/.git/insideGit.js', 'test/temp2/git/outsideGit.js']
				).spread (results, watchTask)->
					expect(results.length).to.equal(1)
					expect(results[0].base).to.equal "outsideGit.js"

					watchTask.stop()
					fs.removeAsync('test/temp2')


		
		test "If a function is provided for options.finalCommand, that command will be executed after each batch of file changes has been processed", ()->
			finalCommandExecuted = false

			runWatchTask(
				expected:1
				expectedTarget: 'finalCommand'
				glob: 'test/samples/js/**'
				targetChange: sample('js/mainCopy.js')
				opts:
					finalCommand: ()-> finalCommandExecuted = true
					finalCommandDelay: 1
			).spread (results, watchTask)->
				expect(finalCommandExecuted).to.be.true

				watchTask.stop()


		
		test "If a string is provided for options.finalCommand, that command will be executed after each batch of file changes has been processed", ()->
			stdout = ''
			customStdout.on 'data', (chunk)-> stdout+=chunk

			runWatchTask(
				expected:1
				expectedTarget: 'finalCommand'
				silent: false
				glob: 'test/samples/js/**'
				targetChange: sample('js/mainCopy.js')
				opts:
					finalCommand: 'echo "final command was executed"'
					finalCommandDelay: 1
			).spread (results, watchTask)->
				expect(stdout).to.include 'final command was executed'

				watchTask.stop()


		
		test "The final command will only execute once in a given delay (options.finalCommandDelay)", ()->
			finalCommandExecuted = 0

			runWatchTask(
				expected:1
				expectedTarget: 'finalCommand'
				glob: 'test/samples/js/**'
				targetChange: [sample('js/mainCopy.js'), [150, sample('js/mainCopy.js')], [350, sample('js/mainCopy.js')]]
				opts:
					finalCommand: ()-> finalCommandExecuted++
					finalCommandDelay: 400
					bufferTimeout: 1
			).spread (results, watchTask)->
				expect(results.length).to.equal 3
				expect(finalCommandExecuted).to.equal 1

				watchTask.stop()


		
		test "If the final command exits with a non-zero status code the error message will be written to the terminal", ()->
			Promise.resolve()
				.then ()->
					stdout = ''
					customStdout.on 'data', (chunk)-> stdout+=chunk

					runWatchTask(
						expected:1
						expectedTarget: 'finalCommand'
						silent: false
						glob: randSample()
						opts:
							finalCommand: 'echo "final command was executed" && exit 2'
							finalCommandDelay: 1
					).spread (results, watchTask)->
						expect(stdout).to.include 'final command was executed'
						expect(stdout).not.to.include 'Error: Command failed:'

						watchTask.stop()
				
				.then ()->
					stdout = ''
					customStdout.on 'data', (chunk)-> stdout+=chunk

					runWatchTask(
						expected:1
						expectedTarget: 'finalCommand'
						silent: false
						glob: randSample()
						opts:
							finalCommand: 'exit 2'
							finalCommandDelay: 1
					).spread (results, watchTask)->
						expect(stdout).to.include 'Error: Command failed:'

						watchTask.stop()


		
		test "If a command exits with a non-zero status the final command execution will be canceled", ()->
			finalCommandExecuted = 0
			stdout = ''
			customStdout.on 'data', (chunk)-> stdout+=chunk

			runWatchTask(
				expected:350
				expectedTarget: 'delay'
				glob: 'test/samples/js/**'
				targetChange: sample('js/mainCopy.js')
				opts:
					command: 'echo 1; exit 1'
					finalCommand: ()-> finalCommandExecuted++
					finalCommandDelay: 1
					bufferTimeout: 1
			).spread (results, watchTask)->
				expect(finalCommandExecuted).to.equal 0
				expect(stdout).to.include 'Final Command'
				expect(stdout).to.include 'Aborted'
				expect(stdout).to.include '(because some tasks failed)'

				watchTask.stop()





	suite "Errors", ()->
		test "no globs", ()->
			caught = false

			Promise.resolve()
				.then ()-> SimplyWatch({command:';'})
				.catch (err)->
					expect(err).to.be.an.error
					expect(err.message).to.equal 'No/Invalid globs were provided'
					caught = true
				
				.then ()->
					expect(caught, 'error thrown').to.equal true
		

		test "invalid globs", ()->
			caught = false

			Promise.resolve()
				.then ()-> SimplyWatch({globs:[123]})
				.catch (err)->
					expect(err).to.be.an.error
					expect(err.message).to.equal 'No/Invalid globs were provided'
					caught = true
				
				.then ()->
					expect(caught, 'error thrown').to.equal true
		

		test "empty globs array", ()->
			caught = false

			Promise.resolve()
				.then ()-> SimplyWatch({globs:[]})
				.catch (err)->
					expect(err).to.be.an.error
					expect(err.message).to.equal 'No/Invalid globs were provided'
					caught = true
				
				.then ()->
					expect(caught, 'error thrown').to.equal true
		

		test "non-array", ()->
			caught = false

			Promise.resolve()
				.then ()-> SimplyWatch({globs:'test/samples', command:';'})
				.catch (err)->
					throw err
					caught = true
				
				.then (watchTask)->
					expect(caught, 'error thrown').to.equal false
					watchTask.stop()
		

		test "no command", ()->
			caught = false

			Promise.resolve()
				.then ()-> SimplyWatch({globs:'*'})
				.catch (err)->
					expect(err).to.be.an.error
					expect(err.message).to.equal 'Execution command not provided'
					caught = true
				
				.then ()->
					expect(caught, 'error thrown').to.equal true
		

		test "invalid command", ()->
			caught = false

			Promise.resolve()
				.then ()-> SimplyWatch({globs:'*', command:14})
				.catch (err)->
					expect(err).to.be.an.error
					expect(err.message).to.equal 'Invalid execution command provided: only a string or a callback may be provided'
					caught = true
				
				.then ()->
					expect(caught, 'error thrown').to.equal true
		

		test "invalid final command", ()->
			caught = false

			Promise.resolve()
				.then ()-> SimplyWatch({globs:'*', command:';', finalCommand:14})
				.catch (err)->
					expect(err).to.be.an.error
					expect(err.message).to.equal 'Invalid final execution command provided: only a string or a callback may be provided'
					caught = true
				
				.then ()->
					expect(caught, 'error thrown').to.equal true
		












