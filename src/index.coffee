
{ EventEmitter } = require "events"

emptyFunction = require "emptyFunction"
addKeyPress = require "keypress"
assertType = require "assertType"
stripAnsi = require "strip-ansi"
parseBool = require "parse-bool"
immediate = require "immediate"
Promise = require "Promise"
isType = require "isType"
assert = require "assert"
Event = require "event"
Null = require "Null"
Type = require "Type"
log = require "log"
FS = require "fs"

BINDINGS = require "./bindings"
MODIFIERS = [ "ctrl", "meta", "shift" ]

# TODO: Enable prompt history.
# history = log.History()
# history.file = Path.resolve __dirname + "/../../.prompt_history"
# history.index = history.cache.length

type = Type "Prompt"

type.defineProperties

  stdin:
    value: null
    didSet: (newValue, oldValue) ->
      return if newValue is oldValue
      if newValue? and newValue.isTTY
        newValue.setRawMode yes
        @_stream = new EventEmitter
        @_stream.write = (chunk) -> newValue.write chunk
        @_stream.on "keypress", @_keypress.bind this
        addKeyPress @_stream
      else if oldValue? and oldValue.isTTY
        @_stream = null

  isReading: get: ->
    @_reading

  _message:
    value: ""
    didSet: (message) ->
      assertType message, [ String, Null ]

type.defineValues

  didPressKey: -> Event()

  didClose: -> Event { maxRecursion: Infinity }

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

  _prevMessage: null

  _stream: null

  _cursorWasHidden: no

  _line: null

  _indent: 0

  _label: ""

  _labelLength: 0

  _labelPrinter: -> emptyFunction.thatReturnsFalse

  _mark: ->
    TimeMarker = require "TimeMarker"
    TimeMarker()

type.initInstance ->
  @stdin = process.stdin

type.defineMethods

  sync: (options) ->
    @_readSync options

  async: (options) ->
    @_readAsync options

  _readAsync: (options) ->

    @_async = yes

    @_setLabel options.label

    deferred = Promise.defer()

    @_open()

    # Wait for the first keypress.
    immediate =>
      deferred.resolve()
      @_loopAsync()

    return deferred.promise

  _writeAsync: (data) ->

    return if not @_reading

    # Notify the keypress detector.
    @_stream.emit "data", data

    # Wait for the next keypress.
    @_loopAsync()

  _cancelAsync: ->

    return no if not @_reading

    result = @_close()

    # TODO: Support 'options.parseBool' in async mode.
    # if options.parseBool
    #   result = parseBool result

    deferred.resolve result

    return yes

  _loopAsync: ->
    buffer = Buffer 3
    FS.read @stdin.fd, buffer, 0, 3, null, (error, length) =>
      throw error if error?
      @_writeAsync? buffer.slice(0, length).toString()

  _readSync: (options = {}) ->

    @_async = no

    @_setLabel options.label

    @_open()

    @_loopSync()

    @_close() if @_reading

    if options.parseBool
      return parseBool @_prevMessage

    return @_prevMessage

  _setLabel: (label) ->

    if isType label, Function
      printLabel = label

    else if isType label, String
      printLabel = -> label

    if printLabel
      @_labelPrinter = printLabel
      @didClose.once => @_labelPrinter = emptyFunction.thatReturnsFalse
    return

  _loopSync: ->
    buffer = Buffer 3
    length = FS.readSync @stdin.fd, buffer, 0, 3
    @_stream.emit "data", buffer.slice(0, length).toString()
    return @_loopSync() if @_reading
    # log "" # TODO: Does this actually prevent stalling?

  _open: ->

    # Silently fail if already reading.
    # To override, close the prompt and then call this method.
    return if @_reading

    @_reading = yes
    @_indent = log.indent

    log.moat 1
    @_printLabel()

    @_cursorWasHidden = log.cursor.isHidden

    if @showCursorDuring
      log.cursor.isHidden = no

    if log.cursor.x < @_labelLength
      log.cursor.x = @_labelLength

    return

  _close: ->

    assert @_reading, "Prompt is not reading!"

    if @showCursorDuring
      log.cursor.isHidden = @_cursorWasHidden

    @_async = null
    @_reading = no

    # @_history.index = @_history.push @_message
    @_prevMessage = @_message
    @_message = ""

    @didClose.emit @_prevMessage
    return @_prevMessage

  _input: (char) ->

    return if not char?

    @_printing = yes

    log.pushIndent 0

    x = Math.max 0, log.cursor.x - @_labelLength

    if x is @_message.length
      @_message += char
      @_print char

    # FIXME: Ansi is not supported when slicing!
    else
      a = @_message.slice 0, x
      b = @_message.slice x
      @_message = a + char + b
      log.line.contents = @_label + a
      log.line.length = @_labelLength + stripAnsi(a).length
      @_print char + b
      log.cursor.x = log.line.length - stripAnsi(b).length

    log.popIndent()

    @_printing = no

    return

  _keypress: (char, key) ->

    return if not @_reading

    hasModifier = no

    if key?
      command = key.name
      for modifier in MODIFIERS
        if key[modifier] is yes
          hasModifier = yes
          command += "+" + modifier
    else
      command = char

    @didPressKey.emit { command, key, char }

    action = BINDINGS[command]

    return action.call this if action instanceof Function

    @_input char if !hasModifier or /[a-z]/i.test char

  _print: (chunk) ->
    @_printing = yes
    log.pushIndent @_indent
    log._printToChunk chunk
    log.popIndent()
    @_printing = no

  _printLabel: ->
    @_printing = yes
    log.moat 0
    log.pushIndent @_indent
    if @_labelPrinter() isnt no
      @_label = log.line.contents
      @_labelLength = log.line.length
    else
      log._printChunk { indent: yes }
      @_label = log._indent
      @_labelLength = log.indent
    log.popIndent()
    @_printing = no

module.exports = type.construct()
