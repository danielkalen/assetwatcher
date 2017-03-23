moment = require 'moment'

module.exports = new ()->
	list = '1':[]
	@iteration = 1

	@add = (event)->
		list[@iteration] ?= []
		list[@iteration].push(event)

	@output = (targetIteration, console)-> if list[targetIteration]
		for event in list[targetIteration]
			event = "[#{moment().format('MM/DD HH:MM:ss')}] #{event}" if process.env.__daemon
			console.log event

		delete list[targetIteration]

	return @