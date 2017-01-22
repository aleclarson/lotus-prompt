var Event, KeyBindings, KeyEmitter, Promise, Type, caret, emptyFunction, fs, immediate, isType, log, stripAnsi, type;

caret = (log = require("log")).caret;

emptyFunction = require("emptyFunction");

stripAnsi = require("strip-ansi");

immediate = require("immediate");

Promise = require("Promise");

isType = require("isType");

Event = require("Event");

Type = require("Type");

fs = require("fs");

KeyBindings = require("./KeyBindings");

KeyEmitter = require("./KeyEmitter");

type = Type("Prompt");

type.defineValues(function() {
  return {
    didClose: Event(),
    showCursorDuring: true,
    _reading: false,
    _printing: false,
    _async: null,
    _error: null,
    _line: null,
    _message: "",
    _prevMessage: null,
    _label: "",
    _labelLength: 0,
    _printLabel: emptyFunction,
    _caretWasHiding: false,
    _keyListener: KeyEmitter.didPressKey((function(_this) {
      return function(event) {
        var action;
        action = KeyBindings[event.command];
        if (isType(action, Function)) {
          return action.call(_this);
        } else {
          return _this._input(event);
        }
      };
    })(this)).start()
  };
});

type.defineGetters({
  isReading: function() {
    return this._reading;
  }
});

type.defineMethods({
  sync: function(options) {
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
    if (options.bool) {
      if (this._prevMessage === null) {
        return null;
      } else {
        return this._prevMessage === "y";
      }
    } else {
      return this._prevMessage;
    }
  },
  async: function(options) {
    var deferred;
    this._async = true;
    this._setLabel(options.label);
    this._open();
    deferred = Promise.defer();
    immediate(this, function() {
      deferred.resolve();
      return this._loopAsync();
    });
    return deferred.promise;
  },
  close: function() {
    this._message = null;
    if (this._async) {
      return this._cancelAsync();
    } else {
      return this._close();
    }
  },
  _setLabel: function(label) {
    if (label == null) {
      label = "";
    }
    if (isType(label, String)) {
      label = log._indent + label;
    }
    this._printLabel = isType(label, Function) ? label : function() {
      return log.white(label);
    };
  },
  _open: function() {
    if (this._reading) {
      return;
    }
    this._reading = true;
    log.pushIndent(0);
    this._printLabel();
    log.popIndent();
    log.flush();
    this._label = log.line.contents;
    this._labelLength = log.line.length;
    this._caretWasHiding = caret.isHidden;
    if (this.showCursorDuring) {
      caret.isHidden = false;
    }
    if (caret.x < this._labelLength) {
      caret.x = this._labelLength;
    }
  },
  _loopSync: function() {
    var buffer, length;
    buffer = Buffer(3);
    length = fs.readSync(process.stdin.fd, buffer, 0, 3);
    KeyEmitter.send(buffer.slice(0, length).toString());
    return this._reading && this._loopSync();
  },
  _close: function() {
    if (!this._reading) {
      throw Error("Prompt is not reading!");
    }
    if (this.showCursorDuring) {
      caret.isHidden = this._caretWasHiding;
    }
    this._async = null;
    this._reading = false;
    this._prevMessage = this._message;
    this._message = "";
    this.didClose.emit(this._prevMessage);
    return this._prevMessage;
  },
  _input: function(event) {
    var a, b, x;
    if (event.char == null) {
      return;
    }
    if ((event.modifier != null) && !/[a-z]/i.test(event.char)) {
      return;
    }
    this._printing = true;
    log.pushIndent(0);
    x = Math.max(0, caret.x - this._labelLength);
    if (x === this._message.length) {
      this._message += event.char;
      log(event.char);
    } else {
      a = this._message.slice(0, x);
      b = this._message.slice(x);
      log.line.contents = this._label + a;
      log.line.length = this._labelLength + stripAnsi(a).length;
      this._message = a + event.char + b;
      log(event.char + b);
      caret.x = log.line.length - stripAnsi(b).length;
    }
    log.popIndent();
    log.flush();
    this._printing = false;
  },
  _writeAsync: function(data) {
    if (this._reading) {
      KeyEmitter.send(data);
      this._loopAsync();
    }
  },
  _cancelAsync: function() {
    if (this._reading) {
      deferred.resolve(this._close());
    }
  },
  _loopAsync: function() {
    var buffer;
    buffer = Buffer(3);
    return fs.read(process.stdin.fd, buffer, 0, 3, null, (function(_this) {
      return function(error, length) {
        if (error) {
          return _this._error = error;
        } else {
          return _this._writeAsync(buffer.slice(0, length).toString());
        }
      };
    })(this));
  }
});

module.exports = type.construct();

//# sourceMappingURL=map/Prompt.map
