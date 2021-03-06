// Generated by CoffeeScript 1.10.0
var File, Path, Promise, SimplyImport, badFilesDeps, chalk, exec, fileInstances, fs, getFile, regEx, watcher;

Promise = require('bluebird');

fs = Promise.promisifyAll(require('fs'));

Path = require('path');

exec = require('child_process').exec;

chalk = require('chalk');

SimplyImport = require('simplyimport');

regEx = require('./regex');

watcher = require('./watcher');

File = function(filePath1, watchContext1, options1) {
  this.filePath = filePath1;
  this.watchContext = watchContext1;
  this.options = options1;
  this.filePathShort = this.filePath.replace(process.cwd() + '/', '');
  this.fileDirShort = Path.dirname(this.filePathShort);
  this.fileDir = Path.dirname(this.filePath);
  this.fileExt = this.getExtension();
  this.filePathNoExt = this.fileDir + '/' + Path.basename(this.filePath, this.fileExt);
  this.relDir = Path.dirname(this.watchContext);
  this.relDir = this.relDir[0] === '.' ? this.relDir.slice(1) : this.relDir;
  this.relDir = this.fileDirShort.replace(this.relDir, '');
  this.pathParams = Path.parse(this.filePath);
  this.pathParams.reldir = this.relDir.slice(1);
  this.deps = badFilesDeps[this.filePathNoExt] || [];
  this.imports = [];
  this.lastProcessed = null;
  this.lastScanned = null;
  this.execCount = 1;
  return this.process();
};

File.prototype.getExtension = function() {
  var extension, files, thisFileName;
  extension = Path.extname(this.filePath);
  if (extension) {
    return extension;
  } else {
    try {
      thisFileName = Path.basename(this.filePath);
      files = fs.readdirSync(this.fileDir).forEach(function(filePath) {
        var fileExt, fileName;
        fileExt = Path.extname(filePath);
        fileName = Path.basename(filePath, fileExt);
        if (fileName === thisFileName) {
          return extension = fileExt;
        }
      });
    } catch (undefined) {}
    if (extension) {
      this.filePath += extension;
      this.filePathShort += extension;
      fileInstances[this.filePath] = this;
    }
    return extension || '';
  }
};

File.prototype.process = function() {
  if (this.canScanImports()) {
    this.lastScanned = Date.now();
    this.scanProcedure = Promise.bind(this).then(this.getContents).then(this.scanForImports);
  }
  return this;
};

File.prototype.getContents = function() {
  return new Promise((function(_this) {
    return function(resolve) {
      if (!_this.fileExt) {
        return resolve();
      } else {
        return fs.readFileAsync(_this.filePath, {
          encoding: 'utf8'
        }).then(function(content) {
          _this.content = content;
          return resolve();
        })["catch"](resolve);
      }
    };
  })(this));
};

File.prototype.scanForImports = function() {
  return new Promise((function(_this) {
    return function(resolve) {
      _this.imports.length = 0;
      SimplyImport.scanImports(_this.content || '', true, true).forEach(function(childPath) {
        var childFile;
        childPath = Path.normalize(_this.fileDir + "/" + childPath);
        childFile = getFile(childPath, _this.watchContext, _this.options);
        if (!childFile.fileExt) {
          if (badFilesDeps[childPath] == null) {
            badFilesDeps[childPath] = [];
          }
          badFilesDeps[childPath].push(_this);
          delete fileInstances[childPath];
        }
        watcher.add(childFile.filePath);
        _this.imports.push(childFile);
        if (!childFile.deps.includes(_this)) {
          return childFile.deps.push(_this);
        }
      });
      if (_this.imports.length === 0) {
        return resolve();
      } else {
        return Promise.map(_this.imports, function(childFile) {
          return childFile.scanProcedure;
        }).then(function() {
          return resolve();
        });
      }
    };
  })(this));
};

File.prototype.prepareCommandString = function(command) {
  var formattedCommand;
  formattedCommand = command.replace(regEx.placeholder, (function(_this) {
    return function(entire, placeholder) {
      switch (false) {
        case placeholder !== 'path':
          return _this.filePathShort;
        case _this.pathParams[placeholder] == null:
          return _this.pathParams[placeholder];
        default:
          return entire;
      }
    };
  })(this));
  return formattedCommand = "FORCE_COLOR=true " + formattedCommand;
};

File.prototype.executeCommand = function(command) {
  return new Promise((function(_this) {
    return function(resolve) {
      command = _this.prepareCommandString(command);
      _this.lastProcessed = Date.now();
      return exec(command, function(err, stdout, stderr) {
        return resolve({
          err: err,
          stdout: stdout,
          stderr: stderr
        });
      });
    };
  })(this));
};

File.prototype.canExecuteCommand = function(invokeTime) {
  if (this.lastProcessed) {
    return invokeTime - this.lastProcessed > this.options.execDelay;
  } else {
    return true;
  }
};

File.prototype.canScanImports = function() {
  if (this.lastScanned) {
    return Date.now() - this.lastScanned > 150;
  } else {
    return true;
  }
};

fileInstances = {};

badFilesDeps = {};

module.exports = getFile = function(filePath, watchContext, options) {
  var ref;
  return ((ref = fileInstances[filePath]) != null ? ref.process() : void 0) || (fileInstances[filePath] = new File(filePath, watchContext, options));
};
