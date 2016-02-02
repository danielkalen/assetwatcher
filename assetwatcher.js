#!/usr/bin/env node
// Generated by CoffeeScript 1.10.0
(function() {
  var args, captureImports, commandToExecute, dirs, exec, execHistory, executeCommandFor, fireworm, fs, help, ignore, importHistory, imports, onlyExt, options, path, processFile, regEx, silent, startExecutionFor, yargs;

  options = {
    'd': {
      alias: 'dir',
      describe: 'Specify all dirs to watch for in quotes, separated with commas. Syntax: -d "dirA", "dirB"',
      type: 'array',
      demand: true
    },
    'i': {
      alias: 'ignore',
      describe: 'Specify all globs to ignore in quotes, separated with commas. Syntax: -s "globA", "globB"',
      type: 'array'
    },
    'e': {
      alias: 'extension',
      describe: 'Only watch files that have a specific extension',
      type: 'string'
    },
    'x': {
      alias: 'execute',
      describe: 'Command to execute upon file addition/change',
      type: 'string',
      demand: true
    },
    's': {
      alias: 'silent',
      describe: 'Suppress any output from the executing command',
      type: 'boolean',
      "default": false
    },
    't': {
      alias: 'imports',
      describe: 'Optionally compile files that are imported by other files.',
      type: 'boolean',
      "default": false
    }
  };

  fs = require('fs');

  path = require('path');

  fireworm = require('fireworm');

  exec = require('child_process').exec;

  yargs = require('yargs').usage("Usage: assetwatcher -d <directory globs> -s <globs to skip> -i").options(options).help('h').alias('h', 'help');

  args = yargs.argv;

  regEx = {
    ext: /.+\.(sass|scss|js|coffee)$/i,
    "import": /@import\s*(.+)/ig,
    placeholder: /#\{(.+)\}/ig
  };

  importHistory = {};

  execHistory = {};

  dirs = args.d || args.dir;

  ignore = args.i || args.ignore;

  help = args.h || args.help;

  silent = args.s || args.silent;

  imports = args.t || args.imports;

  onlyExt = args.e || args.extension;

  commandToExecute = args.x || args.execute;

  if (help) {
    process.stdout.write(yargs.help());
    process.exit(0);
  }

  captureImports = function(fileContent, filePath) {
    var dirPath, extName;
    if (typeof fileContent !== 'string') {
      return fileContent;
    } else {
      extName = path.extname(filePath);
      dirPath = path.dirname(filePath);
      return fileContent.replace(regEx["import"], function(entire, match) {
        var hasExt, resolvedMatch;
        match = match.replace(/'/g, '');
        hasExt = regEx.ext.test(match);
        if (!hasExt) {
          match += extName;
        }
        resolvedMatch = dirPath + '/' + path.normalize(match);
        if (importHistory[resolvedMatch] == null) {
          importHistory[resolvedMatch] = [filePath];
        } else {
          importHistory[resolvedMatch].push(filePath);
        }
        return entire;
      });
    }
  };

  processFile = function(filePath) {
    return fs.readFile(filePath, 'utf8', function(err, data) {
      if (err) {
        console.log(err);
        return;
      }
      captureImports(data, filePath);
      return startExecutionFor(filePath);
    });
  };

  startExecutionFor = function(filePath) {
    var importingFiles;
    if (importHistory[filePath] != null) {
      importingFiles = importHistory[filePath];
      return importingFiles.forEach(function(file) {
        return startExecutionFor(file);
      });
    } else {
      return executeCommandFor(filePath);
    }
  };

  executeCommandFor = function(filePath) {
    var command, pathParams;
    if ((execHistory[filePath] != null) && Date.now() - execHistory[filePath] < 1500) {
      return;
    }
    pathParams = path.parse(filePath);
    execHistory[filePath] = Date.now();
    command = commandToExecute.replace(regEx.placeholder, function(entire, placeholder) {
      if (placeholder === 'path') {
        return filePath;
      } else if (pathParams[placeholder] != null) {
        return pathParams[placeholder];
      } else {
        return entire;
      }
    });
    return exec(command, function(err, stdout, stderr) {
      if (!silent) {
        if (err) {
          console.log(err);
        }
        if (stdout) {
          console.log(stdout);
        }
        if (stderr) {
          return console.log(stderr);
        }
      }
    });
  };

  dirs.forEach(function(dir) {
    var fw;
    fw = fireworm(dir);
    if (onlyExt) {
      fw.add("*." + onlyExt);
      fw.add("**/*." + onlyExt);
    } else {
      fw.add("*");
      fw.add("**/*");
    }
    if (ignore && ignore.length) {
      ignore.forEach(function(globToIgnore) {
        return fw.ignore(globToIgnore);
      });
    }
    fw.on('add', processFile);
    return fw.on('change', processFile);
  });

}).call(this);
