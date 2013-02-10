# -*- coding: utf-8 -*-

dir = File.expand_path(File.dirname(__FILE__))
$LOAD_PATH.push("#{dir}/")
$LOAD_PATH.push("#{dir}/Evernote/EDAM")

#
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

require "digest/md5"
require "kconv"
require "pp"
require "yaml"
require "nokogiri"

class EvernoteSpider

  def initialize(authToken, host="sandbox.evernote.com")
    @authToken = authToken
    @host      = host
    @note2blog = Nokogiri::XSLT(File.read("#{File.expand_path(File.dirname(__FILE__))}/note.xslt"))
    check
  end

  # ノートの中身をXMLで返却
  # XSLT使ってXMLに変換している
  def get_note_xml(note, authToken)
    raw_content = get_note_store.getNoteContent(authToken, note.guid)
    return @note2blog.transform(Nokogiri::XML(raw_content)).to_s
  end

  # ノートのタグを返却
  def get_note_tags(note, authToken)
    return get_note_store.getNoteTagNames(authToken, note.guid)
  end

  # ノートに添付されたやつをハッシュの配列形式で返却
  def get_note_resources(note, authToken)
    if note.resources
      return note.resources.map do |resource|
        data = get_note_store.getResource(authToken, resource.guid, true, true, true, true)

        hash = data.data.bodyHash.unpack('H*').first

        # MIMEタイプを検出
        mime = case data.mime
        when 'image/png'
          'png'
        when 'image/jpeg'
          'jpg'
        else
          nil
        end

        extension = File.extname(data.attributes.fileName)
        body = data.data.body

        {
          "filename" => data.attributes.fileName,
          "body" => body,
          "extension" => extension,
          "mime" => mime,
          "hash" => hash,
        }
      end
    else
      return nil
    end
  end

  # ノートブックからノートの一覧を取得
  def get_note_list(notebook, authToken, options = {})
    options = {
      "words"    => "",
      "offset"   => 0,
      "maxNotes" => 100,
    }.merge(options)

    filter              = Evernote::EDAM::NoteStore::NoteFilter.new
    filter.notebookGuid = get_notebook_guid(notebook)
    filter.words        = options["words"]

    res = get_note_store.findNotes(authToken, filter, options["offset"], options["maxNotes"])

    return res
  end

  def get_notebooks()
    return get_note_store.listNotebooks(@authToken)
  end

  def get_linked_notebooks()
    return get_note_store.listLinkedNotebooks(@authToken)
  end

  def get_shared_notebook(shareKey)
    sharedBookAuthToken = get_authtoken_shared_notebook(shareKey)
    return get_note_store.getSharedNotebookByAuth(sharedBookAuthToken), sharedBookAuthToken
  end

  def get_authtoken_default
    return @authToken
  end

  def get_authtoken_shared_notebook(shareKey)
    authResult = get_note_store.authenticateToSharedNotebook(shareKey, @authToken)
    return authResult.authenticationToken
  end

  private

    # 以下初期化処理など
    # 仕様通りに書いてあるって感じ

    def get_notebook_guid(notebook)
      case notebook
        when Evernote::EDAM::Type::Notebook
        when Evernote::EDAM::Type::LinkedNotebook
          return notebook.guid
        when Evernote::EDAM::Type::SharedNotebook
          return notebook.notebookGuid
        else
          raise "unknown notebook type"
      end
    end

    def get_user_store_url()
      return "https://#{@host}/edam/user"
    end

    def get_store_protocol(store_url)
      storeTransport = Thrift::HTTPClientTransport.new(store_url)
      return Thrift::BinaryProtocol.new(storeTransport)
    end

    def get_note_store()
      userStore      = get_user_store()
      noteStoreUrl   = userStore.getNoteStoreUrl(@authToken)
      store_protocol = get_store_protocol(noteStoreUrl)
      return Evernote::EDAM::NoteStore::NoteStore::Client.new(store_protocol);
    end

    def get_user_store()
      store_url      = get_user_store_url()
      store_protocol = get_store_protocol(store_url)
      return Evernote::EDAM::UserStore::UserStore::Client.new(store_protocol)
    end

    def check()
      userStore = get_user_store
      versionOK = userStore.checkVersion("Evernote EDAMTest (Ruby)",
                                         Evernote::EDAM::UserStore::EDAM_VERSION_MAJOR,
                                         Evernote::EDAM::UserStore::EDAM_VERSION_MINOR)
      raise "Evernote API version must be up to date." if !versionOK
    end

end


