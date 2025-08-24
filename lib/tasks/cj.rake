require 'cj_dropshipping/product_importer'
require 'json'
require 'rainbow'

namespace :cj do
  desc "Export CJ product data to JSON and import into a specific taxon"
  task import_taxon: :environment do
    taxon_name = ENV['TAXON']
    page_size  = ENV['SIZE']&.to_i || 10
    pages      = ENV['PAGES']&.to_i || 1

    if taxon_name.nil? || taxon_name.empty?
      puts Rainbow("❌ Please provide a taxon name using:").red
      puts Rainbow("    TAXON='Your Taxon' rake cj:import_taxon SIZE=10 PAGES=2").yellow
      exit 1
    end

    importer = CjDropshipping::ProductImporter.new

    puts Rainbow("?? Starting CJ Import Task...").cyan.bold
    puts Rainbow("➡️  Taxon: #{taxon_name}").green
    puts Rainbow("➡️  Page size: #{page_size}, Pages: #{pages}").green

    # Use existing method: import_taxon! but split into fetch + import
    puts Rainbow("\n?? Fetching CJ product data...").blue
    all_products = importer.fetch_products(page_size: page_size) # we use existing client fetch
    if all_products.nil? || all_products.empty?
      puts Rainbow("⚠️ No products returned from CJ API").yellow
      exit 1
    end

    # Filter by categoryName matching taxon_name (like your cj_import.rake does)
    product_list = all_products.select do |p|
      p[:categoryName].to_s.strip.casecmp?(taxon_name.strip)
    end

    if product_list.empty?
      puts Rainbow("⚠️ No products found in CJ for category '#{taxon_name}'").yellow
      exit 1
    end

    # Save to JSON
    file_path = Rails.root.join("cj_products_export.json")
    File.open(file_path, "w") do |f|
      f.write(JSON.pretty_generate(product_list))
    end
    puts Rainbow("\n✅ Exported #{product_list.size} products to #{file_path}").green.bold

    # Import into Spree
    puts Rainbow("?? Importing products into Spree taxon: #{taxon_name}...").magenta
    importer.import_taxon!(taxon_name, page_size: page_size, pages: pages)

    puts Rainbow("\n?? CJ Import Completed Successfully!").cyan.bold
  end
end
