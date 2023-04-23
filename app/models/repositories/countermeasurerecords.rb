# frozen_string_literal: true

require_relative 'users'
require_relative 'countermeasures'

module SoMate
  module Repository
    # Repository for CountermeasureRecords Entities
    class CountermeasureRecords
      def self.all
        Database::CountermeasureRecordOrm.all.map { |db_record| rebuild_entity(db_record) }
      end

      # def self.find(entity)
      #   find_origin_id(entity.origin_id)
      # end

      # def self.find_id(id)
      #   db_record = Database::CountermeasureRecordOrm.first(id: id)
      #   rebuild_entity(db_record)
      # end

      # user owner id to find all countermeasure records
      def self.find_owner(owner_id)
        owner = Users.find_id(id: owner_id)
        db_records = Database::CountermeasureRecordOrm.all(owner: owner)
        db_records.map { |db_record| rebuild_entity(db_record) }
      end

      def self.create(entity)
        raise 'Record already exists' if find(entity)

        db_record = PersistCountermeasureRecord.new(entity).call
        rebuild_entity(db_record)
      end

      def self.rebuild_entity(db_record)
        return nil unless db_record

        Entity::CountermeasureRecord.new(
          db_record.to_hash.merge(
            owner: Users.rebuild_entity(db_record.owner),
            countermeasure: Countermeasures.rebuild_entity(db_record.countermeasure)
          )
        )
      end

      # Helper class to persist countermeasure record and its users to database
      class PersistCountermeasureRecord
        def initialize(entity)
          @entity = entity
        end

        def create_countermeasurerecord
          Database::CountermeasureRecordOrm.create(@entity.to_attr_hash)
        end

        def call
          owner = Users.db_find_or_create(@entity.owner)
          countermeasure = Countermeasures.db_find_or_create(@entity.countermeasure)

          create_record.tap do |db_record|
            db_record.update(owner: owner, countermeasure: countermeasure)
          end
        end
      end
    end
  end
end
