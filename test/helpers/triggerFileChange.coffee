fs = require 'fs-jetpack'
retry = require 'promise-retry'
testWatcher = require('@danielkalen/chokidar').watch([], {ignoreInitial:true})

module.exports = (filePath)->
	actualChange = new Promise (resolve)-> testWatcher.once 'change', resolve

	Promise.resolve()
		.then ()-> testWatcher.add(filePath)
		.then ()-> fs.readAsync(filePath)
		.delay(0)
		# .delay if process.platform is 'darwin' then 0 else 200
		# .then (contents)-> fs.writeAsync(filePath, contents)
		
		.then (contents='')->
			retry (tryAgain)->
				fs.writeAsync(filePath, contents)
				new Promise (resolve, reject)->
					actualChange.then(resolve)
					setTimeout (-> reject new Error),300
				.catch(tryAgain)
			, {retries:200, minTimeout:100}

		.timeout(3000)
		.catch Promise.TimeoutError, ()->;