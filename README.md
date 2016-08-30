# SimplyWatch
A command line tool inspired by [smartwatch](https://www.npmjs.com/package/smartwatch) that monitors files under a given directory and individually  executes commands (with optional dynamic placeholders) for changed/added files.


Installation:
------
```bash
npm install simplywatch
```


Usage:
------
**Command Line**
```
simplywatch -d <dirs> -i <globs to ignore> -e <specific extension> -x <command to execute> -[s|t]
```

**Command Line Options:**

```bash
-d, --dir          Specify all dirs to watch for in quotes, separated with
                   commas. Syntax: -d "dirA" "dirB"         [array] [required]
-i, --ignore       Specify all globs to ignore in quotes, separated with
                   commas. Changes to matching files will NOT trigger any
                   executions even if imported by another file. Syntax: -s
                   "globA" "globB"                                     [array]
-I, --ignoreweak   Specify all globs to weakly ignore in quotes, separated
                   with commas. Changes to matching files WILL trigger an
                   execution if imported by another file. Syntax: -s "globA"
                   "globB"                                             [array]
-e, --extension    Only watch files that have a specific extension. Syntax: -e
                   "ext1" "ext2"                                       [array]
-x, --execute      Command to execute upon file addition/change
                                                           [string] [required]
-f, --finally      Command to execute X ms (default: 3000) after the
                   addition/change of the last file. For example if some file
                   change triggered a command to be run for 10 files, after 3
                   seconds this "finally" command will be run once.   [string]
-s, --silent       Suppress any output from the executing command
                                                    [boolean] [default: false]
-n, --now          Execute the command for all files matched immediatly on
                   startup                          [boolean] [default: false]
-t, --imports      Optionally compile files that are imported by other files.
                                                    [boolean] [default: false]
-w, --wait         Execution delay, i.e. how long should the simplywatch wait
                   before re-executing the command. If the watched file
                   changes rapidly, the command will execute only once every X
                   ms.                                         [default: 1500]
-W, --finallywait  The amount of milliseconds to wait before executing the
                   finally command (if passed).                [default: 3000]
-h, --help         Show help                                         [boolean]
```
**Executing Command Placeholders**
```
"path"  -  full path and filename
"root"  -  file root
"dir"   -  path without the filename
"reldir"-  directory name of file relative to the current working directory
"base"  -  file name and extension
"ext"   -  just file extension
"name"  -  just file name
```






Example:
------
#### Command Line:
```
simplywatch -d "assets/" -e "sass" -x "node-sass #{path} -o public/css/#{name}.css"
simplywatch -d "assets/" -e "js" -i "_*.js" "dontcompile/*" -x "simplyimport -i #{path} -o public/js/#{name}.compiled.js"
```

