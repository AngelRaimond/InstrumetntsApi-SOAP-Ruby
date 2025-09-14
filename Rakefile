require 'standalone_migrations'

# Configurar standalone_migrations para usar el archivo correcto
StandaloneMigrations.configure do |config|
  config.db_dir = 'db'
  config.migration_dir = 'db/migrate'
  config.config_file = 'db/migrate.yml'
end

StandaloneMigrations::Tasks.load_tasks

task :environment do
  require_relative 'config/environment.rb'
end

task :console => :environment do
  require 'irb'
  ARGV.clear
  IRB.start
end