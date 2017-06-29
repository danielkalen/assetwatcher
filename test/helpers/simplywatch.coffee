_SimplyWatch = require('../../lib/simplywatch')

module.exports = (options, awaitInitialScan)->
	options.silent = true unless options.silent?
	options.bufferTimeout = 1 unless options.bufferTimeout
	options.stdout = require './customStdout'
	options.stderr = require './customStderr'
	options.useFsEvents = !process.env.CI
	
	_SimplyWatch(options, awaitInitialScan)