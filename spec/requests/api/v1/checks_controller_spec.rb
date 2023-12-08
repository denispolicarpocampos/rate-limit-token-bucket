# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Checks API', type: :request do
  describe 'GET /api/v1/limited' do
    before do
      get api_v1_limited_path
      puts response.body
    end

    it 'returns a successful response' do
      expect(response).to have_http_status(:success)
    end
  end

  describe 'GET /api/v1/unlimited' do
    before do
      get api_v1_unlimited_path
      puts response.body
    end

    it 'returns a successful response' do
      expect(response).to have_http_status(:success)
    end
  end
end
