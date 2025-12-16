require 'redcarpet'
require 'front_matter_parser'

module Synotion
  class MarkdownConverter
    attr_reader :markdown_content, :frontmatter, :content_without_frontmatter

    def initialize(markdown_content)
      @markdown_content = markdown_content
      parse_frontmatter
    end

    def to_notion_blocks
      blocks = []
      lines = content_without_frontmatter.split("\n")
      i = 0

      while i < lines.length
        line = lines[i]

        if line.strip.empty?
          i += 1
          next
        end

        if line.start_with?('#')
          blocks << parse_heading(line)
          i += 1
        elsif line.start_with?('```')
          code_block, lines_consumed = parse_code_block(lines[i..-1])
          blocks << code_block if code_block
          i += lines_consumed
        elsif line.start_with?('|') && is_table?(lines[i..-1])
          table_block, lines_consumed = parse_table(lines[i..-1])
          blocks << table_block if table_block
          i += lines_consumed
        elsif line.match?(/^\s*[-*]\s+\[[ x]\]/)
          blocks << parse_todo(line)
          i += 1
        elsif line.match?(/^\s*[-*+]\s/)
          list_items, lines_consumed = parse_list(lines[i..-1], :bulleted_list_item)
          blocks.concat(list_items)
          i += lines_consumed
        elsif line.match?(/^\s*\d+\.\s/)
          list_items, lines_consumed = parse_list(lines[i..-1], :numbered_list_item)
          blocks.concat(list_items)
          i += lines_consumed
        elsif line.start_with?('>')
          blocks << parse_quote(line)
          i += 1
        elsif line.match?(/^[-*_]{3,}$/)
          blocks << { type: 'divider', divider: {} }
          i += 1
        else
          paragraph, lines_consumed = parse_paragraph(lines[i..-1])
          blocks << paragraph if paragraph
          i += lines_consumed
        end
      end

      blocks
    rescue StandardError => e
      raise MarkdownParseError, "Failed to parse markdown: #{e.message}"
    end

    def extract_title
      first_heading = content_without_frontmatter.lines.find { |line| line.start_with?('#') }
      return first_heading.sub(/^#+\s*/, '').strip if first_heading

      return frontmatter['title'] if frontmatter&.key?('title')

      nil
    end

    def extract_frontmatter
      frontmatter
    end

    private

    def parse_frontmatter
      parsed = FrontMatterParser::Parser.new(:md).call(@markdown_content)
      @frontmatter = parsed.front_matter
      @content_without_frontmatter = parsed.content
    rescue StandardError
      @frontmatter = {}
      @content_without_frontmatter = @markdown_content
    end

    def parse_heading(line)
      level = line.match(/^(#+)/)[1].length
      text = line.sub(/^#+\s*/, '')

      heading_type = case level
                     when 1 then 'heading_1'
                     when 2 then 'heading_2'
                     else 'heading_3'
                     end

      {
        type: heading_type,
        heading_type => {
          rich_text: parse_inline_formatting(text.strip)
        }
      }
    end

    def parse_code_block(lines)
      first_line = lines[0]
      language = first_line.sub('```', '').strip
      language = 'plain text' if language.empty?

      code_lines = []
      i = 1

      while i < lines.length && !lines[i].start_with?('```')
        code_lines << lines[i]
        i += 1
      end

      code_content = code_lines.join("\n")

      block = {
        type: 'code',
        code: {
          rich_text: [{ type: 'text', text: { content: code_content } }],
          language: language
        }
      }

      [block, i + 1]
    end

    def parse_list(lines, type)
      items = []
      i = 0

      pattern = if type == :bulleted_list_item
                  /^\s*[-*+]\s/
                else
                  /^\s*\d+\.\s/
                end

      while i < lines.length
        line = lines[i]
        break unless line.match?(pattern)

        text = if type == :bulleted_list_item
                 line.sub(/^\s*[-*+]\s+/, '').strip
               else
                 line.sub(/^\s*\d+\.\s+/, '').strip
               end

        items << {
          type: type.to_s,
          type => {
            rich_text: parse_inline_formatting(text)
          }
        }
        i += 1
      end

      [items, i]
    end

    def parse_quote(line)
      text = line.sub(/^>\s*/, '')

      {
        type: 'quote',
        quote: {
          rich_text: parse_inline_formatting(text.strip)
        }
      }
    end

    def parse_todo(line)
      match = line.match(/^\s*[-*]\s+\[([x ])\]\s*(.*)/)
      checked = match[1] == 'x'
      text = match[2].strip

      {
        type: 'to_do',
        to_do: {
          rich_text: parse_inline_formatting(text),
          checked: checked
        }
      }
    end

    def parse_paragraph(lines)
      paragraph_lines = []
      i = 0

      while i < lines.length
        line = lines[i]
        break if line.strip.empty?
        break if line.start_with?('#', '```', '>', '-', '*', '+') || line.match?(/^\d+\./)

        paragraph_lines << line
        i += 1
      end

      return [nil, [i, 1].max] if paragraph_lines.empty?

      text = paragraph_lines.join(' ').strip
      rich_text = parse_inline_formatting(text)

      block = {
        type: 'paragraph',
        paragraph: {
          rich_text: rich_text
        }
      }

      [block, i]
    end

    def parse_inline_formatting(text)
      segments = []
      current_pos = 0

      while current_pos < text.length
        link_match = text[current_pos..-1].match(/\[([^\]]+)\]\(([^\)]+)\)/)

        if link_match
          pre_text = text[current_pos...(current_pos + link_match.begin(0))]
          if pre_text.length > 0
            segments << {
              type: 'text',
              text: { content: pre_text }
            }
          end

          link_text = link_match[1]
          link_url = link_match[2].strip

          if link_url.match?(/^https?:\/\//)
            segments << {
              type: 'text',
              text: {
                content: link_text,
                link: { url: link_url }
              }
            }
          elsif link_url.start_with?('#')
            segments << {
              type: 'text',
              text: { content: link_text }
            }
          else
            segments << {
              type: 'text',
              text: { content: link_text }
            }
          end

          current_pos += link_match.begin(0) + link_match[0].length
        else
          remaining_text = text[current_pos..-1]
          if remaining_text.length > 0
            segments << {
              type: 'text',
              text: { content: remaining_text }
            }
          end
          break
        end
      end

      segments.empty? ? [{ type: 'text', text: { content: text } }] : segments
    end

    def is_table?(lines)
      return false if lines.length < 2
      return false unless lines[0].start_with?('|')
      lines[1].match?(/^\|[\s:|-]+\|/)
    end

    def parse_table(lines)
      table_lines = []
      i = 0

      while i < lines.length && lines[i].start_with?('|')
        table_lines << lines[i]
        i += 1
      end

      return [nil, 1] if table_lines.empty?

      rows = table_lines.map { |line| parse_table_row(line) }
      rows = rows.reject { |row| row.all? { |cell| cell.strip.match?(/^[-:|\s]*$/) } }

      return [nil, i] if rows.empty?

      table_width = rows.first.length

      normalized_rows = rows.map do |row_cells|
        normalized_cells = row_cells.dup
        while normalized_cells.length < table_width
          normalized_cells << ''
        end
        normalized_cells = normalized_cells[0...table_width] if normalized_cells.length > table_width
        normalized_cells
      end

      table_rows = normalized_rows.map do |row_cells|
        {
          type: 'table_row',
          table_row: {
            cells: row_cells.map { |cell| [{ type: 'text', text: { content: cell.strip } }] }
          }
        }
      end

      block = {
        type: 'table',
        table: {
          table_width: table_width,
          has_column_header: true,
          has_row_header: false,
          children: table_rows
        }
      }

      [block, i]
    end

    def parse_table_row(line)
      cells = line.split('|').map(&:strip)
      cells = cells[1..-1] if cells.first.empty?
      cells = cells[0..-2] if cells.last.empty?
      cells
    end
  end
end
