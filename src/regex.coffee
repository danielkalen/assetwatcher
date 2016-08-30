module.exports =
	ext: /.+\.(sass|scss|js|coffee)$/i
	import: /@import\s*(.+)/ig
	placeholder: /\#\{([^\/\}]+)\}/ig