#!/usr/bin/env coffee
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



if args.h or args.help
	process.stdout.write(yargs.help());
	process.exit(0)
else
	require('./simplywatch')(options)



