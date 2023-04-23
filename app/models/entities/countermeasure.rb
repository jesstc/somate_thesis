# frozen_string_literal: false

require 'dry-types'
require 'dry-struct'

module SoMate
  module Entity
    # Domain entity for countermeasures
    class Countermeasure < Dry::Struct
      include Dry.Types

      attribute :id,                  Integer.optional
      attribute :title,               Strict::String
      attribute :guidance_content,    Strict::String
      attribute :body_content,        Strict::String

      def to_attr_hash
        to_hash.reject { |key, _| [:id].include? key }
      end
    end
  end
end
