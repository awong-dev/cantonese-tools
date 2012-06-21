#!/usr/bin/ruby -w

require 'rubygems'
require 'sqlite3'
require 'unified_queries'

EntryPattern = /^(\S+) (\S*)\S+ \[(.*)\] \[(.*)\] (.*)/
CommentPattern = /^#.*/

SOURCE_NAME = 'Cantonese CC-CEDICT'
SOURCE_ID = 3
SOURCE_PRIORITY = 300
SOURCE_TRUST = 2

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
      jyutping = $3.strip
      pinyin = $4.strip
      definitions = []
      $5.split('/').each { |x| x.strip!; definitions << x if not x.empty? }

      queries.upsert_entry.execute 'entry' => traditional, 'simplified_entry' => simplified
      entry_id =  queries.find_entry.execute!('entry' => traditional)[0][0]

      jyutping.split("|").each do |p|
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
