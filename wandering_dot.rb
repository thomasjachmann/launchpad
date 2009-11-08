require 'rubygems'
require 'midiator'

@midi = MIDIator::Interface.new
@midi.autodetect_driver

def note_for(x, y)
  y * 16 + x
end

def on_all(&block)
  (0..7).each do |row|
    row_start = row * 16
    (row_start..(row_start+7)).each(&block)
  end
end

def rand_pos
  rand(8)
end

def rand_dir
  rand(3) - 1
end

def new_dir(dir, pos)
  if (dir <= 0 && pos == 0) || pos == 7
    new_dir = rand_dir.abs
    new_dir = -new_dir if dir > 0
    new_dir
  else
    dir
  end
end

def change_dir(dir, pos, change)
  if (dir <= 0 && pos == 0) || pos == 7
    -dir
  elsif change
    case dir
    when -1 then -rand(2)
    when 0  then rand(2) == 0 ? -1 : 1
    when 1  then rand(2)
    end
  else
    dir
  end
end

def new_pos(pos, dir)
  [0, [pos + dir, 7].min].max
end

def end_it
  sleep 1
  final_note = note_for(@pos_x, @pos_y)
  4.times do
    on_all {|note| @midi.note_on(note, 0, 1) unless note == final_note}
    sleep 0.5
    on_all {|note| @midi.note_on(note, 0, 16) unless note == final_note}
    sleep 0.5
  end
  on_all {|note| @midi.note_off(note, 0)}
  sleep 0.5
end

remaining_notes = []
on_all do |note|
  remaining_notes << note
  @midi.note_off(note, 0)
end
remaining_notes.uniq!

sleep (ARGV[0] || 0).to_i

@pos_x = rand_pos
@pos_y = rand_pos
@dir_x = rand_dir
@dir_y = rand_dir

new_note = note_for(@pos_x, @pos_y)
old_note = nil

on_all {|note| @midi.note_on(note, 0, 3)}
on_all {|note| @midi.note_off(note, 0) unless note == new_note}

sleep 2
sleep_time = 1

loop do
  unless old_note == new_note || old_note.nil?
    @midi.note_off(old_note, 0)
    @midi.note_on(old_note, 0, 16)
    @midi.note_on(new_note, 0, 3)
  end
  remaining_notes.delete(new_note)
  end_it && break if remaining_notes.empty?
  change = rand(1)
  @dir_x = change_dir(@dir_x, @pos_x, change == 0)
  @dir_y = change_dir(@dir_y, @pos_y, change != 0)
  #@dir_x = new_dir(@dir_x, @pos_x)
  #@dir_y = new_dir(@dir_y, @pos_y)
  #while @dir_x == 0 && @dir_y == 0 || (old_note.nil? && (@dir_x == 0 || @dir_y == 0))
  #  if rand(1) == 0
  #    @dir_x = new_dir(@dir_x, @pos_x)
  #  else
  #    @dir_y = new_dir(@dir_y, @pos_y)
  #  end
  #end
  @pos_x = new_pos(@pos_x, @dir_x)
  @pos_y = new_pos(@pos_y, @dir_y)
  old_note = new_note
  new_note = note_for(@pos_x, @pos_y)
  sleep sleep_time
  sleep_time *= 0.96
end
