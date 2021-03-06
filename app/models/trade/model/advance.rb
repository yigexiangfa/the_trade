module Trade
  module Model::Advance
    extend ActiveSupport::Concern

    included do
      attribute :amount, :decimal
      attribute :price, :decimal
      attribute :apple_product_id, :string, comment: 'For 苹果应用内支付'

      belongs_to :card_template

      validates :amount, uniqueness: { scope: :card_template_id }
      validates :price, uniqueness: { scope: :card_template_id }

      has_one_attached :logo
    end

    def name
      "#{card_template.name}-#{amount}"
    end

    def order_paid(trade_item)
      if trade_item.respond_to?(:maintain) && trade_item.maintain
        card = card_template.cards.find_or_initialize_by(client_type: trade_item.maintain.client_type, client_id: trade_item.maintain.client_id)
        card.agency_id = trade_item.maintain.agency_id
      else
        card = card_template.cards.find_or_initialize_by(user_id: trade_item.user_id)
      end
      ca = card.card_advances.build
      ca.trade_item = trade_item
      ca.amount = amount

      card.class.transaction do
        card.save!
        ca.save!
        trade_item.maintain.transfer! if trade_item.respond_to?(:maintain) && trade_item.maintain
      end

      card
    end

  end
end
