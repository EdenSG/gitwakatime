require 'git'
require 'logger'
require 'wakatime'
require 'chronic_duration'
require 'yaml'
require 'thor'
require 'active_support/core_ext/date/calculations'
require 'active_support/core_ext/date_and_time/calculations'
require 'active_support/core_ext/integer/time'
require 'active_support/core_ext/time'
require 'pry'
module  GitWakaTime
  # Provides two CLI actions init and tally
  class Cli < Thor
    include Thor::Actions
    desc 'init', 'Setups up Project for using the wakatime API
      it will also add to your git ignore file'
    method_option :file, aliases: '-f', default: '.'

    def init
      unless File.exist?(File.join(Dir.home, '.wakatime.yml'))
        api_key = ask('What is your wakatime api key? ( Get it here https://wakatime.com/settings):')
        say('Adding .wakatime.yml to home directory')

        create_file File.join(Dir.home, '.wakatime.yml') do
          YAML.dump(api_key: api_key, last_commit: nil, log_level: :info)
        end
      end
      reset
    end

    desc 'reset', 'Reset local sqlite db'
    def reset
      DB.disconnect

      db_path = File.expand_path(File.join(Dir.home, '.wakatime.sqlite'))
      FileUtils.rm_r(db_path) if File.exist?(db_path)
      DB.connect("sqlite://#{db_path}")
      GitWakaTime.config.setup_local_db
    end

    desc 'tally', 'Produce time spend for each commit and file in each commit'
    method_option :file, aliases: '-f', default: '.'
    method_option :start_on, aliases: '-s', default: nil
    method_option :output, aliases: '-o', default: 'text', type: 'string'

    def tally
      path = File.expand_path(options.file)
      date = Date.parse(options.start_on) if options.start_on
      date = 7.days.ago unless options.start_on

      @timer = GitWakaTime::Controller.new(path: path, date: date).timer

      if output == 'text'
        @timer.each do |date, commits|
          Log.new format('%-40s %-40s'.blue,
                         date,
                         "Total #{ChronicDuration.output commits.map(&:time_in_seconds).compact.reduce(&:+).to_i}"
                         )
          commits.each do |commit|
            # Log.new commit.message
            Log.new commit.to_s
            commit.commited_files.each { |file| Log.new file.to_s }
          end
        end
      elsif output == 'json'
        @timer.to_json
      end
    end
  end
end
