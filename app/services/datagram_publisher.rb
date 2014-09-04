class DatagramPublisher

  # Publsihes a datagram to RabbitMQ
  #

  def initialize(datagram:, exchange: $x, queue: $datagrams)
    @datagram = datagram
    @exchange = exchange
    @queue = queue
    @timestamp = (Time.now.to_f).round
    @user = datagram.user
  end


  def publish!(params: {})
    return false if @published
    exchange.publish(payload(params).to_json, routing_key: routing_key)
    @published = true
    Rails.logger.info "#DatagramPublisher published datagram id: #{datagram.id} token: #{datagram.token} routing_key: #{routing_key} params: #{params}"
    payload(params)
  end


  def payload(params)
    return @payload if @payload
    watch_publishers.map{|wp| wp.make_new_response!(datagram_id: datagram.id, timestamp: timestamp, params: params)}
    @payload ||= {
      datagram_id: datagram.token.to_s,
      watches: watches_payload,
      routing_key: routing_key,
      datagram_token: datagram.token,
      timestamp: timestamp,
      params: params
    }
  end

  private

  attr_reader :datagram, :exchange, :queue, :timestamp, :user


  def watch_publishers
    @watch_publishers ||= datagram.watches.map{|w|
      WatchPublisher.new(w)
    }
  end

  def watches_payload
    watch_publishers.map(&:payload)
  end

  def watches
    @watches ||= datagram.watches
  end

  def routing_key
    "datagram:#{datagram.use_routing_key ? user.token : queue.name}"
  end

end
