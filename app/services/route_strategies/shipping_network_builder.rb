module RouteStrategies
  class ShippingNetworkBuilder
    def build_from_sailings(sailings)
      shipping_network = Hash.new { |hash, port| hash[port] = [] }

      sailings.each do |sailing|
        next unless sailing.rate
        shipping_network[sailing.origin_port] << create_route_option(sailing)
      end

      shipping_network
    end

    private

    def create_route_option(sailing)
      raise NotImplementedError, "Subclasses must implement create_route_option"
    end
  end
end
