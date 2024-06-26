# frozen_string_literal: true

require_relative 'users'
require_relative 'records'
require_relative 'answers'


module SoMate
  module Repository
    # Finds the right repository for an entity object or class
    module For
      ENTITY_REPOSITORY = {
        Entity::Countermeasure => Countermeasures,
        Entity::CountermeasureRecord => CountermeasureRecords,
        Entity::Answer => Answers,
        Entity::Record => Records,
        Entity::User => Users
      }.freeze

      def self.klass(entity_klass)
        ENTITY_REPOSITORY[entity_klass]
      end

      def self.entity(entity_object)
        ENTITY_REPOSITORY[entity_object.class]
      end
    end
  end
end
