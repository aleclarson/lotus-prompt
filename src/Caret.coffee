
didExit = require "didExit"
Type = require "Type"
log = require "log"

type = Type "Caret"

type.defineValues ->

  _x: 0

  _hidden: no

  _savedPositions: []

  _restoredPositions: []

type.defineFrozenValues

  _printListener: ->
    log.willPrint (chunk) =>
      if chunk.message is log.ln
      then @_x = 0
      else @_x += chunk.length
    .start()

type.initInstance ->
  @isHidden = yes
  didExit 1, =>
    @isHidden = no
  .start()

#
# Prototype
#

type.defineGetters

  position: -> {@x, @y}

type.definePrototype

  x:
    get: -> @_x
    set: (newValue, oldValue) ->
      newValue = Math.max 0, Math.min log.size[0], newValue
      return if newValue is oldValue
      if newValue > oldValue then @_right newValue - oldValue
      else @_left oldValue - newValue
      @_x = newValue

  y:
    get: -> @_y
    set: (newValue, oldValue) ->
      newValue = Math.max 0, Math.min log.lines.length, newValue
      return if newValue is oldValue
      if newValue > oldValue then @_down newValue - oldValue
      else @_up oldValue - newValue
      @_y = newValue

  isHidden:
    get: -> @_hidden
    set: (newValue, oldValue) ->
      if newValue isnt oldValue
        @_hidden = newValue
        log.ansi "?25" + if newValue then "l" else "h"
      return

  _y:
    get: -> log._line
    set: (newValue) ->
      log._line = newValue

type.defineMethods

  move: ({ x, y }) ->
    @y = y if y?
    @x = x if x?
    return

  save: ->
    @_savedPositions.push @position
    return

  restore: ->
    position = @_savedPositions.pop()
    @_restoredPositions.push position
    @move position
    return

  _up: (n = 1) -> log.ansi "#{n}F"

  _down: (n = 1) -> log.ansi "#{n}E"

  _left: (n = 1) -> log.ansi "#{n}D"

  _right: (n = 1) -> log.ansi "#{n}C"

module.exports = type.construct()
