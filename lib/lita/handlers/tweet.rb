require "twitter"
require_relative "./tweet/data"

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
      route %r{^twitter accounts}, :accounts, command: true,
        restrict_to: :tweeters, help: {
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

        account = account_for(response)
        return response.relpy(no_accounts) unless account["secret"]

        client = twitter_client(account["token"], account["secret"])
        tweet = client.update(tweet)

        twitter_data.set_last_tweet(account["username"], tweet.id)
        response.reply(tweet.url)
      end

      def untweet(response)
        account = account_for(response)
        return response.relpy(no_accounts) unless account["secret"]

        last_id = twitter_data.get_last_tweet(account["username"])
        return response.reply("Couldn't find a last tweet!") if last_id.nil?

        client = twitter_client(account["token"], account["secret"])
        client.destroy_status(last_id)
        response.reply("Removed last tweet.")
      end

      def account_for(response)
        twitter_data.account(twitter_data.usernames.first)
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
        names = twitter_data.usernames

        if names.empty?
          "No authorized accounts. Use `twitter accounts add` to add one."
        else
          "Authorized Twitter accounts:\n" + names.map{|n| " - @#{n}\n" }.join
        end
      end

      def add_account
        "Authorize your account for tweeting here:\n" \
          "#{twitter_data.bot_uri('/twitter/login')}"
      end

      def remove_account(name)
        twitter_data.remove_account(name)
        "Removed @#{name}."
      end

      # def channels(response)
      #   # do channel stuff here
      # end

      def login_with_twitter(request, response)
        # Get an oauth_token from Twitter
        request_token = twitter_data.create_request_token

        # Redirect the user to the Twitter login URL
        response.status = 302
        response.headers["Location"] = request_token.authorize_url
      end

      def add_twitter_account(request, response)
        # Load the request_token hash from Redis (by oauth_token)
        request_token = twitter_data.find_request_token(request.params["oauth_token"])

        # Use the RequestToken to `get_access_token` with the oauth_verifier
        access_token = request_token.get_access_token(
          oauth_verifier: request.params["oauth_verifier"])

        # Save the twitter creds with username, token, and secret
        client = twitter_client(access_token.token, access_token.secret)
        username = client.user.screen_name
        twitter_data.add_account(username, access_token)

        response.body << "Done! You can now tweet from @#{username}."
      end

    private

      def twitter_data
        @twitter_data ||= Data.new(redis, config, robot)
      end

      def twitter_client(token, secret)
        ::Twitter::REST::Client.new do |c|
          c.consumer_key        = config.consumer_key
          c.consumer_secret     = config.consumer_secret
          c.access_token        = token
          c.access_token_secret = secret
        end
      end

      Lita.register_handler(self)
    end
  end
end
