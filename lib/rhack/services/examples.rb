# encoding: utf-8
require 'rhack/services'

module RHACK

  class Yandex < Service
    __init__
      
    unless defined? IGNORE_UPPERCASE
    URI = {
        :speller => "http://speller.yandex.net/services/spellservice.json/checkText",
        :search => "http://www.yandex.ru/yandsearch?lr=213&%s",
        :weather => "http://pogoda.yandex.ru/%d/details/"
    }
    
    IGNORE_UPPERCASE = 1
    IGNORE_DIGITS = 2
    IGNORE_URLS = 4
    FIND_REPEAT_WORDS = 8
    IGNORE_LATIN = 16
    NO_SUGGEST = 32
    FLAG_LATIN = 128
    end
      
    def initialize(service=:search, frame=nil)
      ua = RHACK.useragents.rand
      ua << " YB/4.2.0" if !ua["YB"]
      super service, frame, nil, ua, :ck => {
          "yandexuid"=>"3644005621268702222",
          "t"=>"p"
      }, :eval => false
    end
      
    def search(text, opts={}, &block)
      uri = URI.search % urlencode(opts.merge(:text=>text))
      @f.run(uri, :proc_result => block) {|page| process page}
    end
    
    def process page
      page.find('.p1/.cr').map {|n| [n.at('.cs').href, n.at('.cs').text.strip, (n.at('.kk') || n.at('.k7/div')).text.strip]} if page.html.b
    end
      
    def speller(text, opts=23)
      text = text.split_to_lines(10000)
      i = 0
      @f.run({"text" => text[i], "options" => opts}, URI.speller, :json => true) {|pg| 
        yield pg.hash
        text[i+=1] && @f.get({"text" => text[i], "options" => opts}, URI.speller, :json => true)
      }
    end
    
    def fix_content(doc, opts={})
      nodes = doc.root.text_nodes
      speller(nodes*". ", opts) {|json|
        fix = {}
        json.each {|h| fix[h.word] = h.s[0] if h.s[0]}
        nodes.each {|n|
          fixed = false
          text = n.text
          fix.each {|k, v| fixed = true if text.gsub!(/\b#{k}\b/, v)}
          n.text(text) if fixed
        }
      }
      Curl.wait
    end
    
    def weather city=27612, day=nil, &block
      if city.is String
        city = CitiesCodes[city] if defined? CitiesCodes
        raise ServiceError, "can't get weather info for #{city.inspect}:#{city.class}" if !city.is(Fixnum)
      end
      @f.get(URI.weather%city, :proc_result => block) {|pg|
        ary = pg.find('//.b-forecast-details/tbody/tr{_["class"] =~ /t\d/}').map {|e|
          "#{e.at('.date') ? e.at('.date').text+":\n" : ''} - #{e.at('.t').text} - #{e.at('.data').text} - #{e.at('.wind/img').alt} #{e.at('.wind').text} м/с"
        }
        ary = ary[0..11].div(4) + ary[12..-1].div(2)
        day ? ary[day] : ary
      }#.res
    end
    
    def self.weather(*args, &block) new(:weather).go *args, &block end
    def self.search(*args, &block) new.go *args, &block end
      
  end
    
  class Google < Service
    __init__
    URI = {
        :translate => "http://ajax.googleapis.com/ajax/services/language/translate?v=1.0&q=%s&langpair=%s%%7C%s",
        :search => "http://ajax.googleapis.com/ajax/services/search/web?v=1.0&hl=ru&q=%s",
        :detect => "http://ajax.googleapis.com/ajax/services/language/detect?v=1.0&q=%s"
    }
    
    Shortcuts = Hash[*%w{
    v ru.wikipedia.org в ru.wikipedia.org вики en.wikipedia.org
    w en.wikipedia.org ев en.wikipedia.org wiki en.wikipedia.org
    lm lurkmore.ru лм lurkmore.ru
    wa world-art.ru ва world-art.ru
    ad anidb.info ад anidb.info
    ed encyclopediadramatica.com ед encyclopediadramatica.com
   }]
    
    Langs = *%w{
    af sq am ar hy az eu be bn bh bg my ca chr zh zh-CN zh-TW hr cs da dv nl en eo et tl fi fr gl ka de el gn gu iw hi hu is id iu it ja kn kk km ko ku ky lo lv lt mk ms ml mt mr mn ne no or ps fa pl pt-PT pa ro ru sa sr sd si sk sl es sw sv tg ta tl te th bo tr uk ur uz ug vi
  	}
      
    def initialize(service=:search, frame=nil)
      super service, frame, :json => true
    end
      
    def search(text, opts={}, &block)
      text = "site:#{opts[:site]} #{text}" if opts[:site]
      uri = URI.search % CGI.escape(text)
      @f.run(uri, :proc_result => block) {|page|
        if data = page.hash.responseData.b
          data.results.map! {|res| [res.unescapedUrl, res.titleNoFormatting, res.content]}
        end
      }#.res
    end
      
    def detect(text, wait=!block_given?, &block)
      text = text.is(String) ? text[0...600] : text[0]
      uri = URI[:detect] % CGI.escape(text)
      @f.run(uri, :proc_result => block, :wait => wait) {|page|
        (data = page.hash.responseData.b) && data.language
      }
    end
      
    def translate(text, to, from=nil, &block)
      text = text.split_to_blocks(600, :syntax) if !text.is Array
      if !from
        if block_given?
          return detect(text) {|from| yield translate(text, to, from)}
        else
          return translate(text, to, detect(text).res)
        end
      end
      res = []
      i = 0
      text.each_with_index {|b, j|
        @f.run(URI.translate%[CGI.escape(text[j]), from, to], :proc_result => block, :wait => false) {|page|
          res[j] = (data = page.hash.responseData.b and data.translatedText)
          (i += 1) == text.size ? res*"\n" : :skip
        }
      }
      Curl.wait if !block_given?
      res*"\n"
    end
    
    def self.search(*args, &block) new.search *args, &block end
    def self.tr(*args, &block) new(:translate).translate *args, &block end
    
  end
  
  class Infoseek < Service
    URI = {:tr => 'http://translation.infoseek.co.jp/'}
    
    def initialize frame=nil
      super :tr, frame, :eval => false
    end
    
    def get_token page
      @token = page.at('input[name=token]').value
    end
    
    def tr(text, direction=:from_ja, &block)
      if @token
        selector = direction.in([:from_ja, :from_jp, :to_en]) ? 1 : 0
        body = {'ac' => 'Text', 'lng' => 'en', 'original' => text, 'selector' => selector, 'token' => @token, 'submit' => '　翻訳'}
        @f.run(body, :proc_result => block) {|page| 
          get_token page
          page.at('textarea[name=converted]').text
        }#.res
      else
        @f.run(:save_result => !block) {|page| 
          get_token page
          tr text, direction, &block
        }#.res
      end
    end
    
    def self.tr(*args, &block) new.tr *args, &block end
    
  end
  
  class Youtube < Service
    URI = {:info => "http://www.youtube.com/get_video_info?video_id=%s"}
    attr_reader :track
    
    def initialize frame=nil
      super :dl, frame, :eval => false
      @f.ss.each {|s| s.timeout=600}
      require 'open3'
      require 'mp3info'
    end
    
    def dl(id, fd=nil, &block)
      if block 
        info(id) {|lnk| __dl(lnk, fd, block)}
      else  __dl(info(id), fd)
      end
    end
    
    def dlmp3(id, mp3=nil)
      dl(id) {|flv| 
        if !File.file?(df = mp3||flv.sub(/.flv$/, '.mp3'))
          Open3.popen3("ffmpeg -i '#{flv}' -ab 262144 -ar 44100 '#{df}'") {|i,o,e|
            if $verbose
              t = e.gets2 and t and t[/^size=/] and print t until e.eof?
              puts "\n#{t}"
            end
          }
        end
        Mp3Info.open(df, :encoding=>'utf-8') {|mp3| 
          mp3.tag2.TPE1, mp3.tag2.TIT2 = @track[1..2]
        }  }
    end

    def self.dl(id) new.dl(id) end
    def self.dlmp3(id) new.dlmp3(id) end
    
  private
    def info(id, &block)
      @f.run(URI.info%[id[/\/watch/] ?
                               id.parseuri.query.v : 
                               File.basename(id).till(/[&?]/)],:hash=>true,:proc_result=>block){|p|
        res = p.hash
        @track = [res.author, res.creator, res.title]
        CGI.unescape(res.fmt_url_map).split(/,\d+\|/)[0].after('|')
      }#.res
    end
    
    def __dl(lnk,fd,block=nil)
      @f.dl(lnk, fd||"files/youtube/#{@track*' - '}.flv", :auto, 5, &block)
    end
  
  end

  class VK < Service
    attr_reader :links, :open_links
    URI = {
      :people => "http://vkontakte.ru/gsearch.php?from=people&ajax=1",
      :login => "http://vkontakte.ru/index.php",
      :id => "http://vkontakte.ru%s"
    }
    DefaultParams = Hash[*%w[
      c[city] 1
      c[country] 1
      c[noiphone] 1
      c[photo] 1
      c[section] people
      c[sex] 1
      c[status] 6
  ]]
    @@reloadable = ReloadablePage {
      if !@title and !@hash
        L << self 
        L << @doc
      end
      if @hash == false or @hash.nil? && (!@title or @title["Ошибка"])
        L.info "@title caller.size", binding
        sleep 2
      end
    }
    def self.com; new end
  
    class NotFoundError < Exception; end
        
    def initialize frame=nil
      super :people, frame, {:cp => true, :relvl => 5, :eval => false}, 5
      @links = []
      @open_links = []
      login
    end
    
    def login params={'email'=>'fshm@bk.ru', 'pass'=>'Riddick2', 'expire'=>nil}
      super {|login_page|
        login_page.submit('form', @f, params).submit('form', @f, {})
      }
    end
    
    def get_links h, pagenum, &block
      @f.run(h.merge('offset' => pagenum*20), URI[:people], :proc_result=>block, :result=>@@reloadable, :json => true) {|page|
        ls = Page(page.hash.rows).get_links('.image/a')
        @links.concat ls
        ls
      }
    end
    
    def people(q, *args, &block)
      age, opts = args.get_opts [17..23]
      h = DefaultParams.merge('c[q]' => q)
      h.merge! Hash[opts.map {|k,v| ["c[#{k}]", v]}]
      h['c[age_from]'], h['c[age_to]'] = age.first, age.last
      
      @f.run(h, URI[:people], :proc_result => block, :json => true) {|page|
      # ответом может быть невнятное требование залогиниться
        sum = page.hash.summary.sub(/<span.+>/, '')
        puts sum
        found = sum[/\d+/]
        if !found
          L.warn sum 
        else
          @links.concat Page(page.hash.rows).get_links('.image/a')
          max_page = [50, (found.to_f/20).ceil].min
          (1...max_page).each {|_|
            sleep 0.5
            get_links h, _, &block
          }
        end
      }
    end
    
    def get_people q, *opts
      @links = []
      @open_links = []
      people q, *opts
      get_pages q
    end
    
    def get_pages q=nil
      @links.uniq.each {|id| get_page id, q; sleep 1.5}
    end
    
    def get_page id, q=nil
      q = q ? q.ci.to_re : // unless q.is Regexp
      id_num = id[/\d+/].to_i
      @f.get(id, :result=>@@reloadable) {|p|
        data = p.find('.profileTable//.dataWrap').to_a.b
        if data
          L.debug "!p.at('.basicInfo//.alertmsg') data.contents.join('')[/(\\d\\s*){6,}/] data.contents.join('')[q]", binding
        end
        if data = p.find('.profileTable//.dataWrap').b and
           contents = data.to_a.contents.join.b and contents[q]
          digits = contents[/(\d *){6,9}/]
          bot = (digits and digits[/^\d{7}$/] and id_num.between 852e5, 893e5)
          if !bot and !p.at('.basicInfo//.alertmsg') || digits
            L << "added vk.com#{id}"
            @open_links << id
          elsif bot
            L << "bot #{id_num} detected"
          else tick!
          end
        else tick!
        end
      }
    end
    
  end
  
  class Mamba < Service
    attr_reader :links, :open_links
    @@login, @@pass = %w{AnotherOneUser AyaHirano8}
    URI = {
      :people => "http://mamba.ru/?",
      :login => "http://mamba.ru/tips/?tip=Login",
      :id => "http://vk.com%s"
    }
    DefaultParams = Hash[*%w[
      c[city] 1
      c[country] 1
      c[noiphone] 1
      c[photo] 1
      c[section] people
      c[sex] 1
      c[status] 6
  ]]
        
    def initialize frame=nil
      super :people, frame, {:cp=>{
        "PREV_LOGIN"=>"anotheroneuser", "LOGIN"=>"anotheroneuser", "UID"=>"494809761", "LEVEL"=>"Low", "bar"=>"AShwjUz54RmYnfClOdlMYZylGUU90PUxeFkwlGixrP2ARHDs3A0EbDDxQTEksEm4LPT8FfzpfdiMME1omFz0tVhA5QjcsCgckaSQfIDxI", "s"=>"MJt2J3U9Pnk7Qvpie13lN7rrqmahTrAk", "SECRET"=>"adqH47"},
        :eval=>false, :timeout=>5, :retry=>['TimeoutError']
      }, 5
      @links = []
      @open_links = []
    end
    
    def login
      @f.run(URI[:login]) {|p|
        p.submit('.ap-t-c//form', @f, 'login'=>@@login, 'password'=>@@pass, 'level'=>nil) {
          @f.each {|s| s.cookies.replace @f[0].cookies}
        }
      }
      Curl.wait
    end
    
    def people
      # TODO
      # ... or not TODO?
    end
    # seems like NOT... LOL
    
  end
  
  
  
  module Downloaders
  
    def letitbit(path, &block)
      link = ''
      frame = Frame 'letitbit.net', {:cp => true, :eval => nil}, 1
      frame.run(path, :wait => !block) {|page1|
        page1.submit('#ifree_form', frame) {|page2|
          page2.submit('[action=/download4.php]', frame) {|page3|
            page3.submit('[action=/download3.php]', frame) {|page4|
              t = Thread.new {
                sleep 60
                frame.run({}, '/ajax/download3.php', 
                                    :headers => {"Referer" => "http://letitbit.net/download3.php"}
                             ) {|res|
                  link << res.html
                  block[link] if block
                }
              }
              t.join if !block
      }}}}
      link
    end
    
    module_function :letitbit
  end
  
end