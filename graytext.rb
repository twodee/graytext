#!/usr/bin/env ruby

require 'tempfile'

module Graytext
  def self.configure path
    # STDERR.puts "path: #{path}"
    dir = File.expand_path(path)
    config = {}
    $offset = ''
    loop do
      dir = File.dirname(dir)
      rc_file = dir + '/.grayrc'
      if File.exists?(rc_file)
        lines = IO.read(rc_file).lines.grep(/(.*?)\s*=\s*(.*?)/)
        config = lines.map { |line| line.chomp.split(/\s*=\s*/) }.to_h
        break
      end
      break if dir == '/'
      $offset = File.basename(dir) + '/' + $offset
    end

    $offset.gsub!(/\/$/, '')

    config
  end

  class Token
    attr_reader :type, :text

    def initialize type, text = ''
      @type = type
      @text = text
    end
  end

  class Lexer
    attr_reader :tokens, :src

    def initialize src
      @src = src.dup
    end

    def lex
      @states = [:default, :linestart]
      @tokens = []
      @i = 0

      token = nil
      until token && token.type == :EOF
        token = get_token
        # STDERR.puts "#{token.inspect} -- now in #{@states[-1]}"
        @tokens << token
      end
    end

    def get_token
      @token_so_far = ''

      if @i >= src.length
        Token.new :EOF
      elsif @states[-1] == :linestart
        get_linestart_token
      elsif @states[-1] == :default
        get_default_token
      elsif @states[-1] == :table
        get_table_token
      elsif @states[-1] == :blockcode
        get_block_code_token
      elsif @states[-1] == :command
        get_command
      elsif @states[-1] == :attributes
        get_attributes
      elsif @states[-1] == :inline_code
        get_token_after_backtick
      elsif @states[-1] == :style_lines
        get_style_lines
      elsif @states[-1] == :eatspace
        until @i >= src.length || @src[@i] != ' '
          @i += 1
        end
        @states.pop
        get_token
      end
    end

    def get_command
      rest = @src[@i..-1]
      if rest =~ /\Astyle/
        @i += $&.length
        while @src[@i] == ' '
          @i += 1
        end
        @states[-1] = :attributes
        @id = 'style'
        Token.new :IDENTIFIER, 'style'
      elsif @src[@i] =~ /[A-Za-z0-9]/
        while @i < @src.length && @src[@i] =~ /[A-Za-z0-9]/
          @token_so_far << @src[@i]
          @i += 1
        end
        @id = @token_so_far
        @states[-1] = :attributes
        Token.new :IDENTIFIER, @token_so_far
      elsif @src[@i] == '"'
        # Skip over ".
        @i += 1

        # Skip over whitespace.
        while @i < @src.length && @src[@i] =~ /[ \t]/
          @i += 1
        end

        @token_so_far = ''
        while @i < @src.length && @src[@i] != ']'
          @token_so_far << @src[@i]
          @i += 1
        end

        @states[-1] = :default
        Token.new :COMMENT, @token_so_far
      else
        raise "I dunno #{@src[@i..-1]}"
      end
    end

    def get_style_lines
      if @src[@i] == ']'
        @i += 1
        @states[-1] = :default
        Token.new :RIGHT_BRACKET, ']'
      else
        @token_so_far = ''
        while @i < @src.length && @src[@i] != "\n"
          @token_so_far << @src[@i]
          @i += 1
        end

        if @src[@i] == "\n"
          @i += 1
        else
          raise "ouch2"
        end

        Token.new :STYLE_LINE, @token_so_far
      end
    end

    def get_attributes
      while @src[@i] == ' '
        @i += 1
      end

      if @src[@i] == "\n"
        if @id == 'code' || @id == 'lineveil' || @id == 'madeup' || @id == 'css' || @id == 'mup' || @id == 'latex' || @id == 'texmath' # Any code blocks
          @states[-1] = :blockcode
        elsif @id == 'block' || @id == 'listveil' || @id == 'slide'
          @states[-1] = :linestart
        elsif @id == 'style'
          @states[-1] = :style_lines
        elsif @id == 'table'
          @states[-1] = :table
        else
          @states[-1] = :default
        end
        @i += 1
        Token.new :EOL, "\n"
      elsif @src[@i] == '|'
        @i += 1
        @states[-1] = :command
        @states.push :eatspace
        Token.new :SEPARATOR, '|'
      elsif @src[@i] == ']'
        @i += 1
        # @states[-1] = :default
        @states.pop
        Token.new :RIGHT_BRACKET, ']'
      elsif @src[@i] == '='
        @i += 1
        Token.new :EQUALS, '='
      elsif @src[@i] == '"'
        @i += 1
        value = ''
        while @i < @src.length && @src[@i] != '"'
          # Allow escaped.
          if @i < @src.length - 1 && @src[@i] == '\\'
            @i += 1
          end
          @token_so_far << @src[@i]
          @i += 1
        end
        if @src[@i] == '"'
          @i += 1
        end
        Token.new :QUOTED_VALUE, @token_so_far
      elsif @src[@i] !~ /[= \]\n]/
        while @i < @src.length && @src[@i] !~ /[= \]\n]/
          @token_so_far << @src[@i]
          @i += 1
        end
        if @token_so_far =~ /^[A-Za-z][A-Za-z0-9]+$/
          Token.new :IDENTIFIER, @token_so_far
        else
          Token.new :UNQUOTED_VALUE, @token_so_far
        end
      end
    end

    def get_linestart_token
      rest = @src[@i..-1]

      if rest =~ /\A(\d+)\.\s+/
        @i += $&.length
        @states.pop
        Token.new :INT, @token_so_far
      elsif rest =~ /\A-{5,}\r?\n/
        @i += $&.length
        Token.new :LINE, @token_so_far
      else
        c = src[@i]
        @i += 1
        @token_so_far << c

        case c
          when ' '
            get_token_indent
          when '-'
            @states[-1] = :eatspace
            Token.new :BULLET, @token_so_far
          when '_'
            @states[-1] = :eatspace
            Token.new :CHECKBOX, @token_so_far
          when '#'
            get_token_after_hash
          else
            @i -= 1
            @token_so_far = ''
            @states.pop
            @states.push :default
            get_default_token
        end
      end
    end

    def get_table_token
      get_default_token
    end

    def get_token_after_hash
      while @i < @src.length && @src[@i] == '#'
        @token_so_far << @src[@i]
        @i += 1
      end

      @states.push :default
      @states.push :eatspace

      if @i < @src.length && @src[@i] == '.'
        @i += 1
        Token.new :COUNTED_HASHES, @token_so_far
      else
        Token.new :HASHES, @token_so_far
      end
    end

    def get_default_token
      c = src[@i]
      @i += 1
      @token_so_far << c

      case c
        when "\n"
          if @states[-1] != :table
            @states.push :linestart
          end
          Token.new :EOL, @token_so_far
        when '*'
          get_token_after_asterisk
        when '`'
          @states.push :inline_code
          Token.new :BACKTICK, @token_so_far
        when '['
          @states.push :command
          Token.new :LEFT_BRACKET, @token_so_far
        when ']'
          @states.pop
          Token.new :RIGHT_BRACKET, @token_so_far
        when '-'
          get_token_after_dash
        when '\\'
          get_token_after_backslash
        when '|'
          if @states[-1] == :table
            Token.new :SEPARATOR, @token_so_far 
          else
            get_token_content
          end
        else
          get_token_content
      end
    end

    def get_token_after_backslash
      # Replace the slash we just read with the succeeding character.
      if @i < @src.length
        @token_so_far[-1] = src[@i]
        @i += 1
      end
      get_default_token
    end

    def get_token_after_backtick
      c = src[@i]
      @i += 1
      @token_so_far << c

      if c == '`'
        @states.pop
        Token.new :BACKTICK, @token_so_far
      else
        while @i < @src.length && @src[@i] != '`'
          @token_so_far << @src[@i]
          @i += 1
        end
        Token.new :CODE, @token_so_far
      end
    end

    def get_token_after_dash
      if @i + 1 < @src.length && @src[@i] == '-' && @src[@i + 1] == '-'
        @i += 2
        Token.new :EMDASH, '---'
      else
        get_token_content
      end
    end

    def get_token_after_asterisk
      if @i < @src.length && @src[@i] == '*'
        @i += 1
        Token.new :STARSTAR, @token_so_far
      else
        Token.new :STAR, @token_so_far
      end
    end

    def get_block_code_token
      # if @src[@i..-1] =~ /\A([ \t]*\])/
      if @src[@i..-1] =~ /\A\]/
        @i += 1
        @states.pop
        Token.new :RIGHT_BRACKET, ']'
      elsif @src[@i] == "\n"
        @i += 1
        Token.new :EOL, "\n"
      else
        while @i < @src.length && @src[@i] != "\n"
          @token_so_far << @src[@i]
          @i += 1
        end
        Token.new :CODE, @token_so_far.gsub(/\A\\\]/, ']')
      end
    end

    def get_token_content
      while @i < @src.length && @src[@i] != "\n" && @src[@i] != '`' && @src[@i] != '*' && @src[@i] != '[' && @src[@i] != '-' && (@states[-1] != :table || @src[@i] != '|')
        # Skip
        if @src[@i] == '\\' && @i + 1 < @src.length
          @i += 1
        end
        @token_so_far << @src[@i]
        @i += 1
      end
      Token.new :CONTENT, @token_so_far
    end

    def get_token_indent
      while @i < @src.length && @src[@i] == ' '
        @token_so_far << @src[@i]
        @i += 1
      end
      Token.new :INDENT, @token_so_far
    end
  end

  class Parser
    def initialize tokens, target, config
      @tokens = tokens
      @target = target
      @config = config
      @root = nil
      @madeupurl = 'http://madeup.xyz'
      @maxmupframes = 8
      @skin = 'flat'
      @styles = Hash.new
      @counters = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
      @mups = []
      @css = ''

      # @tokens.each do |token|
        # if token.type == :COMMENT
          # if token.text =~ /\broot\s*=\s*(\S+)/
            # @root = $1
          # elsif token.text =~ /\broot\s*=\s*(\S+)/
            # @root = $1
          # end
        # end
      # end

      if @target == 'wordpress' && @config.has_key?('root')
        @root = @config['root'] + '/' + $offset
      end
    end

    def entitize code
      code.gsub(/&/, '&amp;').gsub(/</, '&lt;').gsub(/>/, '&gt;')
    end

    def parse
      dst = ''

      @is_in_backtick = false
      @is_in_asterisk = false
      @is_in_starstar = false

      @i = 0
      until @tokens[@i].type == :EOF
        dst += line
      end

      if @target == 'html'
        dst += IO.read(File.dirname(__FILE__) + "/skins/#{@skin}/footer.html")

        header = IO.read(File.dirname(__FILE__) + "/skins/#{@skin}/header.html")
        # Header has \0 in it, which is special to gsub.
        header.gsub!(/(?<=<style>)(?=<\/style>)/, IO.read(File.dirname(__FILE__) + "/skins/#{@skin}/style.css").gsub(/(\\\d)/, '\\\\\1') + "\n\n/* Custom CSS */\n#{@css}")
        utilities_source = IO.read(File.dirname(__FILE__) + "/skins/#{@skin}/utilities.js").gsub(/\\'/, "\\\\\\\\'")
        header.gsub!(/(?<=<script>)(?=<\/script>)/, utilities_source)
        dst = header + dst
      end

      if !@mups.empty?
        dst += <<EOF
  <script>
  var maxMupFrames = #{@maxmupframes};
  var mups = [#{@mups.map { |mup| "'#{mup}'" }.join(', ')}];
EOF

        if @skin != 'slides'
          dst += <<EOF
  mups.forEach(function(mup) {
    document.getElementById('mup-form-' + mup).submit();
  });
EOF
        end

        dst += '</script>'
      end

      dst
    end

    def list indent
      dst = ''

      if indent == 0
        list_type = @tokens[@i].type
      else
        list_type = @tokens[@i + 1].type
      end

      dst += ' ' * 2 * indent
      if list_type == :BULLET
        dst += "<ul>\n"
      elsif list_type == :CHECKBOX
        dst += "<ul class=\"gray-todo\">\n"
      else
        dst += "<ol>\n"
      end
      while (indent == 0 && @tokens[@i].type == list_type) || (@tokens[@i].type == :INDENT && @tokens[@i].text.length / 2 == indent && @tokens[@i + 1].type == list_type)
        if @tokens[@i].type == :INDENT
          @i += 1
        end
        @i += 1
        dst += "#{' ' * 2 * (indent + 1)}<li>"
        dst += '<input type="checkbox" class="gray-todo-checkbox">' if list_type == :CHECKBOX
        dst += content
        if @tokens[@i].type == :EOL
          @i += 1
        else
          raise 'expected eol'
        end
        if @i + 1 < @tokens.length && @tokens[@i].type == :INDENT && @tokens[@i].text.length / 2 > indent && (@tokens[@i + 1].type == :BULLET || @tokens[@i + 1].type == :INT)
          dst += "\n"
          # puts @tokens[@i].text.length / 2
          # puts indent
          # puts @tokens[@i].inspect
          # puts @tokens[@i + 1].inspect
          dst += list indent + 1
          dst += ' ' * 2 * indent
        end
        dst += "</li>\n"
      end
      dst += ' ' * 2 * indent
      if list_type == :BULLET
        dst += "</ul>\n"
      elsif list_type == :CHECKBOX
        dst += "</ul>\n"
      else
        dst += "</ol>\n"
      end

      dst
    end

    def just_saw_comment
      i_last_non_eol = @i
      while i_last_non_eol > 0 && @tokens[i_last_non_eol].type == :EOL
        i_last_non_eol -= 1
      end
      i_last_non_eol >= 2 && @tokens[i_last_non_eol - 2].type == :LEFT_BRACKET && @tokens[i_last_non_eol - 1].type == :COMMENT && @tokens[i_last_non_eol].type == :RIGHT_BRACKET
    end

    def line
      dst = ''

      if @tokens[@i].type == :HASHES || @tokens[@i].type == :COUNTED_HASHES
        rank = @tokens[@i].text.length
        real_rank = rank
        rank += 2 # if @target == 'wordpress' # HEADER TAGS
        dst += "<h#{rank}>"
        if @tokens[@i].type == :COUNTED_HASHES
          # lesser ranks go back to 0
          for ri in real_rank...@counters.size
            @counters[ri] = 0
          end
          @counters[real_rank - 1] += 1
          dst += @counters.take(real_rank).map(&:to_s).join('.') + '. '
        end
        @i += 1
        dst += content
        dst += "</h#{rank}>\n"
        if @tokens[@i].type == :EOL
          @i += 1
        else
          raise "Expected end-of-line, found #{@tokens[@i].type}"
        end
      elsif @tokens[@i].type == :LINE
        if @styles.has_key? 'gray.line'
          dst += "<hr style=\"#{@styles['gray.line']}\">"
        else
          dst += '<hr>'
        end
        @i += 1
      elsif @tokens[@i].type == :INDENT
        @i += 1
      elsif @tokens[@i].type == :BULLET
        dst += list 0
      elsif @tokens[@i].type == :INT
        dst += list 0
      elsif @tokens[@i].type == :CHECKBOX
        dst += list 0
      else
        dst += content

        # Don't add a linebreak after a comment tag.
        dst += "\n" if !just_saw_comment

        if @tokens[@i].type == :EOL
          @i += 1
        else
          raise "Expected end-of-line, found #{@tokens[@i].type}"
        end
      end

      dst
    end

    def first_of_content? type
      ([:CONTENT, :LEFT_BRACKET, :COMMENT].member? type) || (type == :BACKTICK && !@is_in_backtick) || (type == :STAR && !@is_in_asterisk) || (type == :STARSTAR && !@is_in_starstar) || (type == :EMDASH)
    end

    def first_of_line? type
      ([:COUNTED_HASHES, :HASHES, :LINE, :INDENT, :BULLET, :INT, :EOL, :CHECKBOX].member? type) || first_of_content?(type)
    end

    def parse_attributes
      attributes = Hash.new
      while @tokens[@i].type == :IDENTIFIER
        key = @tokens[@i].text
        @i += 1
        if @tokens[@i].type == :EQUALS
          @i += 1
        else
          raise "expected =, found #{@tokens[@i].type} [#{@tokens[@i].text}]"
        end
        if @tokens[@i].type == :QUOTED_VALUE || @tokens[@i].type == :UNQUOTED_VALUE || @tokens[@i].type == :IDENTIFIER
          value = @tokens[@i].text
          @i += 1
        else
          raise "expected =, found #{@tokens[@i].type}"
        end
        attributes[key] = value
      end
      attributes
    end

    def count_preceding_linebreaks
      n = 0
      pi = @i - 1
      while pi >= 0
        # puts @tokens[pi].inspect
        if @tokens[pi].type == :EOL
          n += 1
          # puts n
          pi -= 1
        elsif pi >= 2 && @tokens[pi - 2].type == :LEFT_BRACKET && @tokens[pi - 1].type == :COMMENT && @tokens[pi].type == :RIGHT_BRACKET
          pi -= 3
        else
          break
        end
      end
      # puts
      n
    end

    def is_comment
      @tokens[@i].type == :LEFT_BRACKET && @tokens[@i + 1].type == :COMMENT && @tokens[@i + 2].type == :RIGHT_BRACKET
    end

    def is_let
      @tokens[@i].type == :LEFT_BRACKET && @tokens[@i + 1].type == :IDENTIFIER && 'let' == @tokens[@i + 1].text
    end

    def is_image
      @tokens[@i].type == :LEFT_BRACKET && @tokens[@i + 1].type == :IDENTIFIER &&
      (@tokens[@i + 1].text == 'image')
    end

    def is_block
      @tokens[@i].type == :LEFT_BRACKET && @tokens[@i + 1].type == :IDENTIFIER &&
      (@tokens[@i + 1].text == 'block' ||
       @tokens[@i + 1].text == 'code' ||
       @tokens[@i + 1].text == 'hide' ||
       @tokens[@i + 1].text == 'slide' ||
       @tokens[@i + 1].text == 'listveil')
    end

    def is_code
      @tokens[@i].type == :LEFT_BRACKET && @tokens[@i + 1].type == :IDENTIFIER && @tokens[@i + 1].text == 'code'
    end

    def content coalesce_adjacent_lines = true
      dst = ''

      # Need a paragraph?
      # puts "checking before #{@tokens[@i].inspect}"
      needs_paragraph = (count_preceding_linebreaks >= 2 || @i == 0) && !is_comment && !is_let && !is_block && !is_image && @tokens[@i].type != :EOL
      dst += "<p class=\"grayblock\">" if needs_paragraph

      while first_of_content? @tokens[@i].type
        if @tokens[@i].type == :CONTENT
          dst += @tokens[@i].text
          @i += 1
          is_first_content = false
        elsif @tokens[@i].type == :BACKTICK
          @i += 1
          dst += '<code>'
          @is_in_backtick = true
          if @tokens[@i].type != :CODE
            raise "expected backtick, found #{@tokens[@i].inspect}"
          end
          dst += entitize(@tokens[@i].text)#.gsub(/ {2,}/) do |match|
            # '&nbsp;' * match.length
          # end
          @i += 1
          if @tokens[@i].type == :BACKTICK
            @i += 1
          else
            raise "expected backtick, found #{@tokens[@i].inspect}"
          end
          @is_in_backtick = false
          dst += '</code>'
        elsif @tokens[@i].type == :STAR
          @i += 1
          dst += '<em>'
          @is_in_asterisk = true
          dst += content
          if @tokens[@i].type == :STAR
            @i += 1
          else
            raise "expected asterisk, found #{@tokens[@i].inspect}"
          end
          @is_in_asterisk = false
          dst += '</em>'
        elsif @tokens[@i].type == :EMDASH
          @i += 1
          dst += '&mdash;'
        elsif @tokens[@i].type == :STARSTAR
          @i += 1
          dst += '<b>'
          @is_in_starstar = true
          dst += content
          if @tokens[@i].type == :STARSTAR
            @i += 1
          else
            raise "expected starstar, found #{@tokens[@i].inspect}"
          end
          @is_in_starstar = false
          dst += '</b>'
        elsif @tokens[@i].type == :LEFT_BRACKET
          @i += 1

          dst += handle_command

          if @tokens[@i].type == :RIGHT_BRACKET
            @i += 1
          else
            puts dst
            raise "expected ], found #{@tokens[@i].inspect} AND THEN #{@tokens[@i + 1].inspect}"
          end
        end

        # If content picks up again immediately after the line break, we merge
        # the next line with the content of the current line. The linebreak
        # isn't really a linebreak,
        # you see?
        if coalesce_adjacent_lines && @tokens[@i].type == :EOL && @i < @tokens.length - 1 && @tokens[@i + 1].type == :CONTENT
          @i += 1
        end
      end

      dst += "</p>" if needs_paragraph

      dst
    end

    def handle_command
      dst = ''

      # Comments
      if @tokens[@i].type == :COMMENT
        dst += "<!-- #{@tokens[@i].text} -->" if @target != 'wordpress'
        @i += 1

      # Macro
      elsif @tokens[@i].type == :IDENTIFIER
        command = @tokens[@i].text
        @i += 1
        attributes = parse_attributes

        # STDERR.puts "attributes: #{attributes.inspect}"

        # Expand style key.
        if attributes.has_key? 'style'
          attributes['style'] = @styles[attributes['style']]
        end

        if command == "link"
          blacklist = %w{to title}
          attributes_string = attributes.reject { |key, _| blacklist.include? key }.map { |key, value| " #{key}=\"#{value}\"" }.join
          dst += "<a href=\"#{attributes['to']}\"#{attributes_string}>#{attributes['title']}</a>"
          
        # Style definitions
        elsif command == 'style'
          if @tokens[@i].type == :EOL
            @i += 1
          else
            raise 'expected EOL'
          end

          lines = []
          while @tokens[@i].type == :STYLE_LINE
            lines << @tokens[@i].text
            @i += 1
          end 

          if !attributes.has_key?('id')
            STDERR.puts "Styles need IDs."
            exit 1
          end
          key = attributes['id']

          @styles[key] = lines.map { |line| "#{line};" }.join(' ')
          if attributes.has_key?('parent')
            @styles[key] = @styles[attributes['parent']] + @styles[key]
          end

        elsif command == 'css'
          if @tokens[@i].type == :EOL
            @i += 1
          else
            raise 'expected EOL'
          end

          lines = []
          while @i < @tokens.length && @tokens[@i].type == :CODE
            lines << @tokens[@i].text
            @i += 1
            if @tokens[@i].type == :EOL
              @i += 1
            else
              raise "expected EOL after code, found #{@tokens[@i].type}"
            end
          end 

          if !attributes.has_key?('selector')
            STDERR.puts "CSS blocks need selector defined."
            exit 1
          end
          selector = attributes['selector']

          @css += "#{selector} {\n" + lines.map { |line| "  #{line};" }.join("\n") + "\n}\n\n"

        elsif command == 'let'
          if @target != 'wordpress' && attributes.has_key?('root')
            @root = attributes['root']
          end

          if attributes.has_key? 'skin'
            @skin = attributes['skin']
          end

          if attributes.has_key? 'madeupurl'
            @madeupurl = attributes['madeupurl']
          end

          if attributes.has_key? 'maxmupframes'
            @maxmupframes = attributes['maxmupframes']
          end

          attributes.each do |key, value|
            @config[key] = value
          end

        elsif command == 'break'
          dst += '<br>'

        elsif command == "table"
          dst += "<table>\n"
          if @tokens[@i].type == :EOL
            @i += 1
          else
            raise 'expected EOL'
          end

          irow = 0

          while @tokens[@i].type != :RIGHT_BRACKET
            cell_letter = (irow == 0 && attributes.has_key?('headers') && attributes['headers'] == 'true') ? 'h' : 'd'
            icolumn = 0

            def get_cell_style attributes, col
              if attributes.has_key?('align') && col < attributes['align'].length
                case attributes['align'][col]
                  when 'r'
                    "text-align: right"
                  when 'c'
                    "text-align: center"
                  else
                    "text-align: left"
                end
              else
                "text-align: left"
              end
            end

            dst += "  <tr>\n    <t#{cell_letter} style=\"#{get_cell_style attributes, icolumn}\">\n"
            while @tokens[@i].type != :EOL
              while @tokens[@i].type != :SEPARATOR && @tokens[@i].type != :EOL
                dst += content false
              end
              if @tokens[@i].type == :SEPARATOR
                icolumn += 1
                dst += "\n    </t#{cell_letter}>\n    <t#{cell_letter} style=\"#{get_cell_style attributes, icolumn}\">\n"
                @i += 1
              end
            end
            dst += "\n    </t#{cell_letter}>\n  </tr>\n"
            @i += 1
            irow += 1
          end
          dst += "</table>"

        elsif command == "javascript"
          src = attributes['src']
          if @target == 'wordpress'
            if src !~ /https?:\/\// && @root
              src = "#{@root}/#{src}"
            end
            dst += "[emjs src=\"#{src}\"]"
          else
            dst += "<script src=\"#{src}\"></script>"
          end
          
        elsif command == "frame"
          s = attributes.map { |key, value| ['src', 'autosize'].member?(key) ? '' : " #{key}=\"#{value}\"" }.join
          if attributes.has_key?('autosize') && attributes['autosize'] == 'true'
            if attributes.has_key?('id')
              if @target == 'wordpress'
                autosize_attribute = " autosize=\"true\""
              else
                autosize_attribute = " onload=\"autosize('#{attributes['id']}')\"";
              end
            else
              STDERR.puts "Autosizes need IDs."
              exit 1
            end
          else
            autosize_attribute = ""
          end
          if @target == 'wordpress'
            src = attributes['src']
            if src !~ /https?:\/\// && @root
              src = "#{@root}/#{src}"
            end
            dst += "[frame src=\"#{src}\"#{s}#{autosize_attribute}]"
          else
            dst += "<iframe scrolling=\"auto\" src=\"#{attributes['src']}\"#{s}#{autosize_attribute} frameborder=\"0\"></iframe>"
          end

        elsif command == "youtube"
          attributes['src'].gsub!(/youtu\.be/, 'www.youtube.com/embed')
          s = attributes.map { |key, value| key == 'src' ? '' : " #{key}=\"#{value}\"" }.join
          if @target == 'wordpress'
            dst += "[frame src=\"#{attributes['src']}\"#{s} frameborder=\"0\" allowfullscreen]"
          else
            dst += "<iframe src=\"#{attributes['src']}\"#{s} frameborder=\"0\" allowfullscreen></iframe>"
          end
        elsif command == "timedown"
          if @target == 'wordpress'
            dst += "[timedown seconds=#{attributes['seconds']} id=timedown1]"
          else
            dst += "<script>generateTimedown(#{attributes['seconds']}, 'timedown1');</script>"
          end
        elsif command == "span"
          s = attributes.map { |key, value| "#{key}=\"#{value}\"" }.join
          dst += "<span #{s}>"
          while @i < @tokens.length && (first_of_line? @tokens[@i].type)
            dst += line.chomp
          end
          dst += "</span>"
        elsif command == "slide"
          dst += "<div class=\"gray-slide #{(attributes.has_key?('fullscreen') && attributes['fullscreen'] == 'true') ? '' : 'not-'}fullscreen#{attributes.has_key?('class') ? " #{attributes['class']}" : ''}\">"

          is_valigned = attributes.has_key?('valign')
          if is_valigned
            dir = attributes['valign']
          else
            dir = 'top'
          end

          dst += %Q{<div class="gray-slide-content gray-valign-#{dir}">}

          while @i < @tokens.length && (first_of_line? @tokens[@i].type)
            dst += line
          end

          dst += '</div>'
          dst += '</div>'

        elsif command == "redacted"
          dst += '&#9608;&#9608;&#9608;&#9608;&#9608;&#9608;'

        elsif command == 'shot'
          ['app', 'src', 'ext'].each do |key|
            if !attributes.has_key? key
              raise "Shot must have #{key} attribute!"
            end
          end

          inpath = attributes['src']
          basepath = File.basename(inpath)
          ext = attributes['ext']
          outpath = "shots/#{basepath}.#{ext}"
          FileUtils.mkdir_p('shots')

          if !File.exists?(outpath) || File.mtime(outpath) < File.mtime(inpath)
            if attributes['app'] == 'puredata'
              `open -a Pd-0.48-0.app #{inpath}`
              STDERR.puts "screencapture -l $(GetWindowID Pd '#{inpath}') '#{outpath}'"
              `screencapture -l $(GetWindowID Pd '#{basepath}') '#{outpath}'`
              sleep 2
            else
              raise "I don\'t know #{attributes['app']}."
            end
          end

          outpath = "#{@root}/#{outpath}"

          if attributes.has_key?('caption')
            style = attributes.has_key?('style') ? " style=\"#{attributes['style']}\"" : ''
            dst += "<figure#{style}>"
          end

          s = attributes.map { |key, value| (['src', 'selflink', 'ext', 'app'].include?(key) || (attributes.has_key?('caption') && key == 'style')) ? '' : " #{key}=\"#{value}\"" }.join
          if attributes.has_key?('caption')
            s += ' width="100%"'
          end

          is_selflink = attributes.has_key?('selflink') && attributes['selflink'] == 'true'
          if is_selflink
            dst += "<a href=\"#{outpath}\" target=_blank>"
          end

          dst += "<img src=\"#{outpath}\"#{s}>"

          if is_selflink
            dst += "</a>"
          end

          if attributes.has_key? 'caption'
            dst += "<figcaption>#{attributes['caption']}</figcaption></figure>"
          end

        elsif command == "image"
          path = attributes['src']
          if path !~ /^https?:\/\//
            path = "#{@root}/#{path}"
          end

          if attributes.has_key?('caption')
            style = attributes.has_key?('style') ? " style=\"#{attributes['style']}\"" : ''
            dst += "<figure#{style}>"
          end

          s = attributes.map { |key, value| (key == 'src' || key == 'selflink' || (attributes.has_key?('caption') && key == 'style')) ? '' : " #{key}=\"#{value}\"" }.join
          if attributes.has_key?('caption')
            s += ' width="100%"'
          end

          is_selflink = attributes.has_key?('selflink') && attributes['selflink'] == 'true'
          if is_selflink
            dst += "<a href=\"#{path}\">"
          end

          dst += "<img src=\"#{path}\"#{s}>"

          if is_selflink
            dst += "</a>"
          end

          if attributes.has_key? 'caption'
            dst += "<figcaption>#{attributes['caption']}</figcaption></figure>"
          end

        else
          pair_string = attributes.map { |key, value| " #{key}=\"#{value}\"" }.join

          if command != 'code' || !attributes.has_key?('file')
            if @tokens[@i].type == :EOL
              @i += 1
            elsif @tokens[@i].type == :SEPARATOR
            else
              raise "expected EOL, found #{@tokens[@i].type}"
            end
          end

          if command == 'code'
            if attributes.has_key?('hide')
              dst += "<div class=\"indented grayblock\">"
              dst += "<a href=\"#\" class=\"toggler\">#{attributes['hide']}</a>"
              dst += '<div class="togglee">'
            end

            code = ''
            if attributes.has_key? 'file'
              code = IO.read(attributes['file'])
            else
              while @i < @tokens.length && (@tokens[@i].type == :CODE || @tokens[@i].type == :EOL)
                if @tokens[@i].type == :CODE
                  if @i + 2 < @tokens.length && @tokens[@i + 2].type == :CODE
                    code += "#{@tokens[@i].text}\n"
                  else
                    code += @tokens[@i].text
                  end
                  @i += 1
                else
                  code += "\n\n"
                end
                if @tokens[@i].type == :EOL
                  @i += 1
                else
                  raise "expected EOL after code, found #{@tokens[@i].type}"
                end
              end
            end

            if attributes.has_key?('scrambled')
              dst += '<div class="scramblebox">'
              dst += '<ol class="scrambled">'
              code.lines.each do |line|
                if attributes.has_key? 'lang'
                  dst += '<li>'
                  IO.popen("coderay -#{attributes['lang']} -div", 'r+') do |pipe|
                    pipe.puts line.chomp
                    pipe.close_write
                    code = pipe.read
                    dst += code.chomp
                  end
                  dst += '</li>'
                else
                  dst += "<li><pre>#{line.chomp}</pre></li>"
                end
              end
              dst += '</ol>'
              dst += '<p class="grayblock"><input type="button" class="scramble" value="Scramble"></p>'
              dst += '</div>'
            else
              if attributes.has_key? 'lang'
                if attributes['lang'] == 'madeup'
                  IO.popen("coderay -#{attributes['lang']} -div", 'r+') do |pipe|
                    pipe.puts code
                    pipe.close_write
                    code = pipe.read
                    code.gsub!(/<pre>/, '<pre class="gray-wrap">') if attributes['wrap'] == 'true'
                    dst += "<div#{pair_string}>#{code}</div>"
                  end
                else
                  IO.popen("pygmentize -Ostyle=colorful -f html -l #{attributes['lang']}", 'r+') do |pipe|
                    pipe.puts code
                    pipe.close_write
                    code = pipe.read
                    # STDERR.puts code
                    code.gsub!(/<pre>/, '<pre class="gray-wrap">') if attributes['wrap'] == 'true'
                    dst += "<div#{pair_string}>#{code}</div>"
                  end
                end
              else
                dst += "<pre#{pair_string}>"
                dst += entitize(code)
                dst += '</pre>'
              end
            end

            if attributes.has_key?('hide')
              dst += '</div>'
              dst += '</div>'
            end

          elsif command == 'raffle'
            choices = []
            while @i < @tokens.length && (@tokens[@i].type != :RIGHT_BRACKET)
              choices << line.chomp
            end

            if @target == 'wordpress'
              dst += "[raffle id=#{attributes['id']}]#{choices.join("\n")}[/raffle]"
            else
              dst += <<EOF
<script>
var raffle_choices_#{attributes['id']} = [#{choices.map { |choice| "'#{choice.gsub(/\\/, '\\\\\\\\')}'" }.join(', ')}];
shuffle(raffle_choices_#{attributes['id']});
</script>
<div id="#{attributes['id']}" style="user-select: none; text-align: center; font-size: 24pt;" onclick="raffle(this, raffle_choices_#{attributes['id']});">
click for a random term...
</div>
EOF
            end

          elsif command == 'texmath'
            dst += '<div class="mathjax">$$'
            while @i < @tokens.length && @tokens[@i].type == :CODE
              dst += @tokens[@i].text
              @i += 1

              if @tokens[@i].type == :EOL
                @i += 1
              else
                raise "expected EOL after texmath, found #{@tokens[@i].type}"
              end
            end
            dst += '$$</div>'

          elsif command == 'latex'
            ['id'].each do |key|
              if !attributes.has_key? key
                raise "latex snippet must have #{key} attribute!"
              end
            end

            latex_source = <<'EOF'
\documentclass[fleqn]{article}
\usepackage{mathtools}
\usepackage{amsmath}
\usepackage[active,tightpage,textmath,displaymath,pdftex]{preview}
\begin{document}
\makeatletter\setlength\@mathmargin{0pt}\makeatother
EOF
            while @i < @tokens.length && @tokens[@i].type == :CODE
              latex_source += @tokens[@i].text
              @i += 1

              if @tokens[@i].type == :EOL
                @i += 1
              else
                raise "expected EOL after latex, found #{@tokens[@i].type}"
              end
            end
            latex_source += "\n\\end{document}"

            # IO.popen("pdflatex -jobname=#{attributes['id']} && gs -sDEVICE=png16m -dTextAlphaBits=4 -r144 -dGraphicsAlphaBits=4 -dSAFER -q -dNOPAUSE -dBATCH -sOutputFile=#{attributes['id']}.png #{attributes['id']}.pdf && mogrify -quality 100 -resize #{attributes['width']}x#{attributes['height']} #{attributes['id']}.png", 'w+') do |pipe|
            IO.popen("pdflatex -jobname=#{attributes['id']} && (pdftoppm -rx 400 -ry 400 -png #{attributes['id']}.pdf > #{attributes['id']}.png)", 'w+') do |pipe|
              pipe.write(latex_source)
              pipe.close_write
              pipe.read.split("\n").each do |line|
                STDERR.puts line
              end
            end

            dst += "<img src=\"#{attributes['id']}.png\"#{s} style=\"#{@styles['latex_math']}\">"

          elsif command == 'listveil'
            if attributes.has_key?('class') 
              attributes['class'] += ' listveil'
            else
              attributes['class'] = 'listveil'
            end

            pair_string = attributes.map { |key, value| " #{key}=\"#{value}\"" }.join

            dst += "<div#{pair_string}>\n"
            while @i < @tokens.length && (first_of_line? @tokens[@i].type)
              dst += line
            end
            dst += '</div>'

          elsif command == 'lineveil'
            dst += "<pre#{pair_string}>"
            li = 0
            while @i < @tokens.length && @tokens[@i].type == :CODE
              dst += "#{'&nbsp;' * (2 - li.to_s.length)}<a href=\"#\" class=\"lineveil\">#{li}</a>: <span class=\"lineveil\">#{@tokens[@i].text}</span>"
              if @i + 2 < @tokens.length && @tokens[@i + 2].type == :CODE
                dst += "\n"
              end
              @i += 1
              if @tokens[@i].type == :EOL
                @i += 1
              else
                raise "expected EOL after code, found #{@tokens[@i].type}"
              end
              li += 1
            end
            dst += '</pre>'
          elsif command == 'mup'
            code = ''
            while @i < @tokens.length && (@tokens[@i].type != :RIGHT_BRACKET)
              code += @tokens[@i].text
              @i += 1
            end
            code.gsub!(/'/, '\\\\\'')

            tmp = Tempfile.new('mup')
            tmp.write code
            tmp.close
            tree = `../../build/merp --tree #{tmp.path}`

            dst += <<EOF
<div class="mup-switcher">
  <div class="text-editor">#{code.chomp}</div>
  <div class="block-editor"><div class="s-expression">#{tree}</div></div>
</div>
EOF

          elsif command == 'madeup'
            ['id', 'width', 'height'].each do |key|
              if !attributes.has_key? key
                raise "madeup snippet must have #{key} attribute!"
              end
            end

            code = ''
            while @i < @tokens.length && (@tokens[@i].type != :RIGHT_BRACKET)
              code += @tokens[@i].text
              @i += 1
            end
            # code.gsub!(/'/, '\\\\\'')
            code.gsub!(/</, '&lt;')
            code.gsub!(/>/, '&gt;')

            if @target == 'wordpress'
              dst += <<EOF
<pre>[mup id=#{attributes['id']} width=#{attributes['width']} height=#{attributes['height']}]#{code}[/mup]</pre>
EOF
            else
              @mups << attributes['id']
              dst += <<EOF
<form style="display: none" id="mup-form-#{attributes['id']}" target="mup-frame-#{attributes['id']}" action="#{@madeupurl}" method="post">
<input type="hidden" name="embed" value="true">
<textarea name="src">#{code}</textarea>
EOF

              dst += %Q{<input type="hidden" name="runonload" value="#{attributes.has_key?('run') ? attributes['run'] : 'true'}">}

              if @skin == 'slides'
                dst += <<EOF
<input type="hidden" name="isPresenting" value="true">
EOF
              end

              dst += <<EOF
<input type="submit"/>
</form>
<iframe id="mup-frame-#{attributes['id']}" name="mup-frame-#{attributes['id']}" src="" width="#{attributes['width']}" height="#{attributes['height']}" class="madeup-frame#{attributes.has_key?('class') ? " #{attributes['class']}" : ''}"></iframe>
EOF
            end

          elsif command == 'quote'
            dst += "<blockquote#{pair_string}>"
            while @i < @tokens.length && (first_of_content?(@tokens[@i].type) || @tokens[@i].type == :EOL)
              dst += content
              dst += "\n" if @i + 1 < @tokens.length && @tokens[@i + 1].type != :RIGHT_BRACKET
              if @tokens[@i].type == :EOL
                @i += 1
              else
                raise "expected EOL after quote content, found #{@tokens[@i].type}"
              end
            end
            dst += '</blockquote>'
          elsif command == 'hide'
            is_indented = attributes.has_key?('indent') && attributes['indent'] == 'true'
            dst += "<div class=\"indented grayblock\">" if is_indented
            dst += "<span class=\"toggler\">#{attributes['title']}</span>"
            classes = attributes.has_key?('class') ? ' ' + attributes['class'] : ''
            dst += "<div class=\"togglee#{classes}\">"
            if @tokens[@i].type == :SEPARATOR
              @i += 1
              dst += handle_command
            else

              while @i < @tokens.length && (first_of_line? @tokens[@i].type)
                dst += line
              end

              # dst += content
              # if @tokens[@i].type == :RIGHT_BRACKET
                # @i += 1
              # else
                # raise "expected ] after hide content, found #{@tokens[@i].type}"
              # end
            end
            dst += '</div>'
            dst += '</div>' if is_indented
          elsif command == 'haiku'
            dst += "<blockquote#{pair_string}>"
            is_first = true
            while @i < @tokens.length && (first_of_content? @tokens[@i].type)
              if !is_first
                dst += '<br>'
              else
                is_first = false
              end
              dst += content false
              # dst += "\n" if @i + 1 < @tokens.length && @tokens[@i + 1].type != :RIGHT_BRACKET
              if @tokens[@i].type == :EOL
                @i += 1
              else
                raise "expected EOL after quote content, found #{@tokens[@i].type}"
              end
            end
            dst += '</blockquote>'
          elsif command == 'block'
            if attributes.has_key?('hide')
              dst += "<div class=\"grayblock indented\">"
              dst += "<a href=\"#\" class=\"toggler\">#{attributes['hide']}</a>"
              if attributes.has_key?('class')
                attributes['class'].gsub!(/"?$/, ' togglee')
              else
                attributes['class'] = 'togglee'
              end
            end

            pair_string = attributes.map { |key, value| " #{key}=\"#{value}\"" }.join

            dst += "<div#{pair_string}>\n"
            while @i < @tokens.length && (first_of_line? @tokens[@i].type)
              dst += line
            end
            dst += '</div>'

            if attributes.has_key?('hide')
              dst += '</div>'
            end
          elsif command == 'strike'
            dst += '<strike>'
            if @tokens[@i].type == :SEPARATOR
              @i += 1
              dst += handle_command
            else
              while @i < @tokens.length && (first_of_line? @tokens[@i].type)
                dst += line
              end
            end
            dst += '</strike>'
          elsif command == 'toggle'
            dst += "<div class=\"toggle\"#{pair_string}>"
            while @i < @tokens.length && (first_of_content? @tokens[@i].type)
              dst += content
              dst += "\n" if @i + 1 < @tokens.length && @tokens[@i + 1].type != :RIGHT_BRACKET
              if @tokens[@i].type == :EOL
                @i += 1
              else
                raise "expected EOL after toggle content, found #{@tokens[@i].type}"
              end
            end
            dst += '</div>'
          end
        end
      else
        raise 'expected ID'
      end

      dst
    end
  end

  def self.upload
    ARGV.each do |path|
      config = configure path

      dir = "/var/www/twodee/#{config['root']}/#{$offset}".gsub(/\/{2,}/, '/')

      command = "ssh twodee 'umask 1067 && mkdir -p #{dir} && umask 0017 && chmod -R g+X /var/www/twodee/#{config['root']}/#{$offset.gsub(/\/.*$/, '')}' && scp #{path} twodee:#{dir} && ssh twodee 'chmod g+r #{dir}/#{File.basename(path)}'"
      puts command
      `#{command}`

      puts
    end
  end

  def self.incode
    path = ARGV.shift 
    code = ''
    ARGV.each_with_index do |codepath, i|
      if i > 0
        code += "\n"
      end
      code += "## #{File.basename(codepath)}\n\n"
      language = case File.extname(codepath)
        when '.java'
          'java'
        when '.mup'
          'madeup'
        when '.cpp', '.h', '.ino'
          'cpp'
        when '.c'
          'c'
        when '.rb'
          'ruby'
        when '.zsh'
          'zsh'
        when '.html'
          'html'
        when '.js'
          'js'
        when '.css'
          'css'
        when '.hs'
          'haskell'
        else
          ''
        end
      if File.basename(codepath).downcase == 'makefile'
        language = 'make'
      end
      language = " lang=#{language}" if !language.empty?
      code += "[code#{language}\n"
      src = IO.read(codepath).gsub(/\t/, '  ').chomp
      code += src
      code += "\n]\n"
    end

    code.gsub!(/\\/, '\\\\\\')

    text = IO.read(path)
    if !text.gsub!(/(?<=\[" CODE START\]\n).*?(?=\n\[" CODE END\])/m, code)
      text.sub!(/\s*\Z/, "\n\n[\" CODE START]\n#{code}\n[\" CODE END]\n")
    end

    File.open(path, 'w') do |file|
      file.write(text)
    end
  end

  def self.interpret(target, path)
    config = configure path
    src = File.read(path)
    lexer = Lexer.new src
    lexer.lex
    parser = Parser.new(lexer.tokens, target, config)
    [parser.parse, config]
  end
end

if __FILE__ == $0
  command = ARGV.shift
  if command == 'upload'
    Graytext::upload
  elsif command == 'code'
    Graytext::incode
  else
    puts Graytext::interpret(ARGV[0], ARGV[1])[0]
  end
end
