require "rails_helper"

RSpec.describe "Api::Bids", type: :request do
  let(:admin) { create(:user, :admin) }
  let(:non_admin) { create(:user) }
  let(:client) { create(:client) }
  let(:auth_headers) do
    { "Authorization" => "Bearer #{admin.api_token}", "Content-Type" => "application/json" }
  end

  def valid_payload(overrides = {})
    {
      bid: {
        client_id: client.id,
        title: "Acme Internal CRM",
        hourly_rate: 150,
        requirements_summary: "Build a CRM",
        ai_generated: true,
        features: [
          {
            description: "User auth + SSO",
            work_category: "development",
            hours: 16
          },
          {
            description: "Stripe billing",
            work_category: "integration",
            hours: 20,
            rate: 175
          }
        ],
        monthly_costs: [
          {
            description: "Render hosting",
            unit_cost: 25,
            is_recurring: true,
            billing_frequency: "monthly"
          }
        ]
      }
    }.deep_merge(overrides)
  end

  describe "POST /api/bids" do
    context "happy path (auto_accept: false)" do
      it "creates bid + line items as draft" do
        expect {
          post "/api/bids", params: valid_payload.to_json, headers: auth_headers
        }.to change(Bid, :count).by(1)
          .and change(BidLineItem, :count).by(3)
          .and change(Project, :count).by(0)
          .and change(Invoice, :count).by(0)

        expect(response).to have_http_status(:created)
        body = JSON.parse(response.body)
        expect(body["bid"]["status"]).to eq("draft")
        expect(body["bid"]["line_item_count"]).to eq(3)
        expect(body["project"]).to be_nil
        expect(body["invoice"]).to be_nil
        expect(body["admin_url"]).to include("/admin/bids/")

        bid = Bid.last
        expect(bid.client_id).to eq(client.id)
        expect(bid.hourly_rate).to eq(150)
        expect(bid.development_line_items.count).to eq(2)
        expect(bid.system_cost_line_items.count).to eq(1)
        # First feature: 16 * 150 = 2400, second: 20 * 175 = 3500. Dev subtotal 5900.
        expect(bid.development_subtotal).to eq(5900)
      end
    end

    context "auto_accept: true" do
      it "creates bid + project + draft deposit invoice in one call" do
        payload = valid_payload(auto_accept: true)

        expect {
          post "/api/bids", params: payload.to_json, headers: auth_headers
        }.to change(Bid, :count).by(1)
          .and change(Project, :count).by(1)
          .and change(Invoice, :count).by(1)

        expect(response).to have_http_status(:created)
        body = JSON.parse(response.body)
        expect(body["bid"]["status"]).to eq("accepted")
        expect(body["project"]).to be_present
        expect(body["project"]["stage"]).to eq("in_development")
        expect(body["invoice"]).to be_present
        expect(body["invoice"]["status"]).to eq("draft")
        # 50% deposit of 5900 = 2950
        expect(body["invoice"]["deposit_amount"]).to eq(2950.0)
      end
    end

    context "status guardrails" do
      it "ignores status='sent' in the payload and forces draft" do
        payload = valid_payload(bid: { status: "sent" })
        post "/api/bids", params: payload.to_json, headers: auth_headers
        expect(response).to have_http_status(:created)
        expect(Bid.last.status).to eq("draft")
      end

      it "ignores status='accepted' in the payload" do
        payload = valid_payload(bid: { status: "accepted" })
        post "/api/bids", params: payload.to_json, headers: auth_headers
        expect(response).to have_http_status(:created)
        expect(Bid.last.status).to eq("draft")
      end
    end

    context "auth" do
      it "returns 401 with invalid token" do
        post "/api/bids", params: valid_payload.to_json,
                          headers: { "Authorization" => "Bearer bogus", "Content-Type" => "application/json" }
        expect(response).to have_http_status(:unauthorized)
      end

      it "returns 403 for non-admin user" do
        headers = { "Authorization" => "Bearer #{non_admin.api_token}", "Content-Type" => "application/json" }
        post "/api/bids", params: valid_payload.to_json, headers: headers
        expect(response).to have_http_status(:forbidden)
      end
    end

    context "strict preconditions" do
      it "rejects missing client_id" do
        payload = valid_payload
        payload[:bid].delete(:client_id)
        expect {
          post "/api/bids", params: payload.to_json, headers: auth_headers
        }.not_to change(Bid, :count)
        expect(response).to have_http_status(:unprocessable_entity)
        expect(JSON.parse(response.body)["errors"]).to include(match(/client_id is required/))
      end

      it "returns 404 for nonexistent client_id" do
        payload = valid_payload(bid: { client_id: 999_999 })
        post "/api/bids", params: payload.to_json, headers: auth_headers
        expect(response).to have_http_status(:not_found)
      end

      it "rejects missing hourly_rate" do
        payload = valid_payload
        payload[:bid].delete(:hourly_rate)
        post "/api/bids", params: payload.to_json, headers: auth_headers
        expect(response).to have_http_status(:unprocessable_entity)
        expect(JSON.parse(response.body)["errors"]).to include(match(/hourly_rate must be finalized/))
      end

      it "rejects hourly_rate of 0" do
        payload = valid_payload(bid: { hourly_rate: 0 })
        post "/api/bids", params: payload.to_json, headers: auth_headers
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it "rejects empty features array" do
        payload = valid_payload(bid: { features: [] })
        post "/api/bids", params: payload.to_json, headers: auth_headers
        expect(response).to have_http_status(:unprocessable_entity)
        expect(JSON.parse(response.body)["errors"]).to include(match(/at least one feature/))
      end

      it "rejects feature with invalid work_category" do
        payload = valid_payload
        payload[:bid][:features][0][:work_category] = "bogus"
        post "/api/bids", params: payload.to_json, headers: auth_headers
        expect(response).to have_http_status(:unprocessable_entity)
        expect(JSON.parse(response.body)["errors"]).to include(match(/work_category/))
      end

      it "rejects feature with hours <= 0" do
        payload = valid_payload
        payload[:bid][:features][0][:hours] = 0
        post "/api/bids", params: payload.to_json, headers: auth_headers
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it "rejects missing title" do
        payload = valid_payload
        payload[:bid][:title] = ""
        post "/api/bids", params: payload.to_json, headers: auth_headers
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it "rejects app entry with neither app_id nor new_app_name" do
        payload = valid_payload
        payload[:bid][:apps] = [{ app_id: nil, new_app_name: "" }]
        post "/api/bids", params: payload.to_json, headers: auth_headers
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it "rejects nonexistent app_id" do
        payload = valid_payload
        payload[:bid][:apps] = [{ app_id: 999_999 }]
        post "/api/bids", params: payload.to_json, headers: auth_headers
        expect(response).to have_http_status(:not_found)
      end

      it "rolls back the whole transaction on any precondition failure" do
        payload = valid_payload(bid: { hourly_rate: 0 })
        expect {
          post "/api/bids", params: payload.to_json, headers: auth_headers
        }.to change(Bid, :count).by(0)
          .and change(BidLineItem, :count).by(0)
          .and change(BidApp, :count).by(0)
      end
    end

    context "apps" do
      it "links existing apps and creates placeholders" do
        existing_app = create(:app)
        payload = valid_payload
        payload[:bid][:apps] = [
          { app_id: existing_app.id },
          { new_app_name: "Future Portal" }
        ]
        post "/api/bids", params: payload.to_json, headers: auth_headers
        expect(response).to have_http_status(:created)
        bid = Bid.last
        expect(bid.bid_apps.count).to eq(2)
        expect(bid.bid_apps.where(app_id: existing_app.id)).to exist
        expect(bid.bid_apps.where(new_app_name: "Future Portal")).to exist
      end
    end
  end

  describe "POST /api/bids/:id/accept" do
    let!(:bid) do
      bid = create(:bid, client: client, hourly_rate: 150)
      bid.line_items.create!(
        line_item_type: "development",
        description: "Auth",
        work_category: "development",
        hours: 10,
        rate: 150
      )
      bid.recalculate_total!
      bid
    end

    it "converts a draft bid into a project + deposit invoice" do
      expect {
        post "/api/bids/#{bid.id}/accept", headers: auth_headers
      }.to change(Project, :count).by(1)
        .and change(Invoice, :count).by(1)

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["bid"]["status"]).to eq("accepted")
      expect(body["project"]).to be_present
      expect(body["invoice"]["status"]).to eq("draft")
    end

    it "refuses to re-accept an already-accepted bid" do
      bid.update!(status: "accepted")
      post "/api/bids/#{bid.id}/accept", headers: auth_headers
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "returns 403 for non-admin" do
      headers = { "Authorization" => "Bearer #{non_admin.api_token}", "Content-Type" => "application/json" }
      post "/api/bids/#{bid.id}/accept", headers: headers
      expect(response).to have_http_status(:forbidden)
    end
  end
end
