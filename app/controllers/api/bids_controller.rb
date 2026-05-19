class Api::BidsController < ApplicationController
  skip_before_action :verify_authenticity_token
  before_action :require_admin!

  def create
    result = BidBuilderService.new(params.to_unsafe_h, user: current_user).call

    unless result[:success]
      render json: { errors: result[:errors] }, status: result[:status]
      return
    end

    bid = result[:bid]

    if ActiveModel::Type::Boolean.new.cast(params[:auto_accept])
      accept_result = BidToProjectService.new(bid).call
      unless accept_result[:success]
        render json: { errors: ["auto_accept failed: #{accept_result[:error]}"] },
               status: :unprocessable_entity
        return
      end
      audit!("api_bid_created_and_accepted", bid)
      render json: serialize(bid.reload, project: accept_result[:project], invoice: accept_result[:invoice]),
             status: :created
    else
      audit!("api_bid_created", bid)
      render json: serialize(bid), status: :created
    end
  end

  def accept
    bid = Bid.find(params[:id])

    if bid.status == "accepted"
      render json: { errors: ["bid already accepted"] }, status: :unprocessable_entity
      return
    end

    result = BidToProjectService.new(bid).call

    if result[:success]
      audit!("api_bid_accepted", bid)
      render json: serialize(bid.reload, project: result[:project], invoice: result[:invoice]),
             status: :ok
    else
      render json: { errors: [result[:error]] }, status: :unprocessable_entity
    end
  end

  private

  def require_admin!
    return if current_user&.admin?

    render json: { errors: ["admin access required"] }, status: :forbidden
  end

  def serialize(bid, project: nil, invoice: nil)
    {
      bid: {
        id: bid.id,
        status: bid.status,
        title: bid.title,
        client_id: bid.client_id,
        hourly_rate: bid.hourly_rate.to_f,
        total: bid.total.to_f,
        estimated_hours_total: bid.estimated_hours_total.to_f,
        monthly_costs_total: bid.monthly_costs_total.to_f,
        line_item_count: bid.line_items.count,
        app_count: bid.bid_apps.count
      },
      project: project && {
        id: project.id,
        title: project.title,
        status: project.status,
        stage: project.stage
      },
      invoice: invoice && {
        id: invoice.id,
        status: invoice.status,
        total: invoice.total.to_f,
        deposit_amount: invoice.deposit_amount.to_f
      },
      admin_url: bid_admin_url(bid)
    }
  end

  def bid_admin_url(bid)
    Rails.application.routes.url_helpers.admin_bid_url(
      bid,
      host: request.host_with_port,
      protocol: request.protocol.sub("://", "")
    )
  rescue StandardError
    "/admin/bids/#{bid.id}"
  end

  def audit!(action, auditable, changes_data = {})
    return unless defined?(AuditLogger)

    AuditLogger.log(
      user: current_user,
      action: action,
      auditable: auditable,
      changes_data: changes_data
    )
  end
end
