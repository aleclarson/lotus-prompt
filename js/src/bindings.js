var log;

log = require("log");

module.exports = {
  "up": function() {},
  "down": function() {},
  "right": function() {
    if (log.cursor.x === this._labelLength + this._message.length) {
      return;
    }
    return log.cursor.x++;
  },
  "left": function() {
    if (log.cursor.x === this._labelLength) {
      return;
    }
    return log.cursor.x--;
  },
  "return": function() {
    if (this._message.length === 0) {
      return;
    }
    if (this._async) {
      return this._cancelAsync();
    } else {
      return this._close();
    }
  },
  "tab": function() {},
  "tab+shift": function() {},
  "backspace": function() {
    var cursorWasHidden, messageAfter, messageBefore, x;
    x = log.cursor.x - this._labelLength;
    if (x <= 0) {
      return;
    }
    cursorWasHidden = log.cursor.isHidden;
    log.cursor.isHidden = true;
    log.cursor.x -= 1;
    messageBefore = this._message.slice(0, x - 1);
    messageAfter = this._message.slice(x);
    if (messageAfter.length) {
      this._print(messageAfter + " ");
      this._message = messageBefore + messageAfter;
      log.cursor.x -= messageAfter.length + 1;
    } else {
      this._print(" ");
      log.cursor.x -= 1;
      this._message = messageBefore;
    }
    log.cursor.isHidden = cursorWasHidden;
  },
  "c+ctrl": function() {
    var length;
    length = this._message.length;
    if (length === 0) {
      log.red("CTRL+C");
      log.moat(1);
      this._message = null;
      if (this._async) {
        return this._cancelAsync();
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
    return log.cursor.x = this._labelLength;
  },
  "e+ctrl": function() {
    return log.cursor.x = log.line.length;
  },
  "w+ctrl": function() {
    var a, b, cursorWasHidden, x;
    cursorWasHidden = log.cursor.isHidden;
    log.cursor.isHidden = true;
    a = this._message.slice(0, log.cursor.x);
    if (a.length > 0) {
      x = 1 + a.replace(/\s+$/, "").lastIndexOf(" ");
      a = a.slice(0, x);
      b = this._message.slice(log.cursor.x);
      this._message = a + b;
      log.clearLine();
      this._printLabel();
      this._print(this._message);
      log.cursor.x = this._labelLength + x;
    }
    return log.cursor.isHidden = cursorWasHidden;
  }
};

//# sourceMappingURL=../../map/src/bindings.map
