# -*- coding: utf-8 -*-

require "pp"
require "yaml"

require "./lib/evernote_spider.rb"

# EvernoteSpiderインスタンスを作る
# config.ymlにある内容はauthToken(期限付きだった気がする)を作るために必要
# API使うには基本的にauthTokenさえあればいいが、
# 共有ノートブックに関連する操作は、その共有ノートブックに
# 付けられたauthTokenが別途必要になる
config = YAML.load(open("config.yml"))
es     = EvernoteSpider.new(config["evernote"]["authToken"])

# 共有ノートブックの取得(別途authTokenが必要)
# ここではget_shared_notebookの返り値にauthTokenが含まれているから
# それを使っているが、
# authToken = get_authtoken_shared_notebook(shareKey)
# としてもok、いずれにしてもauthTokenには期限があるので毎回生成してる
shareKey            = config["sharedNotebook"]["shareKey"]
notebook, authToken = es.get_shared_notebook(shareKey)

# ノートブック内のノート一覧を取得
note_list = es.get_note_list(notebook, authToken)

# ノートを1つずつ処理していく
# Noteに関するリファレンス
#   Types.Note          = http://dev.evernote.com/documentation/reference/Types.html#Struct_Note
#   Types.NoteAttribute = http://dev.evernote.com/documentation/reference/Types.html#Struct_NoteAttributes
note_list.notes.each do |note|

  # ここでは
  # ・ノートに貼り付けられたリソース(画像とかZIPとかPDFとか)
  # ・タグ
  # ・ノートの内容(XMLで宣言されてるけどHTMLの<xml>body</xml>みたいになってるだけ)
  # の3つを取得している。
  # ノートの情報はnote.title, note.createdみたいな感じでとる
  resources    = es.get_note_resources(note, authToken)
  tags         = es.get_note_tags(note, authToken)
  xml_content  = es.get_note_xml(note, authToken)

  # 取得したリソースはデータベースにぶっ込んでおくって感じ
  pp note, resources.delete("body"), tags, xml_content

end

__END__

#notebooks        = es.get_notebooks
#linked_notebooks = es.get_linked_notebooks
#shared_notebook  = es.get_shared_notebook(linked_notebooks.first.shareKey)



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
