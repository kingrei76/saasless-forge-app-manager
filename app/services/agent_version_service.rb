class AgentVersionService
  def self.snapshot!(agent, user = nil, change_summary = nil)
    version_number = (agent.agent_versions.maximum(:version_number) || 0) + 1

    agent.agent_versions.create!(
      version_number: version_number,
      system_prompt: agent.system_prompt,
      config_snapshot: {
        name: agent.name,
        slug: agent.slug,
        category: agent.category,
        llm_model: agent.llm_model,
        temperature: agent.temperature,
        max_iterations: agent.max_iterations,
        mode: agent.mode,
        config: agent.config,
        memory_config: agent.memory_config,
        tools: agent.agent_tools.includes(:tool_definition).map { |at|
          { tool: at.tool_definition.slug, enabled: at.enabled, requires_approval: at.requires_approval }
        }
      },
      change_summary: change_summary,
      created_by: user
    )

    agent.update_column(:version, version_number)
  end

  def self.snapshot_tool!(tool, user = nil, change_summary = nil)
    version_number = (tool.tool_versions.maximum(:version_number) || 0) + 1

    tool.tool_versions.create!(
      version_number: version_number,
      description: tool.description,
      input_schema: tool.input_schema,
      config_snapshot: {
        name: tool.name,
        slug: tool.slug,
        category: tool.category,
        handler_class: tool.handler_class,
        risk_level: tool.risk_level,
        status: tool.status,
        config: tool.config
      },
      change_summary: change_summary,
      created_by: user
    )

    tool.update_column(:version, version_number)
  end

  def self.restore_agent!(agent, version_number, user = nil)
    version = agent.agent_versions.find_by!(version_number: version_number)
    snapshot = version.config_snapshot

    agent.update!(
      system_prompt: version.system_prompt,
      llm_model: snapshot["llm_model"],
      temperature: snapshot["temperature"],
      max_iterations: snapshot["max_iterations"],
      config: snapshot["config"] || {},
      memory_config: snapshot["memory_config"] || {}
    )

    snapshot!(agent, user, "Restored from version #{version_number}")
  end
end
