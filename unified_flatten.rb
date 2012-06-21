#!/usr/bin/ruby -w

require 'rubygems'
require 'sqlite3'
require 'unified_queries'

unified = SQLite3::Database.open(ARGV[0])
flattened = SQLite3::Database.open(ARGV[1])

flattened.transaction

def make_source_query(table)
  return "SELECT c.source_id, s.trust FROM #{table} c" +
    " JOIN Sources s ON c.source_id = s.source_id" +
    " WHERE c.entry_id = :entry_id " +
    " ORDER by s.priority LIMIT 1"
end

def make_value_query(table, column)
  return "SELECT #{column} FROM #{table} c" +
  " WHERE c.entry_id = :entry_id AND c.source_id = :source_id" +
  " ORDER BY c.sort_order" +
  " LIMIT :limit"
end

SOURCE_QUERIES = {}
SOURCE_QUERIES['Definitions'] = unified.prepare(make_source_query('Definitions'))
SOURCE_QUERIES['Cantonese'] = unified.prepare(make_source_query('Cantonese'))
SOURCE_QUERIES['CantoneseNum'] = unified.prepare(make_source_query('Cantonese'))
SOURCE_QUERIES['Pinyin'] = unified.prepare(make_source_query('Pinyin'))
SOURCE_QUERIES['Variants'] = unified.prepare(make_source_query('Variants'))

VALUE_QUERIES = {}
VALUE_QUERIES['Definitions'] = unified.prepare(make_value_query('Definitions', 'definition'))
VALUE_QUERIES['Cantonese'] = unified.prepare(make_value_query('Cantonese', 'yale_tone_mark'))
VALUE_QUERIES['CantoneseNum'] = unified.prepare(make_value_query('Cantonese', 'yale_tone_num'))
VALUE_QUERIES['Pinyin'] = unified.prepare(make_value_query('Pinyin', 'pinyin'))
VALUE_QUERIES['Variants'] = unified.prepare(make_value_query('Variants', 'variant'))

FLATTENED_DELETE = flattened.prepare(
  'DELETE From FlattenedEntries WHERE entry = :entry')
FLATTENED_INSERT = flattened.prepare(
  'INSERT INTO FlattenedEntries' +
  ' (entry, simplified, variant, trust, cantonese, pinyin, definition, extra_search)' +
  ' VALUES (:entry, :simplified, :variant, :trust, :cantonese, :pinyin, :definition, :extra_search)')

def get_entries(entry_id, table, limit)
  source_id = -1
  source_trust = -1
  SOURCE_QUERIES[table].execute!('entry_id' => entry_id) do |source_row|
    source_id = source_row[0]
    source_trust = source_row[1]
  end
  if source_id == -1
#    puts "nothing for #{entry_id} in #{table}"
    return 4,[] if source_id == -1  # No source means no entry for this field.
  end

  values = []
  VALUE_QUERIES[table].execute!('entry_id' => entry_id,
                                'source_id' => source_id,
                                'limit' => limit) do |value_row|
    value_row.each { |entry|
      entry.strip!;
      values << entry if not entry.empty?
    }
  end
  return Integer(source_trust), values
end

count = 0
bad_entries = []
unified.execute('SELECT entry_id, entry, simplified_entry FROM Entries ORDER BY entry') do |row|
  entry_id = row[0]
  entry = row[1]
  simplified = row[2]
  (def_trust, def_values) = get_entries(entry_id, 'Definitions', 5)
  (cant_trust, cant_values) = get_entries(entry_id, 'Cantonese', 5)
  (cant_num_trust, cant_num_values) = get_entries(entry_id, 'CantoneseNum', 1)
  (pinyin_trust, pinyin_values) = get_entries(entry_id, 'Pinyin', 5)
  (variant_trust, variant_values) = get_entries(entry_id, 'Variants', 5)
  if def_values.empty? and cant_num_values.empty? and pinyin_values.empty?
    #bad_entries << entry
    puts "Bad: #{entry_id} #{entry}"
    next
  end
  # Always trust unihan variant data for single characters.
  if entry.length == 1
    variant_values = []
    variant_trust = 2
    # TODO(awong): Don't hardcode Unihan as 1.
    VALUE_QUERIES['Variants'].execute!(
      'entry_id' => entry_id, 'source_id' => 1, 'limit' => 50) do |variant_row|
      variant_values << variant_row[0]
    end
  end

  # Now insert stuff.
  FLATTENED_DELETE.execute!('entry' => entry)
  FLATTENED_INSERT.execute!(
    'entry' => entry,
    'simplified' => simplified,
    'variant' => variant_values.join('/'),
    'trust' => [def_trust,
      pinyin_trust,
      cant_trust,
      variant_trust].max,
    'cantonese' => cant_values.join('/'),
    'pinyin' => pinyin_values.join('/'),
    'definition' => def_values.join('/'),
    'extra_search' => cant_num_values[0])
  count = count + 1
  puts "at #{count}" if count % 500 == 0
end

puts "Finished with #{count}"
puts "Bad entries: #{bad_entries.to_s}.  total #{bad_entries.length}"

flattened.commit
