#!/usr/bin/ruby -w

require 'rubygems'
require 'sqlite3'
require 'unified_queries'
require 'set'

unified = SQLite3::Database.open(ARGV[0])
unihan = SQLite3::Database.open(ARGV[1])
queries = UnifiedQueries.new(unified)

EXTRACT_CODEPOINT=/U\+([0-9A-F]+)<?(.*)?/

UNIHAN_FIND = unihan.prepare('SELECT value FROM Fields where codepoint = :codepoint AND field_name = :field')

SOURCE_NAME = 'Unihan'
SOURCE_ID = 1
SOURCE_PRIORITY = 500
SOURCE_TRUST = 1

unified.transaction

queries.upsert_source(SOURCE_NAME, SOURCE_ID, SOURCE_PRIORITY, SOURCE_TRUST)

def find_variants(codepoint)
  traditional = nil
  simplified = nil
  variants = []
  UNIHAN_FIND.execute!('codepoint' => codepoint, 'field' => 'kSimplifiedVariant') do |variant_row|
    variant_row[0] =~ EXTRACT_CODEPOINT
    simplified = [$1.hex].pack('U*')
  end

  UNIHAN_FIND.execute!('codepoint' => codepoint, 'field' => 'kTraditionalVariant') do |variant_row|
    variant_row[0] =~ EXTRACT_CODEPOINT
    variant_char_utf8 = [$1.hex].pack('U*')
    traditional = variant_char_utf8
  end

  UNIHAN_FIND.execute!('codepoint' => codepoint, 'field' => 'kSemanticVariant') do |variant_row|
    variant_row[0].split(' ').each do |var|
      var =~ EXTRACT_CODEPOINT
      variant_char_utf8 = [$1.hex].pack('U*')
      if not $2.nil?
        suffix = $2.strip
        if not suffix.empty? and suffix.length == 1
          variant_char_utf8 = variant_char_utf8 + ($2.split(',')[-1].strip)
        end
      end
      variants << variant_char_utf8
    end
  end

  UNIHAN_FIND.execute!('codepoint' => codepoint, 'field' => 'kSpecializedSemanticVariant') do |variant_row|
    variant_row[0].split(' ').each do |var|
      var =~ EXTRACT_CODEPOINT
      variant_char_utf8 = [$1.hex].pack('U*')
      if not $2.nil?
        suffix = $2.strip
        if not suffix.empty? and suffix.length == 1
          variant_char_utf8 = variant_char_utf8 + ($2.split(',')[-1].strip)
        end
      end
      variants << variant_char_utf8
    end
  end
  return traditional, simplified, variants
end

count = 0
unihan.execute("select codepoint,char_utf8 from Characters" ) do |row|
  codepoint = row[0]
  char_utf8 = row[1]
  # Find variants
  (traditional, simplified, variants) = find_variants(codepoint)
  if not traditional.nil? and not traditional.eql?(char_utf8)
    # Skip all simplified characters.  Some characters used in both trad & simp are makred as
    # the traditional variant of themsleves so we allow adding those.
    #
    # This loses some variant data since mulipled traditional characters may map to a simplified
    # character, but that's to fix later.
    puts "Skipping #{codepoint}, #{char_utf8}, t: #{traditional} s:#{simplified} v:#{variants.join(',')}"
    next
  end

  # Ensure entry exists.
  queries.upsert_entry.execute 'entry' => char_utf8, 'simplified_entry' => simplified

  entry_id = 0
  queries.find_entry.execute!('entry' => char_utf8) { |entry_row| entry_id = entry_row[0] }

  # Add variants.
  variants_added = Set.new()
  variants_added.add(char_utf8)
  variants.each do |v|
    if not variants_added.member?(v)
      queries.add_variant(entry_id, SOURCE_ID, v)
      variants_added.add(v)
    end
  end

  # Find definitions.
  queries.delete_definitions.execute('entry_id' => entry_id, 'source_id' => SOURCE_ID)
  num_rows = 0
  UNIHAN_FIND.execute!('codepoint' => codepoint, 'field' => 'kDefinition') do |definition_row|
    num_rows = num_rows + 1
    raise "too many defs" if num_rows > 1
    raw_definition = definition_row[0]
    sort_order = 0
    raw_definition.split(';').each do |definition| 
      queries.insert_definition.execute('entry_id' => entry_id, 'source_id' => SOURCE_ID, 'sort_order' => sort_order, 'definition' => definition.strip)
      sort_order = sort_order + 1
    end
  end

  # Find pinyin.
  queries.delete_pinyin.execute('entry_id' => entry_id, 'source_id' => SOURCE_ID)
  num_rows = 0
  UNIHAN_FIND.execute!('codepoint' => codepoint, 'field' => 'kMandarin') do |pinyin_row|
    num_rows = num_rows + 1
    raise "too many pinyins" if num_rows > 1
    raw_pinyin = pinyin_row[0]
    sort_order = 0
    raw_pinyin.split(' ').each do |pinyin| 
      queries.insert_pinyin.execute('entry_id' => entry_id, 'source_id' => SOURCE_ID, 'sort_order' => sort_order, 'pinyin' => pinyin.strip)
      sort_order = sort_order + 1
    end
  end

  # Find jyutping.
  num_rows = 0
  queries.delete_jyutping.execute('entry_id' => entry_id, 'source_id' => SOURCE_ID)
  UNIHAN_FIND.execute!('codepoint' => codepoint, 'field' => 'kCantonese') do |jyutping_row|
    num_rows = num_rows + 1
    raise "too many jyutpings" if num_rows > 1
    raw_jyutping = jyutping_row[0]
    sort_order = 0
    raw_jyutping.split(' ').each do |jyutping| 
      queries.insert_jyutping.execute('entry_id' => entry_id, 'source_id' => SOURCE_ID, 'sort_order' => sort_order, 'jyutping' => jyutping.strip)
      sort_order = sort_order + 1
    end
  end

  count = count +1
  puts "at #{count}" if count % 500 == 0
end

unified.commit
