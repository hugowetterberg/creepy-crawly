utils = require './utils'
path = require 'path'
url = require 'url'

###
The request handlers.
###

exports.register = (app, crawly)->

  helpers =
    ###
    Convenience function for sending results to the client.

    @result object
    ###
    result: (res, result)->
      res.writeHead 200,
        'Content-Type': 'application/json'
        'Cache-Control': 'no-cache'
        'Expires': 'Fri, 30 Oct 1998 14:19:41 GMT'
      res.end JSON.stringify(result)
      null

    ###
    Convenience function for sending an error response to the client.

    @status int
      Error code.
    @message object
    ###
    errorResult: (res, status, message, error)->
      res.writeHead status,
        'Content-Type': 'application/json'
      response =
        status: status
        message: if message then message else 'Error'

      if error
        console.dir error
        response.errorCode = error.code
        if error.data?
          response.data = error.data

      res.end JSON.stringify(response)
      null

    ###
    Convenience function for an not found error response to the client.

    @message object
    ###
    notFoundResult = (message)->
      @errorResult res, 404, message ? message : 'Resource cannot be found'
      null

  # Get start page
  ### SYMBOL:GET pages ###
  app.get '/pages', (req, res)->
    db = crawly.getRedis()
    purl = url.parse(req.url, true)
    page = if purl.query['page'] then purl.query['page'] else 0
    db.zrevrange 'uri:score', page*20, page*20+19, 'WITHSCORES', (err, result)->
      if not err
        helpers.result res, result
      else
        helpers.errorResult res, 501, 'Could not fetch pages from database'
    null

  ### SYMBOL:GET batches ###
  app.get '/api/batches', (req, res)->
    db = crawly.getRedis()
    purl = url.parse(req.url, true)
    page = if purl.query['page'] then purl.query['page'] else 0
    db.lrange "batches", page*20, page*20+19, (err, result)->
      if not err
        multi = db.multi()
        for batchId in result
          multi.hgetall "batch:#{batchId}"
        multi.exec (err, batches)->
          helpers.result res, batches
      else
        helpers.errorResult res, 501, 'Could not fetch batches from database'

    null

  ### SYMBOL:GET single batch ###
  app.get '/api/batches/:batch', (req, res)->
    db = crawly.getRedis()
    multi = db.multi()
    multi.hgetall "batch:#{req.params.batch}"
    multi.hgetall "batch:#{req.params.batch}:stats:files"
    multi.hgetall "batch:#{req.params.batch}:stats:size"
    multi.hgetall "batch:#{req.params.batch}:stats:download_time"
    multi.exec (err, data)->
      if not err
        # format result
        result = data[0]
        result['stats'] = {}
        result['stats']['files'] = data[1]
        result['stats']['size'] = data[2]
        result['stats']['download_time'] = data[3]
        helpers.result res, result
      else
        helpers.errorResult res, 501, 'Could not fetch batch from database'
    null

  # Add a starting point
  ### SYMBOL:POST api/add-starting-point ###
  app.post '/api/add-starting-point', (req, res)->
    crawly.addStartingPoint req.body.url
    helpers.result res, 'ok'
    null

  # Start crawling
  ### SYMBOL:POST api/crawl ###
  app.post '/api/crawl', (req, res)->
    helpers.result res, 'ok'
    null
