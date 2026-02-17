class RenameModelNameToLlmModelOnAgents < ActiveRecord::Migration[7.2]
  def change
    rename_column :agents, :model_name, :llm_model
  end
end
