creepy = require './creepy'
path = require 'path'
fs = require 'fs'
redis = require 'redis'

fs.readFile "crawl.json", "utf-8", (error, data)->
  if error then throw error

  config = JSON.parse(data)

  db_connection = ()-> redis.createClient()
  crawly = new creepy.Crawly(config.directory, db_connection)
  crawly.setDomain(config.domain)

  if config.supported_paramaters?
    crawly.addSupportedParameters config.supported_paramaters
  else
    crawly.addSupportedParameters ['page']

  if config.starting_point?
    crawly.startBatch ()->
      crawly.addStartingPoint config.starting_point, yes, ()->
        console.log "Starting point added, crawling"
        crawly.crawl()
