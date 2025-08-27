# lib/tasks/wuhugoods_create_and_map.rake
namespace :wuhugoods do
  desc "Create and map products from CJ detailed JSON files"
  task create_and_map: :environment do
    require 'json'
    require 'securerandom'
    require 'open-uri'
    require 'set'

    category = ENV["CJ_CATEGORY_NAME"] || "Lady Dresses"
    debug    = ENV["DEBUG"] == "true"

    puts "[WuhuGoods] ⚡  Processing CJ category: #{category}"
    puts "[WuhuGoods] ⚡  Debug mode: #{debug}"

    # Start timing
    start_time = Time.current

    store = Spree::Store.default || Spree::Store.first
    puts "[WuhuGoods] Using store: #{store.name}" if debug

    safe_category = category.encode('UTF-8', invalid: :replace, undef: :replace)
                          .gsub(/[^\p{Alnum}\s_-]/, '') # remove hidden chars
                          .strip
                          .downcase
                          .gsub(/\s+/, "_")
    details_path  = Rails.root.join("tmp/cj_products/#{safe_category}/details")

    unless Dir.exist?(details_path)
      puts "[WuhuGoods] ❌  No details directory found: #{details_path}"
      next
    end

    detail_files = Dir.glob(details_path.join("*.json"))
    if detail_files.empty?
      puts "[WuhuGoods] ❌  No detail files found in #{details_path}"
      next
    end

    puts "[WuhuGoods] ✅ Found #{detail_files.size} detailed product files..."

    # Preload existing data to reduce database queries
    existing_skus = Spree::Variant.pluck(:sku)
    puts "[WuhuGoods] ?? Found #{existing_skus.size} existing variants in database" if debug
    
    shipping_category = Spree::ShippingCategory.first_or_create!(name: "Default")
    tax_category      = Spree::TaxCategory.first_or_create!(name: "Default")
    stock_location    = Spree::StockLocation.first_or_create!(name: "Default")

    # Create option types
    color_option_type = Spree::OptionType.find_or_create_by!(name: "color", presentation: "Color")
    size_option_type  = Spree::OptionType.find_or_create_by!(name: "size",  presentation: "Size")

    created, updated, failed = 0, 0, 0
    seen_skus = []

    detail_files.each_with_index do |file_path, index|
      begin
        raw = JSON.parse(File.read(file_path))
        item = raw["data"] || raw

        sku = item["sku"] || item["productSku"]
        if sku.blank?
          puts "[WuhuGoods] ⚠️  Skipping detail file #{file_path} with no SKU"
          next
        end

        puts "[WuhuGoods][#{index + 1}/#{detail_files.size}] Processing SKU #{sku}"

        # Use English name if available, otherwise fallback
        name  = item["productNameEn"] || item["productName"] || "Product #{sku}"
        
        # Use English description if available, otherwise fallback
        description = item["productDescriptionEn"] || item["productDescription"] || item["description"] || name
        
        price = (item["sellPrice"] || 0).to_f * 1.4
        weight = (item["productWeight"] || 0).to_f
        cost_price = (item["costPrice"] || price / 1.5).to_f

        # Extract all available images from multiple possible fields
        images = []
        %w[productImageSet productImage images imageUrls].each do |image_field|
          if item[image_field]
            if item[image_field].is_a?(String)
              # Handle JSON string arrays
              begin
                parsed_images = JSON.parse(item[image_field])
                images += Array(parsed_images) if parsed_images.is_a?(Array)
              rescue
                images += [item[image_field]]
              end
            elsif item[image_field].is_a?(Array)
              images += item[image_field]
            end
          end
        end
        
        images.compact!
        images.uniq!
        images.reject! { |url| url =~ /(size|measure|placeholder|blank)/i }

        puts "[WuhuGoods][DEBUG] Processing #{sku} - #{name}, price=#{price}, images: #{images.size}" if debug

        # Check if product exists by checking if any variant with master SKU exists
        master_sku = "#{sku}-MASTER"
        product_exists = existing_skus.include?(master_sku)
        product = nil
        
        if product_exists
          # Find product by master variant
          master_variant = Spree::Variant.find_by(sku: master_sku)
          product = master_variant.product if master_variant
        end

        if product
          # --- Update existing product
          product.update!(
            name: name,
            description: description,
            price: price,
            available_on: Time.current,
	    status: :active,
            deleted_at: nil,
            weight: weight,
            cost_price: cost_price
          )
          updated += 1
          puts "[WuhuGoods] ?? Updated: #{name} (#{sku})"
        else
          # --- Create new product
          product = Spree::Product.new(
            name: name,
            description: description,
            price: price,
            available_on: Time.current,
            status: :active,
            shipping_category: shipping_category,
            tax_category: tax_category,
            weight: weight
          )

          # Generate unique slug
          base_slug = "#{name.parameterize}-#{sku.downcase}"[0..250]
          slug_candidate = base_slug
          i = 1
          while Spree::Product.exists?(slug: slug_candidate)
            slug_candidate = "#{base_slug}-#{SecureRandom.hex(2)}"
            i += 1
            break if i > 5
          end
          product.slug = slug_candidate
          
          if product.save
            # Ensure master variant has a different SKU to avoid conflicts with child variants
            product.master.update!(
              sku: master_sku,
              price: price,
              weight: weight,
              cost_price: cost_price
            )

            created += 1
            puts "[WuhuGoods] ✅ Created: #{name} (#{sku})"
          else
            failed += 1
            puts "[WuhuGoods] ❌ Failed to create product #{sku}: #{product.errors.full_messages.join(', ')}"
            next
          end
        end

        # Ensure store assignment
        unless product.stores.include?(store)
          product.stores << store
          puts "[WuhuGoods] ?? Added to store: #{store.name}" if debug
        end

        # Save all metadata from JSON
        product_metadata = {}
        item.each do |key, value|
          next if %w[sku productSku productName productNameEn description productDescription productDescriptionEn 
                    sellPrice costPrice productWeight productImage productImageSet images imageUrls variants].include?(key)
          next if value.nil? || value.to_s.empty?
          
          # Handle JSON string values
          if value.is_a?(String) && value.start_with?('[') && value.end_with?(']')
            begin
              value = JSON.parse(value)
            rescue
              # Keep as string if not valid JSON
            end
          end
          
          product_metadata[key] = value
        end
        product.public_metadata = product_metadata
        product.save!

        # Handle images
        if images.any?
          puts "[WuhuGoods] ??️  Processing #{images.size} images for #{sku}" if debug
          
          # Clear existing images first
          product.images.destroy_all if product.images.any?
          
          images.each_with_index do |image_url, img_index|
            begin
              next if image_url.blank?
              
              puts "[WuhuGoods] ?? Downloading image #{img_index + 1}: #{image_url}" if debug
              
              # Download and attach image
              downloaded_image = URI.open(image_url)
              image = product.images.new
              image.attachment.attach(io: downloaded_image, filename: "#{sku}_#{img_index + 1}.jpg")
              image.save!
              
              puts "[WuhuGoods] ✅ Image added: #{image_url}" if debug
            rescue => e
              puts "[WuhuGoods] ⚠️  Failed to download image #{image_url}: #{e.message}"
            end
          end
        end

        # Handle variants
        if item["variants"] && item["variants"].any?
          puts "[WuhuGoods] ?? Processing #{item['variants'].size} variants for #{sku}" if debug
          
          # Add option types to product
          product.option_types = [color_option_type, size_option_type]
          product.save!
          
          # Collect all option values from variants
          color_values = Set.new
          size_values = Set.new
          
          item["variants"].each do |v|
            if v["variantKey"].present? && v["variantKey"].include?('-')
              color, size = v["variantKey"].split('-', 2)
              color_values.add(color.strip) if color.present?
              size_values.add(size.strip) if size.present?
            end
          end
          
          # Create option values
          color_values.each do |color|
            Spree::OptionValue.find_or_create_by!(option_type: color_option_type, name: color.parameterize, presentation: color)
          end
          
          size_values.each do |size|
            Spree::OptionValue.find_or_create_by!(option_type: size_option_type, name: size.parameterize, presentation: size)
          end
          
          item["variants"].each do |v|
            vsku = v["variantSku"] || v["sku"]
            next if vsku.blank?
            
            seen_skus << vsku
            vprice  = (v["variantSellPrice"] || v["sellPrice"] || price).to_f * 1.4
            vweight = (v["variantWeight"] || v["productWeight"] || weight).to_f
            vcost_price = (v["costPrice"] || vprice / 1.5).to_f

            # Find or initialize variant
            variant = product.variants.find_or_initialize_by(sku: vsku)
            variant.price      = vprice
            variant.weight     = vweight
            variant.cost_price = vcost_price
            
            # Clear existing option values and set new ones
            variant.option_values = []
            
            # Parse variant options from variantKey (e.g., "Green-S")
            if v["variantKey"].present? && v["variantKey"].include?('-')
              color_name, size_name = v["variantKey"].split('-', 2).map(&:strip)
              
              if color_name.present?
                color_value = Spree::OptionValue.find_by(option_type: color_option_type, name: color_name.parameterize)
                variant.option_values << color_value if color_value
              end
              
              if size_name.present?
                size_value = Spree::OptionValue.find_by(option_type: size_option_type, name: size_name.parameterize)
                variant.option_values << size_value if size_value
              end
            end
            
            # Save variant metadata
            variant_metadata = {}
            v.each do |key, value|
              next if %w[sku variantSku variantName variantNameEn sellPrice variantSellPrice costPrice productWeight variantWeight stock].include?(key)
              next if value.nil? || value.to_s.empty?
              
              variant_metadata[key] = value
            end
            variant.public_metadata = variant_metadata
            
            if variant.save
              stock = variant.stock_items.find_or_initialize_by(stock_location_id: stock_location.id)
              stock.count_on_hand = v["inventoryNum"].to_i > 0 ? v["inventoryNum"].to_i : 10
              stock.backorderable = false
              stock.save!
              
              puts "[WuhuGoods] ✅ Variant: #{vsku} (#{v['variantKey']})" if debug
            else
              puts "[WuhuGoods] ❌ Failed to save variant #{vsku}: #{variant.errors.full_messages.join(', ')}"
            end
          end
          
          # Hide the master variant since we have child variants
          product.master.update!(is_master: true, sku: master_sku)
          
          # Make sure master variant is not track inventory
          master_stock = product.master.stock_items.find_or_initialize_by(stock_location_id: stock_location.id)
          master_stock.count_on_hand = 0
          master_stock.backorderable = false
          master_stock.save!
        else
          # Ensure stock for master variant with stock location
          stock = product.master.stock_items.find_or_initialize_by(stock_location_id: stock_location.id)
          stock.count_on_hand = item["inventoryNum"].to_i > 0 ? item["inventoryNum"].to_i : 10
          stock.backorderable = false
          stock.save!
        end

      rescue => e
        failed += 1
        puts "[WuhuGoods] ❌ Failed #{file_path}: #{e.message}"
        puts e.backtrace.first(5) if debug
      end
    end

    # --- Orphan cleanup (only if we processed successfully)
    if failed == 0
      puts "[WuhuGoods] ?? Checking for orphan products..."
      stale_skus = existing_skus - seen_skus
      
      if stale_skus.any?
        puts "[WuhuGoods] ??️ Found #{stale_skus.size} orphan products to remove"
        
        stale_skus.each do |sku|
          variant = Spree::Variant.find_by(sku: sku)
          next unless variant
          
          product = variant.product
          if product
            puts "[WuhuGoods] ??️ Removing orphan product #{product.name} (#{variant.sku})"
            product.destroy
          else
            puts "[WuhuGoods] ??️ Orphan variant #{variant.sku} had no product, deleting variant"
            variant.destroy
          end
        end
      end
    else
      puts "[WuhuGoods] ⚠️  Skipping orphan cleanup due to previous errors"
    end

    end_time = Time.current
    duration = (end_time - start_time).round(2)

    puts "[WuhuGoods] ?? Done! (#{duration}s)"
    puts "[WuhuGoods] ?? Created: #{created}"
    puts "[WuhuGoods] ?? Updated: #{updated}"
    puts "[WuhuGoods] ?? Failed: #{failed}"
    puts "[WuhuGoods] ?? Removed: #{stale_skus&.size || 0}"
  end
end
