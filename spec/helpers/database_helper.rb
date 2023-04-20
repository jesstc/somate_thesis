# frozen_string_literal: true

# Helper to clean database during test runs
module DatabaseHelper
  def self.wipe_database
    # Ignore foreign key constraints when wiping tables
    SoMate::App.DB.run('PRAGMA foreign_keys = OFF')
    SoMate::Database::UserOrm.map(&:destroy)
    SoMate::Database::RecordOrm.map(&:destroy)
    SoMate::Database::AnswerOrm.map(&:destroy)
    SoMate::App.DB.run('PRAGMA foreign_keys = ON')
  end
end
