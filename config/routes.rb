Rails.application.routes.draw do
  namespace :admin do

    resources :goods do
      get 'pic' => :edit_pic, :on => :member
      patch 'pic' => :update_pic, :on => :member
      get 'items' => :edit_items, :on => :member
      patch 'items' => :update_items, :on => :member
      get 'taxons' => :edit_taxons, :on => :member
      patch 'taxons' => :update_taxons, :on => :member
      get 'promote' => :edit_promote, :on => :member
      patch 'promote' => :update_promote, :on => :member
      resources :good_items
      resources :sales
    end


    resources :users, :only => [:index, :show, :destroy]
    resources :invites
    resources :races do
      resources :crowds, :shallow => true
    end
    resources :taxons
    resources :promotes
    resources :providers
    resources :produces
    resources :orders, :only => [:index, :show, :edit, :update, :destroy]
    resources :carts, :only => [:index, :destroy]
    resources :areas

  end
end
