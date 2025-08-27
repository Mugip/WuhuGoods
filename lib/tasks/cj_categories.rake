# lib/tasks/cj_categories.rake
namespace :cj do
  desc "Fetch all CJ categories and save to tmp/cj_categories.json"
  task fetch_categories: :environment do
    require 'json'
    require 'fileutils'
    require 'net/http'
    require 'uri'

    debug = ENV["DEBUG"] == "true"
    tmp_file = Rails.root.join("tmp/cj_categories.json")
    FileUtils.mkdir_p(Rails.root.join("tmp"))

    api_key = ENV["CJ_API_KEY"]
    email   = ENV["CJ_EMAIL"]
    base_url = ENV["CJ_API_BASE"] || "https://developers.cjdropshipping.com/api2.0/v1"

    unless api_key && email
      puts "[CJ] ❌ CJ_API_KEY or CJ_EMAIL not set in environment"
      next
    end

    begin
      # 1️⃣ Get Access Token
      uri_token = URI("https://developers.cjdropshipping.com/api2.0/v1/authentication/getAccessToken")
      req = Net::HTTP::Post.new(uri_token, "Content-Type" => "application/json")
      req.body = { email: email, apiKey: api_key }.to_json

      res = Net::HTTP.start(uri_token.hostname, uri_token.port, use_ssl: true) do |http|
        http.request(req)
      end

      token_json = JSON.parse(res.body)
      if token_json["result"] && token_json["data"] && token_json["data"]["accessToken"]
        access_token = token_json["data"]["accessToken"]
        puts "[CJ] ✅ Access token obtained" if debug
      else
        puts "[CJ] ❌ Failed to get access token: #{res.body}"
        next
      end

      # 2️⃣ Fetch Categories
      uri_cat = URI("#{base_url}/product/getCategory")
      req_cat = Net::HTTP::Get.new(uri_cat)
      req_cat["CJ-Access-Token"] = access_token

      res_cat = Net::HTTP.start(uri_cat.hostname, uri_cat.port, use_ssl: true) do |http|
        http.request(req_cat)
      end

      cat_json = JSON.parse(res_cat.body)
      if cat_json["result"] && cat_json["data"]
        File.write(tmp_file, JSON.pretty_generate(cat_json["data"]))
        puts "[CJ] ✅ Categories saved to #{tmp_file}"
        puts "[CJ] ℹ Fetched #{cat_json['data'].size} first-level categories"
      else
        puts "[CJ] ❌ Failed to fetch categories: #{res_cat.body}"
      end

    rescue => e
      puts "[CJ] ❌ Error: #{e.message}"
      puts e.backtrace.first(5) if debug
    end
  end
end
