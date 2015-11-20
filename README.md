
# lotus-prompt v1.0.0 [![stable](http://badges.github.io/stability-badges/dist/stable.svg)](http://github.com/badges/stability-badges)

```sh
npm install aleclarson/lotus-prompt#1.0.0
```

`lotus-prompt` provides a prompt capable of taking synchronous and asynchronous input inside your terminal.

&nbsp;

## usage

```CoffeeScript
require "lotus-prompt"

log = require "lotus-log"

# Take user input synchronously.
input = log.prompt.sync()

# Take user input asynchronously.
log.prompt().then (input) ->
```

&nbsp;
