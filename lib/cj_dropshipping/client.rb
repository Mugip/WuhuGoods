require 'httparty'
require 'json'

module CjDropshipping
  class Client
    BASE_URL = ENV['CJ_API_BASE'] || "https://developers.cjdropshipping.com/api2.0/v1"
    AUTH_URL = "#{BASE_URL}/authentication/getAccessToken".freeze

    attr_reader :access_token, :warehouse

    def initialize
      @email = ENV['CJ_EMAIL']
      @api_key = ENV['CJ_API_KEY']
      @warehouse = ENV['CJ_WAREHOUSE'] || 'CN'
      @access_token = nil
      
      validate_credentials
      fetch_access_token
    end

    def validate_credentials
      raise "CJ_EMAIL is missing from .env file" if @email.blank?
      raise "CJ_API_KEY is missing from .env file" if @api_key.blank?
    end

    def fetch_access_token
      auth_payload = {
        email: @email,
        password: @api_key
      }

      puts "[DEBUG] Authenticating with CJ API using email: #{@email}"
      puts "[DEBUG] Auth URL: #{AUTH_URL}"
      
      response = HTTParty.post(
        AUTH_URL,
        body: auth_payload.to_json,
        headers: {
          'Content-Type' => 'application/json',
          'Accept' => 'application/json'
        },
        timeout: 30
      )

      puts "[DEBUG] Auth response code: #{response.code}"
      puts "[DEBUG] Auth response body: #{response.body}"

      if response.success?
        json_response = JSON.parse(response.body)
        
        if json_response['code'] == 200 && json_response['data'] && json_response['data']['accessToken']
          @access_token = json_response['data']['accessToken']
          puts "[DEBUG] Successfully authenticated. Access token received."
        else
          error_msg = json_response['msg'] || json_response['message'] || 'Authentication failed'
          raise "CJ Authentication failed: #{error_msg} (Code: #{json_response['code']})"
        end
      else
        raise "CJ Authentication HTTP error: #{response.code} - #{response.body[0..200]}"
      end
      
    rescue JSON::ParserError => e
      raise "CJ API returned invalid JSON response: #{response.body[0..200]}..."
    rescue => e
      raise "CJ Authentication error: #{e.message}"
    end

    def authenticated?
      !@access_token.nil?
    end

    def search_products_by_category(category_name, params = {})
      unless authenticated?
        raise "Not authenticated with CJ API. Please call fetch_access_token first."
      end

      default_params = {
        pageNum: 1,
        pageSize: 200,
        warehouse: @warehouse,
        categoryName: category_name
      }.merge(params)

      # Try to search by category name
      response = HTTParty.get(
        "#{BASE_URL}/product/list",
        headers: {
          'Content-Type' => 'application/json',
          'Accept' => 'application/json',
          'CJ-Access-Token' => @access_token
        },
        query: default_params,
        timeout: 30
      )

      handle_response(response)
    end

    def fetch_product_list(page_num: 1, page_size: 200, **params)
      get_products(params.merge('pageNum' => page_num, 'pageSize' => page_size))
    end

    def get_products(params = {})
      unless authenticated?
        raise "Not authenticated with CJ API. Please call fetch_access_token first."
      end

      default_params = {
        pageNum: 1,
        pageSize: 200,
        warehouse: @warehouse
      }.merge(params)

      puts "[DEBUG] Fetching products with params: #{default_params}"
      puts "[DEBUG] Access token: #{@access_token[0..20]}..." if @access_token

      response = HTTParty.get(
        "#{BASE_URL}/product/list",
        headers: {
          'Content-Type' => 'application/json',
          'Accept' => 'application/json',
          'CJ-Access-Token' => @access_token
        },
        query: default_params,
        timeout: 30
      )

      puts "[DEBUG] Products response code: #{response.code}"
      puts "[DEBUG] Products response body: #{response.body}"

      handle_response(response)
    end

    def get_product_details(product_id)
      unless authenticated?
        raise "Not authenticated with CJ API. Please call fetch_access_token first."
      end

      response = HTTParty.get(
        "#{BASE_URL}/product/query",
        headers: {
          'Content-Type' => 'application/json',
          'Accept' => 'application/json',
          'CJ-Access-Token' => @access_token
        },
        query: {
          pid: product_id,
          warehouse: @warehouse
        },
        timeout: 30
      )

      handle_response(response)
    end

    def search_products(keyword, params = {})
      unless authenticated?
        raise "Not authenticated with CJ API. Please call fetch_access_token first."
      end

      default_params = {
        keyword: keyword,
        pageNum: 1,
        pageSize: 200,
        warehouse: @warehouse
      }.merge(params)

      response = HTTParty.get(
        "#{BASE_URL}/product/list",
        headers: {
          'Content-Type' => 'application/json',
          'Accept' => 'application/json',
          'CJ-Access-Token' => @access_token
        },
        query: default_params,
        timeout: 30
      )

      handle_response(response)
    end

    private

    def handle_response(response)
      if response.success?
        json_response = JSON.parse(response.body)
        puts "[DEBUG] Response data: #{json_response.inspect}"
        json_response
      else
        error_message = "CJ API Error: HTTP #{response.code}"
        begin
          error_data = JSON.parse(response.body)
          error_message += " - #{error_data['msg'] || error_data['message']}" if error_data
        rescue JSON::ParserError
          error_message += " - #{response.body[0..200]}"
        end
        raise error_message
      end
    rescue JSON::ParserError => e
      raise "CJ API returned invalid JSON: #{response.body[0..200]}..."
    end
  end
end
