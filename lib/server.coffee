http = require 'http'
handlers = require './handlers'
socket_io = require 'socket.io'
express = require 'express'
SigningAuth = require('signing_auth').SigningAuth
AuthStore = require './auth_store'

exports.start = (crawly)->
  authStore = new AuthStore(crawly)
  auth = new SigningAuth(authStore, express)

  app = express.createServer()
  app.use(express.logger())
  app.use(auth.connectMiddleware())
  app.use(express.static(__dirname + '/public'))
  app.io = socket_io.listen(app)

  handlers.register(app, crawly)

  secureHandler = (path, handler)->
    app.post path, (req, res)->
      if not req.signedBy?
        res.writeHead 401, 'Content-Type':'text/plain'
        res.end 'Update requests must be signed'
      else
        handler req, res

  secureHandler '/api/updates', (req, res)->
    console.log JSON.stringify(req.body)
    for resource in req.body
      switch resource.state
        when 'update' then crawly.markResourceAsDirty resource
        when 'delete' then crawly.markResourceAsDeleted resource

    res.writeHead 200, 'Content-Type':'text/json'
    res.end '{"status":"ok"}'

  secureHandler '/api/bake', (req, res)->
    # TODO: Bake changes
    res.writeHead 200, 'Content-Type':'text/json'
    res.end '{"status":"ok"}'

  secureHandler '/api/bake-all', (req, res)->
    # TODO: Bake all
    res.writeHead 200, 'Content-Type':'text/json'
    res.end '{"status":"ok"}'

  app.listen(8033)

  app.io.sockets.on 'connection', (socket)->
    
    auth.issueChallenge socket, (error, credentials)->
      console.log "We're on!"
    socket.emit 'update',
      hello: 'hello world'
    socket.on 'hello', (data)->
      console.log data
    crawly.on 'stats', (data)->
      socket.emit 'stats', data

  app
  