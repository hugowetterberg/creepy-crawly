url = require 'url'

r_url = /url\([^)]+\)/g
r_url_argument = /\(['"]?(.*)['"]?\)/

exports.Parser = class CssParser
  constructor: (@crawly, @uri, response = null)->
    if response
      response.setEncoding('utf8')
    console.log "Parsing CSS"

  parse: (data)->
    urls = data.match(r_url)
    if urls
      for url_match in urls
        match = url_match.match(r_url_argument)
        if match
          @crawly.addStartingPoint url.resolve(@uri.href, match[1])

  isStreaming: ()->
    return false

  isMutator: ()->
    return false