# frozen_string_literal: true

require_relative 'users'

module SoMate
  module Repository
    # Repository for Record Entities
    class FomoRecords
      def self.all
        Database::FomoRecordOrm.all.map { |db_record| rebuild_entity(db_record) }
      end

      # def self.find_full_name(owner_name, record_id)
      #   db_record = Database::FomoRecordOrm
      #     .left_join(:users, id: :owner_id)
      #     .where(account: owner_name, id: record_id)
      #     .first
      #   rebuild_entity(db_record)
      # end

      def self.find(entity)
        find_origin_id(entity.origin_id)
      end

      def self.find_origin_id(origin_id)
        db_record = Database::FomoRecordOrm.first(id: origin_id)
        rebuild_entity(db_record)
      end

      def self.create(entity)
        raise 'Record already exists' if find(entity)

        db_record = PersistRecord.new(entity).call
        rebuild_entity(db_record)
      end

      def self.rebuild_entity(db_record)
        return nil unless db_record

        Entity::Record.new(
          db_record.to_hash.merge(
            owner: Users.rebuild_entity(db_record.owner)
          )
        )
      end

      # Helper class to persist record and its users to database
      class PersistRecord
        def initialize(entity)
          @entity = entity
        end

        def create_record
          Database::FomoRecordOrm.create(@entity.to_attr_hash)
        end

        def call
          owner = Users.db_find_or_create(@entity.owner)

          create_record.tap do |db_record|
            db_record.update(owner: owner)
          end
        end
      end
    end
  end
end
