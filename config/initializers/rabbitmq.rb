begin
  if ENV['RABBITMQ_PORT']
    endpoint=ENV['RABBITMQ_PORT'].gsub("tcp","amqp")
  else
    endpoint = Rails.application.secrets.rabbitmq_url || ENV['RABBITMQ_URL'] || "amqp://rabbitmq:5672"
  end
  Rails.logger.info "Connecting to RabbitMQ at #{endpoint}"
  username = Rails.application.secrets.rabbitmq_user || "guest"
  password = Rails.application.secrets.rabbitmq_password || "guest"

  $conn = Bunny.new(endpoint)

  $conn.start

  $ch = $conn.create_channel
  $watches  = $ch.queue("watches", :durable => true)
  $watch_responses  = $ch.queue(Rails.application.secrets["watch_response_q"] || "watch_responses", :durable => true)
  $x  = $ch.topic('datagrams_topic_exchange', auto_delete: false)

  $watches.bind($x)
  Rails.logger.info "Connected to rabbitMQ"
  Rails.logger.info $x
rescue Exception => e
  Rails.logger.error e.message
end
