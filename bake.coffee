creepy = require './creepy'
path = require 'path'
redis = require 'redis'

directory = path.resolve(process.argv[2])

domain = 'bibsvar.local'
if process.argv.length > 3
  domain = process.argv[3]
start = "http://#{domain}"

console.log "Baking #{domain} to #{directory}"

db = redis.createClient()

crawly = new creepy.Crawly(directory, db)
crawly.addDomain(domain)
crawly.addSupportedParameters ['page']
crawly.addStartingPoint start, yes
crawly.crawl()
