ENV["RACK_ENV"] = 'test'

require 'minitest/autorun'
require 'rack/test'
require 'fileutils'

#require_relative '../header_helpers'
require_relative "../cms"

# test suite

class AppTest < Minitest::Test
  
  include Rack::Test::Methods

  def app
    Sinatra::Application
  end

  def add_document(name, contents='')
    File.open(File.join(document_path, name), 'w') do |open_file|
      open_file.write(contents)
    end
  end

  def setup
    # create directories for test context
    FileUtils.mkdir_p(File.join(root_path, 'documents'))
  end
  
  def teardown
    FileUtils.rm_rf(root_path)
  end

  def test_root
    add_document('about.txt')
    add_document('changes.txt')
    add_document('history.txt')

    get '/'

    assert_equal(200, last_response.status)
  
    assert_equal(CONTENT_TYPE_HTML, last_response[HEADER_CONTENT_TYPE])
  
    assert_includes(last_response.body, 'about.txt')
    assert_includes(last_response.body, 'changes.txt')
    assert_includes(last_response.body, 'history.txt')
  end

  def test_valid_text_document
    add_document('about.txt', 'This is why.')

    get '/about.txt'

    assert_equal(200, last_response.status)
    assert_equal(CONTENT_TYPE_PLAIN_TEXT, last_response[HEADER_CONTENT_TYPE])
    assert_includes(last_response.body, 'This is why.')
  
  end

  def test_invalid_text_document
    invalid_file_name = 'some_invalid_file_name.txt'

    # request invalid filename and be redirected
    get("/#{invalid_file_name}")
    assert_equal(302, last_response.status)

    # follow redirection to a valid page
    get(last_response[HEADER_LOCATION])
    assert_equal(200, last_response.status)

    # check that page contains error message somewhere in the HTML
    assert_includes(last_response.body, "#{invalid_file_name} does not exist.")

    # check the the error message is gone after page refresh
    get('/')
    assert_equal(200, last_response.status)
    refute_includes(last_response.body, "#{invalid_file_name} does not exist.")
  end

  def test_markdown_document
    add_document('ruby.md', '<h2>Ruby is</h2>')
  
    get '/ruby.md'

    assert_equal(200, last_response.status)
    assert_equal(CONTENT_TYPE_HTML, last_response[HEADER_CONTENT_TYPE])
    assert_includes(last_response.body, '<h2>Ruby is</h2>')
  end

  def test_document_edit
    add_document('about.txt')

    get '/about.txt/edit'

    assert_equal(200, last_response.status)
    assert_equal(CONTENT_TYPE_HTML, last_response[HEADER_CONTENT_TYPE])
    assert_includes(last_response.body, '<textarea')
    assert_includes(last_response.body, '<input type="submit')
  end

  def test_document_update
    add_document('history.txt')

    post '/history.txt/update', new_file_content: 'replacement text' 
    assert_equal(302, last_response.status)

    get last_response[HEADER_LOCATION]
    assert_equal(200, last_response.status)
    assert_includes(last_response.body, "history.txt has been updated.")

    get '/history.txt'
    assert_equal(200, last_response.status)
    assert_equal(last_response.body, 'replacement text')
  end

  def test_document_new
    get '/new'

    assert_equal(200, last_response.status)
    assert_includes(last_response.body, 'name="new_document_name"')
    assert_includes(last_response.body, '<input type="submit"')
  end

  def test_document_creation
    post '/new', new_document_name: ''
    assert_equal(400, last_response.status)
    assert_includes(last_response.body, 'A name is required.')

    post '/new', new_document_name: 'some_name.txt'
    assert_equal(302, last_response.status)

    get last_response[HEADER_LOCATION]
    assert_equal(200, last_response.status)
    assert_includes(last_response.body, 'some_name.txt was created.')

    get '/'
    assert_includes(last_response.body, 'some_name.txt')
  end

  def test_document_invalid_deletion
    post '/some.txt/delete'
    assert_equal(400, last_response.status)
    assert_includes(last_response.body, 'some.txt does not exist.')
  end

  def test_document_valid_deletion
    add_document('some.txt')
    
    get '/'
    assert_includes(last_response.body, 'some.txt')

    post '/some.txt/delete'
    assert_equal(302, last_response.status)

    get last_response[HEADER_LOCATION]
    assert_equal(200, last_response.status)
    assert_includes(last_response.body, 'some.txt was deleted.')

    get '/'
    refute_includes(last_response.body, 'some.txt')
  end
  
end