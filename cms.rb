require_relative 'header_helpers'
require 'sinatra'
require 'sinatra/reloader' if development?
require 'redcarpet'

# useful constants
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

  def success?
    session.key?(:success)
  end

  def retrieve_success
    session.delete(:success)
  end
end

# route helpers
def root_path
  if ENV['RACK_ENV'] == 'test'
    File.expand_path('../test/data', __FILE__)
  else
    File.expand_path('../data', __FILE__)
  end
end

def document_path
  File.join(root_path, 'documents')
end

def all_documents_info
  document_root_path_abs = document_path

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
      text: File.read(entry_path_absolute)
    }

    # add content type for file type
    entry_extension = entry_name.split('.').last

    content_type = case entry_extension
    when 'txt' then CONTENT_TYPE_PLAIN_TEXT
    when 'md'  then CONTENT_TYPE_HTML
    else
      CONTENT_TYPE_HTML
    end


    names_links_text_map[entry_name][:content_type] = content_type
  end

  names_links_text_map
end

def render_markdown_to_html(markdown_text)
  MARKDOWN_PARSER.render(markdown_text)
end

def record_error(error_string)
  session[:error] = error_string
end

def record_success(success_string)
  session[:success] = success_string
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

def document_content_type_for(document_name_with_extension)
  document_for(document_name_with_extension)[:content_type]
end

def document_content_for(document_name_with_extension)
  document_contents = document_for(document_name_with_extension)[:text]

  case document_for(document_name_with_extension)[:content_type]
  when CONTENT_TYPE_PLAIN_TEXT
    document_contents
  when CONTENT_TYPE_HTML
    render_markdown_to_html(document_contents)
  else
    render_markdown_to_html(document_contents)
  end
end

def document_is_text?(document_name_with_extension)
  document_for(document_name_with_extension)[:content_type] == CONTENT_TYPE_PLAIN_TEXT
end

def document_is_markdown?(document_name_with_extension)
  document_for(document_name_with_extension)[:content_type] == CONTENT_TYPE_HTML
end

def update_document_content_for(document_name_with_extension, new_content)
  filepath = document_for(document_name_with_extension)[:absolute_path]

  File::write(filepath, new_content)
end

def document_text_contents_for(document_name_with_extension)
  document_for(document_name_with_extension)[:text]
end

def valid_document_name?(document_name)
  %w(.txt .md).any? { |extension| document_name.end_with?(extension) }
end

def add_document(document_name)
  File.open(File.join(document_path, document_name), 'w')
end

def delete_document(document_name)
  if document_exists?(document_name)
    File.delete(File.join(document_path, document_name))
    true
  else
    false
  end
end

# Routes
# Show list of all text documents
get '/' do

  # sort document names alphabetically
  @all_document_names = all_document_names_with_extension.sort

  erb(:index, layout: :layout)
end

# Create new document form
get '/new' do 
  @default_new_file_name = ''

  erb(:new, layout: :layout)
end

# Create new document
post '/new' do
  new_document_name = params[:new_document_name].strip
  
  if new_document_name.empty?
    # retry
    record_error('A name is required.')
    status(400)

    @default_new_file_name = new_document_name
    erb(:new, layout: :layout)
  elsif !valid_document_name?(new_document_name)
    # invalid file extension
    record_error("Document name must end in either '.txt' or '.md'.")
    status 400
    
    @default_new_file_name = new_document_name
    erb(:new, layout: :layout)
  else
    add_document(new_document_name)
    
    record_success("#{new_document_name} was created.")
    redirect('/')
  end
end

# Show text for specific document
get '/:document_name' do

  requested_document_name = params[:document_name]

  if document_exists?(requested_document_name) && document_is_text?(requested_document_name)
    
    headers[HEADER_CONTENT_TYPE] = document_content_type_for(requested_document_name)
    document_content_for(requested_document_name)

  elsif document_exists?(requested_document_name) && document_is_markdown?(requested_document_name)
    @document_markdown = document_content_for(requested_document_name)
    
    erb(:markdown, layout: :layout)
  else
    record_error("#{requested_document_name} does not exist.")
    redirect('/')
  end
end

# Edit specific document
get '/:document_name/edit' do
  @document_name = params[:document_name]

  if document_exists?(@document_name)
    @document_content = document_text_contents_for(@document_name)

    erb(:edit, layout: :layout)
  else
    record_error("#{@document_name} does not exist.")
    redirect('/')
  end
end

# Delete specific document
post '/:document_name/delete' do
  document_name = params[:document_name]

  if delete_document(document_name)
    record_success("#{document_name} was deleted.")
    redirect('/')
  else
    status(400)
    record_error("#{document_name} does not exist.")
    
    @all_document_names = all_document_names_with_extension.sort
    erb(:index, layout: :layout)
  end
end

# Update specific document with received text
post '/:document_name/update' do

  document_name = params[:document_name]

  if document_exists?(document_name)
    new_file_content = params[:new_file_content]

    update_document_content_for(document_name, new_file_content)
    record_success("#{document_name} has been updated.")
  else
    record_error("#{document_name} does not exist.")
  end

  redirect('/')
end
