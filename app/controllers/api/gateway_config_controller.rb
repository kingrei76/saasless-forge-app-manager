class Api::GatewayConfigController < ApplicationController
  skip_before_action :authenticate_user!, raise: false
  before_action :authenticate_gateway!

  def keys
    providers = ServiceProvider.proxyable.select(:id, :slug, :base_url, :api_key)

    render json: providers.map { |p|
      {
        slug: p.slug,
        api_key: p.api_key,
        base_url: p.base_url
      }
    }
  end

  private

  def authenticate_gateway!
    token = request.headers["Authorization"]&.delete_prefix("Bearer ")&.strip
    expected = Setting[:gateway_auth_token].presence || ENV["GATEWAY_AUTH_TOKEN"]

    unless expected.present? && ActiveSupport::SecurityUtils.secure_compare(token.to_s, expected)
      render json: { error: "Unauthorized" }, status: :unauthorized
    end
  end
end
