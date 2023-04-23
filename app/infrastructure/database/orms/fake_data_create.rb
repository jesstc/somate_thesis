# frozen_string_literal: true

USER_FILE = YAML.safe_load(File.read('app/infrastructure/database/local/user.yml'))
RECORD_FILE = YAML.safe_load(File.read('app/infrastructure/database/local/record.yml'))
ANSWER_FILE = YAML.safe_load(File.read('app/infrastructure/database/local/answer.yml'))
COUNTERMEASURE_FILE = YAML.safe_load(File.read('app/infrastructure/database/local/countermeasure.yml'))
COUNTERMEASURERECORD_FILE = YAML.safe_load(File.read('app/infrastructure/database/local/countermeasurerecord.yml'))

module SoMate
  module InitializeDatabase
    # InitializeDatabase for Create original data
    class Create
      def self.load
        # user
        USER_FILE.map do |data|
          Database::UserOrm.create(data)
        end
        # record
        RECORD_FILE.map do |data|
          Database::RecordOrm.create(data)
        end
        # answer
        ANSWER_FILE.map do |data|
          Database::AnswerOrm.create(data)
        end
        # countermeasure
        COUNTERMEASURE_FILE.map do |data|
          Database::CountermeasureOrm.create(data)
        end
        # countermeasure record
        COUNTERMEASURERECORD_FILE.map do |data|
          Database::CountermeasureRecordOrm.create(data)
        end
      end
    end
  end
end
