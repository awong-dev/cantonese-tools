#!/usr/bin/ruby -w

require 'rubygems'
require 'sqlite3'
require 'unified_queries'
require 'romanization_util'

EntryPattern = /^(\S+) (\S*)\S+ \[(.*)\] \[(.*)\] (.*)/
CommentPattern = /^#.*/

SOURCE_NAME = 'Dictionary of Cantonese Slang'
SOURCE_ID = 4
SOURCE_PRIORITY = 600
SOURCE_TRUST = 1

unified = SQLite3::Database.open(ARGV[0])
queries = UnifiedQueries.new(unified)

unified.transaction

rows = unified.execute("SELECT count(*) FROM Sources where source_name = '#{SOURCE_NAME}'")
#puts rows.inspect
if rows[0][0].eql?(0)
  queries.insert_source.execute 'id' => SOURCE_ID, 'name' => SOURCE_NAME, 'priority' => SOURCE_PRIORITY, 'trust' => SOURCE_TRUST
end

count = 0
File.open(ARGV[1], 'r') do |file|
  file.each_line do |line|
    line.strip!
    if not line =~ CommentPattern and not line.strip().empty?
      line =~ EntryPattern
      if $1.nil?
        puts "bad line #{line}"
        next
      end
      traditional = $1.strip
      simplified = $2.strip
      yale = $3.strip
      pinyin = $4.strip
      definitions = []
      $5.split('/').each { |x| x.strip!; definitions << x if not x.empty? }
      jyutping = []
      yale.split('|').each { |y| jyutping << yale_tone_mark_to_jyutping_phrase(y) }

      queries.upsert_entry.execute 'entry' => traditional, 'simplified_entry' => simplified
      entry_id =  queries.find_entry.execute!('entry' => traditional)[0][0]

      jyutping.each do |p|
        p.strip!
        queries.add_jyutping(entry_id, SOURCE_ID, p) if not p.empty?
      end

      pinyin.split("|").each do |p|
        p.strip!
        queries.add_pinyin(entry_id, SOURCE_ID, p) if not p.empty?
      end

      definitions.each { |d| queries.add_definition(entry_id, SOURCE_ID, d) }
    end

  count = count + 1
  puts "at #{count}" if count % 500 == 0
  end
end
unified.commit
