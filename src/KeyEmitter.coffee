
{EventEmitter} = require "events"

assertType = require "assertType"
Event = require "eve"
Type = require "Type"

keyModifiers = "ctrl meta shift".split " "

type = Type "KeyEmitter"

type.defineValues ->

  didPressKey: Event()

  _emitter: null

type.defineMethods

  send: (data) ->
    assertType data, String
    @_emitter.emit "data", data

  _keypress: (char, key) ->

    command = if key then key.name else char

    if modifier = @_getModifier key
      command += "+" + modifier

    @didPressKey.emit {char, key, command, modifier}
    return

  _getModifier: (key) ->
    for modifier in keyModifiers
      return modifier if key[modifier]
    return null

  _setupStream: (stream) ->
    return if @_emitter
    if stream and stream.isTTY
      stream.setRawMode yes
      keypress = require "keypress"
      keypress do =>
        @_emitter = emitter = new EventEmitter
        emitter.on "keypress", @_keypress.bind this
        emitter.write = (chunk) -> stream.write chunk
        return emitter
    return

module.exports = type.construct()
