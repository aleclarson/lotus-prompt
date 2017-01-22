var caret, log;

caret = (log = require("log")).caret;

module.exports = {
  "right": function() {
    if (caret.x !== this._labelLength + this._message.length) {
      caret.x += 1;
    }
  },
  "left": function() {
    if (caret.x !== this._labelLength) {
      caret.x -= 1;
    }
  },
  "return": function() {
    if (this._message.length > 0) {
      if (this._async) {
        this._cancelAsync();
      } else {
        this._close();
      }
    }
  },
  "tab": function() {},
  "tab+shift": function() {},
  "backspace": function() {
    var caretWasHiding, postCaret, x;
    if (caret.x <= this._labelLength) {
      return;
    }
    caretWasHiding = caret.isHidden;
    caret.isHidden = true;
    caret.x -= 1;
    log._printToChunk(" ", {
      hidden: true
    });
    caret.x -= 1;
    x = caret.x - this._labelLength;
    postCaret = this._message.slice(x + 1);
    this._message = this._message.slice(0, x);
    log.updateLine(this._message);
    if (postCaret.length) {
      this._message += postCaret;
      log(postCaret);
      log._printToChunk(" ", {
        hidden: true
      });
      log.updateLine(this._message);
      log.flush();
    }
    caret.x = x + this._labelLength;
    caret.isHidden = caretWasHiding;
  },
  "c+ctrl": function() {
    if (this._message.length === 0) {
      log.red("CTRL+C");
      log.moat(1);
      this.close();
    } else {
      log.clearLine();
      this._printLabel();
      this._message = "";
    }
  },
  "x+ctrl": function() {
    this.close();
    log.pushIndent(0);
    log.moat(1);
    log.red("CTRL+X");
    log.moat(1);
    log.popIndent();
    log.flush();
    return process.exit(0, "SIGTERM");
  },
  "a+ctrl": function() {
    return caret.x = this._labelLength;
  },
  "e+ctrl": function() {
    return caret.x = log.line.length;
  },
  "w+ctrl": function() {
    var a, b, caretWasHiding, x;
    caretWasHiding = caret.isHidden;
    caret.isHidden = true;
    a = this._message.slice(0, caret.x);
    if (a.length > 0) {
      x = 1 + a.replace(/\s+$/, "").lastIndexOf(" ");
      a = a.slice(0, x);
      b = this._message.slice(caret.x);
      log.clearLine();
      this._printLabel();
      log(this._message = a + b);
      log.flush();
      caret.x = x;
    }
    caret.isHidden = caretWasHiding;
  }
};

//# sourceMappingURL=map/KeyBindings.map
