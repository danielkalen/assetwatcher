chalk = require 'chalk'

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
		alias: 'exec'
		describe: 'Command to execute upon file addition/change'
		type: 'string'
	'f': 
		alias: 'finally'
		describe: "Command to execute #{chalk.bold.italic '*once*'} after all changed files have been processed"
		type: 'string'
	'd': 
		alias: 'delay'
		describe: 'Execution delay, i.e. how long should simplywatch wait before re-executing the command. If the watched file changes rapidly, the command will execute only once every X ms'
		type: 'number'
		default: 1500
	'd': 
		alias: 'finallyDelay'
		describe: 'The amount of milliseconds to wait before executing the "finally" command'
		type: 'number'
		default: 500
	's': 
		alias: 'silent'
		describe: 'Suppress any output from the executing command (including errors)'
		type: 'boolean'
		default: false
	'h': 
		alias: 'haltSerial'
		describe: 'Halt running commands if a change is detected mid-execution'
		type: 'boolean'
		default: false
	'p': 
		alias: 'processImports'
		describe: 'Execute the command for files that are imported by other files'
		type: 'boolean'
		default: false
	'b': 
		alias: 'background'
		describe: 'Run SimplyWatch as a background daemon'
		type: 'boolean'
		default: false
	'log': 
		describe: 'Path of the target log file when running in background mode'
		type: 'string'
		default: './simplywatch.log'
	'trim': 
		describe: 'Trims the output of the command executions to only show the first X characters of the output'
		type: 'number'
		default: undefined