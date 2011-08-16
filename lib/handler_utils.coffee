path = require 'path'
utils = require './utils'

exports.add = (module, method, path, handler)->
  segments = path.split '/'
  segments.unshift 'handlers', method
  console.dir segments
  current = module
  for seg in segments
    if not current[seg]?
      current[seg] = {}
    current = current[seg]
  current['#handler'] = handler

exports.errorResponseIfMissing = (api, data, required, names)->
  missing = utils.missingFields(data, required)
  if missing
    form = if missing.length > 1 then names[1] else names[0]
    api.errorResult 406, 'Missing required ' + form + ' ' + missing.join(' and '),
      data:
        missingFields: missing
    return yes
  no

exports.callMatchingHandler = (handlers, api)->
  stack = []
  components = api.purl.pathname.substr(1).split('/')
  console.dir components
  console.log api.req.method + ' ' + api.purl.pathname

  handlerHandles = (api, handler, callback)->
    if typeof handler.canHandle is 'function'
      handler.canHandle(api, components, callback)
    else
      callback(true)
    null

  stackBuild = (api, current, path, callback)->
    segment = if path.length then path.shift() else null
    if segment is null or typeof current[segment] == 'undefined'
      callback()
      return

    next = current[segment]

    if typeof next['#handler'] == 'undefined'
      stackBuild(api, next, path, callback)
    else
      handlerHandles api, next['#handler'], (canHandle)->
        if canHandle
          stack.push next['#handler']
          stackBuild(api, next, path, callback)
        else
          stackBuild(api, next, path, callback)
    null

  if typeof handlers[api.req.method] is 'undefined'
    console.log "Unsupported http method #{api.req.method}"
    api.errorResult 406, "Unsupported http method #{api.req.method}"
  else
    # Add the root handler as a default fallback if it exists.
    if handlers[api.req.method]['']?
      idx = handlers[api.req.method]['']
      if idx['#handler'] then handlerHandles api, idx, (canHandle)->
        if canHandle then stack.push(idx['#handler'])

    stackBuild api, handlers[api.req.method], components.slice(0), ()->
      handler = if stack.length then stack.pop() else null
      if handler
        try
          # Pick up on requireParameters and requireAttributes
          if handler.requireParameters? and
            exports.errorResponseIfMissing(api, api.purl.query, handler.requireParameters, ['parameter', 'parameters'])
              return null
          if handler.requireAttributes? and
            exports.errorResponseIfMissing(api, api.postData, handler.requireAttributes, ['attribute', 'attributes'])
              return null
          handler.handler(api, components)
        catch e
          api.errorResult 500, "Internal error", e
      else
        api.notFoundResult()
  null
