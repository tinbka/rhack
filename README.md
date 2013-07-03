### RHACK
[github](https://github.com/tinbka/rhack)

RHACK is Ruby Http ACcess Kit: curl-based web-client framework created for developing web-scrapers/bots.

##### Features
* Asynchronous, still EventMachine independent. Synchronization can be turned on with fine of 1sec per [bulk] request
* Fast as on simple queries as on high load. Can process up to thousands (limited by a net interface, of course) different parallel requests of any HTTP method with no penalty
* Flexibly configurable on 3 levels:
  * Curl::Easy (simplest request configuration, inherited from [curb gem](http://github.com/taf2/curb))
  * ::Scout (Curl::Easy wrapper with transparent cookies and extendable anonimization processing, detailed request/response info, callbacks and retry configuration)
  * ::Frame (Scout array wrapper with smart request interpretor, load balancing and extendable response processor)
* Support of javascript processing on loaded html pages is included (johnson gem)
* Web-service-client abstraction implementing some examples of how to use this library

---

It's still randomly documented since it's just my working tool.

#### Main goals for 1.x

* More agile response postprocessing configuration. Instead of using :json, :hash etc as a flag, define some "before filters" in the Page and chain them.
* Route :xhr option to the Scout; add some transparent control on user-agents: desktop, mobile, randomly predefined...

#### Main goals for 2.0
(if it would ever come)

* Full javascript processing, including linked scripts; maybe support of other javascript engines gems.
* Distributed proxified downloading of large files.
* Console real-time speedometer for a downloader. Wait... for f--ks sake?

### CHANGES

##### Version 1.1.4

* ::Frame
  * Moved `Curl.execute` from *initialize* to *on after request added*
  
* ::ScoutSquad
  * Finally stabilized #next and #rand time management for parallel recursive execution

##### Version 1.1.3

* ::Frame
  * Added #anchor
  
* ::Scout
  * Fixed #update
  * Catch weird Curl::Err::CurlOK being thrown on some pages

* Fixed some exceptions messages

##### Version 1.1.0

* ::OAuthClient < ::Client
  * A full set of abstract OAuth2 authorizaztion and API methods
  * Per-user key-value oauth_token storage
  * Handling of tokens expiration
  * Fits for, at least, facebook.com, linkedin.com and vk.com
  
* ::Storage
  * Wrapper of Redis-based storage to handily store/cache scrapers data

##### Version 1.0.0

* ::Frame
  * #initialize: ::ScoutSquad size can be specified by :scouts option (default still is 10)
  * @static with Hash value is now essentially a default route. :protocol and :host values are used for request where only "path" url is given
  * Fixed weird #run_callbacks! and :raw behaviour. @res of a Page now always get result of a block passed as :proc_result or block passed to #exec itself

* ::Scout
  * Added explicit cacert loading, cacert.pem by curl.haxx.se lies in <gemdir>/config
  * Provided support of curl HTTP DELETE and PUT verbs: #loadDelete and #loadPut. From a frame, add :verb => (:delete|:put) as an option to #run.
  
* ::ScoutSquad
  * Automatically Curl.execute on #next and #rand if Carier Thread is exited without an exception
  
* ::Service
  * Is renamed to Client what is more sensible. RHACK::Service is still usable as alias
  * require 'rhack/clients' <-> require 'rhack/services'

* Structural changes
  * Updated and documented rhack.yml.template that now lies in <gemdir>/config
  * All initialization moved to <gemdir>/lib/rhack.rb, rhack_in.rb stays there for compatibility
  * The gem is now being produced in the bundle style: added Gemfile, .gemspec, etc
  * ::Frame#get_cached and all its methods related to #dl (downloading) moved to rhack/dl
  * Global variables is replaced by module attributes of respective names

* Persistence
  * Removed every reference to SQL: /cache.rb, /words.rb (removed) and /extensions/declarative.rb (moved to rmtools project as optional part)
  * Made a foundation for Redis support, redis-based storage itself is coming the very next version

* Added rake redis:config: generate rhack.yml -> redis.conf

##### Version 0.4.1

* Сhanged ::Frame @static behaviour, :static option now accept hash with :procotol key (see ::Frame#validate comment)
* Changed log level in curl-global.rb
* Described the library and *marked down* this readme

##### Version 0.4

* Fixed bugs
  * idle execution in Rails application thread
  * Curl::Easy default callback
  * some misspelling-bugs

* ::ScoutSquad
  * Minified #next waiting time

* ::Service
  * added meta-methods #login (sync only) and #scrape!(<::Page>)

* ::Frame
  * made new cache prototype. Call #use_cache!(false?) for (in)activate and #drop_cache! for clearance
  * added :xhr exec option

* ::Page
  * #title returns full title by default
  * #html is auto-encoded to UTF-8 during #process

##### Version 0.3

* Adjusted cookie processor in accordance with web-servers and entrust redirection process to ::Scout
* Added some shortcuts to Frame and Curl modules
* Сonfig defaults are now taken from rails
* Removed crappy database usage from lib/words.rb
* curb_multi.c: Moved callbacks out of rb_rescue so that I could know wtf was happen there

##### Version 0.2

* Nastily pulled down curb-0.8.1 extension sources and harshly patched by changes made long before, so that the core will be as modern as possible and with necessary features
* Fixed syntax for Ruby 1.9

##### Version 0.1

* A long time ago in a galaxy far, far away...
* A library had been created based on Net::HTTP
* In a few months its base had been changed by curb-0.4.4 because of poorness and incovinience of Net::HTTP
* Had been made background-mode for Curl::Multi and multipart body setting for Curl::Easy so that Curl could be both sync and async
* Had been added a couple of wrappers for Curl::Easy and its results, proxy lists processor, scrapers for a few web-services, and plugin for libxml-ruby that lives at rmtools gem now

### License

RHACK is copyright (c) 2010-2013 Sergey Baev <tinbka@gmail.com>, and released under the terms of the MIT license. 
See the LICENSE and CURB-LICENSE files for the details. 
Rhack includes slightly modified Curb gem extension source code. For original 
Curb gem code you may want to check ext/curb-original directory or visit <http://github.com/taf2/curb/tree/master>.