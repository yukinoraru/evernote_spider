# -*- coding: utf-8 -*-

# Add the Thrift & Evernote Ruby libraries to the load path.
# This will only work if you run this application from the ruby/sample/client
# directory of the Evernote API SDK.
dir = File.expand_path(File.dirname(__FILE__))
$LOAD_PATH.push("#{dir}/")
$LOAD_PATH.push("#{dir}/Evernote/EDAM")

#"
require "thrift/types"
require "thrift/struct"
require "thrift/protocol/base_protocol"
require "thrift/protocol/binary_protocol"
require "thrift/transport/base_transport"
require "thrift/transport/http_client_transport"
require "Evernote/EDAM/user_store.rb"
require "Evernote/EDAM/user_store_constants.rb"
require "Evernote/EDAM/note_store.rb"
require "Evernote/EDAM/limits_constants.rb"

# Load general gems
require "digest/md5"
require "kconv"
require "pp"
require "yaml"
require "nokogiri"

class EvernoteSpider
  def initialize(authToken, host="sandbox.evernote.com")
    self.authToken = authToken
    self.host = host

    self.check()
  end

  private:
    def check()
      userStoreUrl = "https://#{self.host}/edam/user"
      userStoreTransport = Thrift::HTTPClientTransport.new(userStoreUrl)
      userStoreProtocol  = Thrift::BinaryProtocol.new(userStoreTransport)
      userStore          = Evernote::EDAM::UserStore::UserStore::Client.new(userStoreProtocol)
      versionOK = userStore.checkVersion("Evernote EDAMTest (Ruby)",
                                         Evernote::EDAM::UserStore::EDAM_VERSION_MAJOR,
                                         Evernote::EDAM::UserStore::EDAM_VERSION_MINOR)
      if(!versionOK)
        raise "Evernote API version must be up to date."
      end
    end

end

es = EvernoteSpider.new()

__END__

# Get the URL used to interact with the contents of the user's account
# When your application authenticates using OAuth, the NoteStore URL will
# be returned along with the auth token in the final OAuth request.
# In that case, you don't need to make this call.
noteStoreUrl         = userStore.getNoteStoreUrl(authToken)
noteStoreTransport   = Thrift::HTTPClientTransport.new(noteStoreUrl)
noteStoreProtocol    = Thrift::BinaryProtocol.new(noteStoreTransport)
noteStore            = Evernote::EDAM::NoteStore::NoteStore::Client.new(noteStoreProtocol)

notebooks            = noteStore.listLinkedNotebooks(authToken)
defaultNotebook      = notebooks[0]
shareKey             = defaultNotebook.shareKey

pp notebooks; exit 1

# $nb is the linkedNotebook
# Create a connection to the owner's shard
userStoreUrl       = "https://#{evernoteHost}/edam/note"
userStoreTransport = Thrift::HTTPClientTransport.new(userStoreUrl)
noteStoreProtocol1 = Thrift::BinaryProtocol.new(noteStoreTransport);
linkedNoteStore    = Evernote::EDAM::NoteStore::NoteStore::Client.new(noteStoreProtocol1);

# Authenticating using our current access token & the sharekey of the sharedNotebook
authResult       = noteStore.authenticateToSharedNotebook(shareKey, authToken)
linkedNotebooks  = noteStore.getSharedNotebookByAuth(authResult.authenticationToken)
#pp linkedNotebooks

filter = Evernote::EDAM::NoteStore::NoteFilter.new
filter.words = ""
filter.notebookGuid = linkedNotebooks.notebookGuid
res = noteStore.findNotes(authResult.authenticationToken, filter, 0, 100)


note2blog = Nokogiri::XSLT(File.read('lib/note.xslt'))


#####
authToken = authResult.authenticationToken
#####
res.notes.each do |note|

  if note.resources
    note.resources.each do |resource|
      data = noteStore.getResource(authToken, resource.guid, true, true, true, true)
      hex = data.data.bodyHash.unpack('H*').first
      #     ext = case data.mime
      #             when 'image/png'
      #               'png'
      #             when 'image/jpeg'
      #               'jpg'
      #             else
      #               raise "Unknown mime type: #{data.mime}, #{data.inspect}"
      #             end
      ext = File.extname(data.attributes.fileName)
      puts "EXTENTION = #{ext}"
      File.open("./images/#{hex}.#{ext}", 'w') {|f| f.write(data.data.body) }
    end
  end

  tags = noteStore.getNoteTagNames(authToken, note.guid)
  content_raw  = noteStore.getNoteContent(authToken, note.guid)
  content_html = note2blog.transform(Nokogiri::XML(content_raw)).to_s

  File.open("#{note.title}.html", "w"){|f| f.write(content_html)}
  puts note.title, tags, content_html.toutf8

end

