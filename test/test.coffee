fs = require 'fs-extra'
chai = require 'chai'
expect = chai.expect
should = chai.should()
exec = require('child_process').exec


suite "AssetWatcher", ()->
	suiteSetup (done)-> fs.ensureDir 'test/temp', done
	suiteTeardown (done)-> fs.remove 'test/temp', done