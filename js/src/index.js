var BindingMap, EventEmitter, FS, Factory, addKeyPress, assert, assertType, async, cursor, isType, log, modifiers, parseBool, ref, ref1, stripAnsi;

require("lotus-require");

ref = require("type-utils"), isType = ref.isType, assertType = ref.assertType, assert = ref.assert;

EventEmitter = require("events").EventEmitter;

ref1 = require("lotus-log"), log = ref1.log, cursor = ref1.cursor;

async = require("io").async;

addKeyPress = require("keypress");

stripAnsi = require("strip-ansi");

parseBool = require("parse-bool");

Factory = require("factory");

FS = require("fs");

BindingMap = require("./bindings");

modifiers = ["ctrl", "meta", "shift"];

module.exports = Factory("Prompt", {
  singleton: true,
  kind: EventEmitter,
  customValues: {
    stdin: {
      value: null,
      didSet: function(newValue, oldValue) {
        if (newValue === oldValue) {
          return;
        }
        if ((newValue != null) && newValue.isTTY) {
          newValue.setRawMode(true);
          this._stream = new EventEmitter;
          this._stream.write = function(chunk) {
            return newValue.write(chunk);
          };
          this._stream.on("keypress", this._keypress.bind(this));
          return addKeyPress(this._stream);
        } else if ((oldValue != null) && oldValue.isTTY) {
          return this._stream = null;
        }
      }
    },
    inputMode: {
      value: "prompt",
      willSet: function() {
        return assert(!this._reading, "Cannot set 'inputMode' while reading.");
      }
    },
    isReading: {
      get: function() {
        return this._reading;
      }
    },
    _message: {
      value: "",
      didSet: function(message) {
        return assertType(message, [String, Void]);
      }
    }
  },
  initValues: function() {
    return {
      showCursorDuring: true,
      _reading: false,
      _printing: false,
      _async: null,
      _prevMessage: null,
      _stream: null,
      _cursorWasHidden: false,
      _line: null,
      _indent: 0,
      _label: "",
      _labelLength: 0,
      _labelPrinter: function() {
        return false;
      }
    };
  },
  init: function() {
    return this.stdin = process.stdin;
  },
  sync: function(options) {
    return this._readSync(options);
  },
  async: function(options) {
    return this._readAsync(options);
  },
  _readAsync: function(options) {
    var deferred, hasLabel, nextTick;
    hasLabel = isType(options.label, Function);
    if (hasLabel) {
      this._labelPrinter = options.label;
    }
    deferred = async.defer();
    this._async = true;
    this._open();
    nextTick = async.defer();
    async.timeout(nextTick.promise, 1000).fail(function() {
      return deferred.reject(Error("Asynchronous prompt failed unexpectedly. Try using `prompt.sync()` instead."));
    });
    async.nextTick((function(_this) {
      return function() {
        nextTick.resolve();
        return _this._loopAsync();
      };
    })(this));
    return deferred.promise;
  },
  _writeAsync: function(data) {
    if (!this._reading) {
      return;
    }
    this._stream.emit("data", data);
    return this._loopAsync();
  },
  _cancelAsync: function() {
    var result;
    if (!this._reading) {
      return;
    }
    result = this._close();
    if (options.parseBool) {
      result = parseBool(result);
    }
    if (hasLabel) {
      this._labelPrinter = function() {
        return false;
      };
    }
    deferred.resolve(result);
    return true;
  },
  _loopAsync: function() {
    var buffer;
    buffer = Buffer(3);
    return FS.read(this.stdin.fd, buffer, 0, 3, null, (function(_this) {
      return function(error, length) {
        if (error != null) {
          throw error;
        }
        return typeof _this._writeAsync === "function" ? _this._writeAsync(buffer.slice(0, length).toString()) : void 0;
      };
    })(this));
  },
  _readSync: function(options) {
    var hasLabel, result;
    if (options == null) {
      options = {};
    }
    hasLabel = isType(options.label, Function);
    if (hasLabel) {
      this._labelPrinter = options.label;
    }
    this._async = false;
    this._open();
    this._loopSync();
    result = this._close();
    if (options.parseBool) {
      result = parseBool(result);
    }
    if (hasLabel) {
      this._labelPrinter = function() {
        return false;
      };
    }
    return result;
  },
  _loopSync: function() {
    var buffer, length;
    buffer = Buffer(3);
    length = FS.readSync(this.stdin.fd, buffer, 0, 3);
    this._stream.emit("data", buffer.slice(0, length).toString());
    if (this._reading) {
      return this._loopSync();
    }
    return log("");
  },
  _open: function() {
    this._close();
    this._reading = true;
    this._indent = log.indent;
    log.moat(1);
    this._printLabel();
    this._cursorWasHidden = cursor.isHidden;
    if (this.showCursorDuring) {
      cursor.isHidden = false;
    }
    if (cursor.x < this._labelLength) {
      cursor.x = this._labelLength;
    }
  },
  _close: function() {
    if (this._reading) {
      if (this.showCursorDuring) {
        cursor.isHidden = this._cursorWasHidden;
      }
      this._reading = false;
      this._async = null;
      this._prevMessage = this._message;
      this._message = "";
    }
    return this._prevMessage;
  },
  _input: function(char) {
    var a, b, x;
    if (char == null) {
      return;
    }
    this._printing = true;
    log.pushIndent(0);
    x = cursor.x - this._labelLength;
    if (!(x >= 0)) {
      throw Error("'x' should never be under zero.");
    }
    if (x === this._message.length) {
      this._message += char;
      this._print(char);
    } else {
      a = this._message.slice(0, x);
      b = this._message.slice(x);
      this._message = a + char + b;
      log.line.contents = this._label + a;
      log.line.length = this._labelLength + stripAnsi(a).length;
      this._print(char + b);
      cursor.x = log.line.length - stripAnsi(b).length;
    }
    log.popIndent();
    this._printing = false;
  },
  _keypress: function(char, key) {
    var action, command, hasModifier, i, len, modifier;
    if (!this._reading) {
      return log("");
    }
    hasModifier = false;
    if (key != null) {
      command = key.name;
      for (i = 0, len = modifiers.length; i < len; i++) {
        modifier = modifiers[i];
        if (key[modifier] === true) {
          hasModifier = true;
          command += "+" + modifier;
        }
      }
    } else {
      command = char;
    }
    this.emit("keypress", {
      command: command,
      key: key,
      char: char
    });
    action = BindingMap[command];
    if (action instanceof Function) {
      return action.call(this);
    }
    if (!hasModifier || /[a-z]/i.test(char)) {
      return this._input(char);
    }
  },
  _print: function(chunk) {
    this._printing = true;
    log.pushIndent(this._indent);
    log._printToChunk(chunk);
    log.popIndent();
    return this._printing = false;
  },
  _printLabel: function() {
    this._printing = true;
    log.moat(0);
    log.pushIndent(this._indent);
    if (this._labelPrinter() !== false) {
      this._label = log.line.contents;
      this._labelLength = log.line.length;
    } else {
      log._printChunk({
        indent: true
      });
      this._label = log._indent;
      this._labelLength = log.indent;
    }
    log.popIndent();
    return this._printing = false;
  }
});

//# sourceMappingURL=../../map/src/index.map
