### RHACK
[github](https://github.com/tinbka/rhack)

RHACK is Ruby Http ACcess Kit -- curl-based web-client for developing web-scrapers/bots.

##### Features
* Asynchronous, still EventMachine independent. Synchronization can be turned on with 1sec per waiting penalty
* Fast as on simple queries as on high load. Can process up to thousands (limited by a net interface, of course) different parallel requests of any HTTP method with no penalty
* Flexibly configurable on 3 levels:
* * Curl::Easy (simplest request configuration, inherited from [curb gem](http://github.com/taf2/curb))
* * ::Scout (Curl::Easy wrapper with transparent cookies and extendable anonimization processing, detailed request/response info, callbacks and retry configuration)
* * ::Frame (Scout array wrapper with smart request interpretor, load balancing and extendable response processor)
* Included support of javascript processing on loaded pages (johnson gem)
* Web-service abstraction for creating scrapers, that implement some examples of how to use this library

---

It's still randomly documented since it's just my working tool.

#### Expected to complete:

* Redis-based configurable cache for ::Service and for downloads
* Full javascript processing, including linked scripts; maybe support of other javascript engines gems

### CHANGES

##### Version 0.4.1

* Сhanged ::Frame @static behaviour, :static option now accept hash with :procotol key (::Frame#validate comment)
* Changed log level in curl-global.rb
* Described the library and *marked down* this readme

##### Version 0.4

* Fixed bugs
* * idle execution in Rails application thread
* * Curl::Easy default callback
* * some misspelling-bugs
* Minified ::ScoutSquad#next waiting time
* ::Service
* * added meta-methods #login (sync only) and #scrape!(<::Page>)
* ::Frame
* * made new cache prototype. Call #use_cache!(false?) for (in)activate and #drop_cache! for clearance
* * added :xhr exec option
* ::Page
* * #title returns full title by default
* * #html is auto-encoded to UTF-8 during #process

##### Version 0.3

* Adjusted cookie processor in accordance with web-servers and entrust redirection process to ::Scout
* Added some shortcuts to ::Frame and Curl modules
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

RHACK is copyright (c) 2010-2013 Sergey Baev <tinbka@gmail.com>, and released under the terms of the Ruby license. 
See the LICENSE file for the details. 
Rhack is also include slightly modified Curb gem extension source code. For original 
Curb gem code you may want to check ext/curb-original or visit <http://github.com/taf2/curb/tree/master>.
See the CURB-LICENSE file for the details. 