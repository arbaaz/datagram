module Clients
  class Base
    def initialize(url, payload, max_size_limit = 200_000)
      @url = url
      @payload = payload
      @max_size = max_size_limit
      @start_time = Time.now
      save_to_s3
    end

    def response
      ap [url, payload]
      {
        elapsed: elapsed,
        status_code: 200,
        data_filename: filename,
        id: payload["key"],
        datagram_id: payload["datagram_id"],
        timestamp: payload["timestamp"],
        bytesize: bytesize,
        truncated_json: truncated_json
      }.tap{|x| ap x}
    end

    attr_reader :url, :payload, :max_size

    def save_to_s3
      Rails.logger.info "#Perform Storing #{filename}"
      x = AWS::S3::S3Object.store(filename,json, "datagramg-cache")
      Rails.logger.info "#Perform Done storing  #{filename} #{(Time.now - tt).round}"
    end


    def filename
      "#{payload["datagram_id"]}-#{payload["key"]}.json"
    end

    def elapsed
      (Time.now - @start_time).round
    end

    def json
      @json ||= JSON.dump(data)
    end

    def bytesize
      @bytesize ||= json.bytesize
    end

    def truncated_json
      if bytesize > max_size
        @truncated_json ||= r[0..20]
      end
    end
  end

  class Sql < Base
    def data
      return @data if @data
      url = url.gsub("mysql://","mysql2://")
      options = url =~ /redshift/ ? {client_min_messages: false, force_standard_strings: false} : {}
      Sequel.connect(url, options) do |db|
        q = payload["data"]["query"]
        @data = db.fetch(q).all
      end
      Rails.logger.info "#Perform Finished query in #{elapsed} seconds"
      return @data
    end


  end
end