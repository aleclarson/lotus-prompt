var Event, EventEmitter, Type, assertType, keyModifiers, keypress, type;

EventEmitter = require("events").EventEmitter;

assertType = require("assertType");

keypress = require("keypress");

Event = require("Event");

Type = require("Type");

keyModifiers = "ctrl meta shift".split(" ");

type = Type("KeyEmitter");

type.defineValues(function() {
  return {
    _didPressKey: Event(),
    _emitter: null
  };
});

type.initInstance(function() {
  var stream;
  stream = process.stdin;
  if (stream && stream.isTTY) {
    stream.setRawMode(true);
    this._emitter = new EventEmitter;
    this._emitter.on("keypress", this._keypress.bind(this));
    this._emitter.write = function(chunk) {
      return stream.write(chunk);
    };
    keypress(this._emitter);
  }
});

type.defineGetters({
  didPressKey: function() {
    return this._didPressKey.listenable;
  }
});

type.defineMethods({
  send: function(data) {
    assertType(data, String);
    return this._emitter.emit("data", data);
  },
  _keypress: function(char, key) {
    var command, modifier;
    command = key ? key.name : char;
    if (modifier = this._getModifier(key)) {
      command += "+" + modifier;
    }
    this._didPressKey.emit({
      char: char,
      key: key,
      command: command,
      modifier: modifier
    });
  },
  _getModifier: function(key) {
    var i, len, modifier;
    for (i = 0, len = keyModifiers.length; i < len; i++) {
      modifier = keyModifiers[i];
      if (key[modifier]) {
        return modifier;
      }
    }
    return null;
  }
});

module.exports = type.construct();

//# sourceMappingURL=map/KeyEmitter.map
