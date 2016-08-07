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

      TWITTER_AUTH_URL = "/twitter/auth"
      TWITTER_AUTH_CALLBACK_URL = "/twitter/callback"
      http.get TWITTER_AUTH_URL, :twitter_auth
      http.get TWITTER_AUTH_CALLBACK_URL, :twitter_auth_callback

      def tweet(response)
        text = response.match_data[1]
        if text.nil? || text.empty?
          return response.reply("I need something to tweet!")
        end

        account = account_for(response)
        return response.relpy(no_accounts) if account.nil?

        tweet = account.tweet(text)
        twitter_data.set_last_tweet(account.username, tweet.id)
        response.reply(tweet.url)
      end

      def untweet(response)
        account = account_for(response)
        return response.relpy(no_accounts) if account.nil?

        if account.untweet
          response.reply("Removed last tweet.")
        else
          response.reply("Couldn't find a last tweet to remove!")
        end
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

      # def channels(response)
      #   # do channel stuff here
      # end

      def twitter_auth(request, response)
        callback_url = TWITTER_AUTH_CALLBACK_URL
        request_token = twitter_data.create_request_token(callback_url)
        response.status = 302
        response.headers["Location"] = request_token.authorize_url
      end

      def twitter_auth_callback(request, response)
        token = request.params["oauth_token"]
        verifier = request.params["oauth_verifier"]
        account = twitter_data.authorize_account(token, verifier)
        response.body << "Done! You can now tweet from @#{account.username}."
      end

    private

      def list_accounts
        names = twitter_data.usernames

        if names.empty?
          "No authorized accounts. Use `twitter accounts add` to add one."
        else
          usernames = names.map{|n| " - @#{n}" }.join("\n")
          "Authorized Twitter accounts:\n" << usernames
        end
      end

      def add_account
        auth_uri = twitter_data.bot_uri(TWITTER_AUTH_URL)
        "Authorize your account for tweeting here:\n#{auth_uri}"
      end

      def remove_account(name)
        twitter_data.remove_account(name)
        "Removed @#{name}."
      end
      def account_for(response)
        twitter_data.account(twitter_data.usernames.first)
      end

      def twitter_data
        @twitter_data ||= Data.new(redis, config, robot)
      end

      Lita.register_handler(self)
    end
  end
end
