#!/usr/bin/ruby -w

# Mapping data in yale_jyutping.mapping taken from the table at:
#
#   http://cburgmer.nfshost.com/content/cantonese-yale-syllable-table
# and
#   http://cburgmer.nfshost.com/content/jyutping-syllable-table
#
# which are available under http://creativecommons.org/licenses/by-sa/2.0/de/deed.en
#
# So thanks to Christoph for compiling the data.

require 'rubygems'
require 'json'

jyutping_to_yale = {}
yale_to_jyutping = {}

JYUTPING_INITIALS = [
  'b', 'p', 'm', 'f'
  'd', 't', 'n', 'l'
  'g', 'k', 'ng', 'h'
  'gw', 'kw', 'w',
  'z', 'c', 's', 'j'
]

YALE_INITIALS = [
  'b', 'p', 'm', 'f'
  'd', 't', 'n', 'l'
  'g', 'k', 'ng', 'h'
  'gw', 'kw', 'w',
  'j', 'ch', 's', 'j'
]

File.open(ARGV[0]) do |file|
  file.each_line do |line|
    values = line.split(",")
    yale = values[0].strip
    jyutping = values[1].strip
    yale_to_jyutping[yale] = jyutping
    jyutping_to_yale[jyutping] = yale
  end
end

# Non-standard jyutpings that apper in Unihan.
jyutping_to_yale['deu'] = 'diu'
jyutping_to_yale['gep'] = 'gaap'
jyutping_to_yale['kep'] = 'kip'
jyutping_to_yale['lem'] = 'lim'
jyutping_to_yale['loei'] = 'leui'
jyutping_to_yale['loet'] = 'leuk'
jyutping_to_yale['pet'] = 'pek'
jyutping_to_yale['om'] = 'am'

File.open('jyutping_yale.json', 'w') { |file| file.write(jyutping_to_yale.to_json) }
File.open('yale_jyutping.json', 'w') { |file| file.write(yale_to_jyutping.to_json) }
