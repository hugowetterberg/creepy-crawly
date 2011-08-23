utils = require './utils'
path = require 'path'
handler_utils = require './handler_utils'

###
The request handlers.
###

# Static files fallback
### SYMBOL:GET ###
handler_utils.add exports, 'GET', '',
  handler: (api, components)->
    file_path = components.join('/')
    if file_path is ''
      file_path = 'index.html'
    mime = switch path.extname(file_path)
      when '.html', '.htm' then 'text/html'
      when '.js' then 'application/javascript'
      when '.css' then 'text/css'
      when '.png' then 'image/png'
      when '.jpg', '.jpeg' then 'image/jpeg'
      else 'text/plain'
    api.passthrough(file_path, mime)
    null

# Get start page
### SYMBOL:GET pages ###
handler_utils.add exports, 'GET', 'pages',
  handler: (api, components)->
    db = api.crawly.getRedis()
    page = if api.purl.query['page'] then api.purl.query['page'] else 0
    db.zrevrange 'uri:score', page*20, page*20+19, 'WITHSCORES', (err, result)->
      if not err
        api.result result
      else
        api.errorResult 501, 'Could not fetch pages from database'
    null

# Add a starting point
### SYMBOL:POST api/add-starting-point ###
handler_utils.add exports, 'POST', 'api/add-starting-point',
  requireAttributes: ['url']
  handler: (api, components)->
    api.crawly.addStartingPoint 
    api.result 'ok'
    null

# Start crawling
### SYMBOL:POST api/crawl ###
handler_utils.add exports, 'POST', 'api/crawl',
  handler: (api, components)->
    api.result 'ok'
    null