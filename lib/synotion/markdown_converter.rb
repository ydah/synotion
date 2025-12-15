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
          rich_text: [{ type: 'text', text: { content: text.strip } }]
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
            rich_text: [{ type: 'text', text: { content: text } }]
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
          rich_text: [{ type: 'text', text: { content: text.strip } }]
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
          rich_text: [{ type: 'text', text: { content: text } }],
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

      return [nil, i] if paragraph_lines.empty?

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

      [{
        type: 'text',
        text: { content: text }
      }]
    end
  end
end
