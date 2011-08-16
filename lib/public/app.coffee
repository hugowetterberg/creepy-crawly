(($)->
  crawly =
    sensibleErrors: (ajax)->
      originalError = ajax.error
      ajax.error = (callback)->
        originalError.apply ajax, [(jqXHR, status)->
          try
            data = JSON.parse(jqXHR.responseText)
          catch ex
            data =
              status: jqXHR.status
              message: jqXHR.statusText
          finally
            callback(data, status, jqXHR)
        ]
      ajax

    get: (url, parameters = {})->
      ajax = $.ajax
        url: url,
        type: 'GET',
        data: parameters
      @sensibleErrors(ajax)

    post: (url, data='{}')->
      if not (typeof data is 'string')
        data = JSON.stringify(data)

      ajax = $.ajax
          url: url,
          type: 'POST',
          contentType: 'application/json',
          data: data
      @sensibleErrors(ajax)

  crawly.get('/pages', {page:0}).success (data, status)->
    console.log data
)(jQuery)