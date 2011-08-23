creepy = require './creepy'
path = require 'path'
redis = require 'redis'

directory = path.resolve(process.argv[2])

domain = 'golabs.local'
if process.argv.length > 3
  domain = process.argv[3]

db = redis.createClient()

crawly = new creepy.Crawly(directory, db)
crawly.addDomain(domain)
crawly.addSupportedParameters ['page']

