# frozen_string_literal: true

module ActiveRecordDoctor
  module Detectors
    # Base class for all active_record_doctor detectors.
    class Base
      class << self
        attr_reader :description, :config

        def run(config)
          new(config).run
        end

        def underscored_name
          name.demodulize.underscore.to_sym
        end

        def recognized_settings
          config.keys
        end
      end

      def initialize(config)
        @problems = []
        @config = config
      end

      def run
        @problems = []

        detect
        @problems.each do |problem|
          puts(message(**problem))
        end

        success = @problems.empty?
        @problems = nil
        success
      end

      private

      def config(key)
        default_value =
          begin
            self.class.config.fetch(key).fetch(:default)
          rescue KeyError
            raise "#{self.class.name} must provide a default value for #{key}"
          end

        @config.fetch(key, default_value)
      end

      def detect
        raise("#detect should be implemented by a subclass")
      end

      def message(**_attrs)
        raise("#message should be implemented by a subclass")
      end

      def problem!(**attrs)
        @problems << attrs
      end

      def warning(message)
        puts(message)
      end

      def connection
        @connection ||= ActiveRecord::Base.connection
      end

      def indexes(table_name)
        connection.indexes(table_name)
      end

      def tables
        connection.tables
      end

      def table_exists?(table_name)
        connection.table_exists?(table_name)
      end

      def primary_key(table_name)
        primary_key_name = connection.primary_key(table_name)
        column(table_name, primary_key_name)
      end

      def column(table_name, column_name)
        connection.columns(table_name).find { |column| column.name == column_name }
      end

      def views
        @views ||=
          if connection.respond_to?(:views)
            connection.views
          elsif connection.adapter_name == "PostgreSQL"
            ActiveRecord::Base.connection.execute(<<-SQL).map { |tuple| tuple.fetch("relname") }
              SELECT c.relname FROM pg_class c WHERE c.relkind IN ('m', 'v')
            SQL
          else # rubocop:disable Style/EmptyElse
            # We don't support this Rails/database combination yet.
            nil
          end
      end

      def models
        ActiveRecord::Base.descendants
      end
    end
  end
end
