# frozen_string_literal: true

require 'prometheus_ext/threaded_processor'

class ActiveRecordProcessor < PrometheusExt::ThreadedProcessor
  self.type = 'active_record'
  self.logger = Rails.logger

  define_callback(:before_thread_start) do
    ApplicationRecord.connection_pool.release_connection
  end

  def collect
    ApplicationRecord.connection_pool.with_connection do
      metrics = []
      metrics << collect_metric(
        table_size: table_size('users'),
        labels: { table_name: 'users' }
      )
      metrics << collect_metric(
        table_size: table_size('admins'),
        labels: { table_name: 'admins' }
      )
      metrics << collect_metric(
        table_size: table_size('orders'),
        labels: { table_name: 'orders' }
      )
      metrics
    end
  end

  private

  def table_size(table_name)
    ApplicationRecord.connection.select_value("SELECT pg_table_size('#{table_name}')")
  end
end
