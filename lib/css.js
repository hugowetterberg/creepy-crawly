(function() {
  var CssParser, r_url, r_url_argument, url;
  url = require('url');
  r_url = /url\([^)]+\)/g;
  r_url_argument = /\(['"]?(.*)['"]?\)/;
  exports.Parser = CssParser = (function() {
    function CssParser(crawly, uri, response) {
      this.crawly = crawly;
      this.uri = uri;
      if (response == null) {
        response = null;
      }
      if (response) {
        response.setEncoding('utf8');
      }
      console.log("Parsing CSS");
    }
    CssParser.prototype.parse = function(data) {
      var match, url_match, urls, _i, _len, _results;
      urls = data.match(r_url);
      if (urls) {
        _results = [];
        for (_i = 0, _len = urls.length; _i < _len; _i++) {
          url_match = urls[_i];
          match = url_match.match(r_url_argument);
          _results.push(match ? this.crawly.addStartingPoint(url.resolve(this.uri.href, match[1])) : void 0);
        }
        return _results;
      }
    };
    CssParser.prototype.isStreaming = function() {
      return false;
    };
    CssParser.prototype.isMutator = function() {
      return false;
    };
    return CssParser;
  })();
}).call(this);
