# frozen_string_literal: true

RSpec.describe PrometheusExt::ThreadedProcessor do
  describe '.run_once' do
    subject do
      processor_class.run_once
    end

    before do
      processor_class.setup(setup_opts)
    end

    let(:processor_class) do
      Class.new(described_class) do
        self.type = 'rspec'
      end
    end
    let(:setup_opts) do
      { client: client_stub }
    end
    let(:client_stub) do
      instance_double(PrometheusExporter::Client)
    end

    it 'collects and sends metric' do
      processor_stub = instance_double(processor_class)
      metric_stub = double
      expect(processor_class).to have_received(:new).with({}).and_return(processor_stub)
      expect(processor_stub).to have_received(:collect).once.and_return(metric_stub)
      expect(client_stub).to have_received(:send_json).with(metric_stub).once
      subject
    end
  end
end
