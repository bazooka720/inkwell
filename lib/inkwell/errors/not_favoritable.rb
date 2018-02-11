# frozen_string_literal: true

module Inkwell
  module Errors
    class NotFavoritable < StandardError
      def initialize(object)
        @object = object
      end

      def message
        # move to <<~ when ruby supported version starts 2.3 or upper version
        <<-MESSAGE
#{@object.class} cannot be favorited.
include Inkwell::CanBeFavorited to #{@object.class} if this object should be favorited.
        MESSAGE
      end
    end
  end
end
