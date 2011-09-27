cu = require './creepy_url'
creepy = require './creepy'
crawly = new creepy.Crawly(no, ->)
crawly.addSupportedParameters ['id', 'page']

test_urls = [
  "http://www.example.com/templates/Page.aspx?id=17535&epslanguage=SV#do-the-fragment",
  "https://www.example.com",
  "http://www.example.com:80/",
  "http://www.example.com",
]
output_tests = ['normalizedUrl', 'identityUrl', 'plainPath']

console.log
for url in test_urls
  console.log "\nTesting #{url}"
  curl = new cu.CreepyUrl(url, crawly)
  for method in output_tests
    console.log "#{method}:"
    console.log curl[method]()
