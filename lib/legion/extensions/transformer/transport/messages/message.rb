module Legion::Extensions::Transformer::Transport::Messages
  class Message < Legion::Transport::Message
    def type
      'task'
    end

    def message
      { args: @options[:args]||{}}
    end

    def routing_key
      namespace = Legion::Data::Model::Namespace[@options[:namespace_id]]
      namespace.values[:routing_key]
    end

    def exchange
      namespace = Legion::Data::Model::Namespace[@options[:namespace_id]]
      Legion::Transport::Exchanges::Bunny.new(namespace.values[:exchange])
    end
  end
end