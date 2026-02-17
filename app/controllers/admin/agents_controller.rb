class Admin::AgentsController < Admin::BaseController
  before_action :set_agent, only: [:show, :edit, :update, :destroy, :activate, :pause, :archive, :duplicate, :toggle_mode, :execute]

  def index
    @agents = Agent.includes(:service_provider, :created_by)
    @agents = @agents.by_status(params[:status]) if params[:status].present?
    @agents = @agents.by_category(params[:category]) if params[:category].present?
    @agents = @agents.by_mode(params[:mode]) if params[:mode].present?
    @agents = @agents.where("agents.name ILIKE ?", "%#{params[:search]}%") if params[:search].present?
    @agents = @agents.order(:name)

    @stats = {
      total: Agent.count,
      active: Agent.active.count,
      executions_today: AgentExecution.today.count,
      open_alerts: AgentAlert.open_alerts.count
    }
  end

  def show
    @agent_tools = @agent.agent_tools.includes(:tool_definition).ordered
    @handoffs = @agent.agent_handoffs.includes(:target_agent).ordered
    @goals = @agent.agent_goals.ordered
    @triggers = @agent.agent_triggers.includes(:depends_on_agent, :tool_definition)
    @executions = @agent.agent_executions.recent.limit(20)
    @memories = @agent.agent_memories.recent.limit(20)
    @versions = @agent.agent_versions.ordered
    @alerts = @agent.agent_alerts.recent.limit(10)
    @available_tools = ToolDefinition.active.where.not(id: @agent.tool_definitions.select(:id)).order(:name)
    @available_agents = Agent.where.not(id: @agent.id).order(:name)
  end

  def new
    @agent = Agent.new
    @service_providers = ServiceProvider.active.where(category: "llm").order(:name)
  end

  def create
    @agent = Agent.new(agent_params)
    @agent.created_by = current_user

    if @agent.save
      AgentVersionService.snapshot!(@agent, current_user, "Initial creation")
      AuditLogger.log(user: current_user, action: "agent.create", auditable: @agent)
      redirect_to admin_agent_path(@agent), notice: "Agent created."
    else
      @service_providers = ServiceProvider.active.where(category: "llm").order(:name)
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @service_providers = ServiceProvider.active.where(category: "llm").order(:name)
  end

  def update
    changes = @agent.changes
    if @agent.update(agent_params)
      AgentVersionService.snapshot!(@agent, current_user, params[:change_summary])
      AuditLogger.log(user: current_user, action: "agent.update", auditable: @agent, changes_data: changes)
      redirect_to admin_agent_path(@agent), notice: "Agent updated."
    else
      @service_providers = ServiceProvider.active.where(category: "llm").order(:name)
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    AuditLogger.log(user: current_user, action: "agent.destroy", auditable: @agent)
    @agent.destroy
    redirect_to admin_agents_path, notice: "Agent deleted."
  end

  def activate
    @agent.activate!
    AuditLogger.log(user: current_user, action: "agent.activate", auditable: @agent)
    redirect_to admin_agent_path(@agent), notice: "Agent activated."
  end

  def pause
    @agent.pause!
    AuditLogger.log(user: current_user, action: "agent.pause", auditable: @agent)
    redirect_to admin_agent_path(@agent), notice: "Agent paused."
  end

  def archive
    @agent.archive!
    AuditLogger.log(user: current_user, action: "agent.archive", auditable: @agent)
    redirect_to admin_agent_path(@agent), notice: "Agent archived."
  end

  def toggle_mode
    old_mode = @agent.mode
    @agent.toggle_mode!
    AuditLogger.log(user: current_user, action: "agent.toggle_mode", auditable: @agent, changes_data: { mode: [old_mode, @agent.mode] })
    redirect_to admin_agent_path(@agent), notice: "Agent switched to #{@agent.mode} mode."
  end

  def duplicate
    new_agent = @agent.dup
    new_agent.name = "#{@agent.name} (Copy)"
    new_agent.slug = "#{@agent.slug}-copy-#{SecureRandom.hex(3)}"
    new_agent.status = "draft"
    new_agent.created_by = current_user

    if new_agent.save
      @agent.agent_tools.each do |at|
        new_agent.agent_tools.create(at.attributes.except("id", "agent_id", "created_at", "updated_at"))
      end
      redirect_to admin_agent_path(new_agent), notice: "Agent duplicated."
    else
      redirect_to admin_agent_path(@agent), alert: "Failed to duplicate agent."
    end
  end

  def execute
    execution = AgentExecution.create!(
      agent: @agent,
      status: "pending",
      mode: @agent.mode,
      input_data: params[:input_data].present? ? JSON.parse(params[:input_data]) : {}
    )
    AgentExecutionJob.perform_later(execution.id)
    redirect_to admin_agent_execution_path(execution), notice: "Execution started."
  rescue JSON::ParserError
    redirect_to admin_agent_path(@agent), alert: "Invalid input JSON."
  end

  private

  def set_agent
    @agent = Agent.find(params[:id])
  end

  def agent_params
    params.require(:agent).permit(
      :name, :slug, :description, :system_prompt, :category, :status, :mode,
      :max_iterations, :temperature, :llm_model, :service_provider_id, :ai_model_id
    )
  end
end
