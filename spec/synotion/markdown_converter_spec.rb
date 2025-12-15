RSpec.describe Synotion::MarkdownConverter do
  describe '#to_notion_blocks' do
    it 'converts headings' do
      markdown = "# Heading 1\n## Heading 2\n### Heading 3"
      converter = described_class.new(markdown)
      blocks = converter.to_notion_blocks

      expect(blocks.length).to eq(3)
      expect(blocks[0][:type]).to eq('heading_1')
      expect(blocks[1][:type]).to eq('heading_2')
      expect(blocks[2][:type]).to eq('heading_3')
    end

    it 'converts paragraphs' do
      markdown = 'This is a paragraph.'
      converter = described_class.new(markdown)
      blocks = converter.to_notion_blocks

      expect(blocks.length).to eq(1)
      expect(blocks[0][:type]).to eq('paragraph')
      expect(blocks[0][:paragraph][:rich_text][0][:text][:content]).to eq('This is a paragraph.')
    end

    it 'converts code blocks' do
      markdown = "```ruby\nputs 'Hello'\n```"
      converter = described_class.new(markdown)
      blocks = converter.to_notion_blocks

      expect(blocks.length).to eq(1)
      expect(blocks[0][:type]).to eq('code')
      expect(blocks[0][:code][:language]).to eq('ruby')
      expect(blocks[0][:code][:rich_text][0][:text][:content]).to eq("puts 'Hello'")
    end

    it 'converts bulleted lists' do
      markdown = "- Item 1\n- Item 2\n- Item 3"
      converter = described_class.new(markdown)
      blocks = converter.to_notion_blocks

      expect(blocks.length).to eq(3)
      expect(blocks[0][:type]).to eq('bulleted_list_item')
      expect(blocks[1][:type]).to eq('bulleted_list_item')
      expect(blocks[2][:type]).to eq('bulleted_list_item')
    end

    it 'converts numbered lists' do
      markdown = "1. Item 1\n2. Item 2\n3. Item 3"
      converter = described_class.new(markdown)
      blocks = converter.to_notion_blocks

      expect(blocks.length).to eq(3)
      expect(blocks[0][:type]).to eq('numbered_list_item')
      expect(blocks[1][:type]).to eq('numbered_list_item')
      expect(blocks[2][:type]).to eq('numbered_list_item')
    end

    it 'converts quotes' do
      markdown = '> This is a quote'
      converter = described_class.new(markdown)
      blocks = converter.to_notion_blocks

      expect(blocks.length).to eq(1)
      expect(blocks[0][:type]).to eq('quote')
      expect(blocks[0][:quote][:rich_text][0][:text][:content]).to eq('This is a quote')
    end

    it 'converts dividers' do
      markdown = '---'
      converter = described_class.new(markdown)
      blocks = converter.to_notion_blocks

      expect(blocks.length).to eq(1)
      expect(blocks[0][:type]).to eq('divider')
    end

    it 'converts todos' do
      markdown = "- [ ] Unchecked\n- [x] Checked"
      converter = described_class.new(markdown)
      blocks = converter.to_notion_blocks

      expect(blocks.length).to eq(2)
      expect(blocks[0][:type]).to eq('to_do')
      expect(blocks[0][:to_do][:checked]).to be false
      expect(blocks[1][:type]).to eq('to_do')
      expect(blocks[1][:to_do][:checked]).to be true
    end
  end

  describe '#extract_title' do
    it 'extracts title from first heading' do
      markdown = "# My Title\n\nSome content"
      converter = described_class.new(markdown)

      expect(converter.extract_title).to eq('My Title')
    end

    it 'extracts title from frontmatter' do
      markdown = "---\ntitle: Frontmatter Title\n---\n\nContent"
      converter = described_class.new(markdown)

      expect(converter.extract_title).to eq('Frontmatter Title')
    end

    it 'returns nil when no title found' do
      markdown = 'Just some content without a heading'
      converter = described_class.new(markdown)

      expect(converter.extract_title).to be_nil
    end
  end

  describe '#extract_frontmatter' do
    it 'parses YAML frontmatter' do
      markdown = "---\ntitle: Test\nauthor: John\n---\n\nContent"
      converter = described_class.new(markdown)
      frontmatter = converter.extract_frontmatter

      expect(frontmatter['title']).to eq('Test')
      expect(frontmatter['author']).to eq('John')
    end

    it 'returns empty hash when no frontmatter' do
      markdown = 'No frontmatter here'
      converter = described_class.new(markdown)

      expect(converter.extract_frontmatter).to eq({})
    end

    it 'handles invalid frontmatter gracefully' do
      markdown = "---\ninvalid yaml: [unclosed\n---\n\nContent"
      converter = described_class.new(markdown)

      expect(converter.extract_frontmatter).to eq({})
    end
  end

  describe 'edge cases' do
    it 'handles empty markdown' do
      markdown = ''
      converter = described_class.new(markdown)
      blocks = converter.to_notion_blocks

      expect(blocks).to be_empty
    end

    it 'handles markdown with only whitespace' do
      markdown = "   \n\n   \n"
      converter = described_class.new(markdown)
      blocks = converter.to_notion_blocks

      expect(blocks).to be_empty
    end

    it 'handles mixed content' do
      markdown = <<~MD
        # Title

        Paragraph text.

        - List item 1
        - List item 2

        ```ruby
        puts "code"
        ```

        > Quote
      MD

      converter = described_class.new(markdown)
      blocks = converter.to_notion_blocks

      expect(blocks.length).to eq(6)
      expect(blocks[0][:type]).to eq('heading_1')
      expect(blocks[1][:type]).to eq('paragraph')
      expect(blocks[2][:type]).to eq('bulleted_list_item')
      expect(blocks[3][:type]).to eq('bulleted_list_item')
      expect(blocks[4][:type]).to eq('code')
      expect(blocks[5][:type]).to eq('quote')
    end

    it 'handles nested lists correctly' do
      markdown = "- Item 1\n  - Nested item\n- Item 2"
      converter = described_class.new(markdown)
      blocks = converter.to_notion_blocks

      expect(blocks.all? { |b| b[:type] == 'bulleted_list_item' }).to be true
    end

    it 'handles code block without language' do
      markdown = "```\ncode without language\n```"
      converter = described_class.new(markdown)
      blocks = converter.to_notion_blocks

      expect(blocks.length).to eq(1)
      expect(blocks[0][:type]).to eq('code')
      expect(blocks[0][:code][:language]).to eq('plain text')
    end

    it 'handles unclosed code block' do
      markdown = "```ruby\nunclosed code block"
      converter = described_class.new(markdown)
      blocks = converter.to_notion_blocks

      expect(blocks.length).to eq(1)
      expect(blocks[0][:type]).to eq('code')
    end

    it 'handles multiple consecutive headings' do
      markdown = "# H1\n## H2\n### H3"
      converter = described_class.new(markdown)
      blocks = converter.to_notion_blocks

      expect(blocks.length).to eq(3)
      expect(blocks[0][:type]).to eq('heading_1')
      expect(blocks[1][:type]).to eq('heading_2')
      expect(blocks[2][:type]).to eq('heading_3')
    end

    it 'handles headings deeper than h3 as h3' do
      markdown = "#### H4\n##### H5\n###### H6"
      converter = described_class.new(markdown)
      blocks = converter.to_notion_blocks

      expect(blocks.length).to eq(3)
      expect(blocks.all? { |b| b[:type] == 'heading_3' }).to be true
    end

    it 'handles multiline paragraphs' do
      markdown = "Line 1\nLine 2\nLine 3"
      converter = described_class.new(markdown)
      blocks = converter.to_notion_blocks

      expect(blocks.length).to eq(1)
      expect(blocks[0][:type]).to eq('paragraph')
      expect(blocks[0][:paragraph][:rich_text][0][:text][:content]).to include('Line 1')
    end
  end
end
