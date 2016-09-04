module.exports =
	'g': 
		alias: 'glob'
		describe: 'glob/dir to watch. Multiple globs can be passed: -g "globA" "globB"'
		type: 'array'
	'i': 
		alias: 'ignore'
		describe: 'glob/dir to ignore. Multiple globs can be passed: -g "globA" "globB"'
		type: 'array'
	'x': 
		alias: 'execute'
		describe: 'Command to execute upon file addition/change'
		type: 'string'
		demand: true
	'f': 
		alias: 'finally'
		describe: 'Command to execute *once* after all changed files have been processed. Example: if a file change triggered a command to be executed for 10 files, this "finally" command will be executed after the time specified in --finallyDelay'
		type: 'string'
	'd': 
		alias: 'delay'
		describe: 'Execution delay, i.e. how long should simplywatch wait before re-executing the command. If the watched file changes rapidly, the command will execute only once every X ms'
		type: 'number'
		default: 1500
	'D': 
		alias: 'finallyDelay'
		describe: 'The amount of milliseconds to wait before executing the "finally" command'
		type: 'number'
		default: 500
	't': 
		alias: 'trim'
		describe: 'Trims the output of the command executions to only show the first X characters of the output'
		type: 'number'
		default: undefined
	's': 
		alias: 'silent'
		describe: 'Suppress any output from the executing command (including errors)'
		type: 'boolean'
		default: false
	# 'p': 
	# 	alias: 'processImports'
	# 	describe: 'Execute the command for files that are imported by other files'
	# 	type: 'boolean'
	# 	default: true