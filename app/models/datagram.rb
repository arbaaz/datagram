class Datagram < ActiveRecord::Base

  belongs_to :user

  before_save :make_token_and_slug
  include Rails.application.routes.url_helpers

  def as_json(include_root = false)
    attributes.merge({
                       id: id.to_s,
                       private_url: private_url,
                       public_url: public_url,
                       watches: watches.map{|w| w.attributes.slice("name", "token","params","id","slug")},
                       responses: response_data.to_a,
                       timestamp: (Time.at(max_ts/1000) rescue Time.now)
                     }).except("_id")
  end

  # JSON representation of the latest requested responses.
  # params: arbitrary hash passed on to callees
  # as_of: a datetime. we show the last response before the requested time.
  # staleness: no of seconds staleness we can accept
  def response_json(params: {}, as_of: nil, staleness: nil)
    {responses: Hash[response_data(params, as_of, staleness).map{|r| [r[:slug], r]}]}
  end

  # calls WatchPublisher.publish! passing on the given hash.
  def publish(params = {})
    publisher(params).publish!
  end

  def payload
    publisher.payload
  end


  def watches
    @watches ||= Watch.find(watch_ids) rescue []
  end

  def private_url
    api_v1_t_path(slug: slug, api_key: user.token)
  end

  def public_url
    api_v1_d_path(token: token)
  end

  def refresh_channel(params)
    params = {token: self.token}.merge(params || {})
    Base64.urlsafe_encode64(OpenSSL::HMAC.digest(OpenSSL::Digest::Digest.new('sha256'), "secret", params.to_json)).strip
  end

  private

  def publisher(params)
    @publisher ||= DatagramPublisher.new(datagram: self, params: params)
  end


  def max_ts
    last_update_timestamp
  end

  # the last available responses for this datagram for all included watches
  # edge cases abound!
  # what happens if one of the watches crashed?
  def response_data(params = {},as_of = nil, staleness = nil)
    rs = all_responses(params, as_of).
      select('distinct on (watch_id) *').
      order('watch_id, report_time desc, created_at desc')
    if staleness
      rs = rs.where('extract(epoch from (? - response_received_at)) < ?', Time.zone.now, staleness)
    end
    @response_data ||= rs.map{|r| {
        slug: r.watch.slug,
        name: r.watch.name,
        data: r.response_json,
        errors: r.error,
        metadata: r.metadata,
      }}
  end

  def all_responses(search_params, as_of)
    # filters responses for watch params
    return @responses if @responses
    params_clause = (search_params || {}).map{|k,v|
      v = v.gsub("'",%q(\\\')) # escape postgres single quotes
      "params->>'#{k}' = E'#{v}' "}.join(' AND ')
    # and for those where there is no response yet (crashed, timedout, still processing....)
    @responses = WatchResponse.where(datagram_id: self.id).where('response_json is not null')
    # execute search filter
    if !search_params.blank?
      @responses = @responses.where(params_clause)
    end
    # execute report_time filter
    if as_of
      @responses = @responses.where('report_time <= ?',DateTime.parse(as_of))
    end
    @responses
  end

  def make_token_and_slug
    self.token ||= SecureRandom.urlsafe_base64
    self.slug ||= name.parameterize
  end

end
