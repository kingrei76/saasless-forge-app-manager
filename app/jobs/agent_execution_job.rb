class AgentExecutionJob < ApplicationJob
  queue_as :default

  def perform(execution_id)
    execution = AgentExecution.find(execution_id)
    agent = execution.agent

    return if execution.status.in?(%w[cancelled completed failed])

    execution.update!(status: "running", started_at: Time.current)

    client = LanggraphClient.new
    payload = client.send(:build_execution_payload, agent, execution, execution.input_data)

    client.send(:post, "/agents/execute", payload)
  rescue LanggraphClient::ServiceError => e
    execution.update!(
      status: "failed",
      error_message: e.message,
      completed_at: Time.current
    )

    AgentAlert.create!(
      agent: execution.agent,
      agent_execution: execution,
      alert_type: "error",
      severity: "error",
      title: "Execution failed to start",
      description: e.message
    )
  rescue => e
    execution.update!(
      status: "failed",
      error_message: "Internal error: #{e.message}",
      completed_at: Time.current
    )
    raise
  end
end
