module CjDropshipping
  class Client
    include HTTParty
    base_uri "https://developers.cjdropshipping.com/api2"

    def initialize
      @client_id     = ENV["CJ_CLIENT_ID"]
      @client_secret = ENV["CJ_CLIENT_SECRET"]
      @access_token  = fetch_access_token
    end

    # Public method to fetch product list
    def fetch_product_list(page_num: 1, page_size: 5)
      post("/product/list", { pageNum: page_num, pageSize: page_size })
    end

    private

    def fetch_access_token
      response = self.class.post(
        "/auth/access-token",
        headers: { "Content-Type" => "application/json" },
        body: { developerId: @client_id, apiSecret: @client_secret }.to_json
      )
      json = JSON.parse(response.body)
      json["data"]["accessToken"] if json["success"]
    end

    # Keep post as private
    def post(path, body = {})
      response = self.class.post(
        path,
        headers: {
          "Content-Type" => "application/json",
          "CJ-Access-Token" => @access_token
        },
        body: body.to_json
      )
      JSON.parse(response.body)
    end
  end
end
