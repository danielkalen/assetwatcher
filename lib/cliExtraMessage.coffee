chalk = require 'chalk'

extraMessage = [
	chalk.bgCyan.black('Placeholders')
	chalk.dim 'All placeholders can be denoted either with {{placeholder}} or #{placeholder}'
	"path    -  full path and filename"
	"root    -  file root"
	"dir     -  path without the filename"
	"reldir  -  directory name of file relative to the glob provided"
	"base    -  file name and extension"
	"ext     -  just file extension"
	"name    -  just file name"
].join '\n  '



extraMessage += '\n\n\n'+[
	chalk.bgWhite.black('Examples')
	'simplywatch -g "assets/**" -x "node-sass #{path} -o dist/css/#{name}.css"'
	'simplywatch -g "assets/*.coffee" -i "dontCompile/*" -x "cat {{path}} | coffee -s -c > dist/{{name}}.js"'
].join '\n  '



module.exports = '\n'+extraMessage