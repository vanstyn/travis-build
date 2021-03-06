require "metriks"
require "metriks/librato_metrics_reporter"
require "sinatra/base"

module Travis
  module Build
    module AppMiddleware
      class Metriks < Sinatra::Base
        configure do
          ::Metriks::LibratoMetricsReporter.new(
            ENV["LIBRATO_EMAIL"],
            ENV["LIBRATO_TOKEN"],
            source: ENV["LIBRATO_SOURCE"],
            on_error: proc { |ex| puts "librato error: #{ex.message} (#{ex.response.body})" }
          ).start

          use(Rack::Config) { |env| env['metriks.request.start'] ||= Time.now.utc }
        end

        before do
          env["metriks.request.start"] ||= Time.now.utc
        end

        after do
          if queue_start = time(env['HTTP_X_QUEUE_START']) || time(env['HTTP_X_REQUEST_START'])
            time = env['metriks.request.start'] - queue_start
            ::Metriks.timer('build_api.request_queue').update(time)
          end

          time = Time.now.utc - env['metriks.request.start']

          ::Metriks.timer("build_api.requests").update(time)
          ::Metriks.timer("build_api.request.#{request.request_method.downcase}").update(time)
          ::Metriks.timer("build_api.request.status.#{response.status.to_s[0]}").update(time)
        end

        def time(value)
          value = value.to_f
          start = env["metriks.request.start"].to_f
          value /= 1000 while value > start
          Time.at(value) if value > 946684800
        end
      end
    end
  end
end
