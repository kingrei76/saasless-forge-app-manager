class StripeWebhooksController < ApplicationController
  skip_before_action :verify_authenticity_token
  skip_before_action :authenticate_user!, if: -> { defined?(super) }

  def create
    payload = request.body.read
    sig_header = request.env["HTTP_STRIPE_SIGNATURE"]
    webhook_secret = Setting[:stripe_webhook_signing_secret] || ENV["STRIPE_WEBHOOK_SECRET"]

    begin
      event = Stripe::Webhook.construct_event(payload, sig_header, webhook_secret)
    rescue JSON::ParserError
      Rails.logger.error("StripeWebhook: Invalid payload")
      head :bad_request and return
    rescue Stripe::SignatureVerificationError
      Rails.logger.error("StripeWebhook: Invalid signature")
      head :bad_request and return
    end

    Rails.logger.info("StripeWebhook: Received event #{event.type} (#{event.id})")

    StripeWebhookService.new(event).process!

    head :ok
  end
end
