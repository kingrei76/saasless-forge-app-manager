class AddPaymentMethodToClients < ActiveRecord::Migration[7.2]
  def change
    add_column :clients, :stripe_default_payment_method_id, :string
    add_column :clients, :collection_method, :string, default: "send_invoice"
  end
end
