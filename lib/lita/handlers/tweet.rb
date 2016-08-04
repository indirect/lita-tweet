module Lita
  module Handlers
    class Tweet < Handler
      http.get "/twitter/login", :login_with_twitter
      http.get "/twitter/callback", :add_twitter_account

      def login_with_twitter(request, response)
        # Create a request_token
        # Get an oauth_token from Twitter
        # Save the request_token hash to Redis (by oauth_token)
        # Redirect the user to the Twitter login URL
        response.body << "This is where we would redirect you to Twitter to authorize us to use your account."
      end

      def add_twitter_account(request, response)
        # Parse the oauth_token and oauth_verifier
        # Load the request_token hash from Redis (by oauth_token)
        # Use the RequestToken to `get_access_token` with the oauth_verifier
        # Save the twitter creds with username, token, and secret
        response.body << "This is where you would get redirected to Twitter and authorize Lita to have access to your account."
      end

      RequestTokenList = Struct.new(:redis) do
        def add(params)
          oauth_token = params[:oauth_token]
          redis.hset("request_token:#{oauth_token}", params)
        end

        def find(oauth_token)
          redis.hget("request_token:#{oautH_token}")
        end
      end

      TwitterAccount = Struct.new(:name, :token, :secret) do
        def client
          Twitter::Client.new # auth stuff here
        end
      end

      TwitterAccountList = Struct.new(:redis) do
        def all
          redis.smembers("twitter_accounts").map{|n| find(n) }
        end

        def find(name)
          TwitterAccount.new(**redis.hget("twitter_accounts:#{name}"))
        end

        def add(username: username, token: token, secret: secret)
          redis.sadd("twitter_accounts", username)
          redis.hset("twitter_accounts:#{username}",
            token: token, secret: secret)
        end
      end

      Lita.register_handler(self)
    end
  end
end
