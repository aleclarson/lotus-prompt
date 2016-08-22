var BINDINGS, Event, EventEmitter, FS, MODIFIERS, Null, Promise, Type, addKeyPress, assert, assertType, emptyFunction, immediate, isType, log, parseBool, stripAnsi, type;

EventEmitter = require("events").EventEmitter;

emptyFunction = require("emptyFunction");

addKeyPress = require("keypress");

assertType = require("assertType");

stripAnsi = require("strip-ansi");

parseBool = require("parse-bool");

immediate = require("immediate");

Promise = require("Promise");

isType = require("isType");

assert = require("assert");

Event = require("Event");

Null = require("Null");

Type = require("Type");

log = require("log");

FS = require("fs");

BINDINGS = require("./bindings");

MODIFIERS = ["ctrl", "meta", "shift"];

type = Type("Prompt");

type.defineProperties({
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
  isReading: {
    get: function() {
      return this._reading;
    }
  },
  _message: {
    value: "",
    didSet: function(message) {
      return assertType(message, [String, Null]);
    }
  }
});

type.defineValues({
  didPressKey: function() {
    return Event();
  },
  didClose: function() {
    return Event();
  },
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
    return emptyFunction.thatReturnsFalse;
  },
  _mark: function() {
    var TimeMarker;
    TimeMarker = require("TimeMarker");
    return TimeMarker();
  }
});

type.initInstance(function() {
  return this.stdin = process.stdin;
});

type.defineMethods({
  sync: function(options) {
    return this._readSync(options);
  },
  async: function(options) {
    return this._readAsync(options);
  },
  _readAsync: function(options) {
    var deferred;
    this._async = true;
    this._setLabel(options.label);
    deferred = Promise.defer();
    this._open();
    immediate((function(_this) {
      return function() {
        deferred.resolve();
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
      return false;
    }
    result = this._close();
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
    if (options == null) {
      options = {};
    }
    this._async = false;
    this._setLabel(options.label);
    this._open();
    this._loopSync();
    if (this._reading) {
      this._close();
    }
    if (options.parseBool) {
      return parseBool(this._prevMessage);
    }
    return this._prevMessage;
  },
  _setLabel: function(label) {
    var printLabel;
    if (isType(label, Function)) {
      printLabel = label;
    } else if (isType(label, String)) {
      printLabel = function() {
        return label;
      };
    }
    if (printLabel) {
      this._labelPrinter = printLabel;
      this.didClose.once((function(_this) {
        return function() {
          return _this._labelPrinter = emptyFunction.thatReturnsFalse;
        };
      })(this));
    }
  },
  _loopSync: function() {
    var buffer, length;
    buffer = Buffer(3);
    length = FS.readSync(this.stdin.fd, buffer, 0, 3);
    this._stream.emit("data", buffer.slice(0, length).toString());
    if (this._reading) {
      return this._loopSync();
    }
  },
  _open: function() {
    if (this._reading) {
      return;
    }
    this._reading = true;
    this._indent = log.indent;
    log.moat(1);
    this._printLabel();
    this._cursorWasHidden = log.cursor.isHidden;
    if (this.showCursorDuring) {
      log.cursor.isHidden = false;
    }
    if (log.cursor.x < this._labelLength) {
      log.cursor.x = this._labelLength;
    }
  },
  _close: function() {
    assert(this._reading, "Prompt is not reading!");
    if (this.showCursorDuring) {
      log.cursor.isHidden = this._cursorWasHidden;
    }
    this._async = null;
    this._reading = false;
    this._prevMessage = this._message;
    this._message = "";
    this.didClose.emit(this._prevMessage);
    return this._prevMessage;
  },
  _input: function(char) {
    var a, b, x;
    if (char == null) {
      return;
    }
    this._printing = true;
    log.pushIndent(0);
    x = Math.max(0, log.cursor.x - this._labelLength);
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
      log.cursor.x = log.line.length - stripAnsi(b).length;
    }
    log.popIndent();
    this._printing = false;
  },
  _keypress: function(char, key) {
    var action, command, hasModifier, i, len, modifier;
    if (!this._reading) {
      return;
    }
    hasModifier = false;
    if (key != null) {
      command = key.name;
      for (i = 0, len = MODIFIERS.length; i < len; i++) {
        modifier = MODIFIERS[i];
        if (key[modifier] === true) {
          hasModifier = true;
          command += "+" + modifier;
        }
      }
    } else {
      command = char;
    }
    this.didPressKey.emit({
      command: command,
      key: key,
      char: char
    });
    action = BINDINGS[command];
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

module.exports = type.construct();

//# sourceMappingURL=map/index.map
