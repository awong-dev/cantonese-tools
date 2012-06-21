#!/usr/bin/ruby -w

require 'rubygems'
require 'json'

Jyutping2YaleNum = {}
Jyutping2YaleMark = {}
YaleNum2Jyutping = {}
YaleNum2YaleMark = {}
YaleMark2YaleNum = {}
YaleMark2Jyutping = {}

INITIALS = [
  # Common set
  'b', 'p', 'm', 'f', 'd', 't', 'n', 'l', 'g', 'k', 'ng', 'h', 's', 'gw', 'kw', 'w',

  # In Jyutping, y -> j, j -> z, ch -> c.  Also, '' becomes j with the yu vowel.
  'y', 'j', 'ch', ''
]

VOWELS = [
  # Common set
  'a', 'aa', 'e', 'i', 'o', 'u', 'yu',

  # In Jyutping, eu becomes eo EXCEPT when it is bare, or used with the
  # endings ng, or k. In these cases, it becomes oe.
  #
  # Also, the 'e' 'u' vowel, ending sound may exist in jyutping, but
  # is not the same as the "eu" yale vowel.  This does not have a yale
  # representation.  Instead, we use use "ew" in yale for this.
  'eu'
]


VOWEL_ENDINGS = [
  # Common set
  '', 'i', 'u',
]

CONSONANT_ENDINGS = [
  # Common set
  'm', 'n', 'ng', 'p', 't', 'k',
]

RISING_MAP = {
  "a" => "á",
  "e" => "é",
  "i" => "í",
  "o" => "ó",
  "u" => "ú",
  'm' => 'ḿ',
  'ng' => 'ńg',
  'aa' => 'áa',
  'yu' => 'yú',
  'eu' => 'éu',
}

FALLING_MAP = {
  "a" => "à",
  "e" => "è",
  "i" => "ì",
  "o" => "ò",
  "u" => "ù",
  'm' => 'm̀',
  'ng' => 'ǹg',
  'aa' => 'àa',
  'yu' => 'yù',
  'eu' => 'èu',
}

LEVEL_MAP = {
  "a" => "ā",
  "e" => "ē",
  "i" => "ī",
  "o" => "ō",
  "u" => "ū",
  'm' => 'm̄',
  'ng' => 'n̄g',
  "aa" => "āa",
  "yu" => "yū",
  "eu" => "ēu",
}

def generate_jyutping(initial, vowel, ending, tone)
  input = "#{initial}, #{vowel}, #{ending}, #{tone}"
  raise "bad combo #{input}" if vowel.eql?(ending)
  raise "bad combo #{input}" if not ending.empty? and vowel[-1].eql?(ending[1])
  raise "bad combo #{input}" if vowel.empty? and not initial.empty?

  # See comment in INITIALS.
  if initial.eql?('y')
    initial = 'j'
  elsif initial.eql?('j')
    initial = 'z'
  elsif initial.eql?('ch')
    initial = 'c'
  elsif initial.empty? and vowel.eql?('yu')
    initial = 'j'
  end

  # See comment in VOWELS.
  if vowel.eql?('eu')
    if ending.empty? or ending.eql?('ng') or ending.eql?('k')
      vowel = 'oe'
    else
      vowel = 'eo'
    end
  end

  return "#{initial}#{vowel}#{ending}#{tone}"
end

def generate_yale_num(initial, vowel, ending, tone)
  return "#{initial}#{vowel}#{ending}#{tone}"
end

def generate_yale_mark(initial, vowel, ending, tone)
  if not vowel.empty?
    if tone == 1
      vowel = LEVEL_MAP[vowel]
    elsif tone == 2 or tone == 5
      vowel = RISING_MAP[vowel]
    elsif tone == 4
      vowel = FALLING_MAP[vowel]
    end
  end

  if tone > 3
    if ending.eql?('u') or ending.eql?('i')
      ending = ending + 'h'
    elsif not vowel.empty?
      vowel = vowel + 'h'
    end
  end

  return "#{initial}#{vowel}#{ending}"
end

def generate_yale(initial, vowel, ending, tone)
  input = "#{initial}, #{vowel}, #{ending}, #{tone}"
  raise "bad combo #{input}" if vowel.eql?(ending)
  raise "bad combo #{input}" if not ending.empty? and vowel[-1].eql?(ending[1])
  raise "bad combo #{input}" if vowel.empty? and not initial.empty?

  # Special handling of a jyutping "eu" sound, which as an artifact
  # of our enumeration system will show up as vowlen "e" and ending "u"
  # "e" and "u"  -> el mapping.
  #
  # For this sound, we make up an ending 'w' to represent it.
  if vowel.eql?('e') and ending.eql?('u')
    ending = 'w'
  end

  # Yale does not double-up the y for this case.
  if initial.eql?('y') and vowel.eql?('yu')
    initial = ''
  end

  return generate_yale_num(initial, vowel, ending, tone), generate_yale_mark(initial, vowel, ending, tone)
end

def generate_all_maps(initial, vowel, ending, tone)
  # This is an artificial split to handle consonant only phonemes.
  # We need this to more easily add tone marks and h for yale markings.
  if initial.empty? and vowel.empty?
    if ending.eql?('m') 
      vowel = 'm'
      ending = ''
    elsif ending.eql?('ng')
      vowel = 'ng'
      ending = ''
    end
  end

  jyutping = generate_jyutping(initial, vowel, ending, tone)
  (yale_num, yale_mark) = generate_yale(initial, vowel, ending, tone)

  Jyutping2YaleNum[jyutping] = yale_num
  Jyutping2YaleMark[jyutping] = yale_mark

  YaleNum2YaleMark[yale_num] = yale_mark
  YaleNum2Jyutping[yale_num] = jyutping

  YaleMark2Jyutping[yale_mark] = jyutping
  YaleMark2YaleNum[yale_mark] = yale_num
end

(1..6).each do |tone|
  INITIALS.each do |initial|
    VOWELS.each do |vowel|
      last_vowel_char = vowel[-1, 1]
      VOWEL_ENDINGS.each do |ending|
        if not last_vowel_char.eql?(ending) and not last_vowel_char.eql?(ending)
          generate_all_maps(initial, vowel, ending, tone)
        end
      end
      CONSONANT_ENDINGS.each do |ending|
        generate_all_maps(initial, vowel, ending, tone)
      end
    end
  end

  # And special case the 2 consonants m and ng that can stand alone.
  generate_all_maps('', '', 'm', tone)
  generate_all_maps('', '', 'ng', tone)
end

# These aren't yale marks, but since the m4 is so hard to type, often tone mark
# pinyin just uses tone numbers here.
YaleMark2YaleNum['m4'] = 'm4'
YaleMark2Jyutping['m4'] = 'm4'

def mapping_to_s(mapping)
  s = ""
  mapping.each { |key, value|
    s << "'#{key}' => '#{value}',
    "
  }
  return s
end

puts "Jyutping2YaleNum = { #{mapping_to_s(Jyutping2YaleNum.sort)} }"
puts "Jyutping2YaleMark = { #{mapping_to_s(Jyutping2YaleMark.sort)} }"
puts "YaleNum2Jyutping = { #{mapping_to_s(YaleNum2Jyutping.sort)} }"
puts "YaleNum2YaleMark = { #{mapping_to_s(YaleNum2YaleMark.sort)} }"
puts "YaleMark2YaleNum = { #{mapping_to_s(YaleMark2YaleNum.sort)} }"
puts "YaleMark2Jyutping = { #{mapping_to_s(YaleMark2Jyutping.sort)} }"
