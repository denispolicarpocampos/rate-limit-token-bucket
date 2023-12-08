module Api
  module V1
    class ChecksController < ApplicationController
      def limited
        render json: { message: 'limited' }
      end

      def unlimited
        render json: { message: 'unlimited' }
      end
    end
  end
end
