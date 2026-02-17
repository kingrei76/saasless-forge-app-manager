class AgentObservabilityService
  def overview_stats
    {
      total_agents: Agent.count,
      active_agents: Agent.active.count,
      total_executions: AgentExecution.count,
      executions_today: AgentExecution.today.count,
      executions_this_week: AgentExecution.where("created_at >= ?", 1.week.ago).count,
      success_rate: calculate_success_rate,
      avg_duration: calculate_avg_duration,
      open_alerts: AgentAlert.open_alerts.count,
      total_tokens_today: AgentExecution.today.sum(:total_tokens),
      total_cost_today: AgentExecution.today.sum(:total_cost)
    }
  end

  def executions_by_status
    AgentExecution.group(:status).count
  end

  def executions_by_agent(limit: 10)
    AgentExecution.joins(:agent)
      .group("agents.name")
      .order("count_all desc")
      .limit(limit)
      .count
  end

  def daily_executions(days: 30)
    AgentExecution.where("agent_executions.created_at >= ?", days.days.ago)
      .group("DATE(agent_executions.created_at)")
      .count
      .transform_keys(&:to_s)
  end

  def cost_by_agent(days: 30)
    AgentExecution.joins(:agent)
      .where("agent_executions.created_at >= ?", days.days.ago)
      .group("agents.name")
      .sum(:total_cost)
  end

  def cost_by_day(days: 30)
    AgentExecution.where("agent_executions.created_at >= ?", days.days.ago)
      .group("DATE(agent_executions.created_at)")
      .sum(:total_cost)
      .transform_keys(&:to_s)
  end

  def tokens_by_day(days: 30)
    AgentExecution.where("agent_executions.created_at >= ?", days.days.ago)
      .group("DATE(agent_executions.created_at)")
      .sum(:total_tokens)
      .transform_keys(&:to_s)
  end

  def tool_usage_stats(days: 30)
    AgentExecutionStep.where("agent_execution_steps.created_at >= ?", days.days.ago)
      .where(step_type: "tool_call")
      .joins(:tool_definition)
      .group("tool_definitions.name")
      .select(
        "tool_definitions.name",
        "COUNT(*) as usage_count",
        "COUNT(CASE WHEN agent_execution_steps.status = 'failed' THEN 1 END) as error_count",
        "AVG(agent_execution_steps.duration_ms) as avg_duration_ms"
      )
  end

  def active_executions
    AgentExecution.where(status: %w[pending running awaiting_approval])
      .includes(:agent)
      .order(created_at: :desc)
  end

  def recent_alerts(limit: 20)
    AgentAlert.includes(:agent, :agent_execution)
      .recent
      .limit(limit)
  end

  private

  def calculate_success_rate
    total = AgentExecution.where("agent_executions.created_at >= ?", 30.days.ago).count
    return 0 if total.zero?
    completed = AgentExecution.where("agent_executions.created_at >= ?", 30.days.ago).completed.count
    ((completed.to_f / total) * 100).round(1)
  end

  def calculate_avg_duration
    avg = AgentExecution.completed
      .where("agent_executions.created_at >= ?", 30.days.ago)
      .where.not(started_at: nil)
      .average("EXTRACT(EPOCH FROM (completed_at - started_at))")
    avg&.round(1) || 0
  end
end
