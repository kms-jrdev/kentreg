http = require 'http'
fs = require 'fs'
url = require 'url'
qs = require 'querystring'
readline = require 'readline'
process = require 'process'

isInteger = (val) -> (Number.parseInt val) is not NaN
getRandom = (max) -> (Math.floor Math.random()) * max

consts =
  tokenDigits: "0123456789abcdefghijklmnopqrstuvwxyzQPWOEIRUTYALSKDJFHGZMXNCBV"
  optionsFile: "/projects/kentreg/options.json"
  getEpoch: ->
    return (new Date).getTime()

options = JSON.parse fs.readFileSync consts.optionsFile
tokens = JSON.parse fs.readFileSync options.tokensFile

consts.climodules =
  exit: (args) ->
    fs.writeFileSync options.tokensFile, JSON.stringify tokens
    fs.writeFileSync consts.optionsFile, JSON.stringify options
    console.log "All files synchronized, quitting"
    process.exit()
  formtoken_new: (args) ->
    len = Number.parseInt args[0] if isInteger(args[0]) else 16
    tokenBuffer = ""
    for $ in [0...len]
      tokenBuffer += consts.tokenDigits.charAt getRandom consts.tokenDigits.length
    tokens.form[tokenBuffer] = consts.getEpoch() + (1000 * consts.tokenExpireSeconds)
    console.log "Token: #{tokenBuffer}"
    console.log "Successfully inserted new token into form token database. Expires in #{consts.tokenExpireSeconds} second(s)."
  formtoken_delete: (args) ->
    if args.length < 1
      console.log "Command used incorrectly. Usage: formtoken_delete <tokenPart>"
    else
      deletionList = []
      for k, v of tokens.form
        if k.startsWith args[0]
          deletionList.push key
          console.log "Token marked for deletion: #{k}"
      console.log "#{deletionList.length} token(s) marked for deletion"
      for d in deletionList
        delete tokens.form[d]
        console.log "Token deleted: #{d}"
      console.log "All deletions completed"
  formtoken_list: (args) ->
    for k, v of tokens.form
      console.log "#{k} -> #{(new Date(v)).toLocaleString()}"

modules =
  getform:
    method: "POST"
    handle: (data) ->
      if data.token in Object.keys tokens.form and tokens.form[data.token] > consts.getEpoch()
        return fs.readFileSync options.formHtml
      else
        return "Invalid token"

rl = readline.createInterface(
  input: process.stdin
  output: process.stdout
)

rl.on 'line', (line) ->
  args = line.split " "
  if args[0] in Object.keys consts.climodules
    consts.climodules[args[0]] args.slice 1, args.length
  else
    console.log("Unknown command")

httpServer = http.createServer (req, res) ->
  pname = (url.parse req.url).pathname.substring 1
  if pname in Object.keys modules
    if req.method != modules[pname].method
      console.warn "Aborted /#{pname} request because of method mismatch"
      res.end "Method mismatch"
    if req.method == "POST"
      body = ""
      req.on "data", (data) ->
        console.log "req on data"
        body += data

        if body.length > 1e6
          req.connection.destroy()

      req.on "end", ->
        res.end modules[pname].handle qs.parse body
    else if req.method == "GET"
      res.end modules[pname].handle (url.parse req.url, true).query
    else
      console.error "Unsupported method: #{req.method}"
  else
    res.end "I don't understand your query."

httpServer.listen 10203
