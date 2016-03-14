
require "lotus-require"

{ isType, assertType, assert } = require "type-utils"
{ EventEmitter } = require "events"
{ log, cursor } = require "lotus-log"
{ async } = require "io"

addKeyPress = require "keypress"
stripAnsi = require "strip-ansi"
parseBool = require "parse-bool"
Factory = require "factory"
FS = require "fs"

BindingMap = require "./bindings"

modifiers = ["ctrl", "meta", "shift"]

# TODO: Enable prompt history.
# history = log.History()
# history.file = Path.resolve __dirname + "/../../.prompt_history"
# history.index = history.cache.length

module.exports = Factory "Prompt",

  singleton: yes

  kind: EventEmitter

  customValues:

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

    inputMode:
      value: "prompt"
      willSet: ->
        assert not @_reading, "Cannot set 'inputMode' while reading."

    isReading: get: ->
      @_reading

    _message:
      value: ""
      didSet: (message) ->
        assertType message, [ String, Void ]

  initValues: ->

    showCursorDuring: yes

    # TODO: Implement multi-line mode.
    # isMultiline: no

    # TODO: Implement tab completion.
    # tabComplete: -> []

    _reading: no

    _printing: no

    _async: null

    _prevMessage: null

    _stream: null

    _cursorWasHidden: no

    _line: null

    _indent: 0

    _label: ""

    _labelLength: 0

    _labelPrinter: -> no

  init: ->
    @stdin = process.stdin

  sync: (options) ->
    @_readSync options

  async: (options) ->
    @_readAsync options

  _readAsync: (options) ->

    hasLabel = isType options.label, Function

    if hasLabel
      @_labelPrinter = options.label

    deferred = async.defer()

    @_async = yes

    @_open()

    nextTick = async.defer()

    async.timeout nextTick.promise, 1000

    .fail -> deferred.reject Error "Asynchronous prompt failed unexpectedly. Try using `prompt.sync()` instead."

    # Wait for the first keypress.
    async.nextTick =>
      nextTick.resolve()
      @_loopAsync()

    deferred.promise

  _writeAsync: (data) ->

    return unless @_reading

    # Notify the keypress detector.
    @_stream.emit "data", data

    # Wait for the next keypress.
    @_loopAsync()

  _cancelAsync: ->

    return unless @_reading

    result = @_close()

    if options.parseBool
      result = parseBool result

    if hasLabel
      @_labelPrinter = -> no

    deferred.resolve result

    yes

  _loopAsync: ->
    buffer = Buffer 3
    FS.read @stdin.fd, buffer, 0, 3, null, (error, length) =>
      throw error if error?
      @_writeAsync? buffer.slice(0, length).toString()

  _readSync: (options = {}) ->

    hasLabel = isType options.label, Function

    if hasLabel
      @_labelPrinter = options.label

    @_async = no

    @_open()

    @_loopSync()

    result = @_close()

    if options.parseBool
      result = parseBool result

    if hasLabel
      @_labelPrinter = -> no

    result

  _loopSync: ->
    buffer = Buffer 3
    length = FS.readSync @stdin.fd, buffer, 0, 3
    @_stream.emit "data", buffer.slice(0, length).toString()
    return @_loopSync() if @_reading
    log "" # Prevent stalling.

  _open: ->

    @_close()

    @_reading = yes
    @_indent = log.indent

    log.moat 1
    @_printLabel()

    @_cursorWasHidden = cursor.isHidden

    if @showCursorDuring
      cursor.isHidden = no

    if cursor.x < @_labelLength
      cursor.x = @_labelLength

    return

  _close: ->

    if @_reading

      if @showCursorDuring
        cursor.isHidden = @_cursorWasHidden

      @_reading = no
      @_async = null

      @_prevMessage = @_message
      @_message = ""

      # @_history.index = @_history.push @_prevMessage

    @_prevMessage

  _input: (char) ->

    return unless char?

    @_printing = yes

    log.pushIndent 0

    x = cursor.x - @_labelLength

    throw Error "'x' should never be under zero." unless x >= 0

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
      cursor.x = log.line.length - stripAnsi(b).length

    log.popIndent()

    @_printing = no

    return

  _keypress: (char, key) ->

    return log "" unless @_reading

    hasModifier = no

    if key?
      command = key.name
      for modifier in modifiers
        if key[modifier] is yes
          hasModifier = yes
          command += "+" + modifier
    else
      command = char

    @emit "keypress", { command, key, char }

    action = BindingMap[command]

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

# hooker.hook log, "_printChunk", pre: ({ message }) ->
#
#   # Only rewrite the prompt's line during asynchronous reading.
#   return if !prompt._async?
#
#   # Ignore printing by the prompt itself.
#   return if prompt._printing
#
#   # Cache the contents of the prompt's line.
#   prompt._line =
#     contents: @line.contents
#     length: @line.length
#     x: cursor.x
#
#   if prompt._line.contents isnt prompt.label + prompt._message
#     throw Error "Line ##{@line.index} is not the prompt's line..."
#
#   log.clearLine()
#
# log.on "chunk", ->
#   return unless (line = prompt._line)?
#   prompt._line = null
#   log.line.length = line.length
#   log.line.contents = line.contents
#   prompt._printing = yes
#   log line.contents
#   cursor.left line.length - line.x
#   prompt._printing = no
