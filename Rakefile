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

task :default => [:get_auth_token]

desc "Retrieve access token"
task :get_auth_token do
  puts "retrieve access token from sandobox.evernote.com ..."

  begin
    config = YAML.load_file("./config.yml").fetch("evernote")
  rescue
    puts "[ERROR] Please check your config.yml"
  end
  #
  if !config["access_token"].nil?
    puts "[WARNING] You already have access token in your config."
  end

  if config["consumer_key"].nil? || config["consumer_secret"].nil?
    puts "[ERROR] Consumer Key or Consumer Secret is empty."
    exit
  end

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
