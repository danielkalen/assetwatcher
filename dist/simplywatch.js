#!/usr/bin/env node
// Generated by CoffeeScript 1.10.0
var args, captureImports, commandToExecute, dirs, exec, execDelay, execFinallyCommand, execHistory, executeCommandFor, filesToIgnoreExecFor, finallyExecCommand, finallyExecDelay, finallyTimeout, fireworm, fs, glob, help, ignore, ignoreWeak, importHistory, imports, onlyExt, options, passedExecDelay, passedStartDelay, path, processFile, regEx, runNow, silent, startExecutionFor, startProcessingFile, startProcessingFileAdded, startTime, yargs;

options = {
  'd': {
    alias: 'dir',
    describe: 'Specify all dirs to watch for in quotes, separated with commas. Syntax: -d "dirA" "dirB"',
    type: 'array',
    demand: true
  },
  'i': {
    alias: 'ignore',
    describe: 'Specify all globs to ignore in quotes, separated with commas. Changes to matching files will NOT trigger any executions even if imported by another file. Syntax: -s "globA" "globB"',
    type: 'array'
  },
  'I': {
    alias: 'ignoreweak',
    describe: 'Specify all globs to weakly ignore in quotes, separated with commas. Changes to matching files WILL trigger an execution if imported by another file. Syntax: -s "globA" "globB"',
    type: 'array'
  },
  'e': {
    alias: 'extension',
    describe: 'Only watch files that have a specific extension. Syntax: -e "ext1" "ext2"',
    type: 'array'
  },
  'x': {
    alias: 'execute',
    describe: 'Command to execute upon file addition/change',
    type: 'string',
    demand: true
  },
  'f': {
    alias: 'finally',
    describe: 'Command to execute X ms (default: 3000) after the addition/change of the last file. For example if some file change triggered a command to be run for 10 files, after 3 seconds this "finally" command will be run once.',
    type: 'string'
  },
  's': {
    alias: 'silent',
    describe: 'Suppress any output from the executing command',
    type: 'boolean',
    "default": false
  },
  'n': {
    alias: 'now',
    describe: 'Execute the command for all files matched immediatly on startup',
    type: 'boolean',
    "default": false
  },
  't': {
    alias: 'imports',
    describe: 'Optionally compile files that are imported by other files.',
    type: 'boolean',
    "default": false
  },
  'w': {
    alias: 'wait',
    describe: 'Execution delay, i.e. how long should simplywatch wait before re-executing the command. If the watched file changes rapidly, the command will execute only once every X ms.',
    type: 'number',
    "default": 1500
  },
  'W': {
    alias: 'finallywait',
    describe: 'The amount of milliseconds to wait before executing the finally command (if passed).',
    type: 'number',
    "default": 3000
  }
};

fs = require('fs');

glob = require('glob');

path = require('path');

fireworm = require('fireworm');

exec = require('child_process').exec;

yargs = require('yargs').usage("Usage: simplywatch -d <directory globs> -s <globs to skip> -i").options(options).help('h').alias('h', 'help');

args = yargs.argv;

regEx = {
  ext: /.+\.(sass|scss|js|coffee)$/i,
  "import": /@import\s*(.+)/ig,
  placeholder: /\#\{([^\/\}]+)\}/ig
};

importHistory = {};

execHistory = {};

filesToIgnoreExecFor = [];

finallyTimeout = null;

dirs = args.d || args.dir;

ignore = args.i || args.ignore;

ignoreWeak = args.I || args.ignoreweak;

help = args.h || args.help;

silent = args.s || args.silent;

imports = args.t || args.imports;

onlyExt = args.e || args.extension;

runNow = args.n || args.now;

commandToExecute = args.x || args.execute;

finallyExecCommand = args.f || args["finally"];

execDelay = args.w || args.wait;

finallyExecDelay = args.W || args.finallywait;

if (help) {
  process.stdout.write(yargs.help());
  process.exit(0);
}

if (ignoreWeak) {
  ignoreWeak.forEach(function(globToIgnore) {
    return glob(globToIgnore, function(err, files) {
      if (err) {
        throw err;
      }
      return filesToIgnoreExecFor = filesToIgnoreExecFor.concat(files);
    });
  });
}

passedStartDelay = function() {
  return Date.now() - startTime > 3000;
};

passedExecDelay = function(filePath) {
  var passed;
  if (execHistory[filePath] != null) {
    passed = Date.now() - execHistory[filePath] > execDelay;
  } else {
    passed = true;
  }
  return passed;
};

startProcessingFileAdded = function(watchedDir) {
  return function(filePath) {
    return processFile(filePath, watchedDir, 'added');
  };
};

startProcessingFile = function(watchedDir) {
  return function(filePath) {
    return processFile(filePath, watchedDir);
  };
};

processFile = function(filePath, watchedDir, eventType) {
  if (eventType == null) {
    eventType = 'changed';
  }
  return fs.stat(filePath, function(err, stats) {
    if (err) {
      console.log(err);
      return;
    }
    if (stats.isFile()) {
      return fs.readFile(filePath, 'utf8', function(err, data) {
        if (err) {
          console.log(err);
          return;
        }
        if (!silent && passedStartDelay()) {
          console.log("File " + eventType + ": " + filePath);
        }
        captureImports(data, filePath);
        return startExecutionFor(filePath, watchedDir, eventType);
      });
    }
  });
};

captureImports = function(fileContent, filePath) {
  var dirPath, extName;
  if (typeof fileContent !== 'string') {
    return fileContent;
  } else {
    extName = path.extname(filePath);
    dirPath = path.dirname(filePath);
    return fileContent.replace(regEx["import"], function(entire, match) {
      var hasExt, matchFileContent, resolvedMatch, stats;
      match = match.replace(/'/g, '');
      hasExt = regEx.ext.test(match);
      if (!hasExt) {
        match += extName;
      }
      resolvedMatch = path.normalize(dirPath + '/' + match);
      if (importHistory[resolvedMatch] == null) {
        importHistory[resolvedMatch] = [filePath];
      } else {
        if (importHistory[resolvedMatch].indexOf(filePath) === -1) {
          importHistory[resolvedMatch].push(filePath);
        }
      }
      try {
        stats = fs.statSync(resolvedMatch);
        if (stats.isFile()) {
          matchFileContent = fs.readFileSync(resolvedMatch, 'utf8');
          captureImports(matchFileContent, resolvedMatch);
        }
      } catch (undefined) {}
      return entire;
    });
  }
};

startExecutionFor = function(filePath, watchedDir, eventType) {
  var importingFiles;
  if (!passedStartDelay() && !runNow) {
    return;
  }
  if (importHistory[filePath] != null) {
    importingFiles = importHistory[filePath];
    return importingFiles.forEach(function(file) {
      return startExecutionFor(file, watchedDir, eventType);
    });
  } else {
    return executeCommandFor(filePath, watchedDir, eventType);
  }
};

executeCommandFor = function(filePath, watchedDir, eventType) {
  var command, pathParams;
  if (!passedExecDelay(filePath) || filesToIgnoreExecFor.indexOf(filePath) !== -1) {
    return;
  }
  pathParams = path.parse(filePath);
  pathParams.reldir = pathParams.dir.replace(watchedDir, '').slice(1);
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
        console.log(stderr);
      }
      console.log("Finished executing command for \x1b[32m" + pathParams.base + "\x1b[0m\n");
      if (finallyExecCommand) {
        clearTimeout(finallyTimeout);
      }
      if (finallyExecCommand) {
        return finallyTimeout = setTimeout(execFinallyCommand, finallyExecDelay);
      }
    }
  });
};

execFinallyCommand = function() {
  return exec(finallyExecCommand, function(err, stdout, stderr) {
    if (!silent) {
      if (err) {
        console.log(err);
      }
      if (stdout) {
        console.log(stdout);
      }
      if (stderr) {
        console.log(stderr);
      }
      return console.log("Finished executing \x1b[35mfinal command\x1b[0m");
    }
  });
};

startTime = Date.now();

dirs.forEach(function(dir) {
  var dirName, fw;
  fw = fireworm(dir);
  if (onlyExt) {
    onlyExt.forEach(function(ext) {
      return fw.add("**/*." + ext);
    });
  } else {
    fw.add("**/*");
  }
  if (ignore && ignore.length) {
    ignore.forEach(function(globToIgnore) {
      return fw.ignore(globToIgnore);
    });
  }
  dirName = dir.charAt(dir.length - 1) === '/' ? dir.slice(0, dir.length - 1) : dir;
  if (dirName.charAt(0) === '.') {
    dirName = dirName.slice(2);
  } else if (dirName.charAt(0) === '/') {
    dirName = dirName.slice(1);
  }
  fw.on('add', startProcessingFileAdded(dirName));
  fw.on('change', startProcessingFile(dirName));
  return console.log("Started watching \x1b[36m" + dir + "\x1b[0m");
});