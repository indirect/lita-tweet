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
      route %r{^twitter map}, :map, command: true, restrict_to: :tweeters,
        help: {
          "twitter map" => "List account to channel mappings.",
          "twitter map default ACCOUNT" => "Set the default account to tweet from",
          "twitter map NAME ACCOUNT" => "Tweet as ACCOUNT when told to tweet from NAME.",
          "twitter map NAME default" => "Tweet as the default twitter account when told to tweet in channel CHANNEL."
        }

      TWITTER_AUTH_URL = "/twitter/auth"
      TWITTER_AUTH_CALLBACK_URL = "/twitter/callback"
      http.get TWITTER_AUTH_URL, :twitter_auth
      http.get TWITTER_AUTH_CALLBACK_URL, :twitter_auth_callback

      def tweet(response)
        text = response.match_data[1]
        if text.nil? || text.empty?
          return response.reply("I need something to tweet!")
        end

        account = account_for(response.message.source)
        return response.relpy(no_accounts) if account.nil?

        tweet = account.tweet(text)
        twitter_data.set_last_tweet(account.username, tweet.id)
        response.reply(tweet.url)
      end

      def untweet(response)
        account = account_for(response.message.source)
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

      def map(response)
        name, account = response.args[1..2]
        account.gsub!(/^@/, '') if account

        return response.reply(list_map) unless name
        return response.reply(invalid_name) unless valid_name?(name)
        return response.reply(set_default_map(account)) if name == "default"
        return response.reply(clear_map(name)) if account == "default"
        response.reply(set_map(name, account))
      end

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

      def valid_name?(name)
        %w[@ #].include?(name[0])
      end

      def invalid_name
        "Names for mapping need to be @username (for DMs) or #channel!"
      end

      def list_map
        return "No accounts are configured." unless default_account

        channels = twitter_data.channel_map
        if channels.empty?
          "All channels will tweet as @#{default_account.username}"
        else
          "Channel twitter accounts:\n" +
            channels.map{|c,u| " - #{c} will tweet as @#{u}" }.join("\n") +
            "\n - all other channels will tweet as @#{default_account.username}"
        end
      end

      def set_default_map(username)
        if twitter_data.set_default(username)
          "Done. The default account is now @#{username}."
        else
          "I can't tweet as @#{username}, so it can't be the default."
        end
      end

      def set_map(channel, username)
        if twitter_data.set_channel_map(channel, username)
          "From now on, tweets from #{channel} will use the twitter account @#{username}."
        else
          "I can't tweet as @#{username}, so it can't be mapped."
        end
      end

      def clear_map(channel)
        twitter_data.clear_channel_map(channel)
        if default_account
          "Tweets from #{channel} will come from the default account, @#{default_account.username}."
        else
          "No accounts are configured for tweeting."
        end
      end

      def account_for(source)
        channel_name = sender_for(source)
        twitter_data.get_channel_account(channel_name) || default_account
      end

      def default_account
        twitter_data.default_account
      end

      def sender_for(source)
        if source.private_message
          handle = source.user.metadata["mention_name"] || source.user.name
          handle ? "@#{handle}" : nil
        else
          # lita-slack has a bug where source.room_object.name is wrong,
          # and to get the correct name you have to find the room again
          # https://github.com/litaio/lita-slack/issues/44
          name = Lita::Room.find_by_id(source.room).name
          name ? "##{name}" : nil
        end
      end

      def twitter_data
        @twitter_data ||= Data.new(redis, config, robot)
      end

      Lita.register_handler(self)
    end
  end
end
