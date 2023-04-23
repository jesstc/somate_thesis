# frozen_string_literal: true

require 'sequel'

module SoMate
  module Database
    # Object Relational Mapper for Record
    class CountermeasureRecordOrm < Sequel::Model(:countermeasurerecords)
      many_to_one :owner,
          class: :'SoMate::Database::UserOrm'
      
      many_to_one :countermeasure,
          class: :'SoMate::Database::CountermeasureOrm'

      plugin :timestamps, update_on_create: true
    end
  end
end
