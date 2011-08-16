url = require 'url'
fs = require 'fs'
path = require 'path'
handler_utils = require './handler_utils'

exports.RequestHandler = class RequestHandler
  constructor: (@crawly, @req, @res)->
    @purl = url.parse(@req.url, true)
    
    null

  readPostData: (req, callback)->
    data = ''
    req.on 'data', (chunk)->
      data += chunk
    req.on 'end', ()->
      callback JSON.parse(data)
    null

  handle: (handlers)->
    if @req.method is 'POST' or @req.method is 'PUT'
      @readPostData @req, (data)=>
        @postData = data
        handler_utils.callMatchingHandler(handlers.handlers, this)
    else
      handler_utils.callMatchingHandler(handlers.handlers, this)

  publicFilePath: (file_path)->"#{__dirname}/public/#{file_path}"

  passthrough: (file_path, mime='text/html')->
    bufferSize = 1024
    fs.open @publicFilePath(file_path), 'r', (err, fd)=>
      if not err
        @res.setHeader "Content-Type", mime
        buffer = new Buffer(bufferSize)
        readChunk = ()=>
          fs.read fd, buffer, 0, bufferSize, null, (err, bytesRead, buffer)=>
            if bytesRead
              @res.write buffer.slice(0, bytesRead)
              readChunk()
            else
              @res.end()
        readChunk()
      else
        if err.code is 'ENOENT'
          @notFoundResult 'File not found'
        else
          @errorResult 501, 'Could not read from file'

  ###
  Convenience function for sending results to the client.

  @result object
  ###
  result: (result)->
    @res.writeHead 200,
      'Content-Type': 'application/json'
      'Cache-Control': 'no-cache'
      'Expires': 'Fri, 30 Oct 1998 14:19:41 GMT'
    @res.end JSON.stringify(
      status: 200
      response: result
    )
    null

  ###
  Convenience function for sending an error response to the client.

  @status int
    Error code.
  @message object
  ###
  errorResult: (status, message, error)->
    @res.writeHead status,
      'Content-Type': 'application/json'
    response =
      status: status
      message: if message then message else 'Error'

    if error
      console.dir error
      response.errorCode = error.code
      if error.data?
        response.data = error.data

    @res.end JSON.stringify(response)
    null

  ###
  Convenience function for an not found error response to the client.

  @message object
  ###
  notFoundResult: (message)->
    @errorResult(404, message ? message : 'Resource cannot be found')
    null