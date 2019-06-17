module RailsTrade::Order
  extend ActiveSupport::Concern
  included do
    include RailsTrade::Ordering::Payment
    include RailsTrade::Ordering::Refund
    include RailsTrade::Ordering::Base
  
    attribute :payment_status, :string, default: 'unpaid'
    attribute :adjust_amount, :decimal, default: 0
    attribute :expire_at, :datetime
    attribute :extra, :json, default: {}
    attribute :currency, :string, default: RailsTrade.config.default_currency
    
    belongs_to :user, optional: true
    belongs_to :buyer, polymorphic: true, optional: true
    belongs_to :cart, optional: true
    belongs_to :payment_strategy, optional: true
    has_many :payment_orders, dependent: :destroy
    has_many :payments, through: :payment_orders, inverse_of: :orders
    has_many :order_items, dependent: :destroy, autosave: true, inverse_of: :order
    has_many :refunds, dependent: :nullify, inverse_of: :order
    has_many :order_promotes, autosave: true, inverse_of: :order
    has_many :pure_order_promotes, -> { where(order_item_id: nil) }, class_name: 'OrderPromote'
  
    accepts_nested_attributes_for :order_items
    accepts_nested_attributes_for :order_promotes
  
    scope :credited, -> { where(payment_strategy_id: PaymentStrategy.where.not(period: 0).pluck(:id)) }
    scope :to_pay, -> { where(payment_status: ['unpaid', 'part_paid']) }
  
    before_validation do
      self.uuid ||= UidHelper.nsec_uuid('OD')
      self.expire_at ||= Time.now + RailsTrade.config.expire_after
      self.payment_strategy_id ||= self.cart.payment_strategy_id if cart
    end
  
    after_create_commit :confirm_ordered!
  
    enum payment_status: {
      unpaid: 'unpaid',
      part_paid: 'part_paid',
      all_paid: 'all_paid',
      refunding: 'refunding',
      refunded: 'refunded',
      denied: 'denied'
    }
  end
  
  def subject
    order_items.map { |oi| oi.good&.name || 'Goods' }.join(', ')
  end
  
  def user_name
    user&.name.presence || '当前用户'
  end

  def migrate_from_cart_item(cart_item_id)
    cart_item = CartItem.find cart_item_id
    self.buyer = cart_item.buyer
    oi = self.order_items.build(cart_item_id: cart_item_id)
    oi.init_from_cart_item

    cart_item.total_serve_charges.each do |serve_charge|
      self.order_serves.build(serve_charge_id: serve_charge.id, serve_id: serve_charge.serve_id, amount: serve_charge.subtotal)
    end

    compute_sum
  end

  def migrate_from_cart_items(cart_item_id = nil)
    cart_items = buyer.cart_items.checked.default_where(myself: self.myself)

    cart_items.each do |cart_item|
      oi = self.order_items.build cart_item_id: cart_item.id
      oi.init_from_cart_item
    end

    summary = CartService.new(buyer_type: self.buyer_type, buyer_id: self.buyer_id, cart_item_id: cart_item_id, myself: self.myself, extra: self.extra)

    summary.promote_charges.each do |promote_charge|
      self.order_promotes.build(promote_charge_id: promote_charge.id, promote_id: promote_charge.promote_id, amount: promote_charge.subtotal)
    end

    summary.serve_charges.each do |serve_charge|
      self.order_serves.build(serve_charge_id: serve_charge.id, serve_id: serve_charge.serve_id, amount: serve_charge.subtotal)
    end
    compute_sum
  end

  def compute_sum
    _pure_order_promotes = self.order_promotes.select { |i| i.order_item_id.nil? }

    self.pure_promote_sum = _pure_order_promotes.sum(&:amount).to_d
    self.subtotal = self.order_items.sum(&:amount)
    self.amount = self.subtotal.to_d + self.pure_promote_sum.to_d
  end

  def confirm_ordered!
    self.order_items.each(&:confirm_ordered!)
  end

  def compute_received_amount
    _received_amount = self.payment_orders.where(state: :confirmed).sum(:check_amount)
    _refund_amount = self.refunds.where.not(state: :failed).sum(:total_amount)
    _received_amount - _refund_amount
  end

end
