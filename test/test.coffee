Promise = require 'bluebird'
fs = Promise.promisifyAll require 'fs-extra'
chai = require 'chai'
expect = chai.expect
should = chai.should()
execa = require 'execa'
chokidar = require 'chokidar'
fsOpts = encoding:'utf8'
testWatcher = null

SimplyWatch = (options)->
	options.execDelay = 1 unless options.execDelay
	if process.env.fromSrc
		delete require.cache["#{process.cwd()}/src/watcher.coffee"]
		delete require.cache["#{process.cwd()}/src/simplywatch.coffee"]
		require('../src/simplywatch.coffee')(options)
	else
		delete require.cache["#{process.cwd()}/dist/watcher.js"]
		delete require.cache["#{process.cwd()}/dist/simplywatch.js"]
		require('../dist/simplywatch.js')(options)



triggerFileChange = (filePath, resultPath)-> new Promise (resolve)->
	emptyResults = 'result':'', 'resultLines':[]
	
	fs.readFileAsync(filePath, fsOpts).then (contents)->
		fs.writeFileAsync(filePath, contents).then ()->
			if not resultPath then resolve(emptyResults)
			else
				onFsChange = ()->
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
	

	test "Will execute a given command on all matched files/dirs in a given glob upon change", ()->
		options = globs:['test/samples/js/**'], command:'echo {{base}} >> test/temp/one'
		
		SimplyWatch(options).then (watcher)-> new Promise (done)-> watcher.ready.then ()->
			triggerFileChange('test/samples/js/mainCopy.js', 'test/temp/one').then ({result, resultLines})->
				expect(resultLines[0]).to.equal 'mainCopy.js'
				
				watcher.unwatch(options.globs[0])
				done()
	

	


	test "Will search for imports (SimplyImport syntax) and if an import changes only its dependents will get updated", ()->
		options = globs:['test/samples/js/**'], command:'echo {{base}} >> test/temp/two'
		
		SimplyWatch(options).then (watcher)-> new Promise (done)-> watcher.ready.then ()->
			triggerFileChange('test/samples/js/nested/one.js', 'test/temp/two').then ({result, resultLines})->
				expect(result).not.to.include 'one.js'
				expect(result).to.include 'mainCopy.js'
				expect(result).to.include 'mainCopy2.js'
				watcher.unwatch(options.globs[0])
				
				done()

	


	# test "Placeholders can be used in the command which will be dynamically filled according to the subject path", (done)->
	# 	exec "src/simplywatch.coffee -g 'test/samples/sass/css/*' -x 'echo \"{{name}} {{ext}} {{base}} {{reldir}} {{path}} {{dir}}\" >> test/temp/three'", (err)->
	# 		result = fs.readFileSync 'test/temp/three', {encoding:'utf8'}
	# 		resultLines = result.split('\n').filter (validLine)-> validLine

	# 		expect(resultLines.length).to.equal 2
	# 		expect(resultLines[0]).to.equal "main .css main.css samples/sass/css test/samples/sass/css/main.css #{process.cwd()}/test/samples/sass/css"
	# 		expect(resultLines[1]).to.equal "main.copy .css main.copy.css samples/sass/css test/samples/sass/css/main.copy.css #{process.cwd()}/test/samples/sass/css"
	# 		done()
	


	# test "Placeholders can be denoted either with dual curly braces or a hash + single curly brace wrap", (done)->
	# 	exec "src/simplywatch.coffee -g 'test/samples/sass/css/*' -x 'echo \"\#{name} \#{ext} \#{base} \#{reldir} \#{path} \#{dir}\" >> test/temp/four'", (err)->
	# 		result = fs.readFileSync 'test/temp/four', {encoding:'utf8'}
	# 		resultLines = result.split('\n').filter (validLine)-> validLine

	# 		expect(resultLines.length).to.equal 2
	# 		expect(resultLines[0]).to.equal "main .css main.css samples/sass/css test/samples/sass/css/main.css #{process.cwd()}/test/samples/sass/css"
	# 		expect(resultLines[1]).to.equal "main.copy .css main.copy.css samples/sass/css test/samples/sass/css/main.copy.css #{process.cwd()}/test/samples/sass/css"
	# 		done()













