class Admin::BidLineItemsController < Admin::BaseController
  before_action :set_bid
  before_action :set_line_item, only: [:edit, :update, :destroy]

  def new
    @line_item = @bid.line_items.build(
      rate: @bid.hourly_rate,
      position: (@bid.line_items.maximum(:position) || 0) + 1
    )
  end

  def create
    @line_item = @bid.line_items.build(line_item_params)

    if @line_item.save
      @bid.recalculate_total!
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to admin_bid_path(@bid), notice: "Line item added." }
      end
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit; end

  def update
    if @line_item.update(line_item_params)
      @bid.recalculate_total!
      redirect_to admin_bid_path(@bid), notice: "Line item updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @line_item.destroy
    @bid.recalculate_total!

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to admin_bid_path(@bid), notice: "Line item removed." }
    end
  end

  private

  def set_bid
    @bid = Bid.find(params[:bid_id])
  end

  def set_line_item
    @line_item = @bid.line_items.find(params[:id])
  end

  def line_item_params
    params.require(:bid_line_item).permit(
      :description, :hours, :rate, :position, :work_category,
      :unit_cost, :is_recurring, :billing_frequency, :is_new_system, :system_category, :line_item_type
    )
  end
end
