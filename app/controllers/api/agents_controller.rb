class Api::AgentsController < ApplicationController
  skip_before_action :verify_authenticity_token
  before_action :set_agent, only: [:show, :update, :execute]

  def index
    agents = Agent.order(:name)
    agents = agents.by_status(params[:status]) if params[:status].present?
    agents = agents.by_category(params[:category]) if params[:category].present?

    render json: agents.map { |a| agent_summary(a) }
  end

  def show
    render json: agent_detail(@agent)
  end

  def create
    @agent = Agent.new(agent_params)
    @agent.created_by = current_user

    if @agent.save
      audit!("api_agent_created", @agent)
      render json: agent_detail(@agent), status: :created
    else
      render json: { errors: @agent.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def update
    if @agent.update(agent_params)
      audit!("api_agent_updated", @agent)
      render json: agent_detail(@agent)
    else
      render json: { errors: @agent.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def execute
    unless @agent.status == "active"
      return render json: { error: "Agent must be active to execute" }, status: :unprocessable_entity
    end

    input_data = params[:input_data] || {}
    execution = AgentExecution.create!(
      agent: @agent,
      status: "pending",
      mode: @agent.mode,
      input_data: input_data
    )
    AgentExecutionJob.perform_later(execution.id)

    audit!("api_agent_executed", @agent, { execution_id: execution.id })
    render json: { execution_id: execution.id, status: "pending" }, status: :created
  end

  private

  def set_agent
    @agent = Agent.find(params[:id])
  end

  def agent_params
    permitted = params.require(:agent).permit(
      :name, :slug, :category, :status, :mode, :description,
      :system_prompt, :model_name, :temperature, :max_iterations,
      :ai_model_id, :service_provider_id
    )
    permitted
  end

  def agent_summary(agent)
    {
      id: agent.id,
      name: agent.name,
      slug: agent.slug,
      category: agent.category,
      status: agent.status,
      mode: agent.mode,
      tool_count: agent.agent_tools.count,
      trigger_count: agent.agent_triggers.count,
      goal_count: agent.agent_goals.count
    }
  end

  def agent_detail(agent)
    {
      id: agent.id,
      name: agent.name,
      slug: agent.slug,
      category: agent.category,
      status: agent.status,
      mode: agent.mode,
      description: agent.try(:description),
      system_prompt: agent.try(:system_prompt),
      temperature: agent.try(:temperature),
      max_iterations: agent.try(:max_iterations),
      ai_model_id: agent.ai_model_id,
      ai_model: agent.ai_model&.name,
      created_at: agent.created_at,
      updated_at: agent.updated_at,
      tools: agent.agent_tools.includes(:tool_definition).map { |at|
        {
          id: at.id,
          tool_definition_id: at.tool_definition_id,
          name: at.tool_definition.name,
          slug: at.tool_definition.slug,
          enabled: at.enabled?,
          requires_approval: at.try(:requires_approval),
          position: at.try(:position)
        }
      },
      triggers: agent.agent_triggers.map { |t|
        {
          id: t.id,
          trigger_type: t.trigger_type,
          description: t.try(:description),
          event_name: t.try(:event_name),
          schedule: t.try(:schedule),
          enabled: t.enabled?,
          condition: t.condition,
          last_fired_at: t.last_fired_at
        }
      },
      goals: agent.agent_goals.order(:priority).map { |g|
        {
          id: g.id,
          title: g.title,
          description: g.try(:description),
          status: g.status,
          priority: g.try(:priority)
        }
      },
      handoffs: agent.agent_handoffs.map { |h|
        {
          id: h.id,
          target_agent_id: h.target_agent_id,
          target_agent_name: h.target_agent.name,
          enabled: h.try(:enabled),
          priority: h.try(:priority),
          condition: h.try(:condition)
        }
      }
    }
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
