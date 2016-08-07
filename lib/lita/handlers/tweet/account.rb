require "twitter"

module Lita
  module Handlers
    class Tweet < Handler

      class KeywordStruct < Struct
        def initialize(**kwargs)
          super(*members.map{|k| kwargs[k] })
        end
      end

      Account = KeywordStruct.new(:username, :token, :secret, :config, :last_tweet) do
        def username
          @username ||= client.user.screen_name
        end

        def tweet(text)
          client.update(text)
        end

        def untweet
          last_tweet ? client.destroy_status(last_tweet) : false
        end

      private

        def client
          @client ||= ::Twitter::REST::Client.new do |c|
            c.consumer_key        = config.consumer_key
            c.consumer_secret     = config.consumer_secret
            c.access_token        = token
            c.access_token_secret = secret
          end
        end
      end
    end
  end
end
