url = require 'url'
http = require 'http'
fs = require 'fs'
path = require 'path'

try
  mkdirp = require 'npm/lib/utils/mkdir-p'
catch error
  mkdirp = (path, callback)->
    mkdir path, 0777, callback
crypto = require 'crypto'
events = require 'events'
server = require './lib/server'

parsers =
  'text/html': require('./lib/html')
  'text/css': require('./lib/css')

exports.Crawly = class Crawly extends events.EventEmitter
  constructor: (@output_directory, @db_connection)->
    @domain = null
    @variants = {}
    @parameters = {}
    @root_url = no
    if @output_directory
      @server = server.start(this)
    @batch = 0
    @db = @newRedisConnection()
    @queue_feed_db = @newRedisConnection()
    null

  getRedis: ()->
    @db

  newRedisConnection: ()->
    @db_connection()

  startBatch: (callback)->
    if not @batch
      @db.incr "global:next:batch", (error, result)=>
        @batch = if not error then result else 0
        multi = @db.multi();
        multi.rpush "batches", @batch
        multi.hset "batch:#{@batch}", "created", new Date().getTime()
        multi.hset "batch:#{@batch}", "id", @batch
        multi.exec (error, result)->
          callback error, @batch
    else
      callback new Error('Batch already started')

  registerOutLink: (from, to, score=1)->
    multi = @db.multi()
    multi.zincrby "batch:#{@batch}:uri:score", score, to.href
    multi.zincrby "batch:#{@batch}:uri:out:#{from.href}", score, to.href
    multi.zincrby "batch:#{@batch}:uri:in:#{to.href}", score, from.href
    multi.exec()

  setDomain: (domain)->
    @domain = domain
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
    @db.hset "batch:#{batch}:uri:info:#{uri}", property, value

  setUriInfoMulti: (uri, properties)->
    @db.hmset "batch:#{batch}:uri:info:#{uri}", properties

  addStartingPoint: (uri, mutating = no, options = {}, callback = null)->
    @addingStartingPoint()

    if typeof options is 'function'
      callback = options
      options = {}
    modified = options.modified? and options.modified

    puri = url.parse(uri, yes)
    if not callback
      callback = ->

    if not (puri.hostname is @domain)
      return no

    # Ignore non-http protocols
    if puri.protocol? and not (puri.protocol is 'http:' or puri.protocol is 'https:')
      return no

    if not puri.port?
      puri.port = if puri.protocol is 'https:' then 443 else 80
    
    if not puri.pathname? or puri.pathname is ''
      puri.pathname = '/'
    else if not (puri.pathname is '/') and path.extname(puri.pathname) is '' and not (puri.pathname.length is puri.pathname.lastIndexOf('/') + 1)
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

    @db.hget "batch:#{@batch}:crawl_state", puri.sha1, (error, state)=>
        if not state or modified
          @db.multi()
            .rpush("batch:#{@batch}:crawl_queue", puri.sha1)
            .hset("batch:#{@batch}:crawl_state", puri.sha1, 'queued')
            .hmset("batch:#{@batch}:uri:#{puri.sha1}", save)
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

  markResourceAsDirty: (resource)->
    @db.multi()
      .sadd("resources:dirty", resource.identifier)
      .hmset("resource:dirty:#{resource.identifier}", resource)
      .exec()

  markResourceAsDeleted: (resource)->
    @db.multi()
      .sadd("resources:dirty", resource.identifier)
      .del("resource:dirty:#{resource.identifier}")
      # Clean up potential dirty info for the resource
      .srem("resources:dirty", resource.identifier)
      .hdel("resource:dirty:#{resource.identifier}", resource)
      .exec()

  crawl: ()->
    if not path.existsSync @output_directory
      mkdirp(@output_directory, ->)

    @queue_feed_db.blpop "batch:#{@batch}:crawl_queue", 1, (error, result)=>
      if result
        [list, sha1] = result
        if not error and sha1
          console.log "Got sha1 #{sha1} from queue"
          @crawlNext sha1, (error, status)=>
            @crawl()
        else if error
          console.log "Error while fetching jobs from queue #{error}"
    

  crawlNext: (sha1, callback)->
    done = (error, status)=>
      if error
        console.dir error
        @db.multi()
          .rpush("batch:#{@batch}:crawl_queue", sha1)
          .hset("batch:#{@batch}:crawl_state", sha1, 'failed')
          .exec ()->
            callback(error, status)
      else
        @db.hset "batch:#{@batch}:crawl_state", sha1, 'crawled', ()->
          callback(error, status)

    console.log "Loading info for #{sha1}"
    @db.multi()
      .hset("batch:#{@batch}:crawl_state", sha1, 'in_progress')
      .hgetall("batch:#{@batch}:uri:#{sha1}")
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

  saveMimeStats: (info)->
    multi = @db.multi()
    multi.hincrby "batch:#{@batch}:stats:files", info.mime_type, 1
    multi.hincrby "batch:#{@batch}:stats:size", info.mime_type, info.weight
    multi.hincrby "batch:#{@batch}:stats:download_time", info.mime_type, info.download_time
    multi.hincrby "batch:#{@batch}", "files", 1
    multi.hincrby "batch:#{@batch}", "size", info.weight
    multi.hincrby "batch:#{@batch}", "download_time", info.download_time

    if info.parse_time?
      multi.hincrby "batch:#{@batch}:stats:parse_time", info.mime_type, info.parse_time
      multi.hincrby "batch:#{@batch}", "parse_time", info.parse_time
    multi.exec (err, result)=>
      result.unshift(info.mime_type)
      @emit 'stats', result

  download: (uri, callback)->
    console.log "Downloading #{uri.href}"
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

        @saveMimeStats info
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

    request.on 'error', (error)->
      callback(error)

    request.end()
