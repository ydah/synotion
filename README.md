# Synotion

A Ruby gem to sync Markdown files to Notion pages.

## Features

- Multiple update modes: create, append, replace, or upsert pages
- Flexible page identification by custom properties, filenames, or titles
- Automatic Markdown to Notion blocks conversion
- Command-line interface
- YAML front matter support

## Installation

```bash
gem install synotion
```

Or add to your Gemfile:

```ruby
gem 'synotion'
```

## Quick Start

1. Create a Notion integration at https://www.notion.so/my-integrations
2. Share your database with the integration
3. Run:

```bash
synotion sync README.md \
  --api-key=secret_xxx \
  --database-id=your-database-id
```

## Usage

### CLI

```bash
# Basic usage
synotion sync README.md \
  --api-key=$NOTION_API_KEY \
  --database-id=your-database-id

# Specify update mode
synotion sync CHANGELOG.md \
  --api-key=$NOTION_API_KEY \
  --database-id=your-database-id \
  --mode=append

# Use config file
synotion sync README.md --config=.notion-sync.yml
```

### Ruby API

```ruby
require 'synotion'

# Configure globally
Synotion.configure do |config|
  config.notion_api_key = ENV['NOTION_API_KEY']
  config.database_id = 'your-database-id'
end

# Sync a file
syncer = Synotion::Syncer.new
result = syncer.sync('README.md')
# => { action: 'created', page_id: 'xxx', mode: :upsert }

# Sync with options
result = syncer.sync('docs/api.md',
  mode: :replace,
  title: 'API Documentation'
)
```

### Configuration File

Create `.notion-sync.yml`:

```yaml
notion_api_key: secret_xxx
database_id: your-database-id
update_mode: upsert
unique_property: source_file
```

## Configuration Options

| Option | Description | Default |
|--------|-------------|---------|
| `notion_api_key` | Notion API key (required) | - |
| `database_id` | Target database ID | - |
| `page_id` | Target page ID (alternative to database_id) | - |
| `update_mode` | How to handle existing pages | `:upsert` |
| `unique_property` | Property for page identification | `'source_file'` |
| `title_from` | How to extract page title | `:first_heading` |
| `sync_metadata` | Add last_synced timestamp | `true` |

### Update Modes

| Mode | Behavior |
|------|----------|
| `:create` | Create new page only (skip if exists) |
| `:append` | Append content to existing page |
| `:replace` | Replace entire page content |
| `:upsert` | Update if exists, create if not (default) |

### Supported Markdown Elements

- Headings (H1, H2, H3+)
- Paragraphs
- Code blocks with syntax highlighting
- Bulleted lists
- Numbered lists
- Quotes
- Dividers
- Todo items / Checkboxes
- Tables (converted to Notion table blocks)
- Links (external URLs converted to clickable links)
- YAML front matter

## Notion Setup

1. Create an Integration

- Go to https://www.notion.so/my-integrations
- Click "New integration"
- Copy the "Internal Integration Token"

2. Create a Database

Create a Notion database with these properties:

| Property | Type | Purpose |
|----------|------|---------|
| Name | Title | Page title (required) |
| source_file | Text | File path for unique identification |
| last_synced | Date | Last sync timestamp (optional) |

3. Share Database

- Open your database in Notion
- Click "..." → "Add connections"
- Select your integration

## Development

```bash
# Install dependencies
bundle install

# Run tests
bundle exec rspec

# Try in console
bundle exec exe/synotion --help
```

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/ydah/synotion.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
