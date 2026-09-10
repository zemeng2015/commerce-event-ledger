# frozen_string_literal: true

module Orders
  class OrderProjection < Record
    self.table_name = "order_projections"
  end
end
