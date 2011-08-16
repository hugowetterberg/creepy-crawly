url = require 'url'

r_url = /url\([^)]+\)/g
r_url_argument = /\(['"]?(.*[^'"])['"]?\)/

exports.Parser = class CssParser
  constructor: (@crawly, @uri, response = null)->
    if response
      response.setEncoding('utf8')
    console.log "Parsing CSS"

  parse: (data)->
    urls = data.match(r_url)
    @mutated = data.replace r_url, (url_match)=>
      match = url_match.match(r_url_argument)
      if match
        console.log "Found uri reference in css #{match[1]}"
        puri = @crawly.addStartingPoint url.resolve(@uri.href, match[1]), yes
        if puri
          console.log "¶¶ Registering outlink from #{@uri.href} to #{puri.href}"
          console.dir puri
          @crawly.registerOutLink @uri, puri
        if puri and puri.alternate_href?
          return "url(\"#{puri.alternate_href}\")"
      url_match

  isStreaming: ()->
    return no

  isMutator: ()->
    return yes

  mutatedData: ()->
    @mutated