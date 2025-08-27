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

    puts "[WuhuGoods] ⚡   Processing CJ category: #{category}"
    puts "[WuhuGoods] ⚡   Debug mode: #{debug}"

    start_time = Time.current
    store = Spree::Store.default || Spree::Store.first
    puts "[WuhuGoods] Using store: #{store.name}" if debug

    safe_category = category.encode('UTF-8', invalid: :replace, undef: :replace)
                          .gsub(/[^\p{Alnum}\s_-]/, '')
                          .strip
                          .downcase
                          .gsub(/\s+/, "_")

    details_path = Rails.root.join("tmp/cj_products/#{safe_category}/details")
    unless Dir.exist?(details_path)
      puts "[WuhuGoods] ❌  No details directory found: #{details_path}"
      next
    end

    detail_files = Dir.glob(details_path.join("*.json"))
    if detail_files.empty?
      puts "[WuhuGoods] ❌  No detail files found in #{details_path}"
      next
    end

    puts "[WuhuGoods] ✅   Found #{detail_files.size} detailed product files..."

    shipping_category = Spree::ShippingCategory.first_or_create!(name: "Default")
    tax_category      = Spree::TaxCategory.first_or_create!(name: "Default")
    stock_location    = Spree::StockLocation.first_or_create!(name: "Default")

    # === Taxonomy / Taxon setup ===
    taxonomy = Spree::Taxonomy.find_or_create_by!(name: "Categories")
    root_taxon = taxonomy.root || Spree::Taxon.find_or_create_by!(
      name: taxonomy.name,
      taxonomy: taxonomy
    )
    category_taxon = Spree::Taxon.find_or_create_by!(
      name: category,
      taxonomy: taxonomy,
      parent: root_taxon
    )

    created, skipped, failed = 0, 0, 0

    detail_files.each_with_index do |file_path, index|
      begin
        raw = JSON.parse(File.read(file_path))
        item = raw["data"] || raw
        sku  = item["sku"] || item["productSku"]

        if sku.blank?
          puts "[WuhuGoods] ⚠️  Skipping detail file #{file_path} with no SKU"
          next
        end

        puts "[WuhuGoods][#{index + 1}/#{detail_files.size}] Processing SKU #{sku}"

        name        = item["productNameEn"] || item["productName"] || "Product #{sku}"
        description = item["productDescriptionEn"] || item["productDescription"] || item["description"] || name

        # --- Safe sell price handling
        raw_price = item["sellPrice"]
        raw_price = raw_price["USD"] if raw_price.is_a?(Hash)
        price = (raw_price || 0).to_f * 1.7
        weight = (item["productWeight"] || 0).to_f
        cost_price = (item["costPrice"] || price / 1.7).to_f

        master_sku = "#{sku}-MASTER"
        slug_candidate = "#{name.parameterize}-#{sku.downcase}"[0..250]

        # ?? Reliable product existence check
        existing_product = Spree::Product.find_by(slug: slug_candidate) ||
                           Spree::Variant.find_by(sku: master_sku)&.product ||
                           Spree::Variant.find_by(sku: sku)&.product

        if existing_product
          puts "[WuhuGoods] ⚠️  Skipping existing product: #{name} (#{sku})"
          skipped += 1
          next
        end

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

        # Ensure unique slug
        base_slug = slug_candidate
        i = 1
        while Spree::Product.exists?(slug: product.slug || base_slug)
          product.slug = "#{base_slug}-#{SecureRandom.hex(2)}"
          i += 1
          break if i > 5
        end
        product.slug ||= base_slug

        unless product.save
          failed += 1
          puts "[WuhuGoods] ❌  Failed to create product #{sku}: #{product.errors.full_messages.join(', ')}"
          next
        end

        product.master.update!(
          sku: master_sku,
          price: price,
          weight: weight,
          cost_price: cost_price
        )

        # Assign to store
        product.stores << store unless product.stores.include?(store)

        # ✅ Assign to category taxon
        product.taxons << category_taxon unless product.taxons.include?(category_taxon)

        # --- Attach Images
        image_urls = []
        image_urls.concat(item["productImageSet"]) if item["productImageSet"].is_a?(Array)
        if item["productImage"].is_a?(String)
          begin
            parsed = JSON.parse(item["productImage"])
            image_urls.concat(parsed) if parsed.is_a?(Array)
          rescue JSON::ParserError
            # ignore bad json
          end
        end
        image_urls.uniq.each do |url|
          begin
            file = URI.open(url)
            product.images.create!(
              attachment: {
                io: file,
                filename: File.basename(URI.parse(url).path)
              }
            )
          rescue => e
            puts "[WuhuGoods] ⚠️  Failed to attach image #{url}: #{e.message}"
          end
        end

        # --- Variants
        if item["variants"]&.any?
          option_types = []
          if item["productKeyEn"].present?
            item["productKeyEn"].split("-").each do |key|
              ot = Spree::OptionType.find_or_create_by!(
                name: key.parameterize,
                presentation: key
              )
              option_types << ot
            end
          else
            option_types = [
              Spree::OptionType.find_or_create_by!(name: "color", presentation: "Color"),
              Spree::OptionType.find_or_create_by!(name: "size", presentation: "Size")
            ]
          end
          product.option_types = option_types
          product.save!

          item["variants"].each do |v|
            vsku = v["variantSku"] || v["sku"]
            raw_vprice = v["variantSellPrice"]
            raw_vprice = raw_vprice["USD"] if raw_vprice.is_a?(Hash)
            vprice = (raw_vprice || price).to_f * 1.7
            vweight = (v["variantWeight"] || weight).to_f
            vcost = (v["costPrice"] || vprice / 1.7).to_f

            next if vsku.blank?

            variant = product.variants.find_or_initialize_by(sku: vsku)
            variant.price      = vprice
            variant.weight     = vweight
            variant.cost_price = vcost
            variant.option_values = []

            if v["variantKey"].present?
              v["variantKey"].split("-").map(&:strip).each_with_index do |val, idx|
                next unless option_types[idx]
                ov = Spree::OptionValue.find_or_create_by!(
                  option_type: option_types[idx],
                  name: val.parameterize,
                  presentation: val
                )
                variant.option_values << ov
              end
            end

            if variant.save
              stock = variant.stock_items.find_or_initialize_by(stock_location_id: stock_location.id)
              stock.count_on_hand = v["inventoryNum"].to_i > 0 ? v["inventoryNum"].to_i : 10
              stock.backorderable = false
              stock.save!
            else
              puts "[WuhuGoods] ❌  Failed to save variant #{vsku}: #{variant.errors.full_messages.join(', ')}"
            end
          end
        else
          stock = product.master.stock_items.find_or_initialize_by(stock_location_id: stock_location.id)
          stock.count_on_hand = item["inventoryNum"].to_i > 0 ? item["inventoryNum"].to_i : 10
          stock.backorderable = false
          stock.save!
        end

        created += 1
        puts "[WuhuGoods] ✅   Created: #{name} (#{sku})"

      rescue => e
        failed += 1
        puts "[WuhuGoods] ❌  Failed #{file_path}: #{e.message}"
        puts e.backtrace.first(5) if debug
      end
    end

    end_time = Time.current
    duration = (end_time - start_time).round(2)

    puts "[WuhuGoods] ✅   Done! (#{duration}s)"
    puts "[WuhuGoods] → Created: #{created}"
    puts "[WuhuGoods] → Skipped (already existed): #{skipped}"
    puts "[WuhuGoods] → Failed: #{failed}"
  end
end
