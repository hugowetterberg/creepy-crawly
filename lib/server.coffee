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
  app.use(express.bodyParser())
  app.use(auth.connectMiddleware())
  app.use(express.static(__dirname + '/public'))
  app.io = socket_io.listen(app)

  handlers.register(app, crawly)

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
  