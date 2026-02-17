class Admin::AiModelsController < Admin::BaseController
  before_action :set_ai_model, only: [:update, :destroy]

  def create
    @ai_model = AiModel.new(ai_model_params)

    if @ai_model.save
      redirect_to admin_infrastructure_path(tab: "ai_models"), notice: "Model added."
    else
      redirect_to admin_infrastructure_path(tab: "ai_models"), alert: @ai_model.errors.full_messages.join(", ")
    end
  end

  def update
    if @ai_model.update(ai_model_params)
      redirect_to admin_infrastructure_path(tab: "ai_models"), notice: "Model updated."
    else
      redirect_to admin_infrastructure_path(tab: "ai_models"), alert: @ai_model.errors.full_messages.join(", ")
    end
  end

  def destroy
    @ai_model.destroy
    redirect_to admin_infrastructure_path(tab: "ai_models"), notice: "Model removed."
  end

  private

  def set_ai_model
    @ai_model = AiModel.find(params[:id])
  end

  def ai_model_params
    params.require(:ai_model).permit(
      :service_provider_id, :name, :model_id, :category, :context_window,
      :max_output_tokens, :input_price_per_million, :output_price_per_million,
      :status, :sort_order
    )
  end
end
