    class TC_Frame < Test::Unit::TestCase
      include HTTPAccessKit
      
      def test_init
        f = Frame 10
        assert_equal 10, f.ss.size
        assert !f.static
        f = Frame "example.com", :ck=>{"key"=>"value"}, :timeout=>10
        assert_equal 20, f.ss.size
        assert_equal "http://example.com", f.loc.root
        assert_instance_of Scout, f.ss.rand
        assert_equal 'value', f.ss.next.main_cks.values.to_s
        assert_equal 10, f.ss.next.timeout
        assert f.static
        assert_raise(ArgumentError) {Frame "example.com", 0}
      end
      
    end

    class TC_StaticInterpreter < Test::Unit::TestCase
      include HTTPAccessKit
    
      def setup
        @f = Frame("http://site.org/index.html", 1)
      end

      def test_target_fail
        assert_raise(TargetError) {@f.interpret_request("http://example.com")}
        assert_raise(TargetError) {@f.interpret_request({}, "http://example.com")}
        assert_raise(TargetError) {@f.interpret_request({}, true, ["http://example.com", "http://site.org/index.html"])}
      end

      def test_simple
        assert_equal [nil, [:loadGet, "http://site.org/index.html"], nil, {:eval=>true, :a=>:b}],
                          @f.interpret_request(:a=>:b)
        assert_equal [nil, [:loadGet, "http://site.org/"], nil, {:eval=>nil}],
                          @f.interpret_request("http://site.org/", :eval=>nil)
        assert_equal [true, nil, [[:loadGet, "http://site.org/page_1"], [:loadGet, "http://site.org/page_2"]], {:eval=>true, :wait=>1, :headers=>{'Referer'=>'localhost'}}],
                          @f.interpret_request((1..2).map{|i|"http://site.org/page_#{i}"}, :wait=>1, :headers=>{'Referer'=>'localhost'})
        assert_equal [true, nil, [[:loadGet, "http://site.org/page_1"]], {:eval=>true}],
                          @f.interpret_request(["page_1"])
      end
    
      def test_zip
        _1x1 = [true, nil, [[:loadPost, {:a=>:b}, false, "http://site.org/page_3"]], {:eval=>true}]
        assert_equal _1x1, @f.interpret_request([{:a=>:b}], false, ["page_3"])
        assert_equal _1x1, @f.interpret_request([{:a=>:b}], false, ["page_3"], :zip=>1)
        
        assert_equal [true, nil, [[:loadPost, {:a=>:b}, false, "http://site.org/page_3"], [:loadPost, {:c=>:d}, false, "http://site.org/page_4"]], {:eval=>true}],
                          @f.interpret_request([{:a=>:b}, {:c=>:d}], :def, ["page_3", "page_4"], :zip=>true)
      end
    
      def test_zip_fail
        assert_raise(ZippingError) {@f.interpret_request({:a=>:b, :_1=>:_2}, false, "page_3", :zip=>1)}
        assert_raise(ZippingError) {@f.interpret_request([{:a=>:b}], false, "page_3", :zip=>0)}
        assert_raise(ZippingError) {@f.interpret_request([{:a=>:b}, {:_1=>:_2}], false, ["page_3"], :zip=>1)}
      end
        
      def test_quad
        _2x2 = [true, nil, [[:loadPost, {:a=>:b}, false, "http://site.org/page_3"], [:loadPost, {:a=>:b}, false, "http://site.org/page_4"], [:loadPost, {:c=>:d}, false, "http://site.org/page_3"], [:loadPost, {:c=>:d}, false, "http://site.org/page_4"]], {:eval=>true}]
        assert_equal _2x2, @f.interpret_request([{:a=>:b},{:c=>:d}], :def, ["page_3", "page_4"], :zip=>false)
        assert_equal _2x2, @f.interpret_request([{:a=>:b},{:c=>:d}], ["page_3", "page_4"])
      end
      
      def test_implicit
        assert_equal [true, nil, [[:loadPost, {:a=>:b}, false, "http://site.org/index.html"]], {:eval=>true}],
                          @f.interpret_request([:a=>:b])
        assert_equal [nil, [:loadGet, "http://site.org/index.html"], nil, {:eval=>true}],
                          @f.interpret_request
        assert_equal [nil, [:loadPost, {:a=>:b, :_1=>:_2}, false, "http://site.org/"], nil, {:eval=>true}],
                          @f.interpret_request({:a=>:b, :_1=>:_2}, "/")
        assert_equal [nil, [:loadPost, {:a=>:b, :_1=>:_2}, true, "http://site.org/page_3"], nil, {:eval=>true}],
                          @f.interpret_request({:a=>:b, :_1=>:_2}, "/", "page_3")
        assert_equal [true, nil, [[:loadGet, "http://site.org/page_1"], [:loadGet, "http://site.org/page_2"]], {:eval=>true}],
                          @f.interpret_request(['page_1', 'page_2'], true, "/")
      end
      
      def test_params_fail
        assert_raise(TypeError) {@f.interpret_request("/", [])}
        assert_raise(TypeError) {@f.interpret_request([], "/")}
        assert_raise(TypeError) {@f.interpret_request("/", "")}
        assert_raise(TypeError) {@f.interpret_request([], "/", :a=>:b)}
        assert_raise(TypeError) {@f.interpret_request([], true, "/")}
        assert_raise(ArgumentError) {@f.interpret_request({:a=>:b}, [])}
        assert_raise(ArgumentError) {@f.interpret_request({:a=>:b}, true, [])}
      end
    
    end

    class TC_DynamicInterpreter < Test::Unit::TestCase
      include HTTPAccessKit
    
      def setup
        @f = Frame()
      end

      def test_target_fail
        assert_raise(TargetError) {@f.interpret_request}
        assert_raise(TargetError) {@f.interpret_request([{}], "./")}
        assert_raise(TargetError) {@f.interpret_request("example.com")}
        assert_raise(TargetError) {@f.interpret_request({}, true, ["http://example.com", "site.org/index.html"])}
      end

    end



