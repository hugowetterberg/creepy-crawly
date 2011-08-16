jsdom = require 'jsdom'
fs = require 'fs'
htmlencoding = require 'jsdom/lib/jsdom/browser/htmlencoding'
htmlmini = require 'html-minifier'
url = require 'url'
css = require './css'

exports.Parser = class HtmlParser
  constructor: (@crawly, @uri, response = null)->
    if response
      response.setEncoding 'utf8'
    console.log "Parsing HTML"
    @db = @crawly.getRedis()

  parse: (data)->
    @dom = jsdom.jsdom data, jsdom.defaultLevel,
      url: @uri.href
      features:
        MutationEvents: no
        QuerySelector: yes
        FetchExternalResources: no

    title = @dom.querySelector("title")
    if title
      @crawly.setUriInfo @uri.href, 'title', title.innerHTML
    user_link = @dom.querySelectorAll ".username"
    for l in user_link
      console.log "Userlink"
      console.dir l.outerHTML
    
    links = @dom.querySelectorAll "a, link"
    for l in links
      href = l.attributes.getNamedItem 'href'
      if href
        uri = @crawly.addStartingPoint url.resolve(@uri.href, href.nodeValue), yes
        if uri
          @crawly.registerOutLink @uri, uri
        if uri and uri.alternate_href?
          l.href = uri.alternate_href
    
    style = @dom.querySelectorAll "style"
    for s in style
      css_parser = new css.Parser(@crawly, @uri, null)
      css_parser.parse htmlencoding.HTMLDecode(s.innerHTML)
      css_parser.end?()
      if css_parser.isMutator()
        s.innerHTML = css_parser.mutatedData()
    
    sourced = @dom.querySelectorAll "script[src], img"
    for s in sourced
      uri = @crawly.addStartingPoint url.resolve(@uri.href, s.src), yes
      if uri
        @crawly.registerOutLink @uri, uri
      if uri and uri.alternate_href?
        s.src = uri.alternate_href

  isStreaming: ()->
    return false

  isMutator: ()->
    return true

  mutatedData: ()->
    htmlmini.minify @dom.documentElement.outerHTML,
      removeComments: yes
      removeCommentsFromCDATA: yes
      removeCDATASectionsFromCDATA: yes
      #collapseWhitespace: yes
      collapseBooleanAttributes: yes
      removeAttributeQuotes: yes
      removeRedundantAttributes: yes    
      removeEmptyAttributes: yes
      removeEmptyElements: yes
      removeOptionalTags: yes      
      removeScriptTypeAttributes: yes