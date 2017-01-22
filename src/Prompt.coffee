
{caret} = log = require "log"

emptyFunction = require "emptyFunction"
stripAnsi = require "strip-ansi"
parseBool = require "parse-bool"
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

  _indent: 0

  _message: ""

  _prevMessage: null

  _label: ""

  _labelLength: 0

  _labelPrinter: emptyFunction.thatReturnsFalse

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

    if options.parseBool
      return parseBool @_prevMessage

    return @_prevMessage

  async: (options) ->

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
    if @_reading
      KeyEmitter.send data
      @_loopAsync()
    return

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
    fs.read process.stdin.fd, buffer, 0, 3, null, (error, length) =>
      if error
      then @_error = error
      else @_writeAsync buffer.slice(0, length).toString()

  _setLabel: (label) ->

    if isType label, Function
      printLabel = label

    else if isType label, String
      printLabel = -> label

    if printLabel
      @_labelPrinter = printLabel
      @didClose 1, =>
        @_labelPrinter = emptyFunction.thatReturnsFalse
      .start()

    return

  _loopSync: ->
    buffer = Buffer 3
    length = fs.readSync process.stdin.fd, buffer, 0, 3
    KeyEmitter.send buffer.slice(0, length).toString()
    return @_loopSync() if @_reading

  _open: ->

    # Silently fail if already reading.
    # To override, close the prompt and then call this method.
    return if @_reading

    @_reading = yes
    @_indent = log.indent

    log.moat 1
    @_printLabel()

    @_caretWasHiding = caret.isHidden

    if @showCursorDuring
      caret.isHidden = no

    if caret.x < @_labelLength
      caret.x = @_labelLength

    return

  _close: ->

    unless @_reading
      throw Error "Prompt is not reading!"

    if @showCursorDuring
      caret.isHidden = @_caretWasHiding

    @_async = null
    @_reading = no

    # @_history.index = @_history.push @_message
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
      @_print event.char

    # FIXME: Ansi is not supported when slicing!
    else
      a = @_message.slice 0, x
      b = @_message.slice x
      @_message = a + event.char + b
      log.line.contents = @_label + a
      log.line.length = @_labelLength + stripAnsi(a).length

      @_print event.char + b
      caret.x = log.line.length - stripAnsi(b).length

    log.popIndent()
    @_printing = no
    return

  _print: (chunk) ->
    log.pushIndent @_indent
    log._printToChunk chunk
    log.popIndent()
    log.flush()
    return

  _printLabel: ->
    @_printing = yes
    log.moat 0
    log.pushIndent @_indent
    if @_labelPrinter() isnt no
      @_label = log.line.contents
      @_labelLength = log.line.length
    else
      log._printChunk {indent: yes}
      @_label = log._indent
      @_labelLength = log.indent
    log.popIndent()
    log.flush()
    @_printing = no

module.exports = type.construct()
