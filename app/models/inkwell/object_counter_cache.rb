# frozen_string_literal: true

module Inkwell
  class ObjectCounterCache < ApplicationRecord
    belongs_to :cached_object, polymorphic: true
    before_create :fill_counters

    private

      def fill_counters
        self.favorite_count =
          cached_object.try(:inkwell_favorited).try(:count) || 0
        self.reblog_count =
          cached_object.try(:inkwell_reblogged).try(:count) || 0
      end
  end
end
