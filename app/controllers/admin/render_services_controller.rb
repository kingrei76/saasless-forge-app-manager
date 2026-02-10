class Admin::RenderServicesController < Admin::BaseController
  before_action :set_render_service, only: [:link, :unlink]

  def link
    if params[:app_id].blank?
      redirect_to admin_infrastructure_path(tab: "render_services"), alert: "Please select an app to link."
      return
    end

    @app = App.find(params[:app_id])
    @render_service.update!(app: @app)

    respond_to do |format|
      format.turbo_stream { render turbo_stream: turbo_stream.replace(@render_service, partial: "admin/render_services/service_row", locals: { service: @render_service, apps: App.order(:name) }) }
      format.html { redirect_to admin_infrastructure_path(tab: "render_services"), notice: "#{@render_service.name} linked to #{@app.name}." }
    end
  end

  def unlink
    app_name = @render_service.app&.name
    @render_service.update!(app: nil)

    respond_to do |format|
      format.turbo_stream { render turbo_stream: turbo_stream.replace(dom_id(@render_service), partial: "admin/render_services/service_row", locals: { service: @render_service, apps: App.order(:name) }) }
      format.html do
        redirect_path = params[:redirect_to].presence || admin_infrastructure_path(tab: "render_services")
        redirect_to redirect_path, notice: "#{@render_service.name} unlinked from #{app_name}."
      end
    end
  end

  private

  def set_render_service
    @render_service = RenderService.find(params[:id])
  end
end
