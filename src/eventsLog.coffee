module.exports = new ()->
	list = '1':[]
	@iteration = 1

	@add = (event)->
		list[@iteration] ?= []
		list[@iteration].push(event)

	@output = (targetIteration)-> if list[targetIteration]
		for event in list[targetIteration]
			console.log event

		delete list[targetIteration]

	return @