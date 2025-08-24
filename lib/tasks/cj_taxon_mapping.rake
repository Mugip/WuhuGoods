namespace :cj do
  desc "Map CJ products to existing taxons (e.g., /t/categories/lady-dresses)"
  task map_to_taxon: :environment do
    puts "[CJ] Starting taxon mapping from saved JSON..."

    category_name = ENV['CJ_CATEGORY_NAME']
    if category_name.nil?
      puts "[CJ] ❌ CJ_CATEGORY_NAME is required (e.g., CJ_CATEGORY_NAME='Lady Dresses')"
      exit
    end

    json_path = Rails.root.join("tmp/cj_products.json")
    unless File.exist?(json_path)
      puts "[CJ] ❌ No saved product data found at #{json_path}"
      exit
    end

    # Load the CJ product list
    product_list = JSON.parse(File.read(json_path), symbolize_names: true)

    # Convert to slug/permalink format
    category_slug = category_name.parameterize  # => "lady-dresses"

    # Try finding taxon by permalink
    taxon = Spree::Taxon.find_by(permalink: "categories/#{category_slug}")
    if taxon.nil?
      puts "[CJ] ❌ Taxon not found at /t/categories/#{category_slug}"
      exit
    end

    mapped = 0
    skipped = 0

    product_list.each do |product_data|
      next unless product_data[:categoryName].to_s.downcase == category_name.downcase

      sku = product_data[:productSku]
      variant = Spree::Variant.find_by(sku: sku)

      if variant.nil?
        puts "[CJ] ⚠️  Variant with SKU '#{sku}' not found."
        skipped += 1
        next
      end

      product = variant.product

      unless product.taxons.include?(taxon)
        product.taxons << taxon
        puts "[CJ] ✅ Mapped '#{product.name}' to '/t/categories/#{category_slug}'"
        mapped += 1
      end
    end

    puts "\n[CJ] Mapping complete."
    puts "[CJ] → Mapped: #{mapped} product(s)"
    puts "[CJ] → Skipped: #{skipped} (missing variant or unmatched category)"
  end
end
