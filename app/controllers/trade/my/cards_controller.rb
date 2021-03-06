module Trade
  class My::CardsController < My::BaseController
    before_action :set_card, only: [:show, :edit, :update, :destroy]

    def index
      q_params = {}
      q_params.merge! default_params
      q_params.merge! params.permit(:card_uuid, :card_template_id)

      @cards = current_user.cards.includes(:card_template).default_where(q_params).order(id: :desc).page(params[:page])
      @card_templates = CardTemplate.default_where(default_params).where.not(id: @cards.pluck(:card_template_id))
    end

    def new
      @card = current_user.cards.find_or_initialize_by(card_template_id: params[:card_template_id])
    end

    def token
      @card_prepayment = CardPrepayment.find_by token: params[:token]
      @card = current_user.cards.find_or_initialize_by(card_template_id: @card_prepayment.card_template_id)
      @card.card_advances.build(amount: @card_prepayment.amount)
    end

    def create
      if token_params[:token]
        @card_prepayment = CardPrepayment.find_by token: token_params[:token]
        @card = current_user.cards.find_or_initialize_by(card_template_id: @card_prepayment.card_template_id)
      else
        @card = Card.new(card_params)
      end
      @card.assign_attributes card_params

      unless @card.save
        render :new, locals: { model: @card }, status: :unprocessable_entity
      end
    end

    def show
    end

    def edit
    end

    def update
      @card.assign_attributes(card_params)

      unless @card.save
        render :edit, locals: { model: @card }, status: :unprocessable_entity
      end
    end

    def destroy
      @card.destroy
    end

    private
    def set_card
      @card = Card.find(params[:id])
    end

    def token_params
      params.fetch(:card, {}).permit(:token)
    end

    def card_params
      params.fetch(:card, {}).permit(
        :type,
        :card_uuid,
        :effect_at,
        :expire_at,
        :amount,
        :income_amount,
        card_advances_attributes: [:amount]
      )
    end

  end
end
