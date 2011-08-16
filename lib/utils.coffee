crypto = require 'crypto'

module.exports =
  sha1: (data, salt)->
    sha1 = crypto.createHash 'sha1'
    sha1.update data
    if salt
      sha1.update salt
    sha1.digest 'hex'

  randomSha1: ()->
    @sha1(Math.random() + ':' + new Date().getTime())

  isEmptyObject: (ob)->
    for key of ob
      if ob.hasOwnProperty(key)
        return no
    yes

  flattenObject: (ob)->
    modified = {}
    flatten = (base, value)->
      for skey, svalue of value
        if svalue and typeof svalue is 'object'
          flatten "#{base}:#{skey}", svalue
        else
          modified["#{base}:#{skey}"] = svalue

    for key, value of ob
      if value and typeof value is 'object'
        flatten key, value
      else
        modified[key] = value
    modified

  isArray: (t)->
    typeof t is 'object' and typeof t.pop is 'function'

  isError: (t)->
    typeof t.__proto__.name is 'string' and t.__proto__.name is 'Error'

  missingFields: (data, required)->
    missing = []
    for key of required
      if not data[required[key]]?
        missing.push(required[key])
    if missing.length then missing else false
