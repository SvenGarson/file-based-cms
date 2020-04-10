ENV["RACK_ENV"] = 'test'

require 'minitest/autorun'
require 'rack/test'

require_relative "../cms"

class AppTest < Minitest::Test
  
  include Rack::Test::Methods

  def app
    Sinatra::Application
  end

  def test_root
    get '/'

    assert_equal(200, last_response.status)
  
    assert_equal('text/html;charset=utf-8', last_response['Content-Type'])
  
    assert_includes(last_response.body, 'about.txt')
    assert_includes(last_response.body, 'changes.txt')
    assert_includes(last_response.body, 'history.txt')
  end

  def test_valid_text_document
    get '/about.txt'

    assert_equal(200, last_response.status)
    assert_equal('text/plain;charset=utf-8', last_response['Content-Type'])
  end

  def test_invalid_text_document
    invalid_file_name = 'some_invalid_file_name.txt'

    # request invalid filename and be redirected
    get("/#{invalid_file_name}")
    assert_equal(302, last_response.status)

    # follow redirection to a valid page
    get(last_response['Location'])
    assert_equal(200, last_response.status)

    # check that page contains error message somewhere in the HTML
    assert_includes(last_response.body, "#{invalid_file_name} does not exist.")

    # check the the error message is gone after page refresh
    get('/')
    assert_equal(200, last_response.status)
    refute_includes(last_response.body, "#{invalid_file_name} does not exist.")
  end
end