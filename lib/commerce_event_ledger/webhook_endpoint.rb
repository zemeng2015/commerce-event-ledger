# frozen_string_literal: true

module CommerceEventLedger
  # Stable middleware wrapper; package classes are resolved inside the reloader.
  # Intercept before Rails logging, debug exceptions, and parameter parsing so
  # capability URLs and untrusted bodies never reach those middleware paths.
  class WebhookEndpoint
    def initialize(app)
      @app = app
    end

    def call(env)
      return @app.call(env) unless env.fetch("PATH_INFO", "").start_with?("/webhooks/shopify")

      receive(env)
    end

    private

    def receive(env)
      Rails.application.reloader.wrap do
        sources = Webhooks::ShopifySources.from_environment(environment: Rails.env.to_s)
        Webhooks::HttpReceiver.new(sources: sources, handler_name: Orders::Handler::NAME,
          handler_version: Orders::Handler::VERSION,
          enqueuer: ->(receipt) { ProcessEventJob.perform_later(receipt.shop_id, receipt.event_id) }).call(env)
      end
    rescue StandardError
      [ 503, { "content-type" => "application/json", "cache-control" => "no-store" },
        [ '{"error":"unavailable"}' ] ]
    end
  end
end
