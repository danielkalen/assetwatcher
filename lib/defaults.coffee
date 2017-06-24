### istanbul ignore next ###
if process.env.DEBUG?.includes('simplywatch:*')
	stdout = stderr = require('fs').createWriteStream('/dev/null')
else
	stdout = process.stdout
	stderr = process.stderr

module.exports = {
	stdout, stderr
	globs: []
	ignoreGlobs: []
	command: null
	processImports: false
	finalCommand: null
	bufferTimeout: 150
	finalCommandDelay: 500
	trim: 2000
	silent: false
	haltSerial: false
	useFsEvents: true
	retainHistory: false
	watchBinary: false
}