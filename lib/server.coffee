http = require 'http'
handlers = require './handlers'
socket_io = require 'socket.io'
express = require 'express'

exports.start = (crawly)->
  app = express.createServer()
  app.use(express.logger())
  app.use(express.bodyParser())
  app.use(express.static(__dirname + '/public'))
  app.io = socket_io.listen(app)

  handlers.register(app, crawly)

  app.listen(8033)

  app.io.sockets.on 'connection', (socket)->
    socket.emit 'update',
      hello: 'hello world'
    socket.on 'hello', (data)->
      console.log data

  app
  