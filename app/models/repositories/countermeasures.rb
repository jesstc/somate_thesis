# frozen_string_literal: true

module SoMate
  module Repository
    # Repository for Countermeasures
    class Countermeasures
      def self.find_id(id)
        rebuild_entity Database::CountermeasureOrm.first(id: id)
      end

      def self.rebuild_entity(db_record)
        return nil unless db_record

        Entity::Countermeasure.new(
          id:                 db_record.id,
          title:              db_record.title,
          guidance_content:   db_record.guidance_content,
          body_content:       db_record.body_content
        )
      end

      def self.db_find_or_create(entity)
        Database::CountermeasureOrm.find_or_create(entity.to_attr_hash)
      end
    end
  end
end
