class Admin::AgentMemoriesController < Admin::BaseController
  before_action :set_agent

  def index
    @memories = @agent.agent_memories.recent
    @memories = @memories.by_type(params[:type]) if params[:type].present?
  end

  def destroy
    memory = @agent.agent_memories.find(params[:id])
    memory.destroy
    redirect_to admin_agent_path(@agent, anchor: "memory"), notice: "Memory deleted."
  end

  def purge_expired
    count = @agent.agent_memories.expired.destroy_all.count
    redirect_to admin_agent_path(@agent, anchor: "memory"), notice: "Purged #{count} expired memories."
  end

  private

  def set_agent
    @agent = Agent.find(params[:agent_id])
  end
end
