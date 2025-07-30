# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Services::ProductCachingService, type: :service do
  let!(:product1) { create(:product) }
  let!(:product2) { create(:product) }
  let(:mock_redis) { instance_double(Redis) }
  let(:cache_store) { Rails.cache }

  before do
    allow(Redis).to receive(:current).and_return(mock_redis)
    allow(mock_redis).to receive(:sadd).and_return(1)
    allow(mock_redis).to receive(:smembers).and_return([])
    allow(mock_redis).to receive(:del).and_return(1)
    cache_store.clear
  end

  describe '.fetch_all' do
    let(:page) { 1 }
    let(:cache_key) { "products:page:#{page}:#{Product.maximum(:updated_at).to_i}" }

    context 'when the cache is empty' do
      it 'fetches products from the database' do
        expect(Product).to receive(:with_details).and_call_original
        described_class.fetch_all(page)
      end

      it 'writes the result to the cache' do
        expect(cache_store).to receive(:write)
        described_class.fetch_all(page)
      end

      it 'adds the cache key to the Redis set' do
        expect(mock_redis).to receive(:sadd).with(described_class::INDEX_KEYS_SET, cache_key)
        described_class.fetch_all(page)
      end
    end

    context 'when the cache is populated' do
      before do
        described_class.fetch_all(page)
      end

      it 'returns data from the cache without hitting the database' do
        expect(Product).not_to receive(:includes)
        described_class.fetch_all(page)
      end
    end

    context 'when Redis is down' do
      before do
        allow(mock_redis).to receive(:sadd).and_raise(Redis::CannotConnectError)
      end

      it 'falls back to the database without raising an error' do
        expect(Product).to receive(:with_details).and_call_original
        expect { described_class.fetch_all(page) }.not_to raise_error
      end
    end
  end

  describe '.fetch_one' do
    context 'when the product exists' do
      it 'fetches from the database and writes to cache if not cached' do
        expect(Product).to receive(:with_details).and_call_original
        described_class.fetch_one(product1.id)
      end

      it 'fetches from the cache if already cached' do
        described_class.fetch_one(product1.id)
        expect(Product).not_to receive(:includes)
        described_class.fetch_one(product1.id)
      end
    end

    context 'when the product does not exist' do
      it 'returns nil' do
        expect(described_class.fetch_one(-1)).to be_nil
      end

      it 'does not interact with the cache' do
        expect(cache_store).not_to receive(:fetch)
        described_class.fetch_one(-1)
      end
    end
  end

  describe '.invalidate_for_product' do
    it 'calls Rails.cache.delete with the product object' do
      expect(cache_store).to receive(:delete).with(product1)
      described_class.invalidate_for_product(product1)
    end
  end

  describe '.invalidate_index_pages' do
    let(:keys) { ['products:page:1:123', 'products:page:2:456'] }

    context 'when there are keys to invalidate' do
      before do
        allow(mock_redis).to receive(:smembers).with(described_class::INDEX_KEYS_SET).and_return(keys)
      end

      it 'deletes multiple keys from the cache' do
        expect(cache_store).to receive(:delete_multi).with(keys)
        described_class.invalidate_index_pages
      end

      it 'deletes the key set from Redis' do
        allow(cache_store).to receive(:delete_multi)
        expect(mock_redis).to receive(:del).with(described_class::INDEX_KEYS_SET)
        described_class.invalidate_index_pages
      end
    end

    context 'when there are no keys to invalidate' do
      it 'does not call delete_multi or del' do
        expect(cache_store).not_to receive(:delete_multi)
        expect(mock_redis).not_to receive(:del)
        described_class.invalidate_index_pages
      end
    end
  end
end
