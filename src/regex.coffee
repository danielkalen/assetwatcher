module.exports =
	fileExt: ///
		.+ 						# File name
		\. 						# Period separator
		(sass|scss|js|coffee)	# Extension
	$///i

	# import: ///^
	# 	(?:
	# 		.*					# prior content
	# 		\s+					# prior space
	# 			|				# or if above aren't present
	# 		\W?					# no letters
	# 	)
	# 	import					# import declaration
	# 	\s+						# whitespace after import declaration
	# 	(?:\[.+\])?				# conditionals
	# 	\s*						# whitespace after conditional
	# 	(.+)					# filepath
	# ///g

	fileExt: /.+\.(sass|scss|js|coffee)$/i
	placeholder: /\#\{([^\/\}]+)\}/ig