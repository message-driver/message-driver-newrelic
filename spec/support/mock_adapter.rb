require 'message_driver/adapters/in_memory_adapter'

module MessageDriver
  module NewRelic
    class MockAdapter < Adapters::InMemoryAdapter

      def build_context
        MockContext.new(self)
      end

      class MockContext < InMemoryContext
        def supports_client_acks?
          true
        end

        def supports_transactions?
          true
        end

        def handle_begin_transaction(*_); end

        def handle_commit_transaction(*_); end

        def handle_rollback_transaction(*_); end

        def handle_ack_message(*_); end

        def handle_nack_message(*_); end
      end
    end
  end
end
