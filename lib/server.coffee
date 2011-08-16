http = require 'http'
handlers = require './handlers'
RequestHandler = require('./handler').RequestHandler

exports.start = (crawly)->
  server = http.createServer (req, res)->
    handler = new RequestHandler(crawly, req, res)
    handler.handle(handlers)
  server.listen(8033, "127.0.0.1")
  server
  