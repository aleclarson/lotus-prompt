
log = require "log"

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
    #   cursorWasHidden = log.cursor.isHidden
    #   log.cursor.isHidden = yes
    #   log.clearLine()
    #   @_printLabel()
    #   log._printToChunk @_message = @_history.cache[++@_history.index]
    #   log.cursor.isHidden = cursorWasHidden
    #
    # else if @_history.index is ( @_history.count - 1 ) and @_message.length > 0
    #   cursorWasHidden = log.cursor.isHidden
    #   log.cursor.isHidden = yes
    #   log.clearLine()
    #   @_printLabel()
    #   @_history.index++
    #   @_message = ""
    #   log.cursor.isHidden = cursorWasHidden

  "right": ->
    return if log.cursor.x is @_labelLength + @_message.length
    log.cursor.x++

  "left": ->
    return if log.cursor.x is @_labelLength
    log.cursor.x--

  "return": ->
    return if @_message.length is 0
    if @_async then @_cancelAsync()
    else @_close()

  "tab": ->
    # TODO: Implement tab completion.

  "tab+shift": ->
    # no-op

  "backspace": ->

    # You can't delete the prompt label.
    x = log.cursor.x - @_labelLength

    # The cursor is at the beginning of the line.
    return if x <= 0

    cursorWasHidden = log.cursor.isHidden
    log.cursor.isHidden = yes

    # Move the cursor left one character.
    log.cursor.x -= 1

    messageBefore = @_message.slice 0, x - 1
    messageAfter = @_message.slice x
    if messageAfter.length
      @_print messageAfter + " "
      @_message = messageBefore + messageAfter
      log.cursor.x -= messageAfter.length + 1

    else
      @_print " "       # Overwrite the character with whitespace.
      log.cursor.x -= 1 # Pretend like the whitespace isnt there.
      @_message = messageBefore

    log.cursor.isHidden = cursorWasHidden
    return

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
    log.cursor.x = @_labelLength

  # Move cursor to end of prompt.
  "e+ctrl": ->
    log.cursor.x = log.line.length

  # Delete last word before the cursor.
  "w+ctrl": ->
    cursorWasHidden = log.cursor.isHidden
    log.cursor.isHidden = yes
    # BUG: Ansi is not supported when slicing!
    a = @_message.slice 0, log.cursor.x
    if a.length > 0
      x = 1 + a.replace(/\s+$/, "").lastIndexOf " "
      a = a.slice 0, x
      b = @_message.slice log.cursor.x
      @_message = a + b
      log.clearLine()
      @_printLabel()
      @_print @_message
      log.cursor.x = @_labelLength + x
    log.cursor.isHidden = cursorWasHidden
