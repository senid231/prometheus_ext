# frozen_string_literal: true

require 'prometheus_exporter/server/type_collector'
require 'prometheus_exporter/metric/base'
require 'prometheus_exporter/metric/counter'
require 'prometheus_exporter/metric/gauge'
require 'prometheus_exporter/metric/histogram'
require 'prometheus_exporter/metric/summary'
require 'forwardable'

module PrometheusExt
  # Default collector for ThreadedProcessor and OnDemandProcessor.
  # @example
  #   class MyCollector <  PrometheusExt::Collector
  #     self.type = 'my'
  #
  #     define_metric :some_metric, :counter, desc: 'some desc'
  #     define_metric :some_other_metric, :gauge, desc: 'some other desc'
  #     define_metric :hist1, :histogram, desc: 'some other desc'
  #     define_metric :hist2, :histogram, desc: 'some other desc', buckets: [0.1, 1, 10, 100]
  #     define_metric :total, :summary, desc: 'some other desc'
  #     define_metric :sum, :summary, desc: 'some other desc', quantiles: [0.99, 0.5, 0.1, 0.01, 0.001]
  #   end
  class Collector < ::PrometheusExporter::Server::TypeCollector
    extend Forwardable

    class << self
      attr_accessor :type,
                    :metric_max_age,
                    :_observers

      def find_metric_class(type)
        return type if type.is_a?(Class)

        case type
        when :counter then PrometheusExporter::Metric::Counter
        when :gauge then PrometheusExporter::Metric::Gauge
        when :histogram then PrometheusExporter::Metric::Histogram
        when :summary then PrometheusExporter::Metric::Summary
        else
          raise ArgumentError, "invalid metric type #{type.inspect}"
        end
      end

      def define_metric(name, metric_type, desc:, **options)
        self._observers[name.to_sym] = {
          metric_name: "#{type}_#{name}",
          metric_class: find_metric_class(metric_type),
          desc: desc,
          options: options
        }
      end

      private

      def inherited(subclass)
        super
        subclass.metric_max_age = 60
        subclass._observers = {}
      end
    end

    def_instance_delegators :'self.class', :type, :metric_max_age

    def initialize
      super
      @data = []
      build_observers
    end

    def metrics
      return [] if @data.empty?

      @observers.each_value(&:reset!)

      @data.map do |obj|
        labels = {}
        # labels are passed by collector itself
        labels.merge!(obj['labels']) if obj['labels']
        # custom_labels are passed by client
        labels.merge!(obj['custom_labels']) if obj['custom_labels']

        @observers.each do |name, observer|
          value = obj[name.to_s]
          observer.observe(value, labels) if value
        end
      end

      @observers.values
    end

    def collect(obj)
      return @data << obj if metric_max_age.nil?

      now = ::Process.clock_gettime(::Process::CLOCK_MONOTONIC)
      obj['created_at'] = now
      @data.delete_if { |m| m['created_at'] + metric_max_age < now }
      @data << obj
    end

    private

    def build_observers
      @observers = {}

      self.class._observers.each do |name, opts|
        @observers[name] = build_observer(opts)
      end
    end

    def build_observer(opts)
      metric_class = opts[:metric_class]
      metric_name = opts[:metric_name]
      desc = opts[:desc]
      options = opts[:options]
      if options.empty?
        metric_class.new(metric_name, desc)
      else
        metric_class.new(metric_name, desc, options)
      end
    end
  end
end
