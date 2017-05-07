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



