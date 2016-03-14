
prompt = require "../js/src"

loop
  result = prompt.sync()
  log.moat 0
  log.yellow "result = "
  log.white result
  log.moat 0
