#!/usr/bin/ruby -w

require 'rubygems'
require 'sqlite3'

class UnifiedQueries
  attr_accessor :upsert_entry, :find_entry
  attr_accessor :insert_source, :num_source_with_name
  attr_accessor :insert_definition, :delete_definitions, :find_max_definition_sort
  attr_accessor :insert_pinyin, :delete_pinyin, :find_max_pinyin_sort
  attr_accessor :insert_jyutping, :delete_jyutping, :find_max_jyutping_sort
  attr_accessor :insert_variant, :find_max_variant_sort

  def initialize(db)
    @upsert_entry = db.prepare('INSERT OR IGNORE INTO Entries (entry, simplified_entry) values (:entry, :simplified_entry)')
    @find_entry = db.prepare('SELECT entry_id from Entries where entry = :entry')
    @insert_source = db.prepare('INSERT INTO Sources (source_id, source_name, priority, trust) VALUES (:id, :name, :priority, :trust)')
    @num_source_with_name = db.prepare('SELECT count(*) FROM Sources where source_name = :name')
    @insert_definition = db.prepare('INSERT INTO Definitions (entry_id, source_id, sort_order, definition) VALUES (:entry_id, :source_id, :sort_order, :definition)')
    @delete_definitions = db.prepare('DELETE FROM Definitions where entry_id = :entry_id AND source_id = :source_id')
    @find_max_definition_sort = db.prepare('SELECT MAX(sort_order) FROM Definitions WHERE entry_id = :entry_id AND source_id = :source_id')

    @insert_pinyin = db.prepare('INSERT INTO Pinyin (entry_id, source_id, sort_order, pinyin) VALUES (:entry_id, :source_id, :sort_order, :pinyin)')
    @delete_pinyin = db.prepare('DELETE FROM Pinyin where entry_id = :entry_id AND source_id = :source_id')
    @find_max_pinyin_sort = db.prepare('SELECT MAX(sort_order) FROM Pinyin WHERE entry_id = :entry_id AND source_id = :source_id')

    @insert_jyutping = db.prepare('INSERT INTO Cantonese (entry_id, source_id, sort_order, jyutping) VALUES (:entry_id, :source_id, :sort_order, :jyutping)')
    @delete_jyutping = db.prepare('DELETE FROM Cantonese where entry_id = :entry_id AND source_id = :source_id')
    @find_max_jyutping_sort = db.prepare('SELECT MAX(sort_order) FROM Cantonese WHERE entry_id = :entry_id AND source_id = :source_id')

    @find_max_variant_sort = db.prepare('SELECT MAX(sort_order) FROM Variants WHERE entry_id = :entry_id AND source_id = :source_id')
    @insert_variant = db.prepare('INSERT INTO Variants (entry_id, source_id, sort_order, variant) VALUES (:entry_id, :source_id, :sort_order, :variant)')
  end

  def add_pinyin(entry_id, source_id, pinyin)
    pinyin_sort_order = 0
    self.find_max_pinyin_sort.execute!(
      'entry_id' => entry_id,
      'source_id' => source_id) do |row|
      if not row[0].nil?:
        pinyin_sort_order = row[0] + 1
      end
      end
    self.insert_pinyin.execute('entry_id' => entry_id,
                                  'source_id' => source_id,
                                  'sort_order' => pinyin_sort_order,
                                  'pinyin' => pinyin)
  end

  def add_jyutping(entry_id, source_id, jyutping)
    jyutping_sort_order = 0
    self.find_max_jyutping_sort.execute!(
      'entry_id' => entry_id,
      'source_id' => source_id) do |row|
      if not row[0].nil?:
        jyutping_sort_order = row[0] + 1
      end
      end
    self.insert_jyutping.execute('entry_id' => entry_id,
                                 'source_id' => source_id,
                                 'sort_order' => jyutping_sort_order,
                                 'jyutping' => jyutping)
  end

  def add_definition(entry_id, source_id, definition)
    definition_sort_order = 0
    self.find_max_definition_sort.execute!(
      'entry_id' => entry_id,
      'source_id' => source_id) do |row|
      if not row[0].nil?:
        definition_sort_order = row[0] + 1
      end
      end
    self.insert_definition.execute('entry_id' => entry_id,
                                   'source_id' => source_id,
                                   'sort_order' => definition_sort_order,
                                   'definition' => definition)
  end

  def upsert_source(name, id, priority, trust)
    found = false
    self.num_source_with_name.execute('name' => name) do |result_set|
      result_set.each { |row| found = true if row[0] == 0 }
    end
    if found
      self.insert_source.execute('id' => id,
                                 'name' => name,
                                 'priority' => priority,
                                 'trust' => trust)
    end
  end

  def add_variant(entry_id, source_id, variant)
    variant_sort_order = 0
    self.find_max_variant_sort.execute!(
      'entry_id' => entry_id,
      'source_id' => source_id) do |row|
      if not row[0].nil?:
        variant_sort_order = row[0] + 1
      end
      end
    self.insert_variant.execute('entry_id' => entry_id,
                                'source_id' => source_id,
                                'sort_order' => variant_sort_order,
                                'variant' => variant)
  end
end

