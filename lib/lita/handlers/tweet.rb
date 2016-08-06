require "oauth"
require "twitter"

module Lita
  module Handlers
    class Tweet < Handler
      config :consumer_key, type: String
      config :consumer_secret, type: String
      config :http_url

      route %r{^tweet\s(.+)}, :tweet, command: true, restrict_to: :tweeters,
        help: {"tweet MESSAGE" => "Post a tweet."}
      route %r{^untweet}, :untweet, command: true, restrict_to: :tweeters,
        help: {"untweet" => "Delete the last tweet."}
      route %r{^twitter accounts}, :accounts, command: true, help: {
        "twitter accounts" => "List accounts that can be tweeted from.",
        "twitter accounts add" => "Authorize a new account for tweeting.",
        "twitter accounts remove NAME" => "Remove the twitter account NAME"
      }
      # route %r{^twitter channels\s(.+?)\s(.+)}, :channels, command: true, help: {
      #   "twitter channels" => "List account to channel mappings.",
      #   "twitter channels NAME CHANNEL" => "Tweet as twitter account NAME when told to tweet in channel CHANNEL."
      # }

      http.get "/twitter/login", :login_with_twitter
      http.get "/twitter/callback", :add_twitter_account

      def tweet(response)
        tweet = response.match_data[1]
        return response.reply("I need something to tweet!") unless tweet

        access = TwitterAccountList.new(redis).first
        return response.relpy(no_accounts) unless access["secret"]

        client = twitter_client(access["token"], access["secret"])
        tweet = client.update(tweet)
        response.reply(tweet.url)
      end

      def untweet(response)
        # do untweeting here
      end

      def accounts(response)
        case response.args[1]
        when "add"
          response.reply(add_account)
        when "remove"
          response.reply(remove_account(response.args[2]))
        else
          response.reply(list_accounts)
        end
      end

      def list_accounts
        names = TwitterAccountList.new(redis).names

        if names.empty?
          "No authorized accounts. Use `twitter accounts add` to add one."
        else
          "Authorized Twitter accounts:\n" + names.map{|n| " - @#{n}\n" }.join
        end
      end

      def add_account
        "Authorize your account for tweeting here:\n" \
          "#{bot_uri('/twitter/login')}"
      end

      def remove_account(name)
        TwitterAccountList.new(redis).remove(name)
        "Removed @#{name}."
      end

      # def channels(response)
      #   # do channel stuff here
      # end

      def login_with_twitter(request, response)
        # Get an oauth_token from Twitter
        callback = bot_uri("/twitter/callback")
        request_token = RequestTokenList.new(redis, config).add(callback)

        # Redirect the user to the Twitter login URL
        response.status = 302
        response.headers["Location"] = request_token.authorize_url
      end

      def add_twitter_account(request, response)
        # Parse the oauth_token and oauth_verifier
        oauth_token = request.params["oauth_token"]

        # Load the request_token hash from Redis (by oauth_token)
        request_token = RequestTokenList.new(redis, config).find(oauth_token)

        # Use the RequestToken to `get_access_token` with the oauth_verifier
        access_token = request_token.get_access_token(
          oauth_verifier: request.params["oauth_verifier"])

        # Save the twitter creds with username, token, and secret
        client = twitter_client(access_token.token, access_token.secret)
        username = client.user.screen_name
        TwitterAccountList.new(redis).add(username,
          access_token.token, access_token.secret)

        response.body << "Done! You can now tweet from @#{username}."
      end

      def twitter_client(token, secret)
        ::Twitter::REST::Client.new do |c|
          c.consumer_key        = config.consumer_key
          c.consumer_secret     = config.consumer_secret
          c.access_token        = token
          c.access_token_secret = secret
        end
      end

      TwitterAccountList = Struct.new(:redis) do
        def names
          redis.smembers("twitter_accounts")
        end

        def find(username)
          redis.hgetall("twitter_accounts:#{username}")
        end

        def first
          find(names.first)
        end

        def add(username, token, secret)
          redis.sadd("twitter_accounts", username)
          redis.hmset("twitter_accounts:#{username}",
            "token", token, "secret", secret)
        end

        def remove(username)
          redis.del("twitter_accounts:#{username}")
          redis.srem("twitter_accounts", username)
        end
      end

      RequestTokenList = Struct.new(:redis, :config) do
        def add(callback_url)
          request_token = consumer.get_request_token(
            oauth_callback: callback_url.to_s)
          params = request_token.params

          key = "request_token:#{params[:oauth_token]}"
          redis.hmset(key, *params.to_a.flatten)
          redis.expire(key, 120)
        end

        def find(oauth_token)
          params = redis.hgetall("request_token:#{oauth_token}")
          params.keys.each{|k| params[k.to_sym] = params[k] }
          OAuth::RequestToken.from_hash(consumer, params)
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

    private

      def bot_uri(path)
        bot_url = config.http_url ||
           "http://#{robot.config.http.host}:#{robot.config.http.port}"
        URI(File.join(bot_url, path))
      end

      Lita.register_handler(self)
    end
  end
end
