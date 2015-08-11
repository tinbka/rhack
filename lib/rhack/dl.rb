# encoding: utf-8
require 'rhack'

module RHACK
  class Frame
    
    def get_cached(*links)
      res = []
      expire = links[-1] == :expire ? links.pop : false
      links.parses(:uri).each_with_index {|url, i|
        next if url.path[/ads|count|stats/]
        file = Cache.load url, !expire
        if file
          if expire
            @ss.next.loadGet(url.href, :headers=>{'If-Modified-Since'=>file.date}) {|c|
              if c.res.code == 200
                res << [i, (data = c.res.body)]
                Cache.save url, data, false
              else
                res << [i, file.is(String) ? file : read(file.path)]
              end
            }
          else
            res << [i, file.is(String) ? file : read(file.path)]
          end
        else
          @ss.next.loadGet(url.href) {|c|
            if c.res.code == 200
              res << [i, (data = c.res.body)]
              Cache.save url, data, !expire
            end
          }
        end
      }
      Curl.wait
      links.size == 1 ? res[0][1] : res.sort!.lasts
    end
    
    def get_distr(uri, psize, threads, start=0, print_progress=$verbose)
      raise ConfigError, "Insufficient Scouts in the Frame for distributed downloading" if @ss.size < 2
      @print_progress, code, stop_download, @ss_reserve = print_progress, nil, false, []
      (s = @ss.next).http.on_header {|h|
        next h.size unless h[/Content-Length: (\d+)|HTTP\/1\.[01] (\d+)[^\r]+|^\s*$/]
        if code = $2
          if code != '200'
            L << "#$& getting #{uri}; interrupting request."
            s.http.on_header() # set default process
            next 0
          end
          next h.size
        end
        
        s.http.on_header() # set default process
        if !$1 # конец хедера, content-length отсутствует
          L << "No Content-Length header; trying to load a whole #{uri} at once!"
          s.loadGet {|c| yield c.res.body.size, 0, c.res.body}
          next 0
        end
        
        len = $1.to_i - start
        psize = configure_psize(len, psize, threads)
        parts = (len/psize.to_f).ceil
        setup_speedometer(uri, parts, len)
        yield len, psize, :careful_dl if len > (@opts[:careful_dl] || 10.mb)
        
        @ss_reserve = @ss[threads+1..-1]
        @ss = @ss[0..threads]
        (0...parts).each {|n|
          break if stop_download
          
          s = @ss.next
          run_speedometer(s, len, n)
          s.loadGet(uri, :headers => {
            'Range' => "bytes=#{start + n*psize}-#{start + (n+1)*psize - 1}"
          }) {|c|
            clear_speedometer(s)
            if c.res.code/10 == 20
              yield len, n*psize, c.res.body
            else
              L << "#{c.res} during get #{uri.inspect}; interrupting request."
              stop_download = true
            end
          }
        }
        0
      }
      s.raise_err = false
      s.loadGet validate uri
    ensure
      @ss.concat @ss_reserve || []
    end
    
    def dl(uri, df=File.basename(uri.parse(:uri).path), psize=:auto, opts={})
      dled = 0
      lock = ''
      callback = lambda {|len, pos, body|
        if body != :careful_dl
          begin
            write(df, body, pos)
          rescue => e
            binding.start_interaction
            raise
          end
          if (dled += body.size) == len
            File.delete lock if File.file? lock
            yield df if block_given?
          end
        else
          lock = lock_file df, len, pos # filename, filesize, partsize
        end
      }
      opts[:threads] ||= @ss.size-1
      get_distr(uri, psize, opts[:threads], opts[:start].to_i, &callback)
      Curl.wait unless block_given?
      df
    end
    
    def simple_dl(uri, df=File.basename(uri.parse(:uri).path), opts={})
      opts.reverse_merge! :psize => :auto, :threads => 1, :print_progress => $verbose
      L << opts
      
      @print_progress = opts[:print_progress]
      unless len = opts[:len] || (map = read_mapfile(df) and map.len)
        return @ss.next.loadHead(uri) {|c| $log << c
          if len = c.res['Content-Length']
            simple_dl(uri, df, opts.merge(:len => len.to_i))
          else L.warn "Can't get file size, so it has no sence to download this way. Or maybe it's just an error. Check ObjectSpace.find(#{c.res.object_id}) out."
          end
        }
      end
      
      psize, parts = check_mapfile(df, opts)
      return unless psize
      L << [psize, parts]
      setup_speedometer(uri, parts.size, len)
      
      obtained uri do |uri|
        if opts[:threads] == 1
          start = opts[:start].to_i || (parts[0] && parts[0].begin) || 0
          scout = opts[:scout] || @ss.next
          $log << [uri, scout]
          (loadget = lambda {|n|
            run_speedometer(scout, len, n)
            from = start + n*psize
            to = start + (n+1)*psize - 1
            scout.loadGet(uri, :headers => {'Range' => "bytes=#{from}-#{to}"}) {|c|
              begin
                $log << "writing #{df} from #{from}: #{c.res.body.inspect}"
                write(df, c.res.body, from)
              rescue => e
                binding.start_interaction
                raise
              end
              if write_mapfile(df, from, to)
                clear_speedometer(scout)
                L.warn "file completely dl'ed, but (n+1)*psize <= len: (#{n}+1)*#{psize} <= #{len}" if (n+1)*psize <= len 
                yield df if block_given?
              elsif (n+1)*psize <= len 
                loadget[n+1] 
              end
            }
          })[0]
        else
          exec(uri, opts.merge(:raw => true, :ranges => parts)) {|c|
            L << c.res
            range = c.req.range
            begin
              write(df, c.res.body, range.begin)
            rescue => e
              binding.start_interaction
              raise
            end
            if write_mapfile(df, range.begin, range.end)
              @ss.each {|s| s.http.on_progress} if @print_progress
              yield df if block_given?
            end
          }
        end
      end
    end
    
    def check_mapfile(df, opts={})
      opts.reverse_merge! :psize => :auto, :threads => 1
      map = read_mapfile df
      if map
        L << map
        if map.rest.empty?
          puts "#{df} is loaded"
          $log << 'deleting mapfile'
          File.delete df+'.map'
          []
        else
          if opts[:len] and map.len != opts[:len]
            raise "Incorrect file size for #{df}"
          end
          psize = configure_psize *opts.values_at(:len, :psize, :threads)
          [psize, map.rest.div(psize)]
        end
      else
        write_mapfile df, opts[:len]
        psize = configure_psize *opts.values_at(:len, :psize, :threads)
        $log << (0...opts[:len]).div(psize)
        [psize, (0...opts[:len]).div(psize)]
      end
    end
      
    def read_mapfile(df)
      df += '.map'
      text = read df
      $log << "mapfile read: #{text}"
      if text.present?
        text[/^(\d+)\0+(\d+)\0*\n/]
        map = {}
        $log << [$1,$2]
        if $1 and $1 == $2
          map.rest = []
        else
          map.len, *map.parts = text.chop/"\n"
          map.len = map.len.to_i
          map.parts.map! {|part| part /= '-'; part[0].to_i..part[1].to_i}
          $log << map.parts
          map.rest = (0...map.len) - XRange(*map.parts)
        end
        map
      end
    end
    
    def write_mapfile(df, *args)
      df += '.map'
      map = ''
      if args.size != 2
        len = args.shift
        map << len.to_s.ljust(22, "\0") << "\n" if File.file? df
      end
      if args.any?
        read(df)[/^(\d+)\0+(\d+)\0*\n/]
        $log << "mapfile read"
        $log << [$1,$2]
        dled = $2.to_i + args[1] - args[0] + 1
        return true if dled == $1.to_i
        map << "#{args[0]}..#{args[1]}\n"
        $log << 'writing mapfile'
        write(df, dled.to_s.ljust(11, "\0"), 11)
      end
      $log << [df, map]
      $log << 'writing mapfile'
      write df, map
      nil
    end
    
    def configure_psize(len, psize, threads)
      case psize
        when Numeric; psize.to_i
        when :auto; len > 100000 ? len/threads+1 : len
        when :mb; 1.mb
        else raise ArgumentError, "Incorrect value for part size #{psize}:#{psize.class}"
      end
    end
    
    
    
    def setup_speedometer(uri, parts, len)
      return  unless  @print_progress
      @progress = Array.new(parts, 0)
      @stop_print, @speed, @sum, *@speedometer = false, '', 0, Time.now, 0
      @str = "Downloading #{uri.gsub '%', '%%'} (#{len.bytes}) in %03s streams, %07s/s:"
      @bs = "\b\r"*(@newlines = (uri.unpack('U*').size+len.bytes.size+42)/(ENV['COLUMNS'] || 80).to_i)
      Thread.new {
        until @stop_print
          sleep 0.2
          now = Time.now
          if now > @speedometer[0] and @sum > @speedometer[1]
            @speed.replace(((@sum - @speedometer[1])/(now - @speedometer[0])).to_i.bytes)
            @speedometer.replace [now, @sum]
          end
        end
      }
    end
    
    def run_speedometer(scout, len, n)
      return  unless  @print_progress
      scout.http.on_progress {|dl_need, dl_now, *ul|
        if !@stop_print
          @progress[n] = dl_now
          percents = (@sum = @progress.sum)*100/len
          print @str%[@progress.select_b.size, @speed]+"\n%%[#{'@'*percents}#{' '*(100-percents)}]\r\b\r"+@bs
          if percents == 100
            puts "\v"*@newlines
            @stop_print = true
          end
        end
        true
      }
    end
    
    def clear_speedometer(scout)
      return  unless  @print_progress
      scout.http.on_progress
    end
    
  end
  
  def dl(uri, df=File.basename(uri.parse(:uri).path), threads=5, timeout=600, &block)
    Curl.run
    Frame({:timeout=>timeout}, threads).dl(uri, df, :auto, threads, &block)
  end
  module_function :dl
end