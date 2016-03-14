var cursor, log, ref;

ref = require("lotus-log"), log = ref.log, cursor = ref.cursor;

module.exports = {
  "up": function() {},
  "down": function() {},
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
    if (this._async) {
      return this._cancelAsync();
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
    this._print(this._message = halfOne + halfTwo);
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
      this._print(this._message);
      cursor.x = this._labelLength + x;
    }
    return cursor.isHidden = cursorWasHidden;
  }
};

//# sourceMappingURL=../../map/src/bindings.map
