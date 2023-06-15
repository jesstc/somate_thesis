# frozen_string_literal: false

require 'dry-types'
require 'dry-struct'

require_relative 'user'

module SoMate
  module Entity
    # Domain entity for record
    class FomoRecord < Dry::Struct
      include Dry.Types

      attribute :id,          Integer.optional
      attribute :owner,       User

      def to_attr_hash
        to_hash.reject { |key, _| %i[id owner].include? key }
      end
    end
  end
end
