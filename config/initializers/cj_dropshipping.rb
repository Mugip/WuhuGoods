# frozen_string_literal: true

module CjDropshipping
  mattr_accessor :email, :api_key, :api_base, :timeout, :open_timeout, :markup_percent

  self.email        = ENV['CJ_EMAIL'] || Rails.application.credentials.dig(Rails.env.to_sym, :cj, :email)
  self.api_key      = ENV['CJ_API_KEY'] || Rails.application.credentials.dig(Rails.env.to_sym, :cj, :api_key)
  self.api_base     = ENV['CJ_API_BASE'] || Rails.application.credentials.dig(Rails.env.to_sym, :cj, :api_base) || "https://developers.cjdropshipping.com/api2.0/v1"
  self.timeout      = 10
  self.open_timeout = 5
  self.markup_percent = 25
end
