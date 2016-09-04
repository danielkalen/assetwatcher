global.Promise = require 'bluebird'
fs = Promise.promisifyAll require 'fs-extra'
chai = require 'chai'
expect = chai.expect
should = chai.should()
execa = require 'execa'
chokidar = require 'chokidar'
interceptStdout = require 'intercept-stdout'
fsOpts = encoding:'utf8'
testWatcher = null

SimplyWatch = (options)->
	options.execDelay = 1 unless options.execDelay
	if process.env.fromSrc
		clearRequireCache('src')
		require('../src/simplywatch.coffee')(options)
	else
		clearRequireCache('dist')
		require('../dist/simplywatch.js')(options)


clearRequireCache = (dir)->
	files = fs.readdirSync(dir)
	for file in files
		delete require.cache["#{process.cwd()}/#{dir}/#{file}"]



triggerFileChange = (filePath, resultPath, shouldIntercept=true)-> new Promise (resolve)->
	emptyResults = 'result':'', 'resultLines':[]
	
	fs.readFileAsync(filePath, fsOpts).then (contents)->
		removeInterceptor = interceptStdout(()-> '') if shouldIntercept
		
		fs.writeFileAsync(filePath, contents).then ()->
			if not resultPath then resolve(emptyResults)
			else
				onFsChange = ()->
					testWatcher.removeListener 'add', onFsChange
					testWatcher.removeListener 'change', onFsChange
					removeInterceptor() if shouldIntercept
					testWatcher.unwatch(resultPath)
					
					fs.readFileAsync(resultPath, fsOpts).then (result)->
						resultLines = result.split('\n').filter (validLine)-> validLine
						resolve {result, resultLines}
				

				testWatcher.on 'add', onFsChange
				testWatcher.on 'change', onFsChange
				testWatcher.add(resultPath)
				setTimeout ()->
					resolve(emptyResults)
				, 3000


















suite "SimplyWatch", ()->
	suiteSetup ()-> fs.ensureDirAsync('test/temp').then ()-> testWatcher = chokidar.watch 'test/temp/**', 'cwd':process.cwd()
	suiteTeardown (done)-> fs.remove 'test/temp', done



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
		














	suite "File handling", ()->
		suiteTeardown ()-> fs.emptyDirAsync 'test/temp'
		
		test "If a discovered import has no extension specified, various file extensions will be used to check for a valid file", ()->
			options = globs:['test/samples/sass/*'], command:'echo {{base}} >> test/temp/one'
			
			SimplyWatch(options).then (watcher)-> new Promise (done)-> watcher.ready.then ()->
				triggerFileChange('test/samples/sass/nested/one.sass', 'test/temp/one').then ({result, resultLines})->
					expect(resultLines[0]).to.equal "main.sass"

					watcher.close()
					done()

	














	suite "Watching & Command Execution", ()->
		suiteTeardown ()-> fs.emptyDirAsync 'test/temp'


		test "Will execute a given command on all matched files/dirs in a given glob upon change", ()->
			options = globs:['test/samples/js/**'], command:'echo {{base}} >> test/temp/one'
			
			SimplyWatch(options).then (watcher)-> new Promise (done)-> watcher.ready.then ()->
				triggerFileChange('test/samples/js/mainCopy.js', 'test/temp/one').then ({result, resultLines})->
					expect(resultLines[0]).to.equal 'mainCopy.js'
					
					# watcher.close()
					done()
		

		


		test "Will search for imports (SimplyImport syntax) and if an import changes only its dependents will get updated", ()->
			options = globs:['test/samples/js/**'], command:'echo {{base}} >> test/temp/two'
			
			SimplyWatch(options).then (watcher)-> new Promise (done)-> watcher.ready.then ()->
				triggerFileChange('test/samples/js/nested/one.js', 'test/temp/two').then ({result, resultLines})->
					expect(result).not.to.include 'one.js'
					expect(result).to.include 'mainCopy.js'
					expect(result).to.include 'mainCopy2.js'
					
					watcher.close()
					done()
		

		

		test "Commands will only execute once if changed multiple times within the execDelay option", ()->
			options = globs:['test/samples/js/*'], command:'echo {{name}} >> test/temp/three'
			
			SimplyWatch(options).then (watcher)-> new Promise (done)-> watcher.ready.then ()->
				triggerFileChange('test/samples/js/mainCopy.js', 'test/temp/three').then ()->
					triggerFileChange('test/samples/js/mainCopy.js', 'test/temp/three').then ({result, resultLines})->
						expect(result).to.equal "mainCopy\n"

						watcher.close()
						done()









		suite "Placeholders", ()->		
			test "Commands can have placeholders in them replaced by the file's values", ()->
				options = globs:['test/samples/js/**'], command:'echo "{{name}} {{ext}} {{base}} {{reldir}} {{path}} {{dir}}" >> test/temp/four'
				
				SimplyWatch(options).then (watcher)-> new Promise (done)-> watcher.ready.then ()->
					triggerFileChange('test/samples/js/mainCopy.js', 'test/temp/four').then ({result, resultLines})->
						expect(resultLines[0]).to.equal "mainCopy .js mainCopy.js  test/samples/js/mainCopy.js #{__dirname}/samples/js"

						watcher.close()
						done()
			

			

			test "Placeholders can be denoted either with dual curly braces or just a hash+single curly braces", ()->
				options = globs:['test/samples/js/**'], command:'echo "#{name} #{ext} #{base} #{reldir} #{path} #{dir}" >> test/temp/five'
				
				SimplyWatch(options).then (watcher)-> new Promise (done)-> watcher.ready.then ()->
					triggerFileChange('test/samples/js/mainCopy.js', 'test/temp/five').then ({result, resultLines})->
						expect(resultLines[0]).to.equal "mainCopy .js mainCopy.js  test/samples/js/mainCopy.js #{__dirname}/samples/js"

						watcher.close()
						done()
			

			

			test "Invalid placeholders will remain unreplaced", ()->
				options = globs:['test/samples/js/*'], command:'echo "{{name}} {{badPlaceholder}}" >> test/temp/six'
				
				SimplyWatch(options).then (watcher)-> new Promise (done)-> watcher.ready.then ()->
					triggerFileChange('test/samples/js/mainCopy.js', 'test/temp/six').then ({result, resultLines})->
						expect(resultLines[0]).to.equal "mainCopy {{badPlaceholder}}"

						watcher.close()
						done()











		suite "Options", ()->
			test "If options.trim is set to a number, any output messages from commands will be trimmed to only the first X characters", ()->
				stdout = ''
				removeInterceptor = interceptStdout (data)-> stdout += data; return ''

				options = globs:['test/samples/js/*'], command:'echo {{name}} > test/temp/seven && echo {{name}}', trim:5
				
				SimplyWatch(options).then (watcher)-> new Promise (done)-> watcher.ready.then ()->
					triggerFileChange('test/samples/js/mainCopy.js', 'test/temp/seven', false).then ()->
						expect(stdout).to.include "mainC\n"

						removeInterceptor()
						watcher.close()
						done()
		


			test "If options.ignoreGlobs is provided, any file that matches the ignore glob (even partially) will not have a command executed for it, but if it is imported by a parent file then the parent will be processed", ()->
				options = globs:['./test/samples/js/**'], ignoreGlobs:['test/samples/js/nested'], command:'echo {{base}} >> test/temp/eight'
				
				SimplyWatch(options).then (watcher)-> new Promise (done)-> watcher.ready.then ()->
					Promise.all([
						triggerFileChange('test/samples/js/mainCopy2.js', null, false)
						triggerFileChange('test/samples/js/mainDiff.js', 'test/temp/eight', false)
						triggerFileChange('test/samples/js/nested/one.js', null, false)
						triggerFileChange('test/samples/js/nested/three.js', null, false)
					]).then (resultArray)->
						result = resultArray[1].result
						resultLines = resultArray[1].resultLines

						expect(resultLines.length).to.equal 3
						expect(result).to.include 'mainDiff.js'
						expect(result).to.include 'mainCopy2.js'
						expect(result).to.include 'mainCopy.js'
						
						watcher.close()
						done()




			test "Files inside .git/ will autotomatically be ignored", ()->
				options = globs:['test/temp2/**'], command:'echo {{base}} >> test/temp/eight.5'
				
				Promise.all([
					fs.ensureFileAsync('test/temp2/.git/insideGit.js')
					fs.ensureFileAsync('test/temp2/git/outsideGit.js')
				]).then ()->
					SimplyWatch(options).then (watcher)-> new Promise (done)-> watcher.ready.then ()->
						Promise.all([
							triggerFileChange('test/temp2/git/outsideGit.js', 'test/temp/eight.5', false)
							triggerFileChange('test/temp2/.git/insideGit.js', null, false)
						]).then (resultArray)->
							result = resultArray[0].result
							resultLines = resultArray[0].resultLines
							
							expect(resultLines.length).to.equal 1
							expect(resultLines[0]).to.equal 'outsideGit.js'
							
							fs.remove 'test/temp2', ()->
								watcher.close()
								done()


			
			test "If a command is provided for options.finalCommand, that command will be executed after each batch of file changes has been processed", ()->
				options = globs:['test/samples/js/**'], command:' ', finalCommand:'echo "Final command executed" > test/temp/nine && echo {{name}}', finalCommandDelay:1
				
				SimplyWatch(options).then (watcher)-> new Promise (done)-> watcher.ready.then ()->
					triggerFileChange('test/samples/js/mainCopy.js', 'test/temp/nine').then ({result, resultLines})->
						expect(resultLines[0]).to.equal 'Final command executed'
						
						watcher.close()
						done()












