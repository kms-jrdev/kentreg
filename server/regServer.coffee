http = require 'http'
fs = require 'fs'
url = require 'url'
qs = require 'querystring'

consts =
  optionsFile: "/projects/kentreg/options.json"

options = JSON.parse fs.readFileSync consts.optionsFile
tokens = JSON.parse fs.readFileSync options.tokensFile

modules =
  getform:
    method: "POST"
    handle: (data) ->
      if data.token in tokens.form
        return fs.readFileSync options.formHtml


httpServer = http.createServer (req, res) ->
  pname = (url.parse req.url).pathname.substring 1
  if pname in Object.keys modules
    if req.method != modules[pname].method
      console.warn "Aborted /#{pname} request because of method mismatch"
      return
    if req.method == "POST"
      body = ""
      req.on "data", (data) ->
        console.log "req on data"
        body += data

        if body.length > 1e6
          req.connection.destroy()

      req.on "end", ->
        data = qs.parse body
        if modules[pname].method == "POST"
          res.end modules[pname].handle data
        else
          console.warn "Aborted /#{pname} request because of method mismatch"
          res.end()
    else if req.method == "GET"
      res.end modules[pname].handle (url.parse req.url, true).query
    else
      console.error "Unsupported method"
  else
    res.end "I don't understand your query."

httpServer.listen 10203
