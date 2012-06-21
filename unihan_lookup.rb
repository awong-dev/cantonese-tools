#!/usr/bin/ruby -w

require 'rubygems'
require 'sqlite3'

EntryPattern = /^U\+(\S+)\t(\S+)\t(.*)/
CommentPattern = /^#.*/

db = SQLite3::Database.open(ARGV[0])

find_characer = db.prepare('select value from Characters, Fields where Characters.codepoint = :codepoint and Characters.codepoint=Fields.codepoint and (field_name="kCantonese" or field_name="kDefinition") order by field_name')

i = 0

while true do
  line = STDIN.readline
  cps = line.unpack("U*")
  cps.each do |cp|
    res = ''
    find_characer.execute('codepoint' => cp).each { |row|
      f = row[0]
      res <<  f
    }
    res.strip!
    puts "#{i}: #{[cp].pack('U*')} #{res}"
    i = i + 1
  end
end
