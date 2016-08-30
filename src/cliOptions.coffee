module.exports =
	'd': 
		alias: 'dir'
		describe: 'Specify all dirs to watch for in quotes, separated with commas. Syntax: -d "dirA" "dirB"'
		type: 'array'
		demand: true
	'i': 
		alias: 'ignore'
		describe: 'Specify all globs to ignore in quotes, separated with commas. Changes to matching files will NOT trigger any executions even if imported by another file. Syntax: -s "globA" "globB"'
		type: 'array'
	'I': 
		alias: 'ignoreweak'
		describe: 'Specify all globs to weakly ignore in quotes, separated with commas. Changes to matching files WILL trigger an execution if imported by another file. Syntax: -s "globA" "globB"'
		type: 'array'
	'e': 
		alias: 'extension'
		describe: 'Only watch files that have a specific extension. Syntax: -e "ext1" "ext2"'
		type: 'array'
	'x': 
		alias: 'execute'
		describe: 'Command to execute upon file addition/change'
		type: 'string'
		demand: true
	'f': 
		alias: 'finally'
		describe: 'Command to execute X ms (default: 3000) after the addition/change of the last file. For example if some file change triggered a command to be run for 10 files, after 3 seconds this "finally" command will be run once.'
		type: 'string'
	's': 
		alias: 'silent'
		describe: 'Suppress any output from the executing command'
		type: 'boolean'
		default: false
	'n': 
		alias: 'now'
		describe: 'Execute the command for all files matched immediatly on startup'
		type: 'boolean'
		default: false
	't': 
		alias: 'imports'
		describe: 'Optionally compile files that are imported by other files.'
		type: 'boolean'
		default: false
	'w': 
		alias: 'wait'
		describe: 'Execution delay, i.e. how long should simplywatch wait before re-executing the command. If the watched file changes rapidly, the command will execute only once every X ms.'
		type: 'number'
		default: 1500
	'W': 
		alias: 'finallywait'
		describe: 'The amount of milliseconds to wait before executing the finally command (if passed).'
		type: 'number'
		default: 3000