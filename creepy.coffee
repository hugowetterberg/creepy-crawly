url = require 'url'
http = require 'http'
fs = require 'fs'
path = require 'path'
mkdirp = require 'npm/lib/utils/mkdir-p'
crypto = require 'crypto'
events = require 'events'

parsers =
  'text/html': require('./lib/html')
  'text/css': require('./lib/css')

exports.Crawly = class Crawly extends events.EventEmitter
  constructor: (@output_directory, @db)->
    @domains = {}
    @crawl_queue = []
    @crawled = {}
    @variants = {}
    @parameters = {}
    @startingPointBatch = 0
    null

  addDomain: (domain)->
    @domains[domain] = yes

  addSupportedParameters: (parameters)->
    for parameter in parameters
      @parameters[parameter] = yes
    null

  hasSupportedParameter: (query)->
    for key of query
      if @parameters[key]?
        return yes
    no

  urlMod: (uri, mod)->
    puri = if typeof uri is 'object'
      url.parse(url.format(uri))
    else
      url.parse(uri, yes);
    mod puri
    url.format(puri)

  addingStartingPoint: ()->
    @startingPointBatch++

  startingPointAdded: (puri)->
    @startingPointBatch--
    @emit 'starting_point_added', puri
    if not @startingPointBatch
      @emit 'starting_point_batch_finished'
    null

  onceStartingPointBatchFinishes: (callback)->
    if not @startingPointBatch
      callback()
    else
      @once 'starting_point_batch_finished', callback
    null

  addStartingPoint: (uri, mutating = no, callback = null)->
    @addingStartingPoint()

    puri = url.parse(uri, yes)
    if not callback
      callback = ->

    if typeof(@domains[puri.hostname]) is 'undefined'
      return no

    if not puri.port?
      puri.port = if puri.protocol is 'https:' then 443 else 80
    
    if not puri.pathname? or puri.pathname is ''
      puri.pathname = '/'

    norm = url.format(puri)
    puri.href = norm

    plain_href = if puri.search?
      @urlMod norm, (uri)->
        delete uri.search
        delete uri.query
    else
      puri.href

    if puri.pathname is '/'
      puri.file_path = path.resolve(@output_directory, 'index.html')
    else if path.extname(puri.pathname) is ''
      puri.file_path = path.resolve(@output_directory, path.join(puri.pathname.substr(1), 'index.html'))
    else
      puri.file_path = path.resolve(@output_directory, puri.pathname.substr(1))

    if mutating and puri.search? and @hasSupportedParameter(puri.query)
      hash = crypto.createHash('sha1')
      hash.update(puri.search)
      append = '.' + hash.digest('hex') + path.extname(puri.file_path)

      norm = if puri.pathname is '/' or path.extname(puri.pathname) is ''
        @urlMod norm, (uri)->
          uri.pathname = path.join(puri.pathname, 'index.html' + append)
      else
        plain_href + append

      puri.file_path += append
      puri.alternate_href = norm
    else
      norm = plain_href

    hash = crypto.createHash 'sha1'
    hash.update norm
    puri.sha1 = hash.digest 'hex'

    puri.queued = new Date().getTime()
    save =
      serialized: []
    for key, value of puri
      if typeof value is 'object'
        value = JSON.stringify(value)
        save.serialized.push(key)
      save[key] = value
    save.serialized = JSON.stringify(save.serialized)

    @db.hget 'crawl_state', puri.sha1, (error, state)=>
        if not state
          @db.multi()
            .sadd('crawl_queue', puri.sha1)
            .hmset("uri:#{puri.sha1}", save)
            .exec (error, results)=>
              console.log "Queued: #{puri.sha1} (#{norm})"
              @startingPointAdded(puri, yes)
              callback(puri, yes)
        else
          @startingPointAdded(puri, no)
          callback(puri, no)
    puri

  crawl: ()->
    if not path.existsSync @output_directory
      mkdirp(@output_directory, ->)

    @onceStartingPointBatchFinishes =>
      @db.spop 'crawl_queue', (error, sha1)=>
        if not error and sha1
          console.log "Got sha1 #{sha1} from queue"
          @crawlNext sha1, (error, status)=>
            @crawl()
        else if error
          console.log "Error while fetching jobs from queue #{error}"
        else if not sha1
          console.log "The queue is empty"

  crawlNext: (sha1, callback)->
    done = (error, status)=>
      @db.hset 'crawl_state', sha1, 'crawled', ()->
        callback(error, status)

    console.log "Loading info for #{sha1}"
    @db.multi()
      .hset('crawl_state', sha1, 'in_progress')
      .hgetall("uri:#{sha1}")
      .exec (error, results)=>
        [state_set, uri] = results

        uri.serialized = JSON.parse(uri.serialized)
        for key in uri.serialized
          uri[key] = JSON.parse(uri[key])

        # Make sure that we have a directory
        dir = path.dirname(uri.file_path)
        if not path.existsSync dir
          mkdirp dir, ()=>
            @download(uri, done)
        else
          @download(uri, done)

  download: (uri, callback)->
    req_opts =
      host: uri.hostname
      port: uri.port
      path: uri.pathname
      headers:
        'X-Purpose': 'bake'

    if uri.search?
      req_opts.path += uri.search

    request = http.request req_opts, (response)=>
      file = fs.openSync(uri.file_path, 'w')

      mime_type = response.headers['content-type']
      if not ((cpos = mime_type.indexOf(';')) is -1)
        mime_type = mime_type.substr(0, cpos)
      console.log("#{uri.href} is #{mime_type}")
      if typeof(parsers[mime_type]) is 'object'
        parser = new parsers[mime_type].Parser(this, uri, response)
        body = ""
        response.on "data", (chunk)->
          body += chunk
          buffer = new Buffer(chunk)
          if not parser.isMutator()
            fs.write(file, buffer, 0, buffer.length, null)
          if parser.isStreaming()
            parser.parse(chunk)

        response.on "end", ()->
          if not parser.isStreaming()
            parser.parse(body)

          parser.end?()
          if parser.isMutator()
            buffer = new Buffer parser.mutatedData()
            fs.write(file, buffer, 0, buffer.length, null)
          fs.close(file)
          callback()
      else
        response.on "data", (chunk)->
          fs.write(file, chunk, 0, chunk.length, null)
        response.on "end", ()->
          fs.close(file)
          callback()

    request.end()