class GoogleOauthService
  TOKEN_URL = "https://oauth2.googleapis.com/token"
  USERINFO_URL = "https://www.googleapis.com/oauth2/v3/userinfo"

  def initialize(code:, redirect_uri:)
    @code = code
    @redirect_uri = redirect_uri
  end

  def authenticate
    tokens = exchange_code_for_tokens
    return nil unless tokens["access_token"]

    user_info = fetch_user_info(tokens["access_token"])
    return nil unless user_info["email"]

    {
      provider: "google",
      uid: user_info["sub"],
      email: user_info["email"],
      name: user_info["name"],
      avatar_url: user_info["picture"]
    }
  end

  private

  def exchange_code_for_tokens
    conn = Faraday.new(url: TOKEN_URL)
    response = conn.post do |req|
      req.headers["Content-Type"] = "application/x-www-form-urlencoded"
      req.body = URI.encode_www_form(
        code: @code,
        client_id: ENV["GOOGLE_CLIENT_ID"],
        client_secret: ENV["GOOGLE_CLIENT_SECRET"],
        redirect_uri: @redirect_uri,
        grant_type: "authorization_code"
      )
    end

    JSON.parse(response.body)
  rescue StandardError => e
    Rails.logger.error("Google OAuth token exchange failed: #{e.message}")
    {}
  end

  def fetch_user_info(access_token)
    conn = Faraday.new(url: USERINFO_URL)
    response = conn.get do |req|
      req.headers["Authorization"] = "Bearer #{access_token}"
    end

    JSON.parse(response.body)
  rescue StandardError => e
    Rails.logger.error("Google OAuth userinfo fetch failed: #{e.message}")
    {}
  end
end
