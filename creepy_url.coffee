$lib =
  url: require 'url'
  path: require 'path'

exports.CreepyUrl = class CreepyUrl
  constructor: (@url, crawly = no)->
    @purl = $lib.url.parse(@url, yes)

    # Normalize port number.
    if not @purl.port?
      @purl.port = if @purl.protocol is 'https:' then 443 else 80

    # Enforce a ending slash for the url.
    if not @purl.pathname? or @purl.pathname is ''
      @purl.pathname = '/'
    else if not (@purl.pathname is '/') and $lib.path.extname(@purl.pathname) is '' and not (@purl.pathname.length is @purl.pathname.lastIndexOf('/') + 1)
      @purl.pathname = "#{@purl.pathname}/"

    if crawly
      # Limit the query parameters to the supported set.
      @purl.query = if @purl.query? crawly.supportedParameterSubset(@purl.query) else no
      if not @purl.query and @purl.search?
        delete @purl.search
      else if @purl.query
        separator = '?'
        @purl.search = ''
        for k, v in @purl.query
          @purl.search = separator + encodeURIComponent(k) + '=' + encodeURIComponent(v)
          separator = '&'

    @purl.href = $lib.url.format(@purl)

  normalizedUrl: ()->
    @purl.href

  identityUrl: ()->
    @urlMod (p)->
      delete p.hash

  plainPath: ()->
    @urlMod (p)->
      delete p.hash
      delete p.search
      delete p.query

  urlMod: (mod)->
    clone = (o)->
      c = {}
      for key of o
        if o.hasOwnProperty key
          if typeof o[key] is 'object'
            c[key] = clone o[key]
          else
            c[key] = o[key]
      c
    mpurl = clone @purl
    mod mpurl
    $lib.url.format mpurl

