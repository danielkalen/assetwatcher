fs = require 'fs'
chalk = require 'chalk'
yargs = require 'yargs'
yargs
	.usage("#{chalk.bgYellow.black('Usage')} simplywatch -g <glob> -x <command to execute> [options]")
	.options(require './options')
	.epilogue(require './extraDocs')
	.wrap(yargs.terminalWidth())
	.version(()-> require('../../package.json').version)
args = yargs.argv

options = 
	'globs': args.glob or args._[0] or []
	'command': args.exec or args._[1]
	'ignoreGlobs': args.ignore or []
	'processImports': args.processImports
	'bufferTimeout': args.bufferTimeout
	'finalCommand': args.finally
	'finalCommandDelay': args.finallyDelay
	'trim': parseFloat args.trim
	'silent': args.silent
	'haltSerial': args.haltSerial
	'watchModules': args.watchModules


if args.help
	process.stdout.write(yargs.help());
	process.exit(0)
else
	process.title = "simplywatch #{options.globs}"	
	require('../simplywatch')(options)
	require('../daemon')(args)