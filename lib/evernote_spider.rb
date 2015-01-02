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
require "digest/md5"
require "kconv"
require "pp"
require "yaml"
require "nokogiri"

class EvernoteSpider

  def initialize(auth_token, host="sandbox.evernote.com")
    @auth_token = auth_token
    @host       = host
    @note2blog  = Nokogiri::XSLT(File.read("#{File.expand_path(File.dirname(__FILE__))}/note.xslt"))

    check_api_version
  end

  # ノートの中身をXMLで返却
  # XSLT使ってXMLに変換している
  def get_note_xml(note, auth_token)
    raw_content = get_note_store.getNoteContent(auth_token, note.guid)
    return @note2blog.transform(Nokogiri::XML(raw_content)).to_s
  end

  # ノートのタグを返却
  def get_note_tags(note, auth_token)
    return get_note_store.getNoteTagNames(auth_token, note.guid)
  end

  # ノートに添付されたやつをハッシュの配列形式で返却
  def get_note_resources(note, auth_token)
    if note.resources
      return note.resources.map do |resource|
        data = get_note_store.getResource(auth_token, resource.guid, true, true, true, true)

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
  def get_note_list(notebook, auth_token, options = {})
    options = {
      "words"    => "",
      "offset"   => 0,
      "maxNotes" => 100,
    }.merge(options)

    filter              = Evernote::EDAM::NoteStore::NoteFilter.new
    filter.notebookGuid = get_notebook_guid(notebook)
    filter.words        = options["words"]

    res = get_note_store.findNotes(auth_token, filter, options["offset"], options["maxNotes"])

    return res
  end

  def get_notebooks()
    return get_note_store.listNotebooks(@auth_token)
  end

  def get_linked_notebooks()
    return get_note_store.listLinkedNotebooks(@auth_token)
  end

  def get_shared_notebook(shareKey)
    sharedBookauth_token = get_auth_token_shared_notebook(shareKey)
    return get_note_store.getSharedNotebookByAuth(sharedBookauth_token), sharedBookauth_token
  end

  def get_auth_token_default
    return @auth_token
  end

  def get_auth_token_shared_notebook(shareKey)
    authResult = get_note_store.authenticateToSharedNotebook(shareKey, @auth_token)
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
      noteStoreUrl   = userStore.getNoteStoreUrl(@auth_token)
      store_protocol = get_store_protocol(noteStoreUrl)
      return Evernote::EDAM::NoteStore::NoteStore::Client.new(store_protocol);
    end

    def get_user_store()
      store_url      = get_user_store_url()
      store_protocol = get_store_protocol(store_url)
      return Evernote::EDAM::UserStore::UserStore::Client.new(store_protocol)
    end

    def check_api_version()
      userStore = get_user_store
      versionOK = userStore.checkVersion("Evernote EDAMTest (Ruby)",
                                         Evernote::EDAM::UserStore::EDAM_VERSION_MAJOR,
                                         Evernote::EDAM::UserStore::EDAM_VERSION_MINOR)
      raise "Evernote API version must be up to date." if !versionOK
    end

end
