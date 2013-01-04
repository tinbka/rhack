    class TC_Scout < Test::Unit::TestCase
      include HTTPAccessKit
      
      def setup
        Curl.run
      end
    
      def teardown
        Curl.stop
      end
      
      def test_init
        s = {}
        assert_nothing_raised {
          s = Scout 'http://example.com', ['127.0.0.1', 8000], :def, false
        }
        assert_equal s.ua, :rand
        assert_equal s.proxystr, '127.0.0.1:8000'
        assert_nil s.webproxy
      end
    
      def test_load
        res = nil
        s = Scout 'api.rubyonrails.org', :raise=>true
        s.loadGet('/') {|c| res = c.res}
        Curl.wait
        assert_equal res.code, 200
        assert_equal s.http.response_code, 200
        s.loadGet 'http://example.com/aaaaaa'
        assert_equal res.code, 200
        Curl.wait
        assert_equal res.code, 302
        assert_equal s.http.response_code, 302
        s.loadGet 'https://developer.mozilla.org/en'
        Curl.wait
        s.loadGet('./CSS') {|c| res = nil}
        assert_equal res.code, 200
        s.cp_on
        Curl.wait
        assert_nil res
        assert_equal s.res.req.header.Referer, "https://developer.mozilla.org/CSS"
        s.refforge = false
        s.loadGet {|c| res = c.res.req.url}
        Curl.wait
        assert_equal res, "https://developer.mozilla.org/en/CSS"
        assert_nil s.res.req.header.Referer
        assert_not_empty s.main_cks
      end
    
      def test_fail
      end
      
    end