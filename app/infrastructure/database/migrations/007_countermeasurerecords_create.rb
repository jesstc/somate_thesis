# frozen_string_literal: true

require 'sequel'

Sequel.migration do
  change do
    create_table(:countermeasurerecords) do
      primary_key :id
      foreign_key :countermeasure_id, :countermeasures
      foreign_key :owner_id, :users
      
      Boolean  :is_try
      String   :selected_content

      DateTime :created_at
      DateTime :updated_at
    end
  end
end
