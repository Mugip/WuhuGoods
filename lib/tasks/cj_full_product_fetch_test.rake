# lib/tasks/cj_full_product_fetch_test.rake
namespace :cj do
  desc 'Test CJ Dropshipping full product details fetch for specific category'
  task full_product_test: :environment do
    puts "=== CJ Full Product Details Test ==="
    category_name = ENV['CJ_CATEGORY_NAME'] || 'Lady Dresses'
    puts "[CJ] Searching for category: #{category_name}"

    # Create organized directory structure
    category_slug = category_name.parameterize.underscore
    base_dir = Rails.root.join('tmp', 'cj_products')
    category_dir = base_dir.join(category_slug)
    products_dir = category_dir.join('products')
    details_dir = category_dir.join('details')
    FileUtils.mkdir_p(products_dir)
    FileUtils.mkdir_p(details_dir)

    products_file = products_dir.join('list.json')
    metadata_file = category_dir.join('metadata.json')

    begin
      client = CjDropshipping::Client.new
      puts "[CJ] Fetching products for category: #{category_name}..."
      # Fetch products with larger page size to get more results for filtering
      response = client.get_products('pageNum' => 1, 'pageSize' => 200)
      puts "[DEBUG] API response code: #{response['code']}"
      puts "[DEBUG] API success: #{response['success']}"

      if response && response['success'] && response['data'] && response['data']['list']
        all_products = response['data']['list']
        puts "[CJ] Found #{all_products.size} total products"

        # Filter products by category name (case-insensitive)
        category_products = all_products.select do |product|
          product['categoryName']&.downcase&.include?(category_name.downcase)
        end
        puts "[CJ] Found #{category_products.size} products in category '#{category_name}'"

        # Get all unique categories for debugging
        all_categories = all_products.map { |p| p['categoryName'] }.uniq.compact
        puts "[CJ] Available categories: #{all_categories.join(', ')}"

        if category_products.any?
          # Save filtered products to organized file structure
          products_data = {
            category: category_name,
            total_count: category_products.size,
            fetched_at: Time.now.iso8601,
            products: category_products
          }
          File.write(products_file, JSON.pretty_generate(products_data))
          puts "✅   Saved #{category_products.size} products to: #{products_file}"

          # Save metadata
          metadata = {
            category: category_name,
            category_slug: category_slug,
            total_products_found: category_products.size,
            available_categories: all_categories,
            last_updated: Time.now.iso8601
          }
          File.write(metadata_file, JSON.pretty_generate(metadata))
          puts "✅   Metadata saved to: #{metadata_file}"

          # --- Fetch full details for all products in random order
          category_products.shuffle.each do |product|
            pid = product['pid']
            puts "[CJ] Fetching full details for product: #{pid} - #{product['productNameEn']}"
            full_details = client.get_product_details(pid)
            if full_details && full_details['success']
              puts "✅   Full product details fetched successfully!"
              puts "    Product ID: #{full_details['data']['pid']}"
              puts "    Product Name: #{full_details['data']['productNameEn']}"
              puts "    Category: #{full_details['data']['categoryName']}"
              puts "    Price: #{full_details['data']['price']}"
              puts "    Stock: #{full_details['data']['stock']}"

              # Save full details to organized location
              full_details_file = details_dir.join("#{pid}.json")
              File.write(full_details_file, JSON.pretty_generate(full_details))
              puts "    Full details saved to: #{full_details_file}"
            else
              puts "❌   Failed to fetch full product details for PID #{pid}"
            end
          end
        else
          puts "❌   No products found in category '#{category_name}'"
          # Save all products for debugging in organized location
          all_products_file = category_dir.join('all_products_debug.json')
          File.write(all_products_file, JSON.pretty_generate({
            total_count: all_products.size,
            categories: all_categories,
            products: all_products,
            searched_category: category_name
          }))
          puts "    All products saved to: #{all_products_file} for debugging"
        end
      else
        puts "❌   API request failed or invalid response structure"
        puts "    Response keys: #{response.keys if response.respond_to?(:keys)}"
        puts "    Data keys: #{response['data'].keys if response['data'].respond_to?(:keys)}"
      end
    rescue => e
      puts "❌   Error: #{e.message}"
      puts e.backtrace.first(5).join("\n")
    end
  end
end
