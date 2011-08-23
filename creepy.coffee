url = require 'url'
http = require 'http'
fs = require 'fs'
path = require 'path'
mkdirp = require 'npm/lib/utils/mkdir-p'
crypto = require 'crypto'
events = require 'events'
server = require './lib/server'

parsers =
  'text/html': require('./lib/html')
  'text/css': require('./lib/css')

exports.Crawly = class Crawly extends events.EventEmitter
  constructor: (@output_directory, @db)->
    @domains = {}
    @variants = {}
    @parameters = {}
    @root_url = no
    @server = server.start(this)
    null

  getRedis: ()->
    @db

  registerOutLink: (from, to, score=1)->
    multi = @db.multi()
    multi.zincrby "uri:score", score, to.href
    multi.zincrby "uri:out:#{from.href}", score, to.href
    multi.zincrby "uri:in:#{to.href}", score, from.href
    multi.exec()

  addDomain: (domain)->
    @domains[domain] = yes
    if not @root_url
      @root_url = "http://#{domain}/"

  addSupportedParameters: (parameters)->
    for parameter in parameters
      @parameters[parameter] = yes
    null

  hasSupportedParameter: (query)->
    for key of query
      if @parameters[key]?
        return yes
    no

  supportedParameterSubset: (query)->
    supported = no
    for key, enabled of @parameters
      if enabled and query[key]
        if not supported then supported = {}
        supported[key] = query[key]
    supported

  urlMod: (uri, mod)->
    puri = if typeof uri is 'object'
      url.parse(url.format(uri))
    else
      url.parse(uri, yes);
    mod puri
    url.format(puri)

  addingStartingPoint: ()->
    null

  startingPointAdded: (puri, queued)->
    @emit 'starting_point_added', puri, queued
    null

  onceStartingPointBatchFinishes: (callback)->
    if not @startingPointBatch
      callback()
    else
      @once 'starting_point_batch_finished', callback
    null

  setUriInfo: (uri, property, value)->
    @db.hset "uri:info:#{uri}", property, value

  setUriInfoMulti: (uri, properties)->
    @db.hmset "uri:info:#{uri}", properties

  addStartingPoint: (uri, mutating = no, callback = null)->
    @addingStartingPoint()

    puri = url.parse(uri, yes)
    if not callback
      callback = ->

    if typeof(@domains[puri.hostname]) is 'undefined'
      return no

    # Ignore non-http protocols
    if puri.protocol? and not (puri.protocol is 'http:' or puri.protocol is 'https:')
      return no

    if not puri.port?
      puri.port = if puri.protocol is 'https:' then 443 else 80
    
    if not puri.pathname? or puri.pathname is ''
      puri.pathname = '/'
    else if not (puri.pathname is '/') and path.extname(puri.pathname) is '' and not (puri.pathname.length is puri.pathname.lastIndexOf('/') + 1)
      console.log "Adding ending slash to #{puri.pathname}"
      puri.pathname = "#{puri.pathname}/"

    puri.query = if puri.query? @supportedParameterSubset(puri.query) else no
    if not puri.query and puri.search?
      delete puri.search
    else if puri.query
      separator = '?'
      puri.search = ''
      for k, v in puri.query
        puri.search = separator + encodeURIComponent(k) + '=' + encodeURIComponent(v)
        separator = '&'

    if puri.hash?
      delete puri.hash

    norm = url.format(puri)
    puri.href = norm

    plain_href = @urlMod norm, (uri)->
      delete uri.search
      delete uri.query

    if puri.pathname is '/'
      puri.file_path = path.resolve(@output_directory, 'index.html')
    else if path.extname(puri.pathname) is ''
      puri.file_path = path.resolve(@output_directory, path.join(puri.pathname.substr(1), 'index.html'))
    else
      puri.file_path = path.resolve(@output_directory, puri.pathname.substr(1))

    if mutating
      if puri.search? and @hasSupportedParameter(puri.query)
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
      else if @root_url and plain_href.indexOf(@root_url) is 0
        norm = norm.replace(@root_url, '/')
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

    console.log "Queue data"
    console.dir save

    @db.hget 'crawl_state', puri.sha1, (error, state)=>
        if not state
          @db.multi()
            .sadd('crawl_queue', puri.sha1)
            .hset('crawl_state', puri.sha1, 'queued')
            .hmset("uri:#{puri.sha1}", save)
            .exec (error, results)=>
              if not error
                console.log "Queued: #{puri.sha1} (#{norm})"
                @startingPointAdded(puri, yes)
                callback(puri, yes)
              else
                console.log "Failed to queue: #{puri.sha1} (#{norm})"
        else
          @startingPointAdded(puri, no)
          callback(puri, no)
    puri

  crawl: ()->
    if not path.existsSync @output_directory
      mkdirp(@output_directory, ->)
    @db.spop 'crawl_queue', (error, sha1)=>
      if not error and sha1
        console.log "Got sha1 #{sha1} from queue"
        @crawlNext sha1, (error, status)=>
          @crawl()
      else if error
        console.log "Error while fetching jobs from queue #{error}"
      else if not sha1
        console.log "The queue is empty, waiting for starting point"
        @once 'starting_point_added', (puri, queued)=>
          @crawl()
    

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

    download_start = new Date()
    download_finished = no
    parse_start = no
    parse_finished = no

    request = http.request req_opts, (response)=>
      file = fs.openSync(uri.file_path, 'w')
      save_info = ()=>
        info =
          mime_type: mime_type
          weight: weight
          original_weight: original_weight
          download_time: download_finished.getTime() - download_start.getTime()
        if parse_start
          info.parse_time = parse_finished.getTime() - parse_start.getTime()
        @setUriInfoMulti uri.href, info

      mime_type = response.headers['content-type']
      if not ((cpos = mime_type.indexOf(';')) is -1)
        mime_type = mime_type.substr(0, cpos)
      console.log("#{uri.href} is #{mime_type}")
      weight = 0
      original_weight = 0
      if typeof(parsers[mime_type]) is 'object'
        parser = new parsers[mime_type].Parser(this, uri, response)
        body = ""
        response.on "data", (chunk)->
          if not parser.isMutator()
            buffer = new Buffer(chunk)
            fs.write(file, buffer, 0, buffer.length, null)
            original_weight = weight = weight + chunk.length
          else
            original_weight = original_weight + chunk.length

          if parser.isStreaming()
            parser.parse(chunk)
          else
            body += chunk

        response.on "end", ()=>
          download_finished = new Date()

          if not parser.isStreaming()
            parse_start = new Date()
            parser.parse(body)
            parse_finished = new Date()

          parser.end?()
          if parser.isMutator()
            buffer = new Buffer parser.mutatedData()
            weight = buffer.length
            fs.write(file, buffer, 0, buffer.length, null)
          fs.close(file)

          save_info()
          callback()
      else
        response.on "data", (chunk)->
          fs.write(file, chunk, 0, chunk.length, null)
          original_weight = weight = weight + chunk.length
        response.on "end", ()=>
          download_finished = new Date()
          fs.close(file)
          save_info()
          callback()

    request.end()
