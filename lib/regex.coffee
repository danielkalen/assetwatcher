module.exports =
	fileExt: ///
		.+ 						# File name
		\. 						# Period separator
		(sass|scss|js|coffee)	# Extension
	$///i

	placeholder: /(?:\#\{|\{\{)([^\/\}]+)(?:\}\}|\})/ig