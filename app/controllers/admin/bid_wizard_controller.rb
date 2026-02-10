class Admin::BidWizardController < Admin::BaseController
  before_action :set_bid, only: [:show, :update, :regenerate_questions, :regenerate_suggestions, :suggest_costs, :back]

  def new
    @bid = Bid.new(
      status: "draft",
      hourly_rate: Setting[:default_hourly_rate]&.to_f || 60.0,
      title: "New Project Bid",
      wizard_state: { "current_step" => "describe" }
    )
    @clients = Client.order(:name)
    @apps = App.included.includes(:app_assignments).order(:name)
  end

  def create
    @bid = Bid.new(bid_params)
    @bid.status = "draft"
    @bid.ai_generated = true
    @bid.wizard_state = { "current_step" => "describe" }

    if @bid.save
      service = BidWizardService.new(@bid)
      result = service.process_step("describe", wizard_params)

      if result[:success]
        redirect_to admin_bid_wizard_path(@bid)
      else
        flash[:alert] = result[:error]
        redirect_to admin_bid_wizard_path(@bid)
      end
    else
      @clients = Client.order(:name)
      @apps = App.included.includes(:app_assignments).order(:name)
      render :new, status: :unprocessable_entity
    end
  end

  def show
    @step = @bid.current_wizard_step
    @clients = Client.order(:name)

    case @step
    when "describe"
      @apps = App.included.includes(:app_assignments).order(:name)
    when "clarify"
      @questions = @bid.wizard_questions
    when "generate"
      @suggested_items = @bid.suggested_items
    when "costs"
      @existing_costs = @bid.system_cost_line_items
      # Auto-analyze and suggest costs if no costs exist yet
      if @existing_costs.empty?
        service = BidWizardService.new(@bid)
        result = service.suggest_costs
        if result[:success]
          @suggested_costs = result[:costs]
        else
          @suggested_costs = []
          flash.now[:alert] = "SaaSless Agent analysis failed: #{result[:error]}" if result[:error].present?
        end
      end
    when "review"
      @development_items = @bid.development_line_items.order(:position)
      @system_costs = @bid.system_cost_line_items.order(:position)
    when "complete"
      redirect_to admin_bid_path(@bid)
      return
    end

    render "admin/bid_wizard/step_#{@step}"
  end

  def update
    service = BidWizardService.new(@bid)
    @step = @bid.current_wizard_step
    result = service.process_step(@step, wizard_params)

    if result[:success]
      if result[:next_step] == "complete"
        redirect_to admin_bid_path(@bid), notice: "Bid created successfully!"
      else
        redirect_to admin_bid_wizard_path(@bid)
      end
    else
      flash.now[:alert] = result[:error]
      @clients = Client.order(:name)
      @apps = App.included.includes(:app_assignments).order(:name)
      apply_wizard_params_to_bid(@step, wizard_params)
      render "admin/bid_wizard/step_#{@step}", status: :unprocessable_entity
    end
  end

  def regenerate_questions
    service = BidWizardService.new(@bid)
    result = service.regenerate_questions

    if result[:success]
      redirect_to admin_bid_wizard_path(@bid), notice: "Questions regenerated"
    else
      redirect_to admin_bid_wizard_path(@bid), alert: result[:error]
    end
  end

  def regenerate_suggestions
    service = BidWizardService.new(@bid)
    result = service.regenerate_suggestions

    if result[:success]
      redirect_to admin_bid_wizard_path(@bid), notice: "Suggestions regenerated"
    else
      redirect_to admin_bid_wizard_path(@bid), alert: result[:error]
    end
  end

  def suggest_costs
    service = BidWizardService.new(@bid)
    result = service.suggest_costs

    if result[:success]
      render json: { success: true, costs: result[:costs] }
    else
      render json: { success: false, error: result[:error] }, status: :unprocessable_entity
    end
  end

  def back
    service = BidWizardService.new(@bid)
    previous = service.previous_step(@bid.current_wizard_step)

    if previous
      @bid.current_wizard_step = previous
      @bid.save!
    end

    redirect_to admin_bid_wizard_path(@bid)
  end

  private

  def set_bid
    @bid = Bid.find(params[:id])
  end

  def bid_params
    # For new bids, params may not be nested under :bid
    if params[:bid].present?
      params.require(:bid).permit(:title, :client_id, :hourly_rate, :notes)
    else
      params.permit(:title, :client_id, :hourly_rate, :notes).to_h
    end
  end

  def wizard_params
    # Allow dynamic params based on step
    params.permit(
      :project_description, :client_id, :hourly_rate, :title, :notes,
      :requirements_summary, :project_scope,
      items: [:description, :hours, :category, :bid_app_id],
      costs: [:description, :unit_cost, :is_recurring, :billing_frequency, :category, :is_new_system, :system_category],
      app_ids: [],
      new_app_names: [],
      features_list: []
    ).to_h.merge(question_params)
  end

  def question_params
    # Extract question_0, question_1, etc. from params
    question_keys = params.keys.select { |k| k.to_s.match?(/^question_\d+$/) }
    question_keys.each_with_object({}) { |k, h| h[k.to_sym] = params[k] }
  end

  def apply_wizard_params_to_bid(step, params)
    case step
    when "describe"
      @bid.project_description = params[:project_description]
      @bid.title = params[:title] if params[:title].present?
      @bid.hourly_rate = params[:hourly_rate] if params[:hourly_rate].present?
      @bid.client_id = params[:client_id] if params[:client_id].present?
    when "clarify"
      # Load questions for re-render
      @questions = @bid.wizard_questions
    when "generate"
      # Convert items hash to array format expected by the view
      if params[:items].present?
        @suggested_items = params[:items].values.map do |item|
          { "description" => item["description"], "hours" => item["hours"].to_f }
        end
      else
        @suggested_items = @bid.suggested_items
      end
    when "costs"
      # Load existing costs for re-render
      @existing_costs = @bid.system_cost_line_items
    when "review"
      @bid.title = params[:title] if params[:title].present?
      @bid.requirements_summary = params[:requirements_summary] if params[:requirements_summary].present?
      @bid.notes = params[:notes] if params[:notes].present?
      # Load items for re-render
      @development_items = @bid.development_line_items.order(:position)
      @system_costs = @bid.system_cost_line_items.order(:position)
    end
  end
end
