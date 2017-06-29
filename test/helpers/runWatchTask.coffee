SimplyWatch = require './simplywatch'
triggerFileChange = require './triggerFileChange'
promiseWait = require 'p-wait-for'
extend = require 'smart-extend'
fs = require 'fs-jetpack'
sortBy = require 'lodash/sortBy'

defaults = (options, results)-> extend.deep.transform(targetChange:(value)-> [].concat(value))
	timeout: 4000
	targetChange: [].concat(options.targetChange or options.glob)
	expected: 0
	expectedTarget: 'results'
	opts:
		globs: [options.glob]
		command: (file, params)-> results.push(params)
, options


module.exports = (options)->
	watchTask = null
	results = []
	options = defaults(options, results)
	
	Promise.resolve()
		.then ()-> SimplyWatch options.opts
		.then ()-> watchTask = arguments[0]
		.then ()-> Promise.map options.targetChange, (item)->
			if typeof item is 'string' then triggerFileChange(item) else Promise.delay(item[0]).then ()-> triggerFileChange(item[1])
		
		.then ()-> promiseWait ()-> 
			switch options.expectedTarget
				when 'results'
					results.length >= options.expected

				when 'command'
					watchTask.queue.cycles >= options.expected

				when 'finalCommand'
					watchTask.queue.finalCycles >= options.expected

				when 'delay'
					Promise.delay(options.expected).return(true)

				when 'file'
					fs.existsAsync(options.expected).then (exists)->
						results = fs.read(options.expected) if exists
						return !!exists
		
		.timeout(options.timeout).catch Promise.TimeoutError, ()->;
		.then ()-> results = sortBy(results, options.sort) if options.sort
		.then ()-> [results, watchTask]