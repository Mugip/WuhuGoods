# lib/tasks/cj_full_product_fetch_test.rake
namespace :cj do
  desc 'Test CJ Dropshipping full product details fetch for specific category'
  task full_product_test: :environment do
    puts "=== CJ Full Product Details Test ==="
    
    category_name = ENV['CJ_CATEGORY_NAME'] || 'Lady Dresses'
    puts "[CJ] Searching for category: #{category_name}"
    
    # Create tmp directory if it doesn't exist
    tmp_dir = Rails.root.join('tmp', 'cj_products')
    FileUtils.mkdir_p(tmp_dir)
    
    output_file = tmp_dir.join("#{category_name.parameterize.underscore}_products_#{Time.now.to_i}.json")
    
    begin
      client = CjDropshipping::Client.new
      
      puts "[CJ] Fetching products for category: #{category_name}..."
      
      # Fetch products with larger page size to get more results for filtering
      response = client.get_products('pageNum' => 1, 'pageSize' => 50)
      
      puts "[DEBUG] API response code: #{response['code']}"
      puts "[DEBUG] API success: #{response['success']}"
      
      # FIX: Use the correct response structure - products are in 'list' not 'resultList'
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
          # Save filtered products to tmp file
          File.write(output_file, JSON.pretty_generate({
            category: category_name,
            total_count: category_products.size,
            products: category_products
          }))
          
          puts "✅  Saved #{category_products.size} products to: #{output_file}"
          
          # Test full product details for the first product in the category
          first_product = category_products.first
          puts "[CJ] Fetching full details for product: #{first_product['pid']} - #{first_product['productNameEn']}"
          
          full_details = client.get_product_details(first_product['pid'])
          
          if full_details && full_details['success']
            puts "✅  Full product details fetched successfully!"
            puts "    Product ID: #{full_details['data']['pid']}"
            puts "    Product Name: #{full_details['data']['productNameEn']}"
            puts "    Category: #{full_details['data']['categoryName']}"
            puts "    Price: #{full_details['data']['price']}"
            puts "    Stock: #{full_details['data']['stock']}"
            
            # Save full details to another file
            full_details_file = tmp_dir.join("#{first_product['pid']}_full_details.json")
            File.write(full_details_file, JSON.pretty_generate(full_details))
            puts "    Full details saved to: #{full_details_file}"
          else
            puts "❌  Failed to fetch full product details"
          end
        else
          puts "❌  No products found in category '#{category_name}'"
          
          # Save all products for debugging
          all_products_file = tmp_dir.join('all_products.json')
          File.write(all_products_file, JSON.pretty_generate({
            total_count: all_products.size,
            categories: all_categories,
            products: all_products
          }))
          puts "    All products saved to: #{all_products_file} for debugging"
        end
      else
        puts "❌  API request failed or invalid response structure"
        puts "    Response keys: #{response.keys if response.respond_to?(:keys)}"
        puts "    Data keys: #{response['data'].keys if response['data'].respond_to?(:keys)}"
      end
      
    rescue => e
      puts "❌  Error: #{e.message}"
      puts e.backtrace.first(5).join("\n")
    end
  end
end
