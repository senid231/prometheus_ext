# frozen_string_literal: true

require 'forwardable'
require 'prometheus_exporter/client'

module PrometheusExt
  # Prometheus processor that repeats gather of metrics with provided frequency.
  # @example
  #   class MyProcessor < PrometheusExt::OnDemandProcessor
  #     self.type = 'my'
  #     self.logger = Rails.logger
  #
  #     def collect(metric)
  #       format_metric(metric)
  #     end
  #   end
  #
  #   MyProcessor.collect(hist1: 5, hist2: 10)
  #   MyProcessor.collect(hist1: 4, hist2: 7, total: 1, sum: 2)
  #
  class OnDemandProcessor
    extend Forwardable

    class << self
      attr_accessor :logger,
                    :type,
                    :client,
                    :labels,
                    :_on_exception

      def on_exception(&block)
        self._on_exception = block
      end

      def collect(*args)
        with_log_tags(name) do
          logger&.info { 'Collection metrics...' }
          self.client ||= PrometheusExporter::Client.default
          metric = new(labels&.dup || {}).collect(*args)
          client.send_json(metric)
          logger&.info { 'Metrics collected.' }
        rescue StandardError => e
          warn "#{name} Failed To Collect Stats #{e.class} #{e.message}"
          logger&.error { "<#{e.class}>: #{e.message}\n#{e.backtrace&.join("\n")}" }
          instance_exec(e, &_on_exception) unless _on_exception.nil?
        end
      end

      def with_log_tags(*tags, &block)
        return yield if logger.nil? || !logger.respond_to?(:tagged)

        logger.tagged(*tags, &block)
      end
    end

    def_instance_delegators :'self.class', :logger, :type

    # @param labels [Hash] default empty hash.
    def initialize(labels = {})
      @labels = labels
    end

    # Override this method in a subclass with collecting needed metrics.
    # @param args [Array]
    # @return [Hash]
    def collect(*args)
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
