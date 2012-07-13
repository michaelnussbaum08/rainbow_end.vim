
nmap <silent> <leader>b :ruby toggle_rainbow<CR>

ruby << EOF

# TODO: find and highlight middle elements of blocks (else, rescue, etc.)

@rainbow_on = false

def toggle_rainbow
  if @rainbow_on
    Vim.command("call clearmatches()")
  else
    block_finder = BlockFinder.new
    highlighter = BlockHighlighter.new(block_finder.blocks)
    highlighter.color
  end
  @rainbow_on = !@rainbow_on
end

class BlockHighlighter
  COLORS = {RED: 196, ORANGE: 208, YELLOW: 226, GREEN: 10, BLUE: 81}.cycle

  def initialize(blocks)
    @blocks = blocks
  end

  def color()
    @blocks.each do |beginning, ending|
      color, color_code = COLORS.next
      _make_color_group(color, color_code)
      _highlight_word(color, beginning)
      _highlight_word(color, ending)
    end
  end

  def _make_color_group(name, color_code)
    VIM.command("highlight #{name} ctermfg=#{color_code}")
  end

  def _highlight_word(color_group, word_location)
    line = word_location[:line]
    start_column = word_location[:char_range][0] + 1
    end_column = word_location[:char_range][1] + 1
    match_location = "\\(\\%#{line}l\\&\\%#{start_column}v.*\\%#{end_column}v\\)"
    command = "call matchadd(\"#{color_group}\", '#{match_location}')"
    Vim.command(command)
  end
end



class BlockFinder
  attr_reader :blocks

  START_OF_LINE_BEGINNINGS = ['if', 'unless', 'while', 'until']
  ANYWHERE_BEGINNINGS = ['module', 'class', 'def', 'case', 'begin', 'do']

  def initialize()
    @blocks = []
    beginnings, endings = _find_beginnings_and_endings
    _find_blocks(beginnings, endings)
  end

  def _find_blocks(beginnings, ends)
    beginnings.sort_by!{ |match| match[:line] }.reverse!
    ends.map do |ending|
      beginning_match = beginnings.select do |beginning|
        break beginning if beginning[:line] < ending[:line]
      end
      beginnings.delete(beginning_match)
      @blocks << [beginning_match, ending]
    end
  end

  def _find_beginnings_and_endings()
    end_lines = []
    beginning_lines = []
    current_buffer = Vim::Buffer.current
    1.upto(current_buffer.count) do |line_num|
      line = current_buffer[line_num]
      # These keywords only open blocks at the beginning of a line
      beginning_matches = START_OF_LINE_BEGINNINGS.map do |beginning|
        line.match(/^[ ]*#{beginning}([ ]+|$)/i)
      end
      # These keywords always open a block
      anywhere_beginning_matches = ANYWHERE_BEGINNINGS.map do |beginning|
        line.match(/(^|[ ]+)#{beginning}([ ]+|$)/i)
      end
      beginning_matches.concat(anywhere_beginning_matches)
      end_match = line.match(/(^|[ ]+)end([ ]+|$)/)
      if end_match
        end_lines << {line: line_num, char_range: end_match.offset(0)}
      elsif beginning_matches.any?
        # There should only be one beginning per line
        match = beginning_matches.keep_if { |match| match }[0]
        beginning_lines << {line: line_num, char_range: match.offset(0)}
      end
    end
    return beginning_lines, end_lines
  end
end

EOF

