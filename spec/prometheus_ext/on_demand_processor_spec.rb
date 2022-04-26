# frozen_string_literal: true

RSpec.describe PrometheusExt::OnDemandProcessor do
  describe '.collect' do
    subject do
      processor_class.collect(metric)
    end

    let(:processor_class) do
      Class.new(described_class) do
        self.type = 'test'
        self.client = PrometheusTestClient.new

        def collect(metric)
          format_metric(metric)
        end
      end
    end
    let(:metric) do
      { some_metric: 123 }
    end

    before do
      PrometheusTestClient.reset!
    end

    it 'sends correct metric' do
      subject
      expect(PrometheusTestClient.sent).to eq [
        'some_metric' => 123,
        'type' => 'test',
        'labels' => {}
      ]
    end

    context 'when passed metric has labels' do
      let(:metric) do
        super().merge labels: { qwe: 'asd' }
      end

      it 'sends correct metric' do
        subject
        expect(PrometheusTestClient.sent).to eq [
          'some_metric' => 123,
          'type' => 'test',
          'labels' => { 'qwe' => 'asd' }
        ]
      end
    end

    context 'when client has custom labels' do
      before do
        processor_class.client= PrometheusTestClient.new(custom_labels: { 'aaa' => 123 })
      end

      it 'sends correct metric' do
        subject
        expect(PrometheusTestClient.sent).to eq [
          'some_metric' => 123,
          'type' => 'test',
          'labels' => {},
          'custom_labels' => { 'aaa' => 123 }
        ]
      end
    end

    context 'when processor has labels' do
      before do
        processor_class.labels = { foo: 'bar' }
      end

      it 'sends correct metric' do
        subject
        expect(PrometheusTestClient.sent).to eq [
          'some_metric' => 123,
          'type' => 'test',
          'labels' => { 'foo' => 'bar' }
        ]
      end

      context 'when passed metric has labels' do
        let(:metric) do
          super().merge labels: { qwe: 'asd' }
        end

        it 'sends correct metric' do
          subject
          expect(PrometheusTestClient.sent).to eq [
            'some_metric' => 123,
            'type' => 'test',
            'labels' => {
              'foo' => 'bar',
              'qwe' => 'asd'
            }
          ]
        end
      end
    end
  end
end
