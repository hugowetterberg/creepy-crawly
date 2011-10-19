
module.exports = class Store
  constructor: (@creepy)->
    null

  checkNonce: (credentials, nonce, callback)->
    callback no, yes # Always accept nonces
    null

  getCredentials: (key, callback)->
    if key is 'foo' # Placeholder credentials
      callback no,
        key: 'foo'
        secret: 'bar'
    else if key is 'fail'
      callback new Error('Simulated failure'), null
    else # Not found
      callback no, null
