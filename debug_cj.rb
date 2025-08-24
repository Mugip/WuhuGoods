# debug_cj.rb
require_relative './lib/cj_dropshipping/client'

begin
  puts "Testing CJ Dropshipping API connection..."
  client = CjDropshipping::Client.new
  
  puts "Fetching products..."
  products = client.get_products(pageNum: 1, pageSize: 10)
  
  puts "Products response: #{products.inspect}"
  
  if products && products['data'] && products['data']['resultList']
    puts "Found #{products['data']['resultList'].size} products"
    products['data']['resultList'].each do |product|
      puts "Product: #{product['productNameEn']} - #{product['pid']}"
    end
  else
    puts "No products found or unexpected response structure"
    puts "Full response: #{products}"
  end
  
rescue => e
  puts "Error: #{e.message}"
  puts e.backtrace.join("\n")
end
