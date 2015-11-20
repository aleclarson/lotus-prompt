
require "lotus-require"

FS = require "fs"
hooker = require "hooker"
define = require "define"
parseBool = require "parse-bool"
stripAnsi = require "strip-ansi"
repeatString = require "repeat-string"
{ log, cursor, color } = require "lotus-log"
{ EventEmitter } = require "events"
{ isType } = require "type-utils"
{ resolve } = require "path"
{ async } = require "io"

modifiers = ["ctrl", "meta", "shift"]

history = log.History()
history.file = resolve __dirname + "/../../.prompt_history"
history.index = history.cache.length

prompt = (options) ->
  prompt._readAsync options

define prompt, ->

  @options =
    configurable: no
    enumerable: no

  @
    _isReading: no

    _isPrinting: no

    _isAsync: null

    _history: history

    _message:
      value: ""
      didSet: (newValue) ->
        unless newValue is null or isType newValue, String
          throw TypeError "'message' must be a String or null"

    _prevMessage: null

    _stream: null

    _cursorWasHidden: no

    _line: null

    _label: ""

    _labelLength: 0

    _labelPrinter: -> no

    _readAsync: (options) ->

      hasLabel = isType options.label, Function

      if hasLabel
        @_labelPrinter = options.label

      deferred = async.defer()

      @_isAsync = yes

      @_open()

      # Handles each keypress.
      @_writeAsync = (data) =>

        # Notify the keypress detector.
        @_stream.emit "data", data

        # Wait for the next keypress.
        if @_isReading then @_loopAsync()

        # Stop reading.
        else @_cancelAsync?()

      # Handles cancellation.
      @_cancelAsync = =>

        @_writeAsync = null

        @_cancelAsync = null

        result = @_close()

        if options.parseBool
          result = parseBool result

        if hasLabel
          @_labelPrinter = -> no

        deferred.resolve result

        yes

      nextTick = async.defer()

      async.timeout nextTick.promise, 1000

      .fail -> deferred.reject Error "Asynchronous prompt failed unexpectedly. Try using `prompt.sync()` instead."

      # Wait for the first keypress.
      async.nextTick =>
        nextTick.resolve()
        @_loopAsync()

      deferred.promise

    _writeAsync: null

    _cancelAsync: null

    _loopAsync: ->
      buffer = Buffer 3
      FS.read @stdin.fd, buffer, 0, 3, null, (error, length) =>
        throw error if error?
        @_writeAsync? buffer.slice(0, length).toString()

    _readSync: (options = {}) ->

      hasLabel = isType options.label, Function

      if hasLabel
        @_labelPrinter = options.label

      @_isAsync = no

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
      return @_loopSync() if @_isReading
      log "" # Prevent stalling.

    _open: ->

      @_close()

      @_isReading = yes

      @_isPrinting = yes

      @_printLabel()

      @_isPrinting = no

      @_cursorWasHidden = cursor.isHidden

      if @showCursorDuring
        cursor.isHidden = no

      if cursor.x < @_labelLength
        cursor.x = @_labelLength

      return

    _close: ->

      if @_isReading

        if @showCursorDuring then cursor.isHidden = @_cursorWasHidden

        @_isReading = no
        @_isAsync = null

        @_prevMessage = @_message
        @_message = ""

        @_history.index = @_history.push @_prevMessage

      @_prevMessage

    _input: (char) ->

      return unless char?

      @_isPrinting = yes

      log.pushIndent 0

      x = cursor.x - @_labelLength

      throw Error "'x' should never be under zero." unless x >= 0

      if x is @_message.length
        @_message += char
        log._printToChunk char

      # FIXME: Ansi is not supported when slicing!
      else
        a = @_message.slice 0, x
        b = @_message.slice x
        @_message = a + char + b
        log.line.contents = @_label + a
        log.line.length = @_labelLength + stripAnsi(a).length
        log._printToChunk char + b
        cursor.x = log.line.length - stripAnsi(b).length

      log.popIndent()

      @_isPrinting = no

      return

    _keypress: (char, key) ->

      return log "" unless @_isReading

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

      action = @controls[command]

      return action.call this if action instanceof Function

      @_input char if !hasModifier or /[a-z]/i.test char

    _printLabel: ->

      log.moat 0

      if @_labelPrinter() isnt no
        @_label = log.line.contents
        @_labelLength = log.line.length

      else
        @_label = ""
        @_labelLength = 0

  @enumerable = yes

  @
    inputMode:
      value: "prompt"
      willSet: ->
        if @isReading
          throw Error "Cannot set 'inputMode' while the prompt is reading."

    showCursorDuring: yes

    # TODO: Implement multi-line mode.
    # isMultiline: no

    # TODO: Implement tab completion.
    # tabComplete: -> []

    stdin:
      assign: process.stdin
      didSet: (newValue, oldValue) ->
        return if newValue is oldValue
        if newValue? and newValue.isTTY
          @_stream = new EventEmitter
          @_stream.encoding = "utf8"
          @_stream.write = (chunk) -> newValue.write chunk
          @_stream.on "keypress", (ch, key) => @_keypress ch, key
          newValue.setRawMode yes
          require("keypress") @_stream
        else if oldValue? and oldValue.isTTY
          @_stream = null

    controls: value:

      "up": ->

        if @_history.index > 0
          log.clearLine()
          @_printLabel()
          message = @_history.cache[--@_history.index]
          log._repl? { message, history: @_history } unless typeof message is "string"
          log._printToChunk @_message = message

      "down": ->

        if @_history.index < ( @_history.count - 1 )
          cursorWasHidden = cursor.isHidden
          cursor.isHidden = yes
          log.clearLine()
          @_printLabel()
          log._printToChunk @_message = @_history.cache[++@_history.index]
          cursor.isHidden = cursorWasHidden

        else if @_history.index is ( @_history.count - 1 ) and @_message.length > 0
          cursorWasHidden = cursor.isHidden
          cursor.isHidden = yes
          log.clearLine()
          @_printLabel()
          @_history.index++
          @_message = ""
          cursor.isHidden = cursorWasHidden

      "right": ->
        return if cursor.x is @_labelLength + @_message.length
        cursor.x++

      "left": ->
        return if cursor.x is @_labelLength
        cursor.x--

      "return": ->
        return if @_message.length is 0
        if @_isAsync then @_cancelAsync?()
        else @_close()

      "tab": ->
        # TODO: Implement tab completion.

      "tab+shift": ->
        # no-op

      "backspace": ->
        # FIXME: This shouldn't reprint the entire line.

        return if @_message.length is 0

        x = cursor.x - @_labelLength

        return if x <= 0

        cursorWasHidden = cursor.isHidden
        cursor.isHidden = yes
        log.clearLine()
        @_printLabel()

        halfOne = @_message.slice 0, x - 1
        halfTwo = @_message.slice x
        log._printToChunk @_message = halfOne + halfTwo

        cursor.x -= halfTwo.length
        cursor.isHidden = cursorWasHidden

      "c+ctrl": ->
        { length } = @_message
        if length is 0
          log.red "CTRL+C"
          log.moat 1
          @_message = null
          if @_isAsync then @_cancelAsync?()
          else @_close()
        else
          log.clearLine()
          @_printLabel()
          @_message = ""

      "x+ctrl": ->
        log.pushIndent 0
        log.moat 1
        log.red "CTRL+X"
        log.moat 1
        log.popIndent()
        process.exit 0, "SIGTERM"

      # Move cursor to beginning of prompt.
      "a+ctrl": ->
        cursor.x = @_labelLength

      # Move cursor to end of prompt.
      "e+ctrl": ->
        cursor.x = log.line.length

      # Delete last word before the cursor.
      "w+ctrl": ->
        cursorWasHidden = cursor.isHidden
        cursor.isHidden = yes
        # BUG: Ansi is not supported when slicing!
        a = @_message.slice 0, cursor.x
        if a.length > 0
          x = 1 + a.replace(/\s+$/, "").lastIndexOf " "
          a = a.slice 0, x
          b = @_message.slice cursor.x
          @_message = a + b
          log.clearLine()
          @_printLabel()
          log._printToChunk @_message
          cursor.x = @_labelLength + x
        cursor.isHidden = cursorWasHidden

  @writable = no

  @mirror new EventEmitter

  @
    isReading: get: -> @_isReading

    sync: (options) -> @_readSync options

define log, ->
  @options = configurable: no, writable: no
  @ { prompt }

# hooker.hook log, "_printChunk", pre: ({ message }) ->
#
#   # Only rewrite the prompt's line during asynchronous reading.
#   return if !prompt._isAsync?
#
#   # Ignore printing by the prompt itself.
#   return if prompt._isPrinting
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
#   prompt._isPrinting = yes
#   log line.contents
#   cursor.left line.length - line.x
#   prompt._isPrinting = no
