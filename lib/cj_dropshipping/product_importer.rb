require 'cj_dropshipping/client'

module CjDropshipping
  class ProductImporter
    def initialize
      @client = Client.new
    end

    def import
      products = @client.fetch_products
      products.each do |product|
        create_product(product)
      end
    end

    private

    def create_product(product)
      name = extract_product_name(product)
      puts "Name: #{name}"

      spree_product = Spree::Product.create!(
        name: name,
        price: product['sellPrice'].to_f,
        description: clean_description(product['remark']),
        available_on: Time.current,
        shipping_category: Spree::ShippingCategory.find_or_create_by!(name: 'Default')
      )

      attach_image(spree_product, product['productImage'])
      create_variant(spree_product, product)
    end

    def extract_product_name(product)
      name_field = product['productName']
      
      begin
        name_array = JSON.parse(name_field)
        name = name_array.first.is_a?(String) ? name_array.first : name_field
      rescue JSON::ParserError
        name = name_field
      end

      name.to_s.strip
    end

    def clean_description(raw_html)
      return '' unless raw_html

      doc = Nokogiri::HTML.fragment(raw_html)
      doc.search('script, style').remove
      doc.text.strip
    end

    def attach_image(product, image_url)
      return unless image_url

      file = URI.open(image_url)
      product.images.create!(attachment: { io: file, filename: File.basename(URI.parse(image_url).path) })
    rescue => e
      puts "Failed to attach image: #{e.message}"
    end

    def create_variant(product, product_data)
      product.master.update!(
        sku: product_data['productSku'],
        weight: average_weight(product_data['productWeight']),
        cost_price: product_data['sellPrice'].to_f
      )
    end

    def average_weight(weight_range)
      return nil unless weight_range

      if weight_range.include?('-')
        low, high = weight_range.split('-').map(&:to_f)
        ((low + high) / 2).round(2)
      else
        weight_range.to_f
      end
    end
  end
end
