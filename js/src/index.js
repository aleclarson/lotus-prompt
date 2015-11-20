var EventEmitter, FS, async, color, cursor, define, history, hooker, isType, log, modifiers, parseBool, prompt, ref, repeatString, resolve, stripAnsi;

require("lotus-require");

FS = require("fs");

hooker = require("hooker");

define = require("define");

parseBool = require("parse-bool");

stripAnsi = require("strip-ansi");

repeatString = require("repeat-string");

ref = require("lotus-log"), log = ref.log, cursor = ref.cursor, color = ref.color;

EventEmitter = require("events").EventEmitter;

isType = require("type-utils").isType;

resolve = require("path").resolve;

async = require("io").async;

modifiers = ["ctrl", "meta", "shift"];

history = log.History();

history.file = resolve(__dirname + "/../../.prompt_history");

history.index = history.cache.length;

prompt = function(options) {
  return prompt._readAsync(options);
};

define(prompt, function() {
  this.options = {
    configurable: false,
    enumerable: false
  };
  this({
    _isReading: false,
    _isPrinting: false,
    _isAsync: null,
    _history: history,
    _message: {
      value: "",
      didSet: function(newValue) {
        if (!(newValue === null || isType(newValue, String))) {
          throw TypeError("'message' must be a String or null");
        }
      }
    },
    _prevMessage: null,
    _stream: null,
    _cursorWasHidden: false,
    _line: null,
    _label: "",
    _labelLength: 0,
    _labelPrinter: function() {
      return false;
    },
    _readAsync: function(options) {
      var deferred, hasLabel, nextTick;
      hasLabel = isType(options.label, Function);
      if (hasLabel) {
        this._labelPrinter = options.label;
      }
      deferred = async.defer();
      this._isAsync = true;
      this._open();
      this._writeAsync = (function(_this) {
        return function(data) {
          _this._stream.emit("data", data);
          if (_this._isReading) {
            return _this._loopAsync();
          } else {
            return typeof _this._cancelAsync === "function" ? _this._cancelAsync() : void 0;
          }
        };
      })(this);
      this._cancelAsync = (function(_this) {
        return function() {
          var result;
          _this._writeAsync = null;
          _this._cancelAsync = null;
          result = _this._close();
          if (options.parseBool) {
            result = parseBool(result);
          }
          if (hasLabel) {
            _this._labelPrinter = function() {
              return false;
            };
          }
          deferred.resolve(result);
          return true;
        };
      })(this);
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
    _writeAsync: null,
    _cancelAsync: null,
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
      this._isAsync = false;
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
      if (this._isReading) {
        return this._loopSync();
      }
      return log("");
    },
    _open: function() {
      this._close();
      this._isReading = true;
      this._isPrinting = true;
      this._printLabel();
      this._isPrinting = false;
      this._cursorWasHidden = cursor.isHidden;
      if (this.showCursorDuring) {
        cursor.isHidden = false;
      }
      if (cursor.x < this._labelLength) {
        cursor.x = this._labelLength;
      }
    },
    _close: function() {
      if (this._isReading) {
        if (this.showCursorDuring) {
          cursor.isHidden = this._cursorWasHidden;
        }
        this._isReading = false;
        this._isAsync = null;
        this._prevMessage = this._message;
        this._message = "";
        this._history.index = this._history.push(this._prevMessage);
      }
      return this._prevMessage;
    },
    _input: function(char) {
      var a, b, x;
      if (char == null) {
        return;
      }
      this._isPrinting = true;
      log.pushIndent(0);
      x = cursor.x - this._labelLength;
      if (!(x >= 0)) {
        throw Error("'x' should never be under zero.");
      }
      if (x === this._message.length) {
        this._message += char;
        log._printToChunk(char);
      } else {
        a = this._message.slice(0, x);
        b = this._message.slice(x);
        this._message = a + char + b;
        log.line.contents = this._label + a;
        log.line.length = this._labelLength + stripAnsi(a).length;
        log._printToChunk(char + b);
        cursor.x = log.line.length - stripAnsi(b).length;
      }
      log.popIndent();
      this._isPrinting = false;
    },
    _keypress: function(char, key) {
      var action, command, hasModifier, i, len, modifier;
      if (!this._isReading) {
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
      action = this.controls[command];
      if (action instanceof Function) {
        return action.call(this);
      }
      if (!hasModifier || /[a-z]/i.test(char)) {
        return this._input(char);
      }
    },
    _printLabel: function() {
      log.moat(0);
      if (this._labelPrinter() !== false) {
        this._label = log.line.contents;
        return this._labelLength = log.line.length;
      } else {
        this._label = "";
        return this._labelLength = 0;
      }
    }
  });
  this.enumerable = true;
  this({
    inputMode: {
      value: "prompt",
      willSet: function() {
        if (this.isReading) {
          throw Error("Cannot set 'inputMode' while the prompt is reading.");
        }
      }
    },
    showCursorDuring: true,
    stdin: {
      assign: process.stdin,
      didSet: function(newValue, oldValue) {
        if (newValue === oldValue) {
          return;
        }
        if ((newValue != null) && newValue.isTTY) {
          this._stream = new EventEmitter;
          this._stream.encoding = "utf8";
          this._stream.write = function(chunk) {
            return newValue.write(chunk);
          };
          this._stream.on("keypress", (function(_this) {
            return function(ch, key) {
              return _this._keypress(ch, key);
            };
          })(this));
          newValue.setRawMode(true);
          return require("keypress")(this._stream);
        } else if ((oldValue != null) && oldValue.isTTY) {
          return this._stream = null;
        }
      }
    },
    controls: {
      value: {
        "up": function() {
          var message;
          if (this._history.index > 0) {
            log.clearLine();
            this._printLabel();
            message = this._history.cache[--this._history.index];
            if (typeof message !== "string") {
              if (typeof log._repl === "function") {
                log._repl({
                  message: message,
                  history: this._history
                });
              }
            }
            return log._printToChunk(this._message = message);
          }
        },
        "down": function() {
          var cursorWasHidden;
          if (this._history.index < (this._history.count - 1)) {
            cursorWasHidden = cursor.isHidden;
            cursor.isHidden = true;
            log.clearLine();
            this._printLabel();
            log._printToChunk(this._message = this._history.cache[++this._history.index]);
            return cursor.isHidden = cursorWasHidden;
          } else if (this._history.index === (this._history.count - 1) && this._message.length > 0) {
            cursorWasHidden = cursor.isHidden;
            cursor.isHidden = true;
            log.clearLine();
            this._printLabel();
            this._history.index++;
            this._message = "";
            return cursor.isHidden = cursorWasHidden;
          }
        },
        "right": function() {
          if (cursor.x === this._labelLength + this._message.length) {
            return;
          }
          return cursor.x++;
        },
        "left": function() {
          if (cursor.x === this._labelLength) {
            return;
          }
          return cursor.x--;
        },
        "return": function() {
          if (this._message.length === 0) {
            return;
          }
          if (this._isAsync) {
            return typeof this._cancelAsync === "function" ? this._cancelAsync() : void 0;
          } else {
            return this._close();
          }
        },
        "tab": function() {},
        "tab+shift": function() {},
        "backspace": function() {
          var cursorWasHidden, halfOne, halfTwo, x;
          if (this._message.length === 0) {
            return;
          }
          x = cursor.x - this._labelLength;
          if (x <= 0) {
            return;
          }
          cursorWasHidden = cursor.isHidden;
          cursor.isHidden = true;
          log.clearLine();
          this._printLabel();
          halfOne = this._message.slice(0, x - 1);
          halfTwo = this._message.slice(x);
          log._printToChunk(this._message = halfOne + halfTwo);
          cursor.x -= halfTwo.length;
          return cursor.isHidden = cursorWasHidden;
        },
        "c+ctrl": function() {
          var length;
          length = this._message.length;
          if (length === 0) {
            log.red("CTRL+C");
            log.moat(1);
            this._message = null;
            if (this._isAsync) {
              return typeof this._cancelAsync === "function" ? this._cancelAsync() : void 0;
            } else {
              return this._close();
            }
          } else {
            log.clearLine();
            this._printLabel();
            return this._message = "";
          }
        },
        "x+ctrl": function() {
          log.pushIndent(0);
          log.moat(1);
          log.red("CTRL+X");
          log.moat(1);
          log.popIndent();
          return process.exit(0, "SIGTERM");
        },
        "a+ctrl": function() {
          return cursor.x = this._labelLength;
        },
        "e+ctrl": function() {
          return cursor.x = log.line.length;
        },
        "w+ctrl": function() {
          var a, b, cursorWasHidden, x;
          cursorWasHidden = cursor.isHidden;
          cursor.isHidden = true;
          a = this._message.slice(0, cursor.x);
          if (a.length > 0) {
            x = 1 + a.replace(/\s+$/, "").lastIndexOf(" ");
            a = a.slice(0, x);
            b = this._message.slice(cursor.x);
            this._message = a + b;
            log.clearLine();
            this._printLabel();
            log._printToChunk(this._message);
            cursor.x = this._labelLength + x;
          }
          return cursor.isHidden = cursorWasHidden;
        }
      }
    }
  });
  this.writable = false;
  this.mirror(new EventEmitter);
  return this({
    isReading: {
      get: function() {
        return this._isReading;
      }
    },
    sync: function(options) {
      return this._readSync(options);
    }
  });
});

define(log, function() {
  this.options = {
    configurable: false,
    writable: false
  };
  return this({
    prompt: prompt
  });
});

//# sourceMappingURL=../../map/src/index.map
