
{caret} = log = require "log"

emptyFunction = require "emptyFunction"
stripAnsi = require "strip-ansi"
immediate = require "immediate"
Promise = require "Promise"
isType = require "isType"
Event = require "Event"
Type = require "Type"
fs = require "fs"

KeyBindings = require "./KeyBindings"
KeyEmitter = require "./KeyEmitter"

type = Type "Prompt"

type.defineValues ->

  didClose: Event()

  showCursorDuring: yes

  # TODO: Implement multi-line mode.
  # isMultiline: no

  # TODO: Implement tab completion.
  # tabComplete: -> []

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
    .start()

#
# Prototype
#

type.defineGetters

  isReading: -> @_reading

type.defineMethods

  sync: (options = {}) ->

    @_async = no
    @_setLabel options.label
    @_open()
    @_loopSync()
    @_close() if @_reading

    if options.bool
      if @_prevMessage is null
      then null
      else @_prevMessage is "y"
    else @_prevMessage

  async: (options) ->

    @_async = yes
    @_setLabel options.label
    @_open()

    # Wait for the first keypress.
    deferred = Promise.defer()
    immediate this, ->
      deferred.resolve()
      @_loopAsync()
    return deferred.promise

  close: ->
    @_message = null
    if @_async
    then @_cancelAsync()
    else @_close()

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

  _loopSync: ->
    buffer = Buffer 3
    length = fs.readSync process.stdin.fd, buffer, 0, 3
    KeyEmitter.send buffer.slice(0, length).toString()
    @_reading and @_loopSync()

  _close: ->

    unless @_reading
      throw Error "Prompt is not reading!"

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

#
# Async methods
#

  _writeAsync: (data) ->
    if @_reading
      KeyEmitter.send data
      @_loopAsync()
    return

  _cancelAsync: ->
    if @_reading
      deferred.resolve @_close()
    return

  _loopAsync: ->
    buffer = Buffer 3
    fs.read process.stdin.fd, buffer, 0, 3, null, (error, length) =>
      if error
      then @_error = error
      else @_writeAsync buffer.slice(0, length).toString()

module.exports = type.construct()
