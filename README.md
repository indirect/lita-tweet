# lita-tweet

[![Build Status](https://travis-ci.org/indirect/lita-tweet.png?branch=master)](https://travis-ci.org/indirect/lita-tweet)
[![Coverage Status](https://coveralls.io/repos/indirect/lita-tweet/badge.png)](https://coveralls.io/r/indirect/lita-tweet)

Allows the Lita chat bot to tweet on command.


## Installation

Add lita-tweet to your Lita instance's Gemfile:

```ruby
gem "lita-tweet"
```

## Configuration

To make this plugin work, you'll need to set at least `TWITTER\_CONSUMER\_KEY` and `TWITTER\_CONSUMER\_SECRET`. If you want to host the bot at a specific URL, rather than the default `0.0.0.0:1234` type address, you'll also need to set `SERVER\_URL` so that the bot knows where to send users and Twitter auth callbacks.

```ruby
require "lita-tweet" if ENV.has_key?("TWITTER_CONSUMER_KEY")

Lita.configure do |config|
  if ENV.has_key?("TWITTER_CONSUMER_KEY")
    config.handlers.tweet.http_url = ENV["SERVER_URL"]
    config.handlers.tweet.consumer_key = ENV.fetch("TWITTER_CONSUMER_KEY")
    config.handlers.tweet.consumer_secret = ENV.fetch("TWITTER_CONSUMER_SECRET")
  end
end
```

## Usage

To authorize an account for tweeting, use the command `twitter accounts add` and follow the instructions. To tweet, use the command `tweet some text that should go in the tweet`. To delete the last tweet, use the command `untweet`. For a complete list of commands, including how to map specific twitter accounts to specific chat channels, see the output from the command `help`.
