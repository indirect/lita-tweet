require "oauth"
require "twitter"

module Lita
  module Handlers
    class Tweet < Handler
      config :consumer_key, type: String
      config :consumer_secret, type: String
      config :ssl

      route %r{^tweet\s(.+)}, :tweet, command: true, restrict_to: :tweeters,
        help: {"tweet MESSAGE" => "Post a tweet."}
      route %r{^untweet}, :untweet, command: true, restrict_to: :tweeters,
        help: {"untweet" => "Delete the last tweet."}
      route %r{^twitter accounts}, :accounts, command: true, help: {
        "twitter accounts" => "List accounts that can be tweeted from.",
        "twitter accounts add" => "Authorize a new account for tweeting."
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
        client.update(tweet)
      end

      def untweet(response)
        # do untweeting here
      end

      def accounts(response)
        return response.reply(add_account) if response.args.last == "add"

        names = TwitterAccountList.new(redis).names
        return response.reply(no_accounts) if names.empty?
        
        response.reply "Authorized Twitter accounts:\n" +
         names.map{|n| " - @#{n}" }.join("\n")
      end
      
      def no_accounts
        "No authorized accounts. Use `twitter accounts add` to add one."
      end
      
      def add_account
        "Authorize your account for tweeting here:\n" \
          "#{bot_uri('/twitter/login')}"
      end

      # def channels(response)
      #   # do channel stuff here
      # end

      def login_with_twitter(request, response)
        # Get an oauth_token from Twitter
        request_token = consumer.get_request_token(
          oauth_callback: bot_uri("/twitter/callback").to_s)

        # Save the request_token hash to Redis (by oauth_token)
        RequestTokenList.new(redis).add(request_token.params)
        
        # Redirect the user to the Twitter login URL
        response.status = 302
        response.headers["Location"] = request_token.authorize_url
      end

      def add_twitter_account(request, response)
        # Parse the oauth_token and oauth_verifier
        oauth_token = request.params["oauth_token"]

        # Load the request_token hash from Redis (by oauth_token)
        request_token = RequestTokenList.new(redis).find(oauth_token, consumer)

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
      end
      
      RequestTokenList = Struct.new(:redis) do
        def add(params)
          oauth_token = params[:oauth_token]
          redis.hmset("request_token:#{oauth_token}", *params.to_a.flatten)
        end

        def find(oauth_token, consumer)
          params = redis.hgetall("request_token:#{oauth_token}")
          params.keys.each{|k| params[k.to_sym] = params[k] }
          OAuth::RequestToken.from_hash(consumer, params)
        end
      end

    private

      def bot_uri(path)
        scheme = config.ssl ? "https" : "http"
        host = "#{robot.config.http.host}:#{robot.config.http.port}"
        URI(File.join("#{scheme}://#{host}", path))
      end

      def consumer
        @consumer ||= OAuth::Consumer.new(
          config.consumer_key || "PhJYwP0Il1BkLNDAJYnLgFJRT",
          config.consumer_secret || "gguuzCj9esoVApMiQJ3pIN9hVoCmUqvN0vyz6WR3tF4SHpUsD9",
          :site => 'https://api.twitter.com',
          :authorize_path => '/oauth/authenticate',
          :sign_in => true
        )
      end

      Lita.register_handler(self)
    end
  end
end
