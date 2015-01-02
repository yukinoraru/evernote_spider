# coding: utf-8

require "rake"
require "yaml"
require "pp"
require "rack"

# Load libraries required by the Evernote OAuth sample applications
require "oauth"
require "oauth/consumer"

# Load Thrift & Evernote Ruby libraries
require "evernote_oauth"

#
require "./lib/evernote_spider.rb"

task :default => [:get_access_token]

def check_and_get_config(path = "./config.yml")
  config = nil

  begin
    config = YAML.load_file(path).fetch("evernote")
  rescue
    puts "[ERROR] Please check your config.yml"
  end

  #
  if config["access_token"].nil?
    puts "[WARNING] You don't have access token in your config."
  end

  if config["consumer_key"].nil? || config["consumer_secret"].nil?
    puts "[ERROR] Consumer Key or Consumer Secret is empty."
    exit
  end

  config
end

desc "List notebooks"
task :notebooks do
  config = check_and_get_config

  # Evernote API requires only access_token (No need for Consumer-*)
  es     = EvernoteSpider.new(config["access_token"])

  # Get the shared notebook's access token and get notes
  share_key = config["shared_notebooks"].first["share_key"]
  notebook, shared_notebook_access_token = es.get_shared_notebook(share_key)

  # warn: access to shared notebooks needs another access token
  note_list = es.get_note_list(notebook, shared_notebook_access_token)

  # What is Note/NoteAttribute?
  #   Types.Note          = cf. http://dev.evernote.com/documentation/reference/Types.html#Struct_Note
  #   Types.NoteAttribute = cf. http://dev.evernote.com/documentation/reference/Types.html#Struct_NoteAttributes
  note_list.notes.each do |note|

    resources    = es.get_note_resources(note, shared_notebook_access_token)
    tags         = es.get_note_tags(note, shared_notebook_access_token)
    xml_content  = es.get_note_xml(note, shared_notebook_access_token)

    # Write your code: print / insert db / etc...
    pp note, resources.delete("body"), tags, xml_content
  end

end

desc "Retrieve access token"
task :get_access_token do
  puts "retrieve access token from sandobox.evernote.com ..."

  config = check_and_get_config
  client = EvernoteOAuth::Client.new(consumer_key: config["consumer_key"], consumer_secret: config["consumer_secret"], sandbox: true)

  begin

    #
    request_token = client.request_token(:oauth_callback => "http://127.0.0.1:9999/")

    #
    system('open', request_token.authorize_url) || puts("Access here: #{request_token.authorize_url}\nand...")

    # Create callback web app and get access token.
    app = Proc.new do |env|
            access_token = nil

            # when callback reqeust
            if env['PATH_INFO'] == '/'

              # fetch GET params to gen access token
              req = Rack::Request.new(env)
              oauth_verifier = req.params["oauth_verifier"]

              #
              access_token = request_token.get_access_token(:oauth_verifier => oauth_verifier)
              puts "access token: #{access_token.token}"

              Rack::Handler::WEBrick.shutdown
            end

            # Webrick response
            [
              '200',
              {'Content-Type' => 'text/html'},
              [(access_token.nil?) ? "this is callback app." : access_token.token]
            ]
          end

    # Enable 'Ctrl+C' on WEBrick
    Signal.trap('INT') {
      Rack::Handler::WEBrick.shutdown
    }

    handler = Rack::Handler::WEBrick

    # run WEBrick with silent mode
    handler.run(app, :Port => 9999, :Logger => WEBrick::Log.new("/dev/null"), AccessLog: [])

  rescue => e
    puts "Error obtaining temporary credentials: #{e.message}"
  end

end
