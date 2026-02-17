class AgentAlertCheckJob < ApplicationJob
  queue_as :default

  def perform
    check_stalled_executions
    check_service_health
  end

  private

  def check_stalled_executions
    # Flag executions running longer than 30 minutes
    stalled = AgentExecution.where(status: "running")
      .where("started_at < ?", 30.minutes.ago)

    stalled.each do |exec|
      next if AgentAlert.exists?(agent_execution: exec, alert_type: "timeout", status: %w[open acknowledged])

      exec.update!(status: "timed_out", completed_at: Time.current, error_message: "Execution timed out after 30 minutes")

      AgentAlert.create!(
        agent: exec.agent,
        agent_execution: exec,
        alert_type: "timeout",
        severity: "warning",
        title: "Execution timed out: #{exec.agent.name}",
        description: "Execution ##{exec.id} was running for over 30 minutes and has been timed out."
      )
    end
  end

  def check_service_health
    client = LanggraphClient.new
    result = client.health_check

    if result.is_a?(Hash) && result["status"] == "error"
      # Only create alert if there isn't an open one already
      unless AgentAlert.exists?(alert_type: "error", title: "LangGraph service unhealthy", status: %w[open acknowledged])
        AgentAlert.create!(
          alert_type: "error",
          severity: "critical",
          title: "LangGraph service unhealthy",
          description: "Health check failed: #{result['message']}"
        )
      end
    end
  rescue => e
    Rails.logger.error("AgentAlertCheckJob: Health check failed - #{e.message}")
  end
end
