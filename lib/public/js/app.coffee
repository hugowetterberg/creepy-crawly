(($)->

  roundNumber = (number, decimal_points) ->
    return Math.round(number)  unless decimal_points
    if number is 0
      decimals = ""
      i = 0

      while i < decimal_points
        decimals += "0"
        i++
      return "0." + decimals
    exponent = Math.pow(10, decimal_points)
    num = Math.round((number * exponent)).toString()
    num.slice(0, -1 * decimal_points) + "." + num.slice(-1 * decimal_points)

  formatTime = (timeFormat, date) ->
    p = p = (s) ->
      (if (s < 10) then "0" + s else s)

    timeFormat.replace /hh?|HH?|mm?|ss?|tt?/g, (format) ->
      am = "AM"
      pm = "PM"
      switch format
        when "hh"
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

  formatSize = (n) ->
    for m in ['B', 'K', 'M', 'G']
      if n <= 1024 or m == 'G'
        return roundNumber(n, 2) + m
      else
        n = n / 1024

  formatTimeInterval = (milliseconds) ->
    return Math.round(milliseconds / 1000) + 's'

  formatNumber = (num) ->
    return num

  App =
    urlRoot: '/api/batches'
    init: ->
      new App.Admin
      Backbone.history.start()

  App.Batch = Backbone.Model.extend
    urlRoot: 'api/batches'

  App.Batches = Backbone.Collection.extend
    model: App.Batch
    url: 'api/batches'

  App.BatchList = Backbone.View.extend
    el: '#view'

    template: _.template($("#batch-list-template").html())

    initialize: ->
      batches = @collection
      batches.bind('reset', @render, @)
      batches.fetch()

    render: ->
      $(@el).html('');
      @collection.each (model)=>
        vars = model.toJSON()
        created = new Date((parseInt(vars.created, 10)))
        vars.prettyCreated = formatTime('HH:mm', created)
        vars.prettySize = formatSize(vars.size)
        vars.prettyDownloadTime = formatTimeInterval(vars.download_time)
        $(@el).append(@template(vars))
      return @

  App.BatchStats = Backbone.View.extend
    el: '#view'

    batchStatsTemplate: _.template($("#batch-stats-template").html())
    statsTableRowTemplate: _.template($("#stats-table-row-template").html())
    statsTableTemplate: _.template($("#stats-table-template").html())

    initialize: ->
      batch = @model
      batch.bind('change', @render, @)
      batch.fetch()

    render: ->
      pie = (stats, elementID, formater)->
        numbers = []
        labels = []
        _.each stats, (num, mime)->
          numbers.push (num/vars.files) * 100
          label = mime.split('/')[1]
          labels.push label + "\n" + formater(num)
        Raphael(elementID, 400, 400).pieChart(200, 200, 100, numbers, labels, "#fff");

      vars = @model.toJSON()
      mimes = {}
      for stat of vars.stats
        for mime of vars.stats[stat]
          if not mimes[mime] then mimes[mime] = {}
          mimes[mime][stat] = vars.stats[stat][mime]

      rows = ''
      for mime of mimes
        vars = mimes[mime]
        vars.type = mime
        vars.prettyCreated = formatTime('HH:mm', created)
        vars.prettySize = formatSize(vars.size)
        vars.prettyDownloadTime = formatTimeInterval(vars.download_time)
        rows += @statsTableRowTemplate vars



      created = new Date((parseInt(vars.created, 10)))
      vars.prettyCreated = formatTime('HH:mm', created)
      vars.prettySize = formatSize(vars.size)
      vars.prettyDownloadTime = formatTimeInterval(vars.download_time)
      $("h2").html '<a href="/">' + $("h2").text() + '</a> <span class="divider">/</span> Batch ' + @model.id
      $(@el).html @batchStatsTemplate vars
      table = @statsTableTemplate {rows: rows}
      $(@el).append table

      pie vars.stats.files, "chart-files", formatNumber
      pie vars.stats.size, "chart-size", formatSize
      pie vars.stats.download_time, "chart-download-time", formatTimeInterval
      # Table


      return @

  App.Admin = Backbone.Router.extend
    routes:
      "": "index"
      "stats/:batch": "stats"

    index: ->
      new App.BatchList 'collection': new App.Batches
    stats: (batch)->
      b = new App.Batch 'id': batch
      new App.BatchStats 'model': b

  App.init()

)(jQuery)
