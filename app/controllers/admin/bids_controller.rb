class Admin::BidsController < Admin::BaseController
  before_action :set_bid, only: [:show, :edit, :update, :destroy, :preview_pdf, :send_bid, :accept, :reject, :reopen, :update_section]

  def index
    @bids = Bid.includes(:client, :project).order(created_at: :desc)
  end

  def show
    @line_items = @bid.line_items.order(:position)
  end

  def new
    @bid = Bid.new(
      hourly_rate: Setting[:default_hourly_rate]&.to_f || 60.0,
      status: "draft"
    )
    @bid.project_id = params[:project_id] if params[:project_id].present?
    @bid.client_id = params[:client_id] if params[:client_id].present?
    if @bid.project && @bid.client_id.blank?
      @bid.client_id = @bid.project.client_id
    end
    @clients = Client.order(:name)
    @projects = Project.active.order(:title)
  end

  def create
    @bid = Bid.new(bid_params)

    if @bid.save
      redirect_to admin_bid_path(@bid), notice: "Bid created."
    else
      @clients = Client.order(:name)
      @projects = Project.active.order(:title)
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @clients = Client.order(:name)
    @projects = Project.active.order(:title)
  end

  def update
    if @bid.update(bid_params)
      redirect_to admin_bid_path(@bid), notice: "Bid updated."
    else
      @clients = Client.order(:name)
      @projects = Project.active.order(:title)
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @bid.destroy
    redirect_to admin_bids_path, notice: "Bid deleted."
  end

  def preview_pdf
    @line_items = @bid.line_items.order(:position)
    render layout: "print"
  end

  def accept
    assignee = params[:assignee_id].present? ? User.find(params[:assignee_id]) : nil

    result = BidToProjectService.new(@bid, assignee: assignee).call

    if result[:success]
      redirect_to admin_project_path(result[:project]),
                  notice: "Bid accepted! Project created with 50% deposit invoice."
    else
      redirect_to admin_bid_path(@bid), alert: "Error accepting bid: #{result[:error]}"
    end
  end

  def reject
    @bid.update!(status: "rejected")
    redirect_to admin_bid_path(@bid), notice: "Bid rejected."
  end

  def send_bid
    @bid.update!(status: "sent")
    redirect_to admin_bid_path(@bid), notice: "Bid marked as sent. You can now accept or reject it."
  end

  def reopen
    @bid.update!(status: "draft")
    redirect_to admin_bid_path(@bid), notice: "Bid reopened as draft. You can now make edits and resend."
  end

  def update_section
    section = params[:section]
    use_ai = params[:use_ai] == "true" || params[:use_ai] == "1"

    allowed_sections = %w[requirements_summary features_list notes internal_notes]
    unless allowed_sections.include?(section)
      render json: { success: false, error: "Invalid section" }, status: :unprocessable_entity
      return
    end

    if use_ai && params[:ai_prompt].present?
      # Use AI to edit the section
      ai_app = find_ai_app
      grok = GrokApiService.new(app: ai_app, trackable: @bid)
      current_content = section == "features_list" ? @bid.features_list&.join("\n") : @bid.send(section)

      result = grok.edit_section(
        section: section,
        current_content: current_content,
        prompt: params[:ai_prompt],
        project_context: @bid.project_description
      )

      if result[:success]
        if section == "features_list"
          @bid.update!(features_list: result[:content])
        else
          @bid.update!(section => result[:content])
        end
        redirect_to admin_bid_path(@bid), notice: "#{section.titleize} updated with AI assistance."
      else
        redirect_to admin_bid_path(@bid), alert: "AI edit failed: #{result[:error]}"
      end
    else
      # Direct manual update
      new_content = params[:content]

      if section == "features_list"
        # Parse features from textarea (one per line)
        features = new_content.to_s.split("\n").map(&:strip).reject(&:blank?)
        @bid.update!(features_list: features)
      else
        @bid.update!(section => new_content)
      end

      redirect_to admin_bid_path(@bid), notice: "#{section.titleize} updated."
    end
  rescue => e
    redirect_to admin_bid_path(@bid), alert: "Error updating section: #{e.message}"
  end

  private

  def set_bid
    @bid = Bid.find(params[:id])
  end

  def bid_params
    params.require(:bid).permit(:client_id, :project_id, :title, :status, :hourly_rate, :notes, :internal_notes, :requirements_summary, features_list: [])
  end

  def find_ai_app
    # First try the primary app for this bid, then fall back to any app with an AI key
    app = @bid.apps.first
    return app if app&.has_ai_api_key?

    App.where.not(ai_api_key: nil).first ||
      raise("No app with AI API key configured. Please configure an AI API key in an app's settings.")
  end
end
