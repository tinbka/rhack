=== RHACK

Rhack is Ruby Http ACcess Kit -- curl-based web-client for developing web-clients applications.

=== CHANGES

== Version 0.4

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

== Version 0.3

* Adjusted cookie processor in accordance with web-servers and entrust redirection process to ::Scout
* Added some shortcuts to ::Frame and Curl modules
* Сonfig defaults are now taken from rails
* Removed crappy database usage from lib/words.rb
* curb_multi.c: Moved callbacks out of rb_rescue so that I could know wtf was happen there

== Version 0.2

* Nastily pulled down curb-0.8.1 extension sources and harshly patched by changes made long before, so that the core will be as modern as possible and with necessary features
* Fixed syntax for Ruby 1.9

== Version 0.1

* A long time ago in a galaxy far, far away...
* A library had been created based on Net::HTTP
* In a few months its base had been changed by curb-0.4.4 because of poorness and incovinience of Net::HTTP
* Had been made background-mode for Curl::Multi and multipart body setting for Curl::Easy so that Curl could be both sync and async
* Had been added a couple of wrappers for Curl::Easy and its results, proxy lists processor, scrapers for a few web-services, and plugin for libxml-ruby that lives at rmtools gem now

=== License

Rhack is copyright (c)2010 Sergey Baev, and released under the terms of the Ruby license. 
See the LICENSE file for the details. 
Rhack is also include slightly modified Curb gem extension source code. For original 
Curb gem code you may want to check ext/curb-original or visit http://github.com/taf2/curb/tree/master .
See the CURB-LICENSE file for the details. 