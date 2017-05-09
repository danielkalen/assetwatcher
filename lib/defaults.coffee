module.exports = 
	'globs': []
	'ignoreGlobs': []
	'command': null
	'processImports': true
	'finalCommand': null
	'execDelay': 1500
	'finalCommandDelay': 500
	'trim': 2000
	'silent': false
	'haltSerial': false
	'stdout': if process.env.DEBUG?.includes('simplywatch:*') then require('fs').createWriteStream('/dev/null') else process.stdout
	'stderr': if process.env.DEBUG?.includes('simplywatch:*') then require('fs').createWriteStream('/dev/null') else process.stderr
