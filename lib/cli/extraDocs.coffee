chalk = require 'chalk'

module.exports = """

#{chalk.bgCyan.black 'Placeholders'} #{chalk.italic 'All placeholders can be denoted either with {{placeholder}} or #{placeholder}'}
  path    -  #{chalk.dim 'full path and filename'}
  root    -  #{chalk.dim 'file root'}
  dir     -  #{chalk.dim 'path without the filename'}
  reldir  -  #{chalk.dim 'directory name of file relative to the glob provided'}
  base    -  #{chalk.dim 'file name and extension'}
  ext     -  #{chalk.dim 'just file extension'}
  name    -  #{chalk.dim 'just file name'}


#{chalk.bgMagenta.black 'Examples'}
  simplywatch #{chalk.dim '"src/**.sass" "node-sass \#{path} -o dist/css/\#{name}.css"'}
  simplywatch #{chalk.dim '-g "src/**" -x "node-sass \#{path} > dist/css/\#{name}.css"'}
  simplywatch #{chalk.dim '-g "src/*.coffee" -i "dontCompile/*" -x "cat {{path}} | coffee -s -c > dist/{{name}}.js"'}
"""