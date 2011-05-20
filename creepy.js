(function() {
  var Crawly, crypto, events, fs, http, mkdirp, parsers, path, url;
  var __hasProp = Object.prototype.hasOwnProperty, __extends = function(child, parent) {
    for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; }
    function ctor() { this.constructor = child; }
    ctor.prototype = parent.prototype;
    child.prototype = new ctor;
    child.__super__ = parent.prototype;
    return child;
  }, __bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; };
  url = require('url');
  http = require('http');
  fs = require('fs');
  path = require('path');
  mkdirp = require('npm/lib/utils/mkdir-p');
  crypto = require('crypto');
  events = require('events');
  parsers = {
    'text/html': require('./lib/html'),
    'text/css': require('./lib/css')
  };
  exports.Crawly = Crawly = (function() {
    __extends(Crawly, events.EventEmitter);
    function Crawly(output_directory, db) {
      this.output_directory = output_directory;
      this.db = db;
      this.domains = {};
      this.crawl_queue = [];
      this.crawled = {};
      this.variants = {};
      this.parameters = {};
      this.startingPointBatch = 0;
      null;
    }
    Crawly.prototype.addDomain = function(domain) {
      return this.domains[domain] = true;
    };
    Crawly.prototype.addSupportedParameters = function(parameters) {
      var parameter, _i, _len;
      for (_i = 0, _len = parameters.length; _i < _len; _i++) {
        parameter = parameters[_i];
        this.parameters[parameter] = true;
      }
      return null;
    };
    Crawly.prototype.hasSupportedParameter = function(query) {
      var key;
      for (key in query) {
        if (this.parameters[key] != null) {
          return true;
        }
      }
      return false;
    };
    Crawly.prototype.urlMod = function(uri, mod) {
      var puri;
      puri = typeof uri === 'object' ? url.parse(url.format(uri)) : url.parse(uri, true);
      mod(puri);
      return url.format(puri);
    };
    Crawly.prototype.addingStartingPoint = function() {
      return this.startingPointBatch++;
    };
    Crawly.prototype.startingPointAdded = function(puri) {
      this.startingPointBatch--;
      this.emit('starting_point_added', puri);
      if (!this.startingPointBatch) {
        this.emit('starting_point_batch_finished');
      }
      return null;
    };
    Crawly.prototype.onceStartingPointBatchFinishes = function(callback) {
      if (!this.startingPointBatch) {
        callback();
      } else {
        this.once('starting_point_batch_finished', callback);
      }
      return null;
    };
    Crawly.prototype.addStartingPoint = function(uri, mutating, callback) {
      var append, hash, key, norm, plain_href, puri, save, value;
      if (mutating == null) {
        mutating = false;
      }
      if (callback == null) {
        callback = null;
      }
      this.addingStartingPoint();
      puri = url.parse(uri, true);
      if (!callback) {
        callback = function() {};
      }
      if (typeof this.domains[puri.hostname] === 'undefined') {
        return false;
      }
      if (!(puri.port != null)) {
        puri.port = puri.protocol === 'https:' ? 443 : 80;
      }
      if (!(puri.pathname != null) || puri.pathname === '') {
        puri.pathname = '/';
      }
      norm = url.format(puri);
      puri.href = norm;
      plain_href = puri.search != null ? this.urlMod(norm, function(uri) {
        delete uri.search;
        return delete uri.query;
      }) : puri.href;
      if (puri.pathname === '/') {
        puri.file_path = path.resolve(this.output_directory, 'index.html');
      } else if (path.extname(puri.pathname) === '') {
        puri.file_path = path.resolve(this.output_directory, path.join(puri.pathname.substr(1), 'index.html'));
      } else {
        puri.file_path = path.resolve(this.output_directory, puri.pathname.substr(1));
      }
      if (mutating && (puri.search != null) && this.hasSupportedParameter(puri.query)) {
        hash = crypto.createHash('sha1');
        hash.update(puri.search);
        append = '.' + hash.digest('hex') + path.extname(puri.file_path);
        norm = puri.pathname === '/' || path.extname(puri.pathname) === '' ? this.urlMod(norm, function(uri) {
          return uri.pathname = path.join(puri.pathname, 'index.html' + append);
        }) : plain_href + append;
        puri.file_path += append;
        puri.alternate_href = norm;
      } else {
        norm = plain_href;
      }
      hash = crypto.createHash('sha1');
      hash.update(norm);
      puri.sha1 = hash.digest('hex');
      puri.queued = new Date().getTime();
      save = {
        serialized: []
      };
      for (key in puri) {
        value = puri[key];
        if (typeof value === 'object') {
          value = JSON.stringify(value);
          save.serialized.push(key);
        }
        save[key] = value;
      }
      save.serialized = JSON.stringify(save.serialized);
      this.db.hget('crawl_state', puri.sha1, __bind(function(error, state) {
        if (!state) {
          return this.db.multi().sadd('crawl_queue', puri.sha1).hmset("uri:" + puri.sha1, save).exec(__bind(function(error, results) {
            console.log("Queued: " + puri.sha1 + " (" + norm + ")");
            this.startingPointAdded(puri, true);
            return callback(puri, true);
          }, this));
        } else {
          this.startingPointAdded(puri, false);
          return callback(puri, false);
        }
      }, this));
      return puri;
    };
    Crawly.prototype.crawl = function() {
      if (!path.existsSync(this.output_directory)) {
        mkdirp(this.output_directory, function() {});
      }
      return this.onceStartingPointBatchFinishes(__bind(function() {
        return this.db.spop('crawl_queue', __bind(function(error, sha1) {
          if (!error && sha1) {
            console.log("Got sha1 " + sha1 + " from queue");
            return this.crawlNext(sha1, __bind(function(error, status) {
              return this.crawl();
            }, this));
          } else if (error) {
            return console.log("Error while fetching jobs from queue " + error);
          } else if (!sha1) {
            return console.log("The queue is empty");
          }
        }, this));
      }, this));
    };
    Crawly.prototype.crawlNext = function(sha1, callback) {
      var done;
      done = __bind(function(error, status) {
        return this.db.hset('crawl_state', sha1, 'crawled', function() {
          return callback(error, status);
        });
      }, this);
      console.log("Loading info for " + sha1);
      return this.db.multi().hset('crawl_state', sha1, 'in_progress').hgetall("uri:" + sha1).exec(__bind(function(error, results) {
        var dir, key, state_set, uri, _i, _len, _ref;
        state_set = results[0], uri = results[1];
        uri.serialized = JSON.parse(uri.serialized);
        _ref = uri.serialized;
        for (_i = 0, _len = _ref.length; _i < _len; _i++) {
          key = _ref[_i];
          uri[key] = JSON.parse(uri[key]);
        }
        dir = path.dirname(uri.file_path);
        if (!path.existsSync(dir)) {
          return mkdirp(dir, __bind(function() {
            return this.download(uri, done);
          }, this));
        } else {
          return this.download(uri, done);
        }
      }, this));
    };
    Crawly.prototype.download = function(uri, callback) {
      var req_opts, request;
      req_opts = {
        host: uri.hostname,
        port: uri.port,
        path: uri.pathname,
        headers: {
          'X-Purpose': 'bake'
        }
      };
      if (uri.search != null) {
        req_opts.path += uri.search;
      }
      request = http.request(req_opts, __bind(function(response) {
        var body, cpos, file, mime_type, parser;
        file = fs.openSync(uri.file_path, 'w');
        mime_type = response.headers['content-type'];
        if (!((cpos = mime_type.indexOf(';')) === -1)) {
          mime_type = mime_type.substr(0, cpos);
        }
        console.log("" + uri.href + " is " + mime_type);
        if (typeof parsers[mime_type] === 'object') {
          parser = new parsers[mime_type].Parser(this, uri, response);
          body = "";
          response.on("data", function(chunk) {
            var buffer;
            body += chunk;
            buffer = new Buffer(chunk);
            if (!parser.isMutator()) {
              fs.write(file, buffer, 0, buffer.length, null);
            }
            if (parser.isStreaming()) {
              return parser.parse(chunk);
            }
          });
          return response.on("end", function() {
            var buffer;
            if (!parser.isStreaming()) {
              parser.parse(body);
            }
            if (typeof parser.end == "function") {
              parser.end();
            }
            if (parser.isMutator()) {
              buffer = new Buffer(parser.mutatedData());
              fs.write(file, buffer, 0, buffer.length, null);
            }
            fs.close(file);
            return callback();
          });
        } else {
          response.on("data", function(chunk) {
            return fs.write(file, chunk, 0, chunk.length, null);
          });
          return response.on("end", function() {
            fs.close(file);
            return callback();
          });
        }
      }, this));
      return request.end();
    };
    return Crawly;
  })();
}).call(this);
