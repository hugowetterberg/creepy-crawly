jsdom = require 'jsdom'
url = require 'url'
css = require './css'

exports.Parser = class HtmlParser
  constructor: (@crawly, @uri, response = null)->
    if response
      response.setEncoding 'utf8'
    console.log "Parsing HTML"

  parse: (data)->
    @dom = jsdom.jsdom data, jsdom.defaultLevel,
      features:
        MutationEvents: no
        QuerySelector: yes
        FetchExternalResources: no

    links = @dom.querySelectorAll "a, link"
    for l in links
      uri = @crawly.addStartingPoint url.resolve(@uri.href, l.href), yes
      if uri and uri.alternate_href?
        l.href = uri.alternate_href

    style = @dom.querySelectorAll "style"
    for s in style
      css_parser = new css.Parser(@crawly, @uri, null)
      css_parser.parse s.innerHTML
      css_parser.end?()

    sourced = @dom.querySelectorAll "script[src], img"
    for s in sourced
      uri = @crawly.addStartingPoint url.resolve(@uri.href, s.src), yes
      if uri and uri.alternate_href?
        s.src = uri.alternate_href

  isStreaming: ()->
    return false

  isMutator: ()->
    return true

  mutatedData: ()->
    @dom.documentElement.outerHTML
