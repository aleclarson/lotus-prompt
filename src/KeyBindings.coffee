
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

    # The label should not be deleted.
    return if caret.x <= @_labelLength

    caretWasHiding = caret.isHidden
    caret.isHidden = yes

    # Overwrite the character before the caret.
    caret.x -= 1
    log._printToChunk " ", {hidden: yes}
    caret.x -= 1

    # The index used to split `this._message`
    x = caret.x - @_labelLength

    # The characters from the caret onward.
    postCaret = @_message.slice x + 1

    # The characters before the deleted character.
    @_message = @_message.slice 0, x
    log.updateLine @_message

    if postCaret.length
      @_message += postCaret
      log postCaret
      log._printToChunk " ", {hidden: yes}
      log.updateLine @_message
      log.flush()

    caret.x = x + @_labelLength
    caret.isHidden = caretWasHiding
    return

  "c+ctrl": ->
    if @_message.length is 0
      log.red "CTRL+C"
      log.moat 1
      @close()
    else
      log.clearLine()
      @_printLabel()
      @_message = ""
    return

  "x+ctrl": ->
    @close()
    log.pushIndent 0
    log.moat 1
    log.red "CTRL+X"
    log.moat 1
    log.popIndent()
    log.flush()
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
