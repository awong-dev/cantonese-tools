#!/usr/bin/ruby -w

require 'rubygems'
require 'sqlite3'
require 'unified_queries'
require 'romanization_util'

unified = SQLite3::Database.open(ARGV[0])

unified.transaction

UPDATE_YALE_QUERY = unified.prepare(
  'UPDATE Cantonese set yale_tone_num=:yale_tone_num' +
  ', yale_tone_mark=:yale_tone_mark' +
  ' WHERE rowid = :rowid')

count = 0
unified.execute('SELECT rowid,jyutping FROM Cantonese') do |row|
  rowid = row[0]
  jyutping = row[1]
  yale_tone_mark = jyutping_phrase_to_yale_tone_mark(jyutping)
  yale_tone_num = jyutping_phrase_to_yale_tone_num(jyutping)
  puts "bad j: #{jyutping} t: #{yale_tone_mark} n: #{yale_tone_num}" if yale_tone_num.nil? or yale_tone_mark.nil?
  if yale_tone_num.nil?
    yale_tone_num = jyutping
  end
  if yale_tone_mark.nil?
    yale_tone_mark = jyutping
  end
  UPDATE_YALE_QUERY.execute('rowid' => rowid,
                            'yale_tone_mark' => yale_tone_mark,
                            'yale_tone_num' => yale_tone_num)
  count = count +1
  puts "at #{count}" if count % 500 == 0
end

unified.commit
