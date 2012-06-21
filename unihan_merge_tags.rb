#!/usr/bin/ruby -w

require 'rubygems'
require 'sqlite3'

EntryPattern = /^U\+(\S+)\t(\S+)\t(.*)/
CommentPattern = /^#.*/

if File.exists?(ARGV[0])
  db = SQLite3::Database.open(ARGV[0])
else 
  db = SQLite3::Database.new(ARGV[0])
  db.transaction do |trans|
    trans.execute("CREATE TABLE Characters (codepoint INTEGER PRIMARY KEY NOT NULL, char_utf8 TEXT NOT NULL)")
    trans.execute("CREATE TABLE Fields (id INTEGER PRIMARY KEY AUTOINCREMENT, codepoint INT NOT NULL, field_name TEXT NOT NULL, value TEXT NOT NULL, UNIQUE(codepoint, field_name), FOREIGN KEY(codepoint) REFERENCES Characters(codepoint))")
  end
end

upsert_entry = db.prepare('INSERT OR IGNORE INTO Characters (codepoint, char_utf8) values (:codepoint, :char_utf8)')
upsert_field = db.prepare('INSERT OR REPLACE INTO Fields (codepoint, field_name, value) values (:codepoint, :field_name, :value)')

db.transaction
ARGV[1..-1].each do |raw_dict|
  File.open(raw_dict, 'r') do |f|
    f.each_line do |line|
      if not line =~ CommentPattern and not line.strip().empty?
        line =~ EntryPattern
        codepoint = $1.hex
        char_utf8 = [codepoint].pack('U')
        #puts "hmm #{codepoint} #$2 #$3"
        upsert_entry.execute 'codepoint' => codepoint, 'char_utf8' => char_utf8
        upsert_field.execute 'codepoint' => codepoint, 'field_name' => $2, 'value' => $3
      end
    end
  end
end
db.commit
