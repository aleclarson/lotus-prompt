
log = require "log"

caret = require "./Caret"

module.exports =

  "right": ->
    if caret.x isnt @_labelLength + @_message.length
      caret.x += 1
    return

  "left": ->
    if caret.x isnt @_labelLength
      caret.x -= 1
    return

  "return": ->
    if @_message.length > 0
      if @_async
      then @_cancelAsync()
      else @_close()
    return

  "tab": ->
    # TODO: Implement tab completion.

  "tab+shift": ->
    # no-op

  "backspace": ->

    # You can't delete the prompt label.
    x = caret.x - @_labelLength

    # The cursor is at the beginning of the line.
    return if x <= 0

    caretWasHiding = caret.isHidden
    caret.isHidden = yes

    # Move the cursor left one character.
    caret.x -= 1

    messageBefore = @_message.slice 0, x - 1
    messageAfter = @_message.slice x
    if messageAfter.length
      @_print messageAfter + " "
      @_message = messageBefore + messageAfter
      caret.x -= messageAfter.length + 1

    else
      @_print " "       # Overwrite the character with whitespace.
      caret.x -= 1 # Pretend like the whitespace isnt there.
      @_message = messageBefore

    caret.isHidden = caretWasHiding
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
    caret.x = @_labelLength

  # Move cursor to end of prompt.
  "e+ctrl": ->
    caret.x = log.line.length

  # Delete last word before the cursor.
  "w+ctrl": ->
    caretWasHiding = caret.isHidden
    caret.isHidden = yes
    # BUG: Ansi is not supported when slicing!
    a = @_message.slice 0, caret.x
    if a.length > 0
      x = 1 + a.replace(/\s+$/, "").lastIndexOf " "
      a = a.slice 0, x
      b = @_message.slice caret.x
      @_message = a + b
      log.clearLine()
      @_printLabel()
      @_print @_message
      caret.x = @_labelLength + x
    caret.isHidden = caretWasHiding
    return
