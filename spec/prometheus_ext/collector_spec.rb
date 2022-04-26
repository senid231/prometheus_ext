# frozen_string_literal: true

RSpec.describe PrometheusExt::Collector do
  let(:collector_class) do
    Class.new(described_class) do
      self.type = 'foo'

      define_metric :c1, :counter, desc: 'c1 counter'
      define_metric :g1, :gauge, desc: 'g1 gauge'
      define_metric :h1, :histogram, desc: 'h1 histogram'
      define_metric :h2, :histogram, desc: 'h2 histogram', buckets: [0.1, 1, 100]
      define_metric :s1, :summary, desc: 's1 summary'
      define_metric :s2, :summary, desc: 's2 summary', quantiles: [0.99, 0.1, 0.01]
    end
  end

  describe '#metrics' do
    subject do
      texts = collector_instance.metrics.map(&:metric_text)
      lines = []
      texts.each { |text| lines.concat text.split("\n") }
      lines.reject(&:empty?)
    end

    let(:collector_instance) do
      collector_class.new
    end

    context 'without data' do
      it 'returns no metrics' do
        expect(subject).to eq []
      end
    end

    context 'with data' do
      before do
        collector_instance.collect(
          'c1' => 1,
          'type' => 'foo'
        )

        collector_instance.collect(
          'c1' => 1,
          'g1' => 2,
          'h1' => 3,
          's1' => 4,
          's2' => 5,
          'type' => 'foo',
          'labels' => { 'a' => '1' }
        )

        collector_instance.collect(
          'c1' => 2,
          'g1' => 3,
          'h1' => 4,
          's1' => 5,
          's2' => 6,
          'type' => 'foo',
          'labels' => { 'a' => '2' }
        )

        collector_instance.collect(
          'c1' => 3,
          'g1' => 1,
          'h1' => 101,
          's1' => 1,
          's2' => 0.5,
          'type' => 'foo',
          'labels' => { 'a' => '2' }
        )
      end

      it 'returns correct metrics' do
        expect(subject).to match_array(
          [
            'foo_c1 1',
            'foo_c1{a="1"} 1',
            'foo_c1{a="2"} 5',
            'foo_g1{a="1"} 2',
            'foo_g1{a="2"} 1',
            'foo_h1_bucket{a="1",le="+Inf"} 1',
            'foo_h1_bucket{a="1",le="10.0"} 1',
            'foo_h1_bucket{a="1",le="5.0"} 1',
            'foo_h1_bucket{a="1",le="2.5"} 0',
            'foo_h1_bucket{a="1",le="1"} 0',
            'foo_h1_bucket{a="1",le="0.5"} 0',
            'foo_h1_bucket{a="1",le="0.25"} 0',
            'foo_h1_bucket{a="1",le="0.1"} 0',
            'foo_h1_bucket{a="1",le="0.05"} 0',
            'foo_h1_bucket{a="1",le="0.025"} 0',
            'foo_h1_bucket{a="1",le="0.01"} 0',
            'foo_h1_bucket{a="1",le="0.005"} 0',
            'foo_h1_count{a="1"} 1',
            'foo_h1_sum{a="1"} 3.0',
            'foo_h1_bucket{a="2",le="+Inf"} 2',
            'foo_h1_bucket{a="2",le="10.0"} 1',
            'foo_h1_bucket{a="2",le="5.0"} 1',
            'foo_h1_bucket{a="2",le="2.5"} 0',
            'foo_h1_bucket{a="2",le="1"} 0',
            'foo_h1_bucket{a="2",le="0.5"} 0',
            'foo_h1_bucket{a="2",le="0.25"} 0',
            'foo_h1_bucket{a="2",le="0.1"} 0',
            'foo_h1_bucket{a="2",le="0.05"} 0',
            'foo_h1_bucket{a="2",le="0.025"} 0',
            'foo_h1_bucket{a="2",le="0.01"} 0',
            'foo_h1_bucket{a="2",le="0.005"} 0',
            'foo_h1_count{a="2"} 2',
            'foo_h1_sum{a="2"} 105.0',
            'foo_s1{a="1",quantile="0.99"} 4.0',
            'foo_s1{a="1",quantile="0.9"} 4.0',
            'foo_s1{a="1",quantile="0.5"} 4.0',
            'foo_s1{a="1",quantile="0.1"} 4.0',
            'foo_s1{a="1",quantile="0.01"} 4.0',
            'foo_s1_sum{a="1"} 4.0',
            'foo_s1_count{a="1"} 1',
            'foo_s1{a="2",quantile="0.99"} 5.0',
            'foo_s1{a="2",quantile="0.9"} 5.0',
            'foo_s1{a="2",quantile="0.5"} 1.0',
            'foo_s1{a="2",quantile="0.1"} 1.0',
            'foo_s1{a="2",quantile="0.01"} 1.0',
            'foo_s1_sum{a="2"} 6.0',
            'foo_s1_count{a="2"} 2',
            'foo_s2{a="1",quantile="0.99"} 5.0',
            'foo_s2{a="1",quantile="0.1"} 5.0',
            'foo_s2{a="1",quantile="0.01"} 5.0',
            'foo_s2_sum{a="1"} 5.0',
            'foo_s2_count{a="1"} 1',
            'foo_s2{a="2",quantile="0.99"} 6.0',
            'foo_s2{a="2",quantile="0.1"} 0.5',
            'foo_s2{a="2",quantile="0.01"} 0.5',
            'foo_s2_sum{a="2"} 6.5',
            'foo_s2_count{a="2"} 2'
          ]
        )
      end
    end

    context 'when fresh and old data' do
      before do
        collector_class.metric_max_age = 30
        current_time = ::Process.clock_gettime(::Process::CLOCK_MONOTONIC)
        allow(::Process).to receive(:clock_gettime).with(::Process::CLOCK_MONOTONIC).and_return(current_time - 31)
        collector_instance.collect(
          'c1' => 1,
          'type' => 'foo',
          'labels' => { 'a' => '1' }
        )
        allow(::Process).to receive(:clock_gettime).with(::Process::CLOCK_MONOTONIC).and_return(current_time)
        collector_instance.collect(
          'c1' => 1,
          'type' => 'foo',
          'labels' => { 'a' => '2' }
        )
      end

      it 'returns correct metrics' do
        expect(subject).to match_array(
          ['foo_c1{a="2"} 1']
        )
      end
    end
  end
end
