require "twitter"
require "keyword_struct"

module Lita
  module Handlers
    class Tweet < Handler

      Account = KeywordStruct.new(:username, :token, :secret, :config, :last_tweet) do
        def tweet(text)
          client.update(text)
        end

        def untweet
          last_tweet ? client.destroy_status(last_tweet) : false
        end

        def lookup_username!
          client.user.screen_name.tap do |username|
            self.username = username
          end
        end

      private

        def client
          return nil unless config && token && secret

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
