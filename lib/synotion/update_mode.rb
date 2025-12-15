module Synotion
  module UpdateMode
    CREATE = :create
    APPEND = :append
    REPLACE = :replace
    UPSERT = :upsert

    ALL = [CREATE, APPEND, REPLACE, UPSERT].freeze

    def self.valid?(mode)
      ALL.include?(mode)
    end
  end
end
