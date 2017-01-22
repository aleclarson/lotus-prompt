
{caret} = log = require "log"

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

    # Overwrite the character before the caret.
    caret.x -= 1
    log._printToChunk " "
    caret.x -= 1

    # The characters from the caret onward.
    postCaret = @_message.slice x

    # The characters before the deleted character.
    @_message = @_message.slice 0, x - 1
    log.updateLine @_message

    if postCaret.length
      @_print postCaret
      @_message += postCaret
      log.updateLine @_message

      # This erases the remainder of shifting 'postCaret' to the left.
      log._printToChunk " " # , {hidden: yes}

    caret.x = x - 1
    caret.isHidden = caretWasHiding
    return

  "c+ctrl": ->
    { length } = @_message
    if length is 0
      log.red "CTRL+C"
      log.moat 1
      @close()
    else
      log.clearLine()
      @_printLabel()
      @_message = ""

  "x+ctrl": ->
    @close()
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
      log.clearLine()
      @_printLabel()
      @_print @_message = a + b
      caret.x = x
    caret.isHidden = caretWasHiding
    return
