#!/usr/bin/env coffee
chalk = require 'chalk'
yargs = require 'yargs'
yargs
	.usage("#{chalk.bgYellow.black('Usage')} simplywatch -d <directory globs> -s <globs to skip> -i")
	.options(require './cliOptions')
	.help('h')
	.version()
	.wrap(yargs.terminalWidth())
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



if args.h or args.help
	process.stdout.write(yargs.help());
	process.exit(0)
else
	require('./simplywatch')(options)



