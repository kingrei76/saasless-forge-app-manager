class Admin::InvoiceLineItemsController < Admin::BaseController
  before_action :require_admin!
  before_action :set_invoice
  before_action :set_line_item, only: [:edit, :update, :destroy]

  def index
    @line_items = @invoice.line_items.includes(:app)
  end

  def new
    @line_item = @invoice.line_items.build
    @apps = App.included.order(:name)
  end

  def create
    @line_item = @invoice.line_items.build(line_item_params)

    if @line_item.save
      @invoice.recalculate_totals!
      redirect_to admin_invoice_path(@invoice), notice: "Line item added."
    else
      @apps = App.included.order(:name)
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @apps = App.included.order(:name)
  end

  def update
    if @line_item.update(line_item_params)
      @invoice.recalculate_totals!
      redirect_to admin_invoice_path(@invoice), notice: "Line item updated."
    else
      @apps = App.included.order(:name)
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @line_item.destroy
    @invoice.recalculate_totals!
    redirect_to admin_invoice_path(@invoice), notice: "Line item removed."
  end

  private

  def set_invoice
    @invoice = Invoice.find(params[:invoice_id])
  end

  def set_line_item
    @line_item = @invoice.line_items.find(params[:id])
  end

  def line_item_params
    params.require(:invoice_line_item).permit(:app_id, :description, :internal_cost, :markup_percentage, :amount)
  end
end
