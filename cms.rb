require 'sinatra'
require 'sinatra/reloader' if development?
require 'redcarpet'

# useful constants
ROOT_DIR_ABS = File.expand_path('..', __FILE__)
MARKDOWN_PARSER = Redcarpet::Markdown.new(Redcarpet::Render::HTML)

# sinatra configuration
configure do
  enable(:sessions)
  set(:session_secret, 'bad_secret')
end

# sinatra before every route block
before do 
  @all_documents_info = all_documents_info
end

# sinatra view helpers
helpers do
  def error?
    session.key?(:error)
  end

  def retrieve_error
    session.delete(:error)
  end
end

# route helpers
def all_documents_info
  document_root_path_abs = File.join(ROOT_DIR_ABS, 'data', 'documents')

  names_links_text_map = Hash.new

  # select only file names
  Dir.entries(document_root_path_abs).select do |entry_name|
    # ignore if not a file
    entry_path_absolute = File.join(document_root_path_abs, entry_name)
    next unless File.file?(entry_path_absolute)
    
    # store document name along with it's absolute path;
    # source text and file type(text or markdown)
    names_links_text_map[entry_name] = {
      absolute_path: entry_path_absolute,
      text: File.read(entry_path_absolute),
      file_type: entry_name.end_with?('.md') ? :markdown : :text
    }
  end

  names_links_text_map
end

def all_document_names_with_extension
  @all_documents_info.keys
end

def document_for(document_name_with_extension)
  @all_documents_info[document_name_with_extension]
end

def document_exists?(document_name_with_extension)
  @all_documents_info.key?(document_name_with_extension)
end

def document_text_for(document_name_with_extension)
  document_for(document_name_with_extension)[:text]
end

def document_type_for(document_name_with_extension)
  document_for(document_name_with_extension)[:file_type]
end

def render_markdown_to_html(markdown_text)
  MARKDOWN_PARSER.render(markdown_text)
end

def record_error(error_string)
  session[:error] = error_string
end

# Routes
# Show list of all text documents
get '/' do

  # sort document names alphabetically
  @all_document_names = all_document_names_with_extension.sort

  erb(:index, layout: :layout)
end

# Show text for specific document
get '/:document_name' do

  requested_document_name = params[:document_name]

  if document_exists?(requested_document_name)
    
    document_text = document_text_for(requested_document_name)
    
    # check file type markdown or text
    case document_type_for(requested_document_name)
    when :text
      headers['Content-Type'] = 'text/plain;charset=utf-8'
      document_text
    when :markdown
      headers['Content-Type'] = 'text/html;charset=utf-8'
      render_markdown_to_html(document_text)
    end
  else
    record_error("#{requested_document_name} does not exist.")
    redirect('/')
  end
end

# default route when route not found
=begin
not_found do 

end
=end