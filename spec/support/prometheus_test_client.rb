# frozen_string_literal: true

class PrometheusTestClient < ::PrometheusExporter::Client
  class << self
    attr_accessor :sent

    def reset!
      self.sent = []
    end

    def add_metric(json)
      sent << JSON.parse(json)
    end
  end

  reset!

  def initialize(custom_labels: nil)
    super
  end

  # @param json [String]
  def send(json)
    self.class.add_metric(json)
  end
end
