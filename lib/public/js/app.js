(function() {
  var __bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; };
  (function($) {
    var App, formatNumber, formatSize, formatTime, formatTimeInterval, roundNumber;
    roundNumber = function(number, decimal_points) {
      var decimals, exponent, i, num;
      if (!decimal_points) {
        return Math.round(number);
      }
      if (number === 0) {
        decimals = "";
        i = 0;
        while (i < decimal_points) {
          decimals += "0";
          i++;
        }
        return "0." + decimals;
      }
      exponent = Math.pow(10, decimal_points);
      num = Math.round(number * exponent).toString();
      return num.slice(0, -1 * decimal_points) + "." + num.slice(-1 * decimal_points);
    };
    formatTime = function(timeFormat, date) {
      var p;
      p = p = function(s) {
        if (s < 10) {
          return "0" + s;
        } else {
          return s;
        }
      };
      return timeFormat.replace(/hh?|HH?|mm?|ss?|tt?/g, function(format) {
        var am, pm;
        am = "AM";
        pm = "PM";
        switch (format) {
          case "hh":
            if (date) {
              return p(((date.getHours() + 11) % 12) + 1);
            } else {
              return "([0-1][0-9])";
            }
          case "h":
            if (date) {
              return ((date.getHours() + 11) % 12) + 1;
            } else {
              return "([0-1]?[0-9])";
            }
          case "HH":
            if (date) {
              return p(date.getHours());
            } else {
              return "([0-2][0-9])";
            }
          case "H":
            if (date) {
              return date.getHours();
            } else {
              return "([0-2]?[0-9])";
            }
          case "mm":
            if (date) {
              return p(date.getMinutes());
            } else {
              return "([0-6][0-9])";
            }
          case "m":
            if (date) {
              return date.getMinutes();
            } else {
              return "([0-6]?[0-9])";
            }
          case "ss":
            if (date) {
              return p(date.getSeconds());
            } else {
              return "([0-6][0-9])";
            }
          case "s":
            if (date) {
              return date.getSeconds();
            } else {
              return "([0-6]?[0-9])";
            }
          case "t":
            if (date) {
              if (date.getHours() < 12) {
                return am.substring(0, 1);
              } else {
                return pm.substring(0, 1);
              }
            } else {
              return "(" + am.substring(0, 1) + "|" + pm.substring(0, 1) + ")";
            }
          case "tt":
            if (date) {
              if (date.getHours() < 12) {
                return am;
              } else {
                return pm;
              }
            } else {
              return "(" + am + "|" + pm + ")";
            }
        }
        return "";
      });
    };
    formatSize = function(n) {
      var m, _i, _len, _ref;
      _ref = ['B', 'K', 'M', 'G'];
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        m = _ref[_i];
        if (n <= 1024 || m === 'G') {
          return roundNumber(n, 2) + m;
        } else {
          n = n / 1024;
        }
      }
    };
    formatTimeInterval = function(milliseconds) {
      return Math.round(milliseconds / 1000) + 's';
    };
    formatNumber = function(num) {
      return num;
    };
    App = {
      urlRoot: '/api/batches',
      init: function() {
        new App.Admin;
        return Backbone.history.start();
      }
    };
    App.Batch = Backbone.Model.extend({
      urlRoot: 'api/batches'
    });
    App.Batches = Backbone.Collection.extend({
      model: App.Batch,
      url: 'api/batches'
    });
    App.BatchList = Backbone.View.extend({
      el: '#view',
      template: _.template($("#batch-list-template").html()),
      initialize: function() {
        var batches;
        batches = this.collection;
        batches.bind('reset', this.render, this);
        return batches.fetch();
      },
      render: function() {
        $(this.el).html('');
        this.collection.each(__bind(function(model) {
          var created, vars;
          vars = model.toJSON();
          created = new Date(parseInt(vars.created, 10));
          vars.prettyCreated = formatTime('HH:mm', created);
          vars.prettySize = formatSize(vars.size);
          vars.prettyDownloadTime = formatTimeInterval(vars.download_time);
          return $(this.el).append(this.template(vars));
        }, this));
        return this;
      }
    });
    App.BatchStats = Backbone.View.extend({
      el: '#view',
      batchStatsTemplate: _.template($("#batch-stats-template").html()),
      statsTableRowTemplate: _.template($("#stats-table-row-template").html()),
      statsTableTemplate: _.template($("#stats-table-template").html()),
      initialize: function() {
        var batch;
        batch = this.model;
        batch.bind('change', this.render, this);
        return batch.fetch();
      },
      render: function() {
        var created, mime, mimes, pie, rows, stat, table, vars;
        pie = function(stats, elementID, formater) {
          var labels, numbers;
          numbers = [];
          labels = [];
          _.each(stats, function(num, mime) {
            var label;
            numbers.push((num / vars.files) * 100);
            label = mime.split('/')[1];
            return labels.push(label + "\n" + formater(num));
          });
          return Raphael(elementID, 400, 400).pieChart(200, 200, 100, numbers, labels, "#fff");
        };
        vars = this.model.toJSON();
        mimes = {};
        for (stat in vars.stats) {
          for (mime in vars.stats[stat]) {
            if (!mimes[mime]) {
              mimes[mime] = {};
            }
            mimes[mime][stat] = vars.stats[stat][mime];
          }
        }
        rows = '';
        for (mime in mimes) {
          rowData = mimes[mime];
          rowData.type = mime;
          rowData.prettyCreated = formatTime('HH:mm', created);
          rowData.prettySize = formatSize(rowData.size);
          rowData.prettyDownloadTime = formatTimeInterval(rowData.download_time);
          rows += this.statsTableRowTemplate(rowData);
        }
        created = new Date(parseInt(vars.created, 10));
        vars.prettyCreated = formatTime('HH:mm', created);
        vars.prettySize = formatSize(vars.size);
        vars.prettyDownloadTime = formatTimeInterval(vars.download_time);
        $("h2").html('<a href="/">' + $("h2").text() + '</a> <span class="divider">/</span> Batch ' + this.model.id);
        $(this.el).html(this.batchStatsTemplate(vars));
        table = this.statsTableTemplate({
          rows: rows
        });
        $(this.el).append(table);
        pie(vars.stats.files, "chart-files", formatNumber);
        pie(vars.stats.size, "chart-size", formatSize);
        pie(vars.stats.download_time, "chart-download-time", formatTimeInterval);
        return this;
      }
    });
    App.Admin = Backbone.Router.extend({
      routes: {
        "": "index",
        "stats/:batch": "stats"
      },
      index: function() {
        return new App.BatchList({
          'collection': new App.Batches
        });
      },
      stats: function(batch) {
        var b;
        b = new App.Batch({
          'id': batch
        });
        return new App.BatchStats({
          'model': b
        });
      }
    });
    return App.init();
  })(jQuery);
}).call(this);
