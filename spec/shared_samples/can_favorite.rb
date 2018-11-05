# frozen_string_literal: true

require "rails_helper"

RSpec.shared_examples_for "can_favorite" do
  let(:owner) { create(described_class.to_s.underscore.to_sym) }
  let(:post) { create(:post) }
  let(:other_user) { create(:user) }

  context "favorite" do
    it "should be done" do
      expect(Inkwell::Favorite.count).to eq(0)
      expect(post.favorited_count).to eq(0)
      expect(owner.favorites_count).to eq(0)
      expect(owner.favorite(post)).to eq(true)
      expect(Inkwell::Favorite.count).to eq(1)
      expect(post.favorited_count).to eq(1)
      expect(owner.favorites_count).to eq(1)
      favorite = Inkwell::Favorite.first
      { favorite_subject: owner, favorite_object: post }.each do |k, v|
        expect(favorite.public_send(k)).to eq(v)
      end
    end

    it "should be done when already favorited" do
      create(
        :inkwell_favorite,
        favorite_subject: owner,
        favorite_object: post)
      expect(owner.favorite(post)).to eq(true)
      expect(Inkwell::Favorite.count).to eq(1)
    end

    it "should not be done when object is not favoritable" do
      expect { owner.favorite(nil) }
        .to raise_error(Inkwell::Errors::NotFavoritable)
      expect(Inkwell::Favorite.count).to eq(0)
    end
  end

  context "unfavorite" do
    it "should be done" do
      create(:inkwell_favorite, favorite_subject: owner, favorite_object: post)
      create(:inkwell_object_counter_cache, cached_object: post)
      expect(post.favorited_count).to eq(1)
      expect(owner.favorites_count).to eq(1)
      expect(owner.unfavorite(post)).to eq(true)
      expect(Inkwell::Favorite.count).to eq(0)
      expect(owner.reload.favorites_count).to eq(0)
      expect(post.reload.favorited_count).to eq(0)
    end

    it "should be done when object is not favorited" do
      expect(owner.unfavorite(post)).to eq(true)
      expect(Inkwell::Favorite.count).to eq(0)
    end

    it "should not be done when object is not favoritable" do
      expect { owner.unfavorite(nil) }
        .to raise_error(Inkwell::Errors::NotFavoritable)
      expect(Inkwell::Favorite.count).to eq(0)
    end
  end

  context "favorite?" do
    it "should be true" do
      create(:inkwell_favorite, favorite_subject: owner, favorite_object: post)
      expect(owner.favorite?(post)).to eq(true)
    end

    it "should be false" do
      expect(owner.favorite?(post)).to eq(false)
    end

    it "should not be done when object is not favoritable" do
      expect { owner.favorite?(nil) }
        .to raise_error(Inkwell::Errors::NotFavoritable)
    end
  end

  context "favorites" do
    before :each do
      base_date = Date.yesterday
      30.times do |i|
        create(
          :inkwell_favorite,
          favorite_subject: owner,
          favorite_object: create(%i{post comment}.sample),
          created_at: base_date + i.minutes)
      end
    end

    it "should work" do
      result = owner.favorites do |relation|
        relation.page(1).order("created_at DESC")
      end
      expect(result.size).to eq(25)
      expect(result.map(&:favorited_count).uniq).to eq([1])
      expect(result.map { |item| item.class.to_s }.uniq.sort)
        .to eq(%w{Comment Post})
      expect(result.first).to eq(Inkwell::Favorite.last.favorite_object)
    end

    it "should work for viewer" do
      favorited = [Post.last, Comment.last]
      favorited.each do |obj|
        other_user.favorite(obj)
      end
      result = owner.favorites(for_viewer: other_user) do |relation|
        relation.page(1).order("created_at DESC")
      end
      expect(result.size).to eq(25)
      expect((result & favorited).size).to eq(2)
      result.each do |item|
        expect(item.favorited_in_timeline).to eq(item.in?(favorited))
      end
    end

    it "should work without block" do
      result = owner.favorites
      expect(result.size).to eq(30)
    end
  end

  context "favorites_count" do
    it "should work" do
      create(:inkwell_favorite, favorite_subject: owner, favorite_object: post)
      create(
        :inkwell_favorite,
        favorite_subject: owner,
        favorite_object: create(:post))
      expect(owner.reload.favorites_count).to eq(2)
    end

    it "should work without cache" do
      create(:inkwell_favorite, favorite_subject: owner, favorite_object: post)
      Inkwell::SubjectCounterCache.delete_all
      expect(owner.reload.favorites_count).to eq(1)
    end
  end

  context "on destroy" do
    before :each do
      owner.favorite(post)
    end

    it "should remove subject counter cache" do
      expect(owner.inkwell_subject_counter_cache.present?).to eq(true)
      owner.destroy
      expect(Inkwell::SubjectCounterCache.count).to eq(0)
    end

    it "should remove favorites" do
      expect(owner.favorites.count).to eq(1)
      owner.destroy
      expect(Inkwell::Favorite.count).to eq(0)
    end

    it "should correctly process favoriting object counters" do
      comment = create(:comment)
      owner.favorite(comment)
      object_counter = post.inkwell_object_counter_cache
      object_counter_1 = comment.inkwell_object_counter_cache
      expect(object_counter.favorite_count).to eq(1)
      expect(object_counter_1.favorite_count).to eq(1)
      owner.destroy
      expect(object_counter.reload.favorite_count).to eq(0)
      expect(object_counter_1.reload.favorite_count).to eq(0)
    end
  end
end
