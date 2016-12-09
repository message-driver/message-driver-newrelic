require 'spec_helper'

RSpec.describe MessageDriver::NewRelic::Instrumentation do
  # around do |ex|
  #   with_debug_logging do
  #     orig_logger = MessageDriver.logger
  #     MessageDriver.logger = NewRelic::Agent.logger
  #     begin
  #       ex.run
  #     ensure
  #       MessageDriver.logger = orig_logger
  #     end
  #   end
  # end

  def expect_sample
    expect(NewRelic::Agent.agent.transaction_sampler.tl_builder.sample)
  end

  matcher :have_value do |expected|
    chain :on_segment do |segment_name|
      @segment_name = segment_name
    end

    match do |sample|
      @node = find_node_with_name(sample, @segment_name)
      !@node.nil? && @node.params[:statement] == expected
    end

    failure_message do |sample|
      if @node.nil?
        "couldn't find segment #{@segment_name}"
      else
        "expected segment #{@segment_name} to contain #{expected} but got #{@node.params[:statement]}"
      end
    end
  end

  it "adds the instrumentation to MessageDriver::Adapters::Base::ContextBase" do
    expect(MessageDriver::Adapters::ContextBase).to include(MessageDriver::NewRelic::Instrumentation)
  end

  context "when a broker is configured" do
    before(:context) do
      MessageDriver::Broker.configure(:default, adapter: MessageDriver::NewRelic::MockAdapter)
      MessageDriver::Broker.define(:default) do |b|
        b.destination(:my_queue, 'my.test.queue')
      end
      consumer = ->(_) {}
      MessageDriver::Client.consumer(:my_consumer, &consumer)
    end

    after do
      MessageDriver::Broker.reset_after_tests
    end

    let(:destination_key) { :my_queue }
    let(:queue_name) { 'my.test.queue' }
    let(:consumer_key) { :my_consumer }

    it "sends data to newrelic on publish" do
      in_transaction do
        MessageDriver::Client.publish(destination_key, 'hi mom!')

        expect_sample.to have_value(['publish', queue_name].inspect).on_segment("Datastore/statement/MessageDriver/#{queue_name}/publish")
      end

      assert_metrics_recorded(%W{
        Datastore/all
        Datastore/allOther
        Datastore/MessageDriver/all
        Datastore/MessageDriver/allOther
        Datastore/operation/MessageDriver/publish
        Datastore/statement/MessageDriver/#{queue_name}/publish
      })
    end

    it "sends data to newrelic on pop_message and ack_message" do
      in_transaction do
        MessageDriver::Client.publish(destination_key, 'hi mom!')
      end

      NewRelic::Agent.drop_buffered_data

      in_transaction do
        message = MessageDriver::Client.pop_message(destination_key)
        message.ack
      end

      assert_metrics_recorded(%W{
        Datastore/all
        Datastore/allOther
        Datastore/MessageDriver/all
        Datastore/MessageDriver/allOther
        Datastore/operation/MessageDriver/pop_message
        Datastore/statement/MessageDriver/#{queue_name}/pop_message
        Datastore/operation/MessageDriver/ack_message
        Datastore/statement/MessageDriver/#{queue_name}/ack_message
      })
    end

    it "sends data to newrelic on pop_message and nack_message" do
      in_transaction do
        MessageDriver::Client.publish(destination_key, 'hi mom!')
      end

      NewRelic::Agent.drop_buffered_data

      in_transaction do
        message = MessageDriver::Client.pop_message(destination_key)
        message.nack
      end

      assert_metrics_recorded(%W{
        Datastore/all
        Datastore/allOther
        Datastore/MessageDriver/all
        Datastore/MessageDriver/allOther
        Datastore/operation/MessageDriver/pop_message
        Datastore/statement/MessageDriver/#{queue_name}/pop_message
        Datastore/operation/MessageDriver/nack_message
        Datastore/statement/MessageDriver/#{queue_name}/nack_message
      })
    end

    it 'sends data to newrelic on begin_transaction and commit_transaction' do
      in_transaction do
        MessageDriver::Client.with_message_transaction do
          # do nothing
        end
      end

      assert_metrics_recorded(%W{
        Datastore/all
        Datastore/allOther
        Datastore/MessageDriver/all
        Datastore/MessageDriver/allOther
        Datastore/operation/MessageDriver/begin_transaction
        Datastore/statement/MessageDriver/default/begin_transaction
        Datastore/operation/MessageDriver/commit_transaction
        Datastore/statement/MessageDriver/default/commit_transaction
      })
    end

    it 'sends data to newrelic on begin_transaction and rollback_transaction' do
      in_transaction do
        begin
          MessageDriver::Client.with_message_transaction do
            raise MessageDriver::TransactionRollbackOnly
          end
        rescue MessageDriver::TransactionRollbackOnly
          # we expected that
        end
      end

      assert_metrics_recorded(%W{
        Datastore/all
        Datastore/allOther
        Datastore/MessageDriver/all
        Datastore/MessageDriver/allOther
        Datastore/operation/MessageDriver/begin_transaction
        Datastore/statement/MessageDriver/default/begin_transaction
        Datastore/operation/MessageDriver/rollback_transaction
        Datastore/statement/MessageDriver/default/rollback_transaction
      })
    end

    it 'sends data to newrelic on subscribe' do
      in_transaction do
        MessageDriver::Client.subscribe(destination_key, consumer_key)
      end

      assert_metrics_recorded(%W{
        Datastore/all
        Datastore/allOther
        Datastore/MessageDriver/all
        Datastore/MessageDriver/allOther
        Datastore/operation/MessageDriver/subscribe
        Datastore/statement/MessageDriver/#{queue_name}/subscribe
      })
    end

    xit 'sends data to newrelic on unsubscribe' do
      subscriber = MessageDriver::Client.subscribe(destination_key, consumer_key)
      NewRelic::Agent.drop_buffered_data

      in_transaction do
        subscriber.unsubscribe
      end

      assert_metrics_recorded(%W{
        Datastore/all
        Datastore/allOther
        Datastore/MessageDriver/all
        Datastore/MessageDriver/allOther
        Datastore/operation/MessageDriver/unsubscribe
        Datastore/statement/MessageDriver/#{queue_name}/unsubscribe
      })
    end

    it 'sends data to newrelic on message_count' do
      destination = MessageDriver::Client.find_destination(destination_key)
      in_transaction do
        destination.publish('hi mom! 1')
        destination.publish('hi mom! 2')
      end

      NewRelic::Agent.drop_buffered_data

      in_transaction do
        expect(destination.message_count).to eq 2
      end

      assert_metrics_recorded(%W{
        Datastore/all
        Datastore/allOther
        Datastore/MessageDriver/all
        Datastore/MessageDriver/allOther
        Datastore/operation/MessageDriver/message_count
        Datastore/statement/MessageDriver/#{queue_name}/message_count
      })
    end

    it 'sends data to newrelic on consumer_count' do
      destination = MessageDriver::Client.find_destination(destination_key)
      in_transaction do
        MessageDriver::Client.subscribe(destination_key, consumer_key)
      end

      NewRelic::Agent.drop_buffered_data

      in_transaction do
        expect(destination.consumer_count).to eq 1
      end

      assert_metrics_recorded(%W{
        Datastore/all
        Datastore/allOther
        Datastore/MessageDriver/all
        Datastore/MessageDriver/allOther
        Datastore/operation/MessageDriver/consumer_count
        Datastore/statement/MessageDriver/#{queue_name}/consumer_count
      })
    end
  end
end
