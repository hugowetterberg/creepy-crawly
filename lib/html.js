(function() {
  var HtmlParser, css, jsdom, url;
  jsdom = require('jsdom');
  url = require('url');
  css = require('./css');
  exports.Parser = HtmlParser = (function() {
    function HtmlParser(crawly, uri, response) {
      this.crawly = crawly;
      this.uri = uri;
      if (response == null) {
        response = null;
      }
      if (response) {
        response.setEncoding('utf8');
      }
      console.log("Parsing HTML");
    }
    HtmlParser.prototype.parse = function(data) {
      var css_parser, l, links, s, sourced, style, uri, _i, _j, _k, _len, _len2, _len3, _results;
      this.dom = jsdom.jsdom(data, jsdom.defaultLevel, {
        features: {
          MutationEvents: false,
          QuerySelector: true,
          FetchExternalResources: false
        }
      });
      links = this.dom.querySelectorAll("a, link");
      for (_i = 0, _len = links.length; _i < _len; _i++) {
        l = links[_i];
        uri = this.crawly.addStartingPoint(url.resolve(this.uri.href, l.href), true);
        if (uri && (uri.alternate_href != null)) {
          l.href = uri.alternate_href;
        }
      }
      style = this.dom.querySelectorAll("style");
      for (_j = 0, _len2 = style.length; _j < _len2; _j++) {
        s = style[_j];
        css_parser = new css.Parser(this.crawly, this.uri, null);
        css_parser.parse(s.innerHTML);
        if (typeof css_parser.end == "function") {
          css_parser.end();
        }
      }
      sourced = this.dom.querySelectorAll("script[src], img");
      _results = [];
      for (_k = 0, _len3 = sourced.length; _k < _len3; _k++) {
        s = sourced[_k];
        uri = this.crawly.addStartingPoint(url.resolve(this.uri.href, s.src), true);
        _results.push(uri && (uri.alternate_href != null) ? s.src = uri.alternate_href : void 0);
      }
      return _results;
    };
    HtmlParser.prototype.isStreaming = function() {
      return false;
    };
    HtmlParser.prototype.isMutator = function() {
      return true;
    };
    HtmlParser.prototype.mutatedData = function() {
      return this.dom.documentElement.outerHTML;
    };
    return HtmlParser;
  })();
}).call(this);
