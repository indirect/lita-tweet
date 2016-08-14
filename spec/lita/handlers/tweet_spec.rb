require "spec_helper"

describe Lita::Handlers::Tweet, lita_handler: true do
  # Chat routes
  {
    "tweet some text" => :tweet,
    "untweet" => :untweet,
    "twitter accounts" => :accounts,
    "twitter accounts add" => :accounts,
    "twitter accounts remove foo" => :accounts,
    "twitter default foo" => :default,
    "twitter map" => :map,
    "twitter map foo" => :map,
    "twitter unmap foo" => :unmap
  }.each do |command, method|
    it { is_expected.to route_command(command).
         with_authorization_for(:tweeters).
         to(method) }
  end

  # HTTP routes
  {
    "/twitter/auth" => :twitter_auth,
    "/twitter/callback" => :twitter_auth_callback
  }.each do |route, method|
    it { is_expected.to route_http(:get, route).to(method) }
  end

  before(:each) do
    Lita::Authorization.new(registry.config).add_user_to_group!(source.user, :tweeters)
  end

  describe "#tweet" do
    context "without an authorized account" do
      it "should complain" do
        send_command("tweet some text")
        expect(replies).to include(/no accounts/i)
      end
    end

    context "with an authorized account" do
      before do
        subject.twitter_data.add_account("token", "secret", "handle")
      end

      it "should send a tweet" do
        stub_request(:post, "https://api.twitter.com/1.1/statuses/update.json").
          with(body: {status: "some text"}).to_return(status: 200, body: %q[{
            "created_at": "Sun Aug 14 01:53:54 +0000 2016",
            "id": 12345,
            "text": "some text",
            "user": {
              "id": 123,
              "screen_name": "handle",
              "created_at": "Wed Nov 04 17:18:22 +0000 2009"
            }
          }])
        send_command("tweet some text")
        expect(replies).to include("https://twitter.com/handle/status/12345")
      end
    end
  end
end
