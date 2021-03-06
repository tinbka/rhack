/*
 * Simulated browser environment for Rhino
 *   By John Resig <http://ejohn.org/>
 * Copyright 2007 John Resig, under the MIT License
 */

// The window Object
var window = this;

//Ruby.require("uri");

print = function(txt) { Ruby.puts(txt); };

(function(){

  // Browser Navigator

  window.navigator = {
    get userAgent(){
      return "Mozilla/5.0 (Macintosh; U; Intel Mac OS X; en-US; rv:1.8.1.3) Gecko/20070309 Firefox/2.0.0.3";
    }
  };
/*  
  var fileToUrl = function(file) {
    return Ruby.URI.parse("file://" + Ruby.File.expand_path(file));
  };
  
  var curLocation = fileToUrl(".");
  /*
  window.__defineSetter__("location", function(url){
    var xhr = new XMLHttpRequest();
    xhr.open("GET", url);
    xhr.onreadystatechange = function(){
      curLocation = curLocation.merge(url);
      window.document = xhr.responseXML;

      if(window.document) {
        var event = document.createEvent();
        event.initEvent("load");
        window.dispatchEvent( event );
      }
    };
    xhr.send();
  });
  
  window.__defineGetter__("location", function(url){
    return {
      get protocol(){
        return curLocation.scheme() + ":";
      },
      get href(){
        return curLocation.toString();
      },
      toString: function(){
        return this.href.toString();
      }
    };
  });
  */
  
  // Timers

  var timers = [];
  
  window.setTimeout = function(fn, time){
    var num;
    return num = setInterval(function(){
      fn();
      clearInterval(num);
    }, time);
  };
  
  window.setInterval = function(fn, time){
    var num = timers.length;
    
    timers[num] = new Ruby.Thread(function() {
      while(true) {
        Ruby.sleep(time);
        fn();
      }
    });
  
    return num;
  };
  
  window.clearInterval = function(num){
    if ( timers[num] ) {
      timers[num].kill();
      delete timers[num];
    }
  };
  
  // Window Events
  
  var events = [{}];

  window.addEventListener = function(type, fn){
    if ( !this.uuid || this == window ) {
      this.uuid = events.length;
      events[this.uuid] = {};
    }
     
    if ( !events[this.uuid][type] )
      events[this.uuid][type] = [];
    
    if ( events[this.uuid][type].indexOf( fn ) < 0 )
      events[this.uuid][type].push( fn );
  };
  
  window.removeEventListener = function(type, fn){
     if ( !this.uuid || this == window ) {
         this.uuid = events.length;
         events[this.uuid] = {};
     }
     
     if ( !events[this.uuid][type] )
      events[this.uuid][type] = [];
      
    events[this.uuid][type] =
      events[this.uuid][type].filter(function(f){
        return f != fn;
      });
  };
  
  window.dispatchEvent = function(event){
    if ( event.type ) {
      if ( this.uuid && events[this.uuid][event.type] ) {
        var self = this;
      
        events[this.uuid][event.type].forEach(function(fn){
          fn.call( self, event );
        });
      }
      
      if ( this["on" + event.type] )
        this["on" + event.type].call( self, event );
    }
  };
  
  // DOM Document
  
  window.DOMDocument = function(file){
    this._file = file;
    var parser = new W3CDOMImplementation();
    try {
      this._dom = parser.loadXML(file);
    } catch(e) {
      Ruby.puts("*** wycats to fix: " + parser.translateErrCode(e.code));
      throw parser.translateErrCode(e.code);
    }
    
    if ( !obj_nodes["key?"]( this._dom ) )
      obj_nodes[this._dom] = this;
  };
  
  DOMDocument.prototype = {
    nodeType: 1,
    write: function(str) {
      if (typeof(write_output) != 'undefined')
        write_output += str;
    },
    createTextNode: function(text){
      return makeNode( this._dom.createTextNode(
        text.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")) );
    },
    createElement: function(name){
      return makeNode( this._dom.createElement(name.toLowerCase()) );
    },
    getElementsByTagName: function(name){
      return new DOMNodeList( this._dom.getElementsByTagName(
        name.toLowerCase()) );
    },
    getElementById: function(id){
      return makeNode( this._dom.getElementById(id) );
    },
    get body(){
      return this.getElementsByTagName("body")[0];
    },
    get documentElement(){
      return makeNode( this._dom.getDocumentElement() );
    },
    get ownerDocument(){
      return null;
    },
    addEventListener: window.addEventListener,
    removeEventListener: window.removeEventListener,
    dispatchEvent: window.dispatchEvent,
    get nodeName() {
      return "#document";
    },
    importNode: function(node, deep){
      return makeNode( this._dom.importNode(node._dom, deep) );
    },
    toString: function(){
      return "Document" + (typeof this._file == "string" ?
        ": " + this._file : "");
    },
    get innerHTML(){
      return this.documentElement.outerHTML;
    },
    
    get defaultView(){
      return {
        getComputedStyle: function(elem){
          return {
            getPropertyValue: function(prop){
              prop = prop.replace(/\-(\w)/g,function(m,c){
                return c.toUpperCase();
              });
              var val = elem.style[prop];
              
              if ( prop === "opacity" && val === "" )
                val = "1";
                
              return val;
            }
          };
        }
      };
    },
    
    createEvent: function(){
      return {
        type: "",
        initEvent: function(type){
          this.type = type;
        }
      };
    }
  };
  
  function getDocument(node){
    return obj_nodes[node];
  }
  
  // DOM NodeList
  
  window.DOMNodeList = function(list){
    this._dom = list;
    this.length = list.getLength();
    
    for ( var i = 0; i < this.length; i++ ) {
      var node = list.item(i);
      this[i] = makeNode( node );
    }
  };
  
  DOMNodeList.prototype = {
    toString: function(){
      return "[ " +
        Array.prototype.join.call( this, ", " ) + " ]";
    },
    get outerHTML(){
      return Array.prototype.map.call(
        this, function(node){return node.outerHTML;}).join('');
    }
  };
  
  // DOM Node
  
  window.DOMNode = function(node){
    this._dom = node;
  };
  
  DOMNode.prototype = {
    get nodeType(){
      return this._dom.getNodeType();
    },
    get nodeValue(){
      return this._dom.getNodeValue();
    },
    get nodeName() {
      return this._dom.getNodeName();
    },
    cloneNode: function(deep){
      return makeNode( this._dom.cloneNode(deep) );
    },
    get ownerDocument(){
      return getDocument( this._dom.getOwnerDocument() );
    },
    get documentElement(){
      return makeNode( this._dom.getDocumentElement() );
    },
    get parentNode() {
      return makeNode( this._dom.getParentNode() );
    },
    get nextSibling() {
      return makeNode( this._dom.getNextSibling() );
    },
    get previousSibling() {
      return makeNode( this._dom.getPreviousSibling() );
    },
    toString: function(){
      return '"' + this.nodeValue + '"';
    },
    get outerHTML(){
      return this.nodeValue;
    }
  };

  // DOM Element

  window.DOMElement = function(elem){
    this._dom = elem;
    this.style = {
      get opacity(){ return this._opacity; },
      set opacity(val){ this._opacity = val + ""; }
    };
    
    // Load CSS info
    var styles = (this.getAttribute("style") || "").split(/\s*;\s*/);
    
    for ( var i = 0; i < styles.length; i++ ) {
      var style = styles[i].split(/\s*:\s*/);
      if ( style.length == 2 )
        this.style[ style[0] ] = style[1];
    }
  };
  
  DOMElement.prototype = extend( new DOMNode(), {
    get nodeName(){
      return this.tagName.toUpperCase();
    },
    get tagName(){
      return this._dom.getTagName().toUpperCase();
    },
    toString: function(){
      return "<" + this.tagName + (this.id ? "#" + this.id : "" ) + ">";
    },
    get outerHTML(){
      var ret = "<" + this.tagName, attr = this.attributes;
      
      for ( var i in attr )
        ret += " " + i + "='" + attr[i] + "'";
        
      if ( this.childNodes.length || this.nodeName == "SCRIPT" )
        ret += ">" + this.childNodes.outerHTML + 
          "</" + this.tagName + ">";
      else
        ret += "/>";
      
      return ret;
    },
    
    get attributes(){
      var attr = {}, attrs = this._dom.getAttributes();
      
      for ( var i = 0; i < attrs.getLength(); i++ )
        attr[ attrs.item(i).nodeName ] = attrs.item(i).nodeValue;
        
      return attr;
    },
    
    get innerHTML(){
      return this.childNodes.outerHTML; 
    },
    set innerHTML(html){
      html = html.replace(/<\/?([A-Z]+)/g, function(m){
        return m.toLowerCase();
      });
      
      var nodes = this.ownerDocument.importNode(
        new DOMDocument( html ).documentElement, true
      ).childNodes;
        
      while (this.firstChild)
        this.removeChild( this.firstChild );
      
      for ( var i = 0; i < nodes.length; i++ )
        this.appendChild( nodes[i] );
    },
    
    get textContent(){
      function nav(nodes){
        var str = "";
        for ( var i = 0; i < nodes.length; i++ ) {
          if ( nodes[i].nodeType == 3 )
            str += nodes[i].nodeValue;
          else if ( nodes[i].nodeType == 1 )
            str += nav(nodes[i].childNodes);
        }
        return str;
      }
      
      return nav(this.childNodes);
    },
    set textContent(text){
      while (this.firstChild)
        this.removeChild( this.firstChild );
      this.appendChild( this.ownerDocument.createTextNode(text) );
    },
    
    style: {},
    clientHeight: 0,
    clientWidth: 0,
    offsetHeight: 0,
    offsetWidth: 0,
    
    get disabled() {
      var val = this.getAttribute("disabled");
      return val != "false" && !!val;
    },
    set disabled(val) { return this.setAttribute("disabled",val); },
    
    get checked() {
      var val = this.getAttribute("checked");
      return val != "false" && !!val;
    },
    set checked(val) { return this.setAttribute("checked",val); },
    
    get selected() {
      if ( !this._selectDone ) {
        this._selectDone = true;
        
        if ( this.nodeName == "OPTION" && !this.parentNode.getAttribute("multiple") ) {
          var opt = this.parentNode.getElementsByTagName("option");
          
          if ( this == opt[0] ) {
            var select = true;
            
            for ( var i = 1; i < opt.length; i++ ) {
              if ( opt[i].selected ) {
                select = false;
                break;
              }
            }
              
            if ( select )
              this.selected = true;
          }
        }
      }
      
      var val = this.getAttribute("selected");
      return val != "false" && !!val;
    },
    set selected(val) { return this.setAttribute("selected",val); },

    get className() { return this.getAttribute("class") || ""; },
    set className(val) {
      return this.setAttribute("class",
        val.replace(/(^\s*|\s*$)/g,""));
    },
    
    get type() { return this.getAttribute("type") || ""; },
    set type(val) { return this.setAttribute("type",val); },
    
    get value() { return this.getAttribute("value") || ""; },
    set value(val) { return this.setAttribute("value",val); },
    
    get src() { return this.getAttribute("src") || ""; },
    set src(val) { return this.setAttribute("src",val); },
    
    get id() { return this.getAttribute("id") || ""; },
    set id(val) { return this.setAttribute("id",val); },
    
    getAttribute: function(name){
      return this._dom.hasAttribute(name) ?
        new String( this._dom.getAttribute(name) ) :
        null;
    },
    setAttribute: function(name,value){
      this._dom.setAttribute(name,value);
    },
    removeAttribute: function(name){
      this._dom.removeAttribute(name);
    },
    
    get childNodes(){
      return new DOMNodeList( this._dom.getChildNodes() );
    },
    get firstChild(){
      return makeNode( this._dom.getFirstChild() );
    },
    get lastChild(){
      return makeNode( this._dom.getLastChild() );
    },
    appendChild: function(node){
      this._dom.appendChild( node._dom );
    },
    insertBefore: function(node,before){
      this._dom.insertBefore( node._dom, before ? before._dom : before );
    },
    removeChild: function(node){
      this._dom.removeChild( node._dom );
    },

    getElementsByTagName: DOMDocument.prototype.getElementsByTagName,
    
    addEventListener: window.addEventListener,
    removeEventListener: window.removeEventListener,
    dispatchEvent: window.dispatchEvent,
    
    click: function(){
      var event = document.createEvent();
      event.initEvent("click");
      this.dispatchEvent(event);
    },
    submit: function(){
      var event = document.createEvent();
      event.initEvent("submit");
      this.dispatchEvent(event);
    },
    focus: function(){
      var event = document.createEvent();
      event.initEvent("focus");
      this.dispatchEvent(event);
    },
    blur: function(){
      var event = document.createEvent();
      event.initEvent("blur");
      this.dispatchEvent(event);
    },
    get elements(){
      return this.getElementsByTagName("*");
    },
    get contentWindow(){
      return this.nodeName == "IFRAME" ? {
        document: this.contentDocument
      } : null;
    },
    get contentDocument(){
      if ( this.nodeName == "IFRAME" ) {
        if ( !this._doc )
          this._doc = new DOMDocument(
            "<html><head><title></title></head><body></body></html>"
          );
        return this._doc;
      } else
        return null;
    }
  });
  
  DOMElement.prototype.toString = function() {
    return "<" + this.tagName + (this.className !== "" ? " class='" + this.className + "'" : "") + 
      (this.id !== "" ? " id='" + this.id + "'" : "") + ">";
  };
  
  // Helper method for extending one object with another
  
  function extend(a,b) {
    for ( var i in b ) {
      var g = b.__lookupGetter__(i), s = b.__lookupSetter__(i);
      
      if ( g || s ) {
        if ( g )
          a.__defineGetter__(i, g);
        if ( s )
          a.__defineSetter__(i, s);
      } else
        a[i] = b[i];
    }
    return a;
  }
  
  // Helper method for generating the right
  // DOM objects based upon the type
  
  var obj_nodes = new Ruby.Hash;
  
  function makeNode(node){
    if ( node ) {
      if ( !obj_nodes['key?']( node ) )
        obj_nodes[node] = node.getNodeType() == 
          W3CDOMNode.ELEMENT_NODE ?
            new DOMElement( node ) : new DOMNode( node );
      
      return obj_nodes[node];
    } else
      return null;
  }
  
  // XMLHttpRequest
  // Originally implemented by Yehuda Katz

  window.XMLHttpRequest = function(){
    this.headers = {};
    this.responseHeaders = {};
  };
  
  XMLHttpRequest.prototype = {
    open: function(method, url, async, user, password){ 
      this.readyState = 1;
      if (async)
        this.async = true;
      this.method = method || "GET";
      this.url = url;
      this.onreadystatechange();
    },
    setRequestHeader: function(header, value){
      this.headers[header] = value;
    },
    getResponseHeader: function(header){ },
    send: function(data){
      var self = this;

      function makeRequest(){
        var url = curLocation.merge(self.url);
        var connection;
        
        if ( url.scheme == "file" ) {
          if ( self.method == "PUT" ) {
            var out = new Ruby.File(url.path);
            var text = data || "";
            
            out.puts( text );
            out.flush();
            out.close();
          } else if ( self.method == "DELETE" ) {
            var file = new Ruby.File(url.path());
            file["delete"]();
          } else if ( self.method == "GET" ) {
            var file = Ruby.File.read(url.path);
            connection = {
              code: "200",
              message: "Ok",
              body: file,
            }
            handleResponse();
          } else {
            connection = Ruby.Net.HTTP.start(url.host, url.port, function(http) {
              http.get(url.path);
            });
            handleResponse();
          }
        } else { 
          var http = Ruby.Net.HTTP.new(url.host, url.port);
          var request = new Ruby.Net.HTTP.Get(url.path);
          for (var header in self.headers)
            request.add_field(header, self.headers[header]);

          var connection = http.request(request);
          connection.each_header(function(k,v) {
            self.responseHeaders[k] = v;
          });

          handleResponse();
        }
        
        function handleResponse(){
          self.readyState = 4;
          self.status = parseInt(connection.code) || undefined;
          self.statusText = connection.message || "";
          
          self.responseText = connection.body;
            
          self.responseXML = null;
          
          if ( self.responseText.match(/^\s*</) ) {
            self.responseXML = new DOMDocument( self.responseText );
          }
        }
        
        self.onreadystatechange();
      }

      if (this.async)
        new Ruby.Thread(function() { makeRequest(); });
      else
        makeRequest();
    },
    abort: function(){},
    onreadystatechange: function(){},
    getResponseHeader: function(header){
      if (this.readyState < 3)
        throw new Error("INVALID_STATE_ERR");
      else {
        var returnedHeaders = [];
        for (var rHeader in this.responseHeaders) {
          if (rHeader.match(new Regexp(header, "i")))
            returnedHeaders.push(this.responseHeaders[rHeader]);
        }
      
        if (returnedHeaders.length)
          return returnedHeaders.join(", ");
      }
      
      return null;
    },
    getAllResponseHeaders: function(header){
      if (this.readyState < 3)
        throw new Error("INVALID_STATE_ERR");
      else {
        var returnedHeaders = [];
        
        for (var aHeader in this.responseHeaders)
          returnedHeaders.push( aHeader + ": " + this.responseHeaders[aHeader] );
        
        return returnedHeaders.join("\r\n");
      }
    },
    async: true,
    readyState: 0,
    responseText: "",
    status: 0
  };
})();
