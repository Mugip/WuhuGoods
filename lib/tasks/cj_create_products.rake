# lib/tasks/cj_create_products.rake
require 'json'
require 'open-uri'

namespace :cj do
  desc "Create Spree products from saved CJ JSON and make them active with stock"
  task create_products: :environment do
    puts "[CJ] Creating products in Spree from saved JSON..."

    json_path = Rails.root.join("tmp/cj_products.json")
    unless File.exist?(json_path)
      puts "[CJ] ERROR: File not found at #{json_path}. Run `cj:import` first."
      exit
    end

    category_name = ENV['CJ_CATEGORY_NAME']
    product_list = JSON.parse(File.read(json_path), symbolize_names: true)
    created = 0

    default_shipping = Spree::ShippingCategory.first_or_create!(name: "Default")
    stock_location = Spree::StockLocation.first_or_create!(name: "Default", active: true)

    product_list.each do |cj_product|
      next unless cj_product[:categoryName].to_s.downcase == category_name.to_s.downcase

      sku = cj_product[:productSku]
      name = cj_product[:productNameEn] || cj_product[:productName]
      price = cj_product[:sellPrice].to_f
      weight = (cj_product[:productWeight].to_s.split("-").first || "0").to_f
      image_url = cj_product[:productImage]

      next if Spree::Variant.exists?(sku: sku)

      # Create Spree product with master variant
      product = Spree::Product.new(
        name: name,
        description: cj_product[:remark].present? ? cj_product[:remark] : "#{name} — Beautiful #{cj_product[:categoryName]} design.",
        price: price,
        available_on: Time.current,
        status: :active,
        make_active_at: Time.current,
        discontinue_on: nil,
        shipping_category: default_shipping
      )
      product.master.assign_attributes(
        sku: sku,
        weight: weight
      )

      if product.save
        puts "[CJ] ✅ Created '#{product.name}' (SKU: #{sku})"

        # Add stock (default 200)
        stock_item = product.master.stock_items.first_or_initialize(stock_location: stock_location)
        stock_item.count_on_hand = 200
        stock_item.backorderable = false
        stock_item.save!

        # Attach image
        if image_url.present?
          begin
            file = URI.open(image_url)
            product.images.create!(attachment: {
              io: file,
              filename: File.basename(URI.parse(image_url).path)
            })
          rescue => e
            puts "[CJ] ⚠️  Image attach failed for SKU #{sku}: #{e.message}"
          end
        end

        created += 1
      else
        puts "[CJ] ❌ Failed to create product for SKU #{sku}"
        puts product.errors.full_messages.join(", ")
      end
    end

    puts "\n[CJ] Product creation complete."
    puts "[CJ] → Created: #{created} product(s)"
  end
end
