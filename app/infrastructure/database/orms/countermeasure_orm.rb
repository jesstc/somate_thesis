# frozen_string_literal: true

require 'sequel'

module SoMate
  module Database
    # Object-Relational Mapper for Users
    class CountermeasureOrm < Sequel::Model(:countermeasures)
      one_to_many :countermeasure_countermeasurerecords,
      class: :'SoMate::Database::CountermeasureRecordOrm',
      key:   :countermeasure_id

      def self.find_or_create(countermeasure_info)
        first(id: countermeasure_info[:id]) || create(countermeasure_info)
      end
    end
  end
end
