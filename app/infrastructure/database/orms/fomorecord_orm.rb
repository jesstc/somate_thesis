# frozen_string_literal: true

require 'sequel'

module SoMate
  module Database
    # Object Relational Mapper for Record
    class FomoRecordOrm < Sequel::Model(:fomorecords)
      many_to_one :owner,
                  class: :'SoMate::Database::UserOrm'
      
      plugin :timestamps, update_on_create: true
    end
  end
end
