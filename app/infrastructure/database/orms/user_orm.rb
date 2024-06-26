# frozen_string_literal: true

require 'sequel'

module SoMate
  module Database
    # Object-Relational Mapper for Users
    class UserOrm < Sequel::Model(:users)
      one_to_many :owned_records,
      class: :'SoMate::Database::RecordOrm',
      key:   :owner_id

      plugin :timestamps, update_on_create: true

      def self.find_or_create(user_info)
        first(account: user_info[:account]) || create(user_info)
      end
    end
  end
end
