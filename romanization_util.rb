#!/usr/bin/ruby -w

require 'romanization_util_data'

SPLIT_NUM = /([a-zA-Z]+)(\d.*)/
SPLIT_CANTODICT_TONE = /(\d)(\*\d)?/

def split_tone(phonetic)
  phonetic =~ SPLIT_NUM
  phoneme = $1
  tone = $2
  return phoneme, tone
end

def yale_tone_mark_to_jyutping(yale_tone_mark)
  jyutping = YaleMark2Jyutping[yale_tone_mark]
  if jyutping.nil?
    puts "unrecognized yale mark #{yale_tone_mark}"
    return ''
  end
  return jyutping
end

def clean_cantodict_tone(canto_romanization)
  (raw_romanization, tone) = split_tone(canto_romanization)
  tone =~ SPLIT_CANTODICT_TONE
  if raw_romanization.nil? or tone.nil?
    return canto_romanization
  end

  normal_tone = $1
  normal_tone = "1" if normal_tone.eql?("7")
  return raw_romanization + normal_tone
end

def yale_tone_num_to_jyutping(yale_tone_num)
  normal_yale_tone_num = clean_cantodict_tone(yale_tone_num)
  jyutping = YaleNum2Jyutping[normal_yale_tone_num]
  if jyutping.nil?
    puts "unrecognized yale num #{yale_tone_num}: clean #{normal_yale_tone_num}"
  end
  return jyutping
end

def jyutping_to_yale_tone_num(jyutping)
  normal_jyutping = clean_cantodict_tone(jyutping)
  yale_tone_num = Jyutping2YaleNum[normal_jyutping]

  if yale_tone_num.nil?
    # Guess yale.
    return "#{normal_jyutping}"
  end
  return yale_tone_num
end

def jyutping_to_yale_tone_mark(jyutping)
  yale_tone_num = jyutping_to_yale_tone_num(jyutping)
  if yale_tone_num.nil?
    # Guessing yale.
    puts "guessing yale from #{jyutping}"
    yale_tone_num = jyutping
  end
  yale_tone_mark = yale_tone_num_to_tone_mark(yale_tone_num)
  if yale_tone_mark.nil?
    # If unrecognized, return a yale_tone_num
    yale_tone_mark = yale_tone_num
    puts "guessing mark #{yale_tone_mark} from #{yale_tone_num}"
  end
  return yale_tone_mark
#  yale_tone_num = jyutping_to_yale_tone_num(jyutping)
#  if yale_tone_num.nil?
#    # Might as well try jyutping.
#    yale_tone_num = jyutping
#  end
#  yale_tone_mark = YALE_TONE_NUMBER_TO_TONE_MARK[yale_tone_num]
#  if yale_tone_num.nil?
#    # Give up, and just return the original.
#    return jyutping
#  end
#  return yale_tone_mark
end

def yale_tone_num_to_tone_mark(yale_tone_num)
  return YaleNum2YaleMark[yale_tone_num]
end

def yale_tone_mark_to_tone_num(yale_tone_mark)
  return YaleMark2YaleNum[yale_tone_mark]
end

CHUNK_TEST=/[^[:alnum:]]/

def yale_tone_mark_to_jyutping_phrase(phrase)
  new_phrase = ''
  phrase.split(' ').each do |chunk|
    chunk = chunk.strip
    if not chunk.empty?
      if chunk.eql?('.') or chunk.eql?(',')
        new_phrase << chunk
      else
        new_phrase << yale_tone_mark_to_jyutping(chunk.strip)
      end
      new_phrase << ' '
    end
  end
  return new_phrase.strip!
end

def yale_tone_num_to_jyutping_phrase(phrase)
  new_phrase = ''
  phrase.split(' ').each do |chunk|
    chunk = chunk.strip
    if not chunk.empty?
      if chunk.eql?('.') or chunk.eql?(',')
        new_phrase << chunk
      else
        conv = yale_tone_num_to_jyutping(chunk.strip)
        if conv.nil?
          conv = chunk.strip
        end
        new_phrase << conv
      end
      new_phrase << ' '
    end
  end
  return new_phrase.strip!
end

def jyutping_phrase_to_yale_tone_mark(phrase)
  new_phrase = ''
  phrase.split(' ').each do |chunk|
    chunk = chunk.strip
    chunk.downcase!
    if not chunk.empty?
      if chunk.eql?('.') or chunk.eql?(',')
        new_phrase << chunk
      else
        new_phrase << jyutping_to_yale_tone_mark(chunk.strip)
      end
      new_phrase << ' '
    end
  end
  return new_phrase.strip!
end

def jyutping_phrase_to_yale_tone_num(phrase)
  new_phrase = ''
  phrase.split(' ').each do |chunk|
    chunk = chunk.strip
    chunk.downcase!
    if not chunk.empty? and not (chunk =~ CHUNK_TEST)
      new_phrase << jyutping_to_yale_tone_num(chunk.strip)
      new_phrase << ' '
    end
  end
  return new_phrase.strip!
end
