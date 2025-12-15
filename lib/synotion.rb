require_relative "synotion/version"
require_relative "synotion/update_mode"
require_relative "synotion/configuration"
require_relative "synotion/client"
require_relative "synotion/markdown_converter"
require_relative "synotion/syncer"
require_relative "synotion/cli"

module Synotion
  class Error < StandardError; end
  class ConfigurationError < Error; end
  class NotionAPIError < Error; end
  class PageNotFoundError < Error; end
  class MarkdownParseError < Error; end

  class << self
    attr_writer :configuration

    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield(configuration)
    end

    def reset_configuration!
      @configuration = Configuration.new
    end
  end
end
