# encoding: utf-8
module RMTools
    
  def mkprlist(df='proxy.txt')
    if df == :last
      df = Dir.new('log').content.find_all {|e| e[/pl|proxy/]}.sort_by {|e| File.mtime(e)}.last
    end
    pl = [].to_pl df
    if File.file? df
      IO.readlines(df).each {|s|
        s = s[%r{^(?![#/])[^#/]+}]
        pl << s.chomp if s
      }
      pl.map! {|e| e/':'}
    else
      puts df+' is missed!'
    end
    pl
  end
  
  module_function :mkprlist
end

class String
  
  def grabprlist(to)
    to.concat(parseips.uniq).size
  end
  
end

class Array
  
  def to_pl(file=nil)
    ProxyList self, file
  end
  
  def grabprlist(dest)
    if $Carier
      text = ''
      GetAll( lambda {text.grabprlist(dest)} ) {|res| text << res+"\n"}
    else
      getURLs.join("\n").grabprlist(dest)
    end
  end
  
end

class ProxyList < Array
  __init__
  attr_accessor :file
  attr_reader :name
  alias :minus :-
  alias :plus :+
  
  def initialize(source=[], file=nil)
    if source.is String
      super []
      load source
    elsif source.is Array
      raise ArgumentError, 'second arg must be a string' if file and !file.is String
      super source
      fix! if file
      @name	= sort.hash
      @name	= File.split(file)[1] if file and @name == 0
      @file	    = file || "tmp/#{'%0*x'%[12,@name]}.txt"
      rw @file, map {|i| i*':'+"\n"} if file and !empty?
    else raise TypeError, "can't create proxylist from #{source.class}"
    end
  end
  
  def rehash
    ProxyList self, @file
  end
  
  def ==(pl)
    if pl.is ProxyList
      pl.name == @name 
    else
      pl == self
    end
  end
  
  def -(pl)
    ProxyList minus pl
  end
  
  def +(pl)
    ProxyList plus pl
  end
  
  def fix!
    map! {|i|
      if i.is Array and ip = i[0]
        port = i[1].to_i
        [(ip.gsub!(/^(\d+)\.(\d+)\.(\d+)\.(\d+)$/) {|m| sprintf("%d.%d.%d.%d", *$~[1..4].map! {|d| d.to_i})} || ip), port > 0 ? port : i[1]]
      end
    }.compact!
    uniq! || self
  end
  
  def fix
    dup.fixprlist!
  end
  
  def inspect
    @name.is(String) ?
      sprintf("<#ProxyList: %s (%d items)>", @name, size) :
      sprintf("<#ProxyList:%#0*x (%d items)>", 12, @name, size)
  end
  
  def to_pl
    self
  end
  
  def _fixed(ip)
    ip.is String and ip[/^\d+\.\d+\.\d+\.\d+$/] and !ip["\n"]
  end
  
  def ips
    self[0].is(Array) ?
      self[0].size > 1 ?
        find_all	{|i| i[1].to_i > 0 and _fixed i[0]}.firsts :
        find_all	{|i| _fixed i[0]}.firsts :
      find_all	{|i| _fixed i}
  end
  
  def standart
    find_all	{|i| i[1].to_i > 0}
  end
  
  def glypes
    reject	{|i| i[1].to_i > 0}
  end
  
  def ips_fixed
    firsts.each {|ip| return false if !_fixed ip }
    true
  end
  
  def fix_ips
    ts = []
    (0...size).to_a.div(size/50).each {|d| ts << Thread.new {d.each {|i|
    
          if self[i][0].is Fixnum
            self[i][0] = self[i][0].to_ip
            next
          elsif self[i][1].to_i == 0 or self[i][0][/^\d+\.\d+\.\d+\.\d+$/]
            next
          end
          
          if (ip = self[i][0][/\d{1,3}[\.\-]\d+[\.\-]\d+[\.\-]\d{1,3}/])
            self[i][0] = ip.gsub('-', '.')
          elsif $unres_hosts.has ip
            self[i] = nil
          else
            ip = IPSocket.getaddress(self[i][0]) rescue($unres_hosts << self[i][0]; nil)
            ip and (self[i][0] = ip) and tick!
          end
          
    }}}
    ts.joins && ts.clear
    compact! || self
  end
  
  def valid
    each {|i| return false if !i.is Array or i.nitems != 2 or !i[0].is String or !(i[1].is String or i[1].is Fixnum)}
    true
  end
  
  def save(mark=nil)
    str = map {|i| i * ':' + "\n" if i.is Array}
    str = "#"*10+" #{puttime} - #{mark}\n#{str}"+"#"*20 if mark
    rw @file, str
  end
  
  def load(file=@file)
    if "\n".in file or "</".in file
      file.grabprlist self
    elsif File.file?(file)
      IO.read(file).grabprlist(self)
    else
      file.grabprlist self
    end
    self
  end
  
  def find_all
    super
  end
  
  def reject
    super
  end

end