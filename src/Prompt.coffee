
emptyFunction = require "emptyFunction"
stripAnsi = require "strip-ansi"
parseBool = require "parse-bool"
immediate = require "immediate"
Promise = require "Promise"
isType = require "isType"
Event = require "Event"
Type = require "Type"
log = require "log"
fs = require "fs"

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

  _caretWasHiding: no

  _line: null

  _indent: 0

  _message: ""

  _prevMessage: null

  _label: ""

  _labelLength: 0

  _labelPrinter: emptyFunction.thatReturnsFalse

  _keyListener: KeyEmitter
    .didPressKey @_keypress.bind this
    .start()

#
# Prototype
#

type.definePrototype

  isReading:
    get: -> @_reading

  _caret: require "./Caret"

#
# Prototype-related
#

type.defineGetters

  isReading: -> @_reading

type.definePrototype

  stdin:
    get: -> @_stdin
    set: (newValue, oldValue) ->
      return if newValue is oldValue
      if newValue and newValue.isTTY
        newValue.setRawMode yes
        @_stdin = newValue
        @_stream = new EventEmitter
        @_stream.write = (chunk) -> newValue.write chunk
        @_stream.on "keypress", @_keypress.bind this
        addKeyPress @_stream
      else if oldValue and oldValue.isTTY
        @_stream = null
        @_stdin = null
      return

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
    log.flush()

    @_caretWasHiding = @_caret.isHidden

    if @showCursorDuring
      @_caret.isHidden = no

    if @_caret.x < @_labelLength
      @_caret.x = @_labelLength

    return

  _close: ->

    unless @_reading
      throw Error "Prompt is not reading!"

    if @showCursorDuring
      @_caret.isHidden = @_caretWasHiding

    @_async = null
    @_reading = no

    # @_history.index = @_history.push @_message
    @_prevMessage = @_message
    @_message = ""

    @didClose.emit @_prevMessage
    return @_prevMessage

  _keypress: do ->
    bindings = require "./KeyBindings"
    return (event) ->
      action = bindings[event.command]
      if isType action, Function
      then action.call this
      else @_input event

  _input: (event) ->

    return unless event.char?
    return if event.modifier? and not /[a-z]/i.test event.char

    @_printing = yes
    log.pushIndent 0

    x = Math.max 0, @_caret.x - @_labelLength

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
      @_caret.x = log.line.length - stripAnsi(b).length

    log.popIndent()
    @_printing = no
    return

  _print: (chunk) ->
    log.pushIndent @_indent
    log._printToChunk chunk
    log.popIndent()
    return

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