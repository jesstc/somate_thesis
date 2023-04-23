# frozen_string_literal: true

require 'sequel'

Sequel.migration do
  change do
    create_table(:countermeasures_countermeasurerecords) do
      primary_key %i[countermeasurerecord_id user_id]
      foreign_key :countermeasurerecord_id, :countermeasurerecords
      foreign_key :user_id, :users

      index %i[countermeasurerecord_id user_id]
    end
  end
end
