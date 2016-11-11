require 'nodejs-dashboard' if process.env.DEBUG
fs = require 'fs'
chalk = require 'chalk'
yargs = require 'yargs'
yargs
	.usage("#{chalk.bgYellow.black('Usage')} simplywatch -g <glob> -x <command to execute> [options]")
	.options(require './cliOptions')
	.epilogue(require './cliExtraMessage')
	.wrap(yargs.terminalWidth())
	.help('h')
	.version(()-> require('../package.json').version)
args = yargs.argv

options = 
	'globs': args.g or args.glob or args._ or []
	'ignoreGlobs': args.i or args.ignore or []
	'command': args.x or args.execute
	'processImports': args.p or args.processImports
	'finalCommand': args.f or args.finally
	'execDelay': args.d or args.delay
	'finalCommandDelay': args.D or args.finallyDelay
	'trim': parseFloat args.t or args.trim
	'silent': args.s or args.silent



if args.help
	process.stdout.write(yargs.help());
	process.exit(0)
else
	require('./simplywatch')(options)

	if args.background
		if process.env.__daemon
			console.log "Running as daemon - PID #{process.pid}"
		
			notifyDeath = ()-> console.log 'KILLED - exiting'; process.exit()
			process.on 'SIGTERM', notifyDeath
			process.on 'SIGINT', notifyDeath
		

		else
			fs.open args.log, 'w', (err, outputFile)->
				throw err if err
				daemon = require('daemon-plus')({stdout:outputFile, stderr:outputFile}, true)
				
				console.log chalk.bgGreen.black.bold('Running as daemon'), "PID #{daemon.pid}"
				process.exit()



