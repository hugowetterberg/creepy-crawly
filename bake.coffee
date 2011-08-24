creepy = require './creepy'
path = require 'path'
redis = require 'redis'

directory = path.resolve(process.argv[2])

domain = 'golabs.local'
if process.argv.length > 3
  domain = process.argv[3]
start = "http://#{domain}"

console.log "Baking #{domain} to #{directory}"

db_connection = ()-> redis.createClient()

crawly = new creepy.Crawly(directory, db_connection)
crawly.setDomain(domain)
crawly.addSupportedParameters ['page']
crawly.startBatch ()->
  crawly.addStartingPoint start
  crawly.crawl()
