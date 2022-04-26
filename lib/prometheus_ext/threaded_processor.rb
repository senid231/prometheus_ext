# frozen_string_literal: true

require 'forwardable'
require 'prometheus_exporter/client'

module PrometheusExt
  # Prometheus processor that repeats gather of metrics with provided frequency.
  # @example
  #   class MyProcessor < PrometheusExt::ThreadedProcessor
  #     self.type = 'my'
  #     self.logger = Rails.logger
  #
  #     def collect
  #       [
  #         format_metric(some_metric: 5),
  #         format_metric(some_other_metric: 5, labels: { custom: 'foo' })
  #       ]
  #     end
  #   end
  #
  #   MyProcessor.start
  #
  class ThreadedProcessor
    extend Forwardable

    class << self
      attr_accessor :_callbacks,
                    :default_frequency,
                    :logger,
                    :type

      # Adds callback block with provided name.
      # @param name[Symbol,String]
      # @yield
      def define_callback(name, &block)
        raise ArgumentError,
              _callbacks[name.to_sym] << block
      end

      def before_thread_start(&block)
        define_callback(:before_thread_start, &block)
      end

      def after_thread_start(&block)
        define_callback(:after_thread_start, &block)
      end

      def run_callbacks(name, *args)
        _callbacks[name.to_sym].each do |callback|
          instance_exec(*args, &callback)
        end
      end

      # @param client [PrometheusExporter::Client,nil]
      # @param frequency [Numeric]
      # @param labels [Hash,nil]
      def start(client: nil, frequency: default_frequency, labels: nil)
        stop
        setup(client: client, labels: labels)
        run_callbacks(:before_thread_start)
        @thread = Thread.new do
          with_log_tags(name) do
            run_callbacks(:after_thread_start)
            logger&.info { 'started' }
            loop do
              run_once
              sleep frequency
            end
          end
        ensure # will be executed before thread exited.
          logger&.info { 'thread exited' }
        end
        nil
      end

      def setup(client: nil, labels: nil)
        @client = client || PrometheusExporter::Client.default
        @processor = new(labels&.dup || {})
      end

      def run_once
        logger&.info { 'Collection metrics...' }
        metrics = @processor.collect
        metrics.each do |metric|
          @client.send_json metric
        end
        logger&.info { 'Metrics collected.' }
      rescue StandardError => e
        warn "#{name} Failed To Collect Stats #{e.class} #{e.message}"
        logger&.error { "<#{e.class}>: #{e.message}\n#{e.backtrace&.join("\n")}" }
        run_callbacks(:on_exception, e)
      end

      def stop
        return if !defined?(:@thread) || @thread.nil?

        @thread.kill
        @thread = nil
        @client = nil
        @processor = nil
      end

      def with_log_tags(*tags, &block)
        return yield if logger.nil? || !logger.respond_to?(:tagged)

        logger.tagged(*tags, &block)
      end

      private

      def inherited(subclass)
        super
        subclass.default_frequency = 30
        subclass._callbacks = Hash.new([])
      end
    end

    def_instance_delegators :'self.class', :logger, :type

    # @param labels [Hash] default empty hash.
    def initialize(labels = {})
      @labels = labels
    end

    # Override this method in a subclass with collecting needed metrics.
    # @return [Array]
    def collect
      raise NotImplementedError
    end

    private

    # Formats metric by adding type and labels to it.
    # @param metric [Hash] with symbolic keys
    # @return [Hash]
    def format_metric(metric)
      labels = @labels.merge(metric[:labels] || {})
      metric[:type] = type
      metric[:labels] = labels
      metric
    end
  end
end
