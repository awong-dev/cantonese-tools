#!/usr/bin/ruby -w

require 'rubygems'
require 'sqlite3'

unified = SQLite3::Database.open(ARGV[0])

num_inferred = 0

unified.transaction
unified.execute("SELECT DISTINCT Entries.entry_id FROM Entries LEFT JOIN Cantonese ON Entries.entry_id = Cantonese.entry_id WHERE Cantonese.entry_id IS NULL" ) do |row|
  num_inferred = num_inferred + 1
  puts row.inspect
end
puts "num inferred: #{num_inferred}"
#unified.commit
