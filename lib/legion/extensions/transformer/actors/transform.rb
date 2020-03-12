module Legion::Extensions::Transformer
  module Actor
    class Transform < Legion::Extensions::Actors::Subscription
      def runner_function
        'transform'
      end

      def check_subtask?
        false
      end

      def generate_task?
        false
      end

      def use_runner?
        false
      end
    end
  end
end