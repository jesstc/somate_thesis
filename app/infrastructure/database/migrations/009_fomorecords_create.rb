# frozen_string_literal: true

require 'sequel'

Sequel.migration do
  change do
    create_table(:fomorecords) do
      primary_key :id
      foreign_key :owner_id, :users

      DateTime :created_at
      DateTime :updated_at
    end
  end
end
