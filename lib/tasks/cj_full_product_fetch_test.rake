# lib/tasks/cj_full_product_fetch_test.rake
require 'cj_dropshipping/client'
require 'json'
require 'rainbow'

namespace :cj do
  desc "Test fetching CJ full product details"
  task full_product_test: :environment do
    puts Rainbow("=== CJ Full Product Details Test ===").cyan.bold

    client = CjDropshipping::Client.new
    fast_mode = ENV['FAST'] == 'true'

    puts Rainbow("[CJ] Fetching a small sample product list...").blue

    # Fetch sample products (first 10)
    sample_response = client.fetch_product_list(page_num: 1, page_size: 20)

    # Determine correct key for list
    products = sample_response["resultList"] || sample_response[:list] || []
    if products.empty?
      puts Rainbow("❌ No products returned!").red
      exit 1
    end

    puts Rainbow("[CJ] Found #{products.size} sample products").green

    products.each_with_index do |p, i|
      pid = p["pid"] || p[:pid]
      puts Rainbow("\n[#{i+1}/#{products.size}] Fetching full details for product #{pid}...").yellow

      # Fetch full product details
      begin
        details = client.fetch_product_details(pid)
      rescue => e
        puts Rainbow("⚠️  Error fetching product #{pid}: #{e.message}").red
        next
      end

      if details.nil? || details.empty?
        puts Rainbow("⚠️  No details returned for product #{pid}").red
        next
      end

      # Extract main info safely
      product_name = details["productNameEn"] || details[:productNameEn]
      price_range  = details["sellPrice"] || details[:sellPrice]
      sku_count    = details["variants"]&.size || 0
      category     = details["categoryName"] || details[:categoryName]

      puts Rainbow("✅ Product: #{product_name}").green
      puts "   Price Range: #{price_range}"
      puts "   SKU Count: #{sku_count}"
      puts "   Category: #{category}"

      # Optional delay
      unless fast_mode
        puts Rainbow("⏳ Waiting 5 minutes + 10 seconds before next API call...").blue
        sleep(5 * 60 + 10)
      end
    end

    puts Rainbow("\n=== Done testing product details fetch ===").cyan.bold
  end
end
