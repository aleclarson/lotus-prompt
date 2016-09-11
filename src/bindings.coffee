
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
    #   log.clearLine()
    #   @_printLabel()
    #   log._printToChunk @_message = @_history.cache[++@_history.index]
    #
    # else if @_history.index is ( @_history.count - 1 ) and @_message.length > 0
    #   log.clearLine()
    #   @_printLabel()
    #   @_history.index++
    #   @_message = ""

  "right": ->
    return if log.offset is @_labelLength + @_message.length
    log.setOffset log.offset + 1

  "left": ->
    return if log.offset is @_labelLength
    log.setOffset log.offset - 1

  "return": ->
    return if @_message.length is 0
    if @_async
    then @_cancelAsync()
    else @_close()

  "tab": ->
    # TODO: Implement tab completion.

  "tab+shift": ->
    # no-op

  "backspace": ->

    # You can't delete the prompt label.
    x = log.offset - @_labelLength

    # The cursor is at the beginning of the line.
    return if x <= 0

    # Move the cursor left one character.
    log.setOffset log.offset - 1

    messageBefore = @_message.slice 0, x - 1
    messageAfter = @_message.slice x
    if messageAfter.length
      @_print messageAfter + " "
      @_message = messageBefore + messageAfter
      log.setOffset log.offset - messageAfter.length - 1

    else
      # Overwrite the character with whitespace.
      @_print " "

      # Pretend like the whitespace isnt there.
      log.setOffset log.offset - 1

      @_message = messageBefore
    return

  "c+ctrl": ->
    { length } = @_message
    if length is 0
      log.red "CTRL+C"
      log.moat 1
      log.flush()
      @_message = null
      if @_async then @_cancelAsync()
      else @_close()
    else
      log.clearLine()
      @_printLabel()
      @_message = ""
    return

  "x+ctrl": ->
    log.pushIndent 0
    log.moat 1
    log.red "CTRL+X"
    log.moat 1
    log.popIndent()
    log.flush()
    @_message = null
    if @_async then @_cancelAsync()
    else @_close()
    process.exit 0, "SIGTERM"

  # Move cursor to beginning of prompt.
  "a+ctrl": ->
    log.setOffset @_labelLength

  # Move cursor to end of prompt.
  "e+ctrl": ->
    log.setOffset log.line.length

  # Delete last word before the cursor.
  "w+ctrl": ->
    # BUG: Ansi is not supported when slicing!
    firstHalf = @_message.slice 0, log.offset
    if firstHalf.length > 0
      x = 1 + firstHalf.replace(/\s+$/, "").lastIndexOf " "
      firstHalf = firstHalf.slice 0, x
      lastHalf = @_message.slice log.offset
      @_message = firstHalf + lastHalf
      log.clearLine()
      @_printLabel()
      @_print @_message
      log.setOffset @_labelLength + x
    return
