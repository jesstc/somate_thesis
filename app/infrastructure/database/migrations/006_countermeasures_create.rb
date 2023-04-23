# frozen_string_literal: true

require 'sequel'

Sequel.migration do
  change do
    create_table(:countermeasures) do
      primary_key :id

      String   :title
      String   :guidance_content
      String   :body_content
    end
  end
end
