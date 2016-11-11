# SimplyWatch
[![Build Status](https://travis-ci.org/danielkalen/simplywatch.svg)](https://travis-ci.org/danielkalen/simplywatch)
[![Coverage](.config/badges/coverage-node.png?raw=true)](https://github.com/danielkalen/simplyimport)
[![Code Climate](https://codeclimate.com/repos/57cca4d39c1556768c003c7f/badges/bff51b9d181be94abb2b/gpa.svg)](https://codeclimate.com/repos/57cca4d39c1556768c003c7f/feed)

A command line tool that monitors files under a given glob and individually  executes commands (with optional dynamic placeholders) for the changed/added files.

What makes SimplyWatch different from the *few* similar packages available on NPM is:
* It is intergrated with [node-sass](https://www.npmjs.com/package/node-sass) and [simplyimport](https://www.npmjs.com/package/simplyimport) in which discovered files are scanned for import declarations and if SimplyWatch detects a change in any of the imported files, the provided command will be executed for the importing file. *Example: 'FileA' and 'FileB' both import 'ChildFile' - when 'ChildFile' changes the command is executed for both 'FileA' and 'FileB'. Note that the imported file doesn't have to be in the provided glob, and will be watched for changes upon discovery.*
* It executes the commands concurrently. A scenario in which this is useful is when multiple files import the same child file and once the child file changes the command is executed for all importing files.
* It provides debouncing: if a file is changed multiple times in a very short timeframe (i.e. under 2 seconds), the command will only be executed once in that time frame. *Note: The default delay is 1500ms, and can be changed by specifying a different value to [-d || -execDelay]*
* It stacks execution tasks in order: If a file change triggers the command to be executed for it and then changes again (possibly multiple times) while the first command is still executing then the next command[s] will wait until the previous one finishes before being executed.
* It can execute a final command after a given delay once SimplyWatch finishes processing a file change/addition batch. *Example: once the compile command is executed for the source files, copy them to the dist/ folder and restart the server.*
* It can trim the messages outputted from the commands to a certain # of characters. This is useful for example when commands encounter an error they output the entire file's content in order to highlight a line that triggered the error, which can sometimes result in extremely large console outputs.


Installation:
------
```bash
npm install simplywatch
```


Usage:
------
**Command Line Usage**
```
simplywatch -g <glob> -x <command to execute> [options]
```

**Options:**

```bash
-g, --glob          glob/dir to watch. Multiple globs can be passed: -g "globA" "globB"
-i, --ignore        glob/dir to ignore. Multiple globs can be passed: -g "globA" "globB"
-x, --execute       Command to execute upon file addition/change
-f, --finally       Command to execute *once* after all changed files have been processed. Example: if a file change triggered a command to be executed for 10 files, this "finally" command will be executed after the time specified in --finallyDelay
-d, --delay         Execution delay, i.e. how long should simplywatch wait before re-executing the command. If the watched file changes rapidly, the command will execute only once every X ms
-D, --finallyDelay  The amount of milliseconds to wait before executing the "finally" command
-t, --trim          Trims the output of the command executions to only show the first X characters of the output
-s, --silent        Suppress any output from the executing command (including errors)
-b, --background    Run SimplyWatch as a background daemon
-l, --log           Path of the target log file when running in background mode
-h                  Show help
--version           Show version number                                   
```

**Execution Command Placeholders**
```
"path"  -  full path and filename
"root"  -  file root
"dir"   -  path without the filename
"reldir"-  directory name of file relative to the glob provided
"base"  -  file name and extension
"ext"   -  just file extension
"name"  -  just file name
```






Example:
------
```
simplywatch -g "assets/**" -x "node-sass #{path} -o dist/css/#{name}.css"
simplywatch -g "assets/*.coffee" -i "dontCompile/*" -x "cat {{path}} | coffee -s -c > dist/{{name}}.js"
```

