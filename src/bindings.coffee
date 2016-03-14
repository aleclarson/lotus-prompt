
{ log, cursor } = require "lotus-log"

module.exports =

  "up": ->

    # if @_history.index > 0
    #   log.clearLine()
    #   @_printLabel()
    #   message = @_history.cache[--@_history.index]
    #   log._repl? { message, history: @_history } unless typeof message is "string"
    #   log._printToChunk @_message = message

  "down": ->

    # if @_history.index < ( @_history.count - 1 )
    #   cursorWasHidden = cursor.isHidden
    #   cursor.isHidden = yes
    #   log.clearLine()
    #   @_printLabel()
    #   log._printToChunk @_message = @_history.cache[++@_history.index]
    #   cursor.isHidden = cursorWasHidden
    #
    # else if @_history.index is ( @_history.count - 1 ) and @_message.length > 0
    #   cursorWasHidden = cursor.isHidden
    #   cursor.isHidden = yes
    #   log.clearLine()
    #   @_printLabel()
    #   @_history.index++
    #   @_message = ""
    #   cursor.isHidden = cursorWasHidden

  "right": ->
    return if cursor.x is @_labelLength + @_message.length
    cursor.x++

  "left": ->
    return if cursor.x is @_labelLength
    cursor.x--

  "return": ->
    return if @_message.length is 0
    if @_async then @_cancelAsync()
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
    @_print @_message = halfOne + halfTwo

    cursor.x -= halfTwo.length
    cursor.isHidden = cursorWasHidden

  "c+ctrl": ->
    { length } = @_message
    if length is 0
      log.red "CTRL+C"
      log.moat 1
      @_message = null
      if @_async then @_cancelAsync()
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
      @_print @_message
      cursor.x = @_labelLength + x
    cursor.isHidden = cursorWasHidden
