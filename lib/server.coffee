http = require 'http'
handlers = require './handlers'
socket_io = require 'socket.io'
RequestHandler = require('./handler').RequestHandler

exports.start = (crawly)->
  server = http.createServer (req, res)->
    handler = new RequestHandler(crawly, req, res)
    handler.handle(handlers)
  server.io = socket_io.listen(server)
  server.listen(8033, "127.0.0.1")

  server.io.sockets.on 'connection', (socket)->
    socket.emit 'update',
      hello: 'hello world'
    socket.on 'hello', (data)->
      console.log data

  server
  