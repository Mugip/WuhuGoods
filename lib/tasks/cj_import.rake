# lib/tasks/cj_import.rake
require 'json'

namespace :cj do
  desc "Import products from CJ Dropshipping"
  task import: :environment do
    puts "[CJ] Starting product import..."
    begin
      require_relative '../../lib/cj_dropshipping/client'
      desired_category = ENV['CJ_CATEGORY_NAME']
      if desired_category.blank?
        puts "[CJ] ERROR: Please provide CJ_CATEGORY_NAME."
        exit
      end

      client = CjDropshipping::Client.new
      response = client.fetch_products(pageSize: 200)
      all_products = response[:list] || []

      product_list = all_products.select do |product|
        product[:categoryName].to_s.strip.casecmp?(desired_category.strip)
      end

      if product_list.empty?
        puts "[CJ] No products found in category '#{desired_category}'."
        return
      end

      # Save to JSON
      output_file = Rails.root.join("tmp/cj_products.json")
      File.write(output_file, JSON.pretty_generate(product_list))
      puts "[CJ] Saved #{product_list.size} products to #{output_file}"

      # Optional: Print product summary
      product_list.each_with_index do |product, index|
        puts "\n[CJ] Product #{index + 1}:"
        puts "  - Name: #{product[:productNameEn]}"
        puts "  - Product ID: #{product[:pid]}"
        puts "  - SKU: #{product[:productSku]}"
        puts "  - Price: #{product[:sellPrice]}"
        puts "  - Weight: #{product[:productWeight]} kg"
        puts "  - Category: #{product[:categoryName]}"
        puts "  - Customizable?: #{product[:customizationVersion] ? 'Yes' : 'No'}"
        puts "  - Image: #{product[:productImage]}"
      end

      puts "\n[CJ] Import complete. Total: #{product_list.length} products."
    rescue => e
      puts "[CJ] ERROR: #{e.message}"
      puts e.backtrace.join("\n")
    end
  end
end
