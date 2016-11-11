// Generated by CoffeeScript 1.10.0
var Glob, Listr, Path, Promise, absPath, chalk, defaultOptions, eventsLog, exec, extend, getFile, globMatch, regEx, watcher;

Promise = require('bluebird');

Promise.config({
  cancellation: true
});

Glob = Promise.promisify(require('glob'));

Path = require('path');

exec = require('child_process').exec;

absPath = require('abs');

globMatch = require('micromatch');

extend = require('extend');

chalk = require('chalk');

Listr = require('@danielkalen/listr');

regEx = require('./regex');

watcher = require('./watcher');

getFile = require('./FileConstructor');

eventsLog = require('./eventsLog');

defaultOptions = require('./defaultOptions');

module.exports = function(passedOptions) {
  return new Promise(function(resolve) {
    var formatOutputMessage, isIgnored, isValidOutput, options, processFile, queue, scanInitial;
    options = extend({}, defaultOptions, passedOptions);
    if (typeof options.globs === 'string') {
      options.globs = [options.globs];
    }
    if (options.globs.length === 0) {
      throw new Error("No globs were provided");
    }
    if (!options.command) {
      throw new Error("Execution command not provided");
    }
    formatOutputMessage = function(message) {
      if (options.trim) {
        return message.slice(0, options.trim);
      } else {
        return message;
      }
    };
    processFile = function(watchContext, eventType) {
      return function(filePath) {
        filePath = absPath(filePath);
        return queue.add(filePath, watchContext, eventType);
      };
    };
    scanInitial = function(globToScan) {
      return Glob(globToScan, {
        nodir: true,
        dot: true
      }).then(function(files) {
        var filePath, i, len;
        for (i = 0, len = files.length; i < len; i++) {
          filePath = files[i];
          filePath = absPath(filePath);
          if (!filePath.includes('.git')) {
            getFile(filePath, globToScan, options);
          }
        }
      });
    };
    isIgnored = function(path) {
      var glob, i, len, ref;
      ref = options.ignoreGlobs;
      for (i = 0, len = ref.length; i < len; i++) {
        glob = ref[i];
        if (globMatch.contains(path, glob)) {
          return true;
        }
      }
      return false;
    };
    isValidOutput = function(output) {
      return output && output !== 'null' && ((typeof output === 'string' && output.length >= 1) || (typeof output === 'object'));
    };
    queue = new function() {
      this.list = {};
      this.executionLogs = {
        'log': {},
        'error': {}
      };
      this.timeout = {
        process: null,
        final: null
      };
      this.lastTasklist = Promise.resolve();
      this.add = function(filePath, watchContext, eventType) {
        var file, logEvent, wasNotLogged;
        file = getFile(filePath, watchContext, options);
        logEvent = function() {
          return eventsLog.add(chalk.bgGreen.bgGreen.black(eventType) + ' ' + chalk.dim(file.filePathShort));
        };
        if (eventType) {
          if (!isIgnored(file.filePath)) {
            logEvent();
          } else {
            wasNotLogged = true;
          }
        }
        return file.scanProcedure.then((function(_this) {
          return function() {
            var depFile, fileDeps, i, len, ref, results;
            fileDeps = file.deps;
            if (fileDeps.length) {
              fileDeps = file.deps.filter(function(depFile) {
                return !isIgnored(depFile.filePath);
              });
            }
            if (fileDeps.length === 0) {
              if (!isIgnored(file.filePath)) {
                _this.list[file.filePath] = file;
                return _this.beginProcess();
              }
            } else {
              if (wasNotLogged) {
                logEvent();
              }
              ref = file.deps;
              results = [];
              for (i = 0, len = ref.length; i < len; i++) {
                depFile = ref[i];
                results.push(_this.add(depFile.filePath, watchContext));
              }
              return results;
            }
          };
        })(this));
      };
      this.beginProcess = function() {
        clearTimeout(this.timeout.process);
        return this.timeout.process = setTimeout((function(_this) {
          return function() {
            var file, filePath, list;
            list = (function() {
              var ref, results;
              ref = this.list;
              results = [];
              for (filePath in ref) {
                file = ref[filePath];
                results.push(file);
              }
              return results;
            }).call(_this);
            _this.list = {};
            return _this.process(list);
          };
        })(this), 300);
      };
      this.process = function(list) {
        var invokeTime, logIteration;
        logIteration = eventsLog.iteration++;
        invokeTime = Date.now();
        this.lastTasklist = this.lastTasklist.then((function(_this) {
          return function() {
            return new Promise(function(resolve) {
              var tasks;
              eventsLog.output(logIteration, isIgnored);
              tasks = new Listr(list.map(function(file) {
                return {
                  title: "Executing command: " + (chalk.dim(file.filePathShort)),
                  skip: function() {
                    return !file.canExecuteCommand(invokeTime);
                  },
                  task: function() {
                    return new Promise(function(resolve, reject) {
                      return file.executeCommand(options.command).then(function(arg) {
                        var err, stderr, stdout;
                        err = arg.err, stdout = arg.stdout, stderr = arg.stderr;
                        if (isValidOutput(stdout)) {
                          _this.executionLogs.log[file.filePathShort] = stdout;
                        }
                        if (isValidOutput(stderr) && !isValidOutput(err)) {
                          _this.executionLogs.log[file.filePathShort] = stderr;
                        } else if (isValidOutput(err)) {
                          _this.executionLogs.error[file.filePathShort] = stderr || err;
                        }
                        if (isValidOutput(err)) {
                          return reject();
                        } else {
                          return resolve();
                        }
                      });
                    });
                  }
                };
              }), {
                'concurrent': true
              });
              return tasks.run().then(function() {
                _this.outputLogs();
                return resolve();
              });
            });
          };
        })(this));
        return this.processFinalCommand();
      };
      this.processFinalCommand = function() {
        if (options.finalCommand) {
          if (this.timeout.final) {
            this.timeout.final.cancel();
          }
          return this.timeout.final = this.lastTasklist.then((function(_this) {
            return function() {
              return setTimeout(function() {
                return _this.finalCommand();
              }, options.finalCommandDelay);
            };
          })(this));
        }
      };
      this.finalCommand = (function(_this) {
        return function() {
          console.log("" + (chalk.bgBlue.bold('Executing Final Command')));
          return exec("FORCE_COLOR=true " + options.finalCommand, function(err, stdout, stderr) {
            var output;
            if (err) {
              return console.error(err);
            } else {
              output = (stdout || '') + (stderr || '');
              if (output) {
                return console.log(chalk.blue.bold('Output') + ' ' + formatOutputMessage(output));
              }
            }
          });
        };
      })(this);
      this.outputLogs = function() {
        var divider, file, lineCount, logsCount, message, ref, ref1;
        logsCount = Object.keys(this.executionLogs.log).length + Object.keys(this.executionLogs.error).length;
        if (logsCount === 0 || options.silent) {
          return process.stdout.write('\n');
        } else {
          lineCount = Math.floor(require('window-size').width * 0.7);
          divider = '-'.repeat(lineCount);
          process.stdout.write('\n\n');
          process.stdout.write(divider.slice(0, 5) + 'COMMAND OUTPUT' + divider.slice(18));
          ref = this.executionLogs.log;
          for (file in ref) {
            message = ref[file];
            process.stdout.write('\n' + chalk.bgWhite.black.bold("Output") + ' ' + chalk.dim(file));
            process.stdout.write('\n' + formatOutputMessage(message) + '\n');
            delete this.executionLogs.log[file];
          }
          ref1 = this.executionLogs.error;
          for (file in ref1) {
            message = ref1[file];
            process.stdout.write('\n' + chalk.bgRed.white.bold("Error") + ' ' + chalk.dim(file));
            process.stdout.write('\n' + formatOutputMessage(message) + '\n');
            delete this.executionLogs.error[file];
          }
          process.stdout.write(divider);
          return process.stdout.write('\n\n\n');
        }
      };
      return this;
    };
    return Promise.map(options.globs, function(dirPath) {
      watcher.add(dirPath);
      scanInitial(dirPath);
      watcher.on('add', processFile(dirPath, 'Added'));
      watcher.on('change', processFile(dirPath, 'Changed'));
      return console.log(chalk.bgYellow.black('Watching') + ' ' + chalk.dim(dirPath));
    }).then(function() {
      return resolve(watcher);
    });
  });
};
