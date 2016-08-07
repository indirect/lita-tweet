require "oauth"
require_relative "./account"

module Lita
  module Handlers
    class Tweet < Handler
      Data = Struct.new(:redis, :config, :robot) do
        def usernames
          redis.smembers("twitter_accounts")
        end

        def account(username)
          hash = redis.hgetall("twitter_accounts:#{username}")
          data = hash.each_with_object({}){|(k,v),h| h[k.to_sym] = v }
          Account.new(**data.merge(config: config))
        end

        def add_account(token, secret)
          account = Account.new(token: token, secret: secret, config: config)
          username = account.username

          redis.sadd("twitter_accounts", username)
          redis.hmset("twitter_accounts:#{username}",
            "username", username,
            "token", token,
            "secret", secret
          )

          account
        end

        def remove_account(username)
          redis.del("twitter_accounts:#{username}")
          redis.srem("twitter_accounts", username)
        end

        def set_last_tweet(username, tweet_id)
          redis.hset("twitter_accounts:#{username}", "last_tweet", tweet_id)
        end

        def get_last_tweet(username)
          redis.hget("twitter_accounts:#{username}", "last_tweet")
        end

        def create_request_token(callback_path)
          request_token = consumer.get_request_token(
            oauth_callback: bot_uri(callback_path).to_s)
          request_hash = request_token.params

          key = "request_token:#{request_hash[:oauth_token]}"
          redis.hmset(key, *request_hash.to_a.flatten)
          redis.expire(key, 120)

          request_token
        end

        def authorize_account(token, verifier)
          request_token = find_request_token(token)
          access_token = request_token.get_access_token(oauth_verifier: verifier)
          add_account(access_token.token, access_token.secret)
        end

        def bot_uri(path = "")
          base_uri + path
        end

      private

        def find_request_token(oauth_token)
          params = redis.hgetall("request_token:#{oauth_token}")
          params.keys.each{|k| params[k.to_sym] = params[k] }
          OAuth::RequestToken.from_hash(consumer, params)
        end

        def base_uri
          @base_url ||= begin
            http = robot.config.http
            URI(config.http_url || "http://#{http.host}:#{http.port}")
          end
        end

        def consumer
          @consumer ||= OAuth::Consumer.new(
            config.consumer_key,
            config.consumer_secret,
            :site => 'https://api.twitter.com',
            :authorize_path => '/oauth/authenticate',
            :sign_in => true
          )
        end
      end
    end
  end
end
