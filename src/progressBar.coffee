statusBar = require 'node-status'
console = statusBar.console()


module.exports = progressBar =
	'progress': statusBar.addItem 'processed', 'max': 1

	'errorCount': statusBar.addItem 'errors'

	'totalTime': statusBar.addItem 'time'

	start: (totalItems)->
		progressBar.progress.max = totalItems
		statusBar.start
			'bottom': true
			'interval': 10
			'uptime': false
			'pattern': 'Processed: {processed.green.bar} {processed.green.percentage} | Errors: {errors.red.count} | Time: {time.time}'

	end: ()-> statusBar.stop()



# module.exports = 
# 	progress: statusBar.addItem
# 		'type': ['bar', 'percentage']
# 		'name': 'Processed'
# 		'max': 1
# 		'color': 'green'

# 	errorCount: statusBar.addItem
# 		'type': 'count'
# 		'name': 'Errors'
# 		'color': 'red'

# 	totalTime: statusBar.addItem
# 		'type': 'time'
# 		'name': 'Time'

# 	start: (totalItems)->
# 		@progress.max = totalItems
# 		statusBar.start('invert':false, 'interval':20, 'uptime':false)

# 	end: ()-> statusBar.stop()
