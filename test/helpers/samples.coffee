module.exports = 
	'bin/.bin': "module.exports = import '../js/sampleB'"
	'binary/.DS_Store': "module.exports = require('../js/sampleA')"
	'binary/one.zip': "module.exports = require('../js/sampleB')"
	'binary/two.mp3': "module.exports = require('../js/sampleA')"
	'img/one.svg': "module.exports = require('../js/sampleB')"
	'img/two.png': "module.exports = require('../js/sampleA')"
	'js/sampleA.js': 'abc'
	'js/sampleB.js': '123'
	'js/main.js': """
		import 'nested/one'
		import 'nested/two.js'
		import 'nested/nonexistent.js'
		import 'nested/nonexistent'
		import 'ignored/insideIgnored.js'

		module.exports = 'main'
	"""
	'js/mainCopy.js': """
		import 'main.js'

		module.exports = 'mainCopy'
	"""
	'js/mainCopy2.js': """
		import 'nested/one'
		import 'nested/two.js'
		import 'nested/nonexistent.js'

		module.exports = 'mainCopy2'
	"""
	'js/mainDiff.js': """
		module.exports = 'mainDiff'
	"""
	'js/neverImported/neverImported.js': """
		module.exports = 'this module will never be imported by anyone'
	"""
	'js/ignored/insideIgnored.js': """
		module.exports = 'insideIgnored'
	"""
	'js/nested/one.js': """
		module.exports = 'nested-one'
	"""
	'js/nested/two.js': """
		module.exports = 'nested-two'
	"""
	'js/nested/three.js': ''
	'js/ignoredEmpty/': ''
	
	'sass/main.sass': """
		@import 'nested/one'
		@import 'nested/two.sass'
		@import 'nested/six'

		body
			display: none
	"""
	'sass/main.copy.sass': """
		@import 'nested/one'
		@import 'nested/two.sass'

		body
			display: none
			@import 'nested/two.5.sass'
	"""
	'sass/nested/one.sass': """
		#one
			display: none
	"""
	'sass/nested/two.sass': """
		#two
			display: none

		@import 'nested/three.sass'
	"""
	'sass/nested/two.5.sass': ['sass/nested/two.sass', (c)-> c]
	'sass/nested/nested/three.sass': """
		#three
			display: none

		@import 'four.sass'
	"""
	'sass/nested/nested/four.sass': """
		#four
			display: none
		
	"""