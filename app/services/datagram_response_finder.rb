class DatagramResponseFinder

  def initialize(datagram:, params:{}, staleness:nil, max_size: Float::INFINITY)
    @datagram = datagram
    @params = params || {}
    @staleness = staleness
    @max_size = max_size
  end

  def response
    rs = all_responses(params).
    select('distinct on (watch_id) *').
    order('watch_id, timestamp desc')
    if staleness
      rs = rs.where('extract(epoch from (? - response_received_at)) < ?', Time.zone.now, staleness)
    end
    @response_data ||= rs.map{|r|
      {
        slug: r.watch.slug,
        name: r.watch.name,
        data: (r.bytesize.to_i < max_size ? r.response_json : {max_size: "Data size too big. Please use the Public URL to view data"}),
        errors: r.error,
        metadata: r.metadata,
        params: r.params
        }
    }
  end


  private

  attr_reader :datagram, :as_of, :staleness, :max_size

  def params
    p = (datagram.publish_params || {}).merge(@params)
    ParamsRenderer.new({},p).real_data
  end

  def all_responses(search_params)
    # filters responses for watch params
    return @responses if @responses
    @responses = WatchResponse.where(watch_id: datagram.watch_ids, datagram_id: datagram.id, status_code: 200, complete: true).
                 where('response_json is not null')
    if !search_params.blank?
      @responses = @responses.where('params @> ?', params.to_json)
    end
    @responses
  end




end