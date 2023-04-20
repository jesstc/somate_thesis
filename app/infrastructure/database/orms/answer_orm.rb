# frozen_string_literal: true

require 'sequel'

module SoMate
  module Database
    # Object Relational Mapper for Answer
    class AnswerOrm < Sequel::Model(:answers)
      many_to_one :recordbook,
                  class: :'SoMate::Database::RecordOrm'

      plugin :timestamps, update_on_create: true
    end
  end
end
