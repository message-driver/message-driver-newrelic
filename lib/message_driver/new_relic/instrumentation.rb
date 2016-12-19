require 'newrelic_rpm'
require 'new_relic/agent/datastores'

module MessageDriver
  module NewRelic
    module Instrumentation
      DESTINATION_OPS = %w(publish pop_message message_count consumer_count).map!(&:freeze).freeze
      DESTINATION_BLOCK_OPS = %w(subscribe).map!(&:freeze).freeze
      MESSAGE_OPS = %w(ack_message nack_message).map!(&:freeze).freeze
      BROKER_OPS = %w(begin_transaction commit_transaction rollback_transaction).map!(&:freeze).freeze
      OPTS_TO_OVERRIDE = (DESTINATION_OPS + DESTINATION_BLOCK_OPS + MESSAGE_OPS + BROKER_OPS).freeze

      DESTINATION_OPS.each do |op|
        define_method "#{op}_with_newrelic" do |*args|
          destination_name = args[0].nil? ? nil : args[0].name
          callback = proc do |result, metric, elapsed|
            ::NewRelic::Agent::Datastores.notice_statement([op, destination_name].inspect, elapsed)
          end

          ::NewRelic::Agent::Datastores.wrap('MessageDriver', op, destination_name, callback) do
            send(:"#{op}_without_newrelic", *args)
          end
        end
      end

      DESTINATION_BLOCK_OPS.each do |op|
        define_method "#{op}_with_newrelic" do |*args, &block|
          destination_name = args[0].nil? ? nil : args[0].name
          callback = proc do |result, metric, elapsed|
            ::NewRelic::Agent::Datastores.notice_statement([op, destination_name].inspect, elapsed)
          end

          ::NewRelic::Agent::Datastores.wrap('MessageDriver', op, destination_name, callback) do
            send(:"#{op}_without_newrelic", *args, &block)
          end
        end
      end

      MESSAGE_OPS.each do |op|
        define_method "#{op}_with_newrelic" do |*args, &block|
          destination_name = args[0].nil? ? nil : args[0].destination.name
          callback = proc do |result, metric, elapsed|
            ::NewRelic::Agent::Datastores.notice_statement([op, destination_name].inspect, elapsed)
          end

          ::NewRelic::Agent::Datastores.wrap('MessageDriver', op, destination_name, callback) do
            send(:"#{op}_without_newrelic", *args)
          end
        end
      end

      BROKER_OPS.each do |op|
        define_method "#{op}_with_newrelic" do |*args, &block|
          broker_name = adapter.broker.name
          callback = proc do |result, metric, elapsed|
            ::NewRelic::Agent::Datastores.notice_statement([op].inspect, elapsed)
          end

          ::NewRelic::Agent::Datastores.wrap('MessageDriver', op, broker_name, callback) do
            send(:"#{op}_without_newrelic", *args, &block)
          end
        end
      end

      def self.included(other)
        other.class_eval do
          OPTS_TO_OVERRIDE.each do |op|
            alias :"#{op}_without_newrelic" :"#{op}"
            alias :"#{op}" :"#{op}_with_newrelic"
          end
        end
      end
    end
  end
end

DependencyDetection.defer do
  named :message_driver

  depends_on do
    defined?(MessageDriver) &&
      defined?(MessageDriver::Adapters::ContextBase) &&
      ENV['NEWRELIC_ENABLE'].to_s !~ /false|off|no/i
  end

  executes do
    ::NewRelic::Agent.logger.info 'Installing Message Driver instrumentation'
  end

  executes do
    ::MessageDriver::Adapters::ContextBase.class_eval do
      include MessageDriver::NewRelic::Instrumentation
    end
  end
end
