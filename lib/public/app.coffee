(($)->

  formatTime = (timeFormat, date) ->
    p = p = (s) ->
      (if (s < 10) then "0" + s else s)

    timeFormat.replace /hh?|HH?|mm?|ss?|tt?/g, (format) ->
      am = "AM"
      pm = "PM"
      switch format
        when "hh"
          #console.log(date)
          return (if date then p(((date.getHours() + 11) % 12) + 1) else "([0-1][0-9])")
        when "h"
          return (if date then ((date.getHours() + 11) % 12) + 1 else "([0-1]?[0-9])")
        when "HH"
          return (if date then p(date.getHours()) else "([0-2][0-9])")
        when "H"
          return (if date then date.getHours() else "([0-2]?[0-9])")
        when "mm"
          return (if date then p(date.getMinutes()) else "([0-6][0-9])")
        when "m"
          return (if date then date.getMinutes() else "([0-6]?[0-9])")
        when "ss"
          return (if date then p(date.getSeconds()) else "([0-6][0-9])")
        when "s"
          return (if date then date.getSeconds() else "([0-6]?[0-9])")
        when "t"
          return (if date then (if date.getHours() < 12 then am.substring(0, 1) else pm.substring(0, 1)) else "(" + am.substring(0, 1) + "|" + pm.substring(0, 1) + ")")
        when "tt"
          return (if date then (if date.getHours() < 12 then am else pm) else "(" + am + "|" + pm + ")")
      ""

  formatSize = (bytes) ->
    return Math.round(bytes / 1000) + 'KB'

  formatTimeInterval = (milliseconds) ->
    return Math.round(milliseconds / 1000) + 's'

  App =
    Batch: {}
    Bathes: {}
    Admin: {}
    BatchList: {}
    init: ->
      new App.Admin
      Backbone.history.start()

  App.Batch = Backbone.Model.extend
    log: ->
      console.log(@cid)

  App.Batches = Backbone.Collection.extend
    model: App.Batch
    url: 'api/batches'

  App.BatchList = Backbone.View.extend
    el: '#batch-list'

    template: _.template($("#batch-list-template").html())

    initialize: ->
      batches = @collection
      batches.bind('reset', @render, @)
      batches.fetch()

    render: ->
      @collection.each (model)=>
        vars = model.toJSON()
        created = new Date((parseInt(vars.created, 10)))
        vars.prettyCreated = formatTime('HH:mm', created)
        vars.prettySize = formatSize(vars.size)
        vars.prettyDownloadTime = formatTimeInterval(vars.download_time)
        $(@el).append(@template(vars))
      return @

  App.Admin = Backbone.Router.extend
    routes:
      "": "index"
      "stats/:batch": "stats"

    index: ->
      new App.BatchList 'collection': new App.Batches
    stats: (batch)->
      console.log(batch)

  App.init()

)(jQuery)