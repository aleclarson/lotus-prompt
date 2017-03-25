
{caret} = log = require "log"

emptyFunction = require "emptyFunction"
stripAnsi = require "strip-ansi"
readline = require "readline"
Promise = require "Promise"
isType = require "isType"
Event = require "eve"
Type = require "Type"
fs = require "fs"

KeyBindings = require "./KeyBindings"
KeyEmitter = require "./KeyEmitter"

canSync = process.versions.node < '5'

type = Type "Prompt"

type.defineValues ->

  didClose: Event()

  showCursorDuring: yes

  # TODO: Implement multi-line mode.
  # isMultiline: no

  # TODO: Implement tab completion.
  # tabComplete: -> []

  _stream: process.stdin

  # The prompt is reading input.
  _reading: no

  # The prompt is printing output.
  _printing: no

  _async: null

  _error: null

  _line: null

  _message: ""

  _prevMessage: null

  _label: ""

  _labelLength: 0

  _printLabel: emptyFunction

  _caretWasHiding: no

  _keyListener: KeyEmitter
    .didPressKey (event) =>
      action = KeyBindings[event.command]
      if isType action, Function
      then action.call this
      else @_input event

#
# Prototype
#

type.defineGetters

  isReading: -> @_reading

type.defineMethods

  sync: (options = {}) ->

    unless canSync
      throw Error "'prompt.sync' only works with Node 4 or under!"

    KeyEmitter._setupStream @_stream

    @_setLabel options.label
    @_open()
    @_loopSync()
    @_close() if @_reading

    if options.bool
      if @_prevMessage is null
      then null
      else @_prevMessage is "y"
    else @_prevMessage

  async: (options = {}) ->

    @_async = Promise.defer()
    readline.emitKeypressEvents @_stream

    @_setLabel options.label
    @_open()

    @_stream.setRawMode true
    @_stream.on "keypress", listener =
      (char, key) -> KeyEmitter._keypress char, key

    @_async.listener = listener
    return @_async.promise

  close: (message = null) ->

    unless @_reading
      throw Error "Must be reading!"

    @_message = message

    if @_async
      @_stream.removeListener "keypress", @_async.listener
      @_async.resolve @_close()
      return

    @_close()
    return

#
# Internal methods
#

  _setLabel: (label = "") ->

    if isType label, String
      label = log._indent + label

    @_printLabel =
      if isType label, Function
      then label
      else -> log.white label
    return

  _open: ->

    # Silently fail if already reading.
    # To override, close the prompt and then call this method.
    return if @_reading
    @_reading = yes

    log.pushIndent 0
    @_printLabel()
    log.popIndent()
    log.flush()

    @_label = log.line.contents
    @_labelLength = log.line.length

    @_caretWasHiding = caret.isHidden
    caret.isHidden = no if @showCursorDuring
    caret.x = @_labelLength if caret.x < @_labelLength
    return

  # TODO: Fix this method to support Node 5+
  _loopSync: ->
    buffer = Buffer 3
    length = fs.readSync @_stream.fd, buffer, 0, 3
    KeyEmitter.send buffer.slice(0, length).toString()
    @_reading and @_loopSync()

  _close: ->

    if @showCursorDuring
      caret.isHidden = @_caretWasHiding

    @_async = null
    @_reading = no

    @_prevMessage = @_message
    @_message = ""

    @didClose.emit @_prevMessage
    return @_prevMessage

  _input: (event) ->

    return unless event.char?
    return if event.modifier? and not /[a-z]/i.test event.char

    @_printing = yes
    log.pushIndent 0

    x = Math.max 0, caret.x - @_labelLength

    if x is @_message.length
      @_message += event.char
      log event.char

    # FIXME: Ansi is not supported when slicing!
    else
      a = @_message.slice 0, x
      b = @_message.slice x
      log.line.contents = @_label + a
      log.line.length = @_labelLength + stripAnsi(a).length
      @_message = a + event.char + b
      log event.char + b
      caret.x = log.line.length - stripAnsi(b).length

    log.popIndent()
    log.flush()
    @_printing = no
    return

module.exports = type.construct()
