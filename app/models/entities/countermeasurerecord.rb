# frozen_string_literal: false

require 'dry-types'
require 'dry-struct'

require_relative 'user'
require_relative 'countermeasure'

module SoMate
  module Entity
    # Domain entity for countermeasures
    class CountermeasureRecord < Dry::Struct
      include Dry.Types

      attribute :id,                  Integer.optional
      attribute :countermeasure,      Countermeasure
      attribute :owner,               User
      attribute :is_try,              Strict::Bool
      attribute :selected_content,    Strict::String

      def to_attr_hash
        to_hash.reject { |key, _| %i[id countermeasure owner].include? key }
      end
    end
  end
end
