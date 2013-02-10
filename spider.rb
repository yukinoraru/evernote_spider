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

  # ここで、取得したリソースをデータベースにぶっ込むイメージ
  # railsはDBからデータを取得して記事表示って感じ
  pp note, resources.delete("body"), tags, xml_content

end


