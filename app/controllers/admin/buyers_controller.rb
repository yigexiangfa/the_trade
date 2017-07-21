class Admin::BuyersController < Admin::TheTradeController

  def index
    q_params = params.fetch(:q, {}).permit!.reverse_merge('overdue_date-lte': Date.today, payment_status: ['unpaid', 'part_paid'], state: 'active')

    @orders = Order.unscoped.includes(:buyer, :payment_strategy, :charger).select('SUM(`orders`.`amount`) as sum_amount, count(`orders`.`id`) as count_id, `orders`.`buyer_type`, `orders`.`buyer_id`, `orders`.`charger_id`, `orders`.`overdue_date`, `orders`.`payment_strategy_id`')
      .group(:buyer_type, :buyer_id)
      .default_where(q_params)
      .order(overdue_date: :asc)
      .page(params[:page])
  end


  def orders
    @orders = Order.where(buyer_type: params[:buyer_type], buyer_id: params[:buyer_id], payment_status: ['unpaid', 'part_paid']).order(overdue_date: :asc).page(params[:page])
    payment_method_ids = PaymentReference.where(buyer_type: params[:buyer_type], buyer_id: params[:buyer_id]).pluck(:payment_method_id)
    @payments = Payment.where(payment_method_id: payment_method_ids, state: ['init', 'part_checked'])
  end

  def new
    @order = Order.new
  end

  def edit
  end

  def create
    @order = Order.new(order_params)

    if @order.save
      redirect_to @order, notice: 'Order was successfully created.'
    else
      render :new
    end
  end

  def update
    if @order.update(order_params)
      redirect_to @order, notice: 'Order was successfully updated.'
    else
      render :edit
    end
  end

  def destroy
    @order.destroy
    redirect_to orders_url, notice: 'Order was successfully destroyed.'
  end

  private

  def order_params
    params.fetch(:order, {})
  end

end