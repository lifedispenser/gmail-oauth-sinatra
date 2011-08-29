require "rubygems"
require "sinatra"
require 'json'
require "oauth"
require "oauth/consumer"
require 'haml'
require 'gmail'

enable :sessions

#this sets up the oauth configurations, like the request path and the token path
before do
  session[:oauth] ||= {}  
  
  consumer_key = "anonymous"
  consumer_secret = "anonymous"
  
  @consumer ||= OAuth::Consumer.new(consumer_key, consumer_secret,
    :site => "https://www.google.com",
    :request_token_path => '/accounts/OAuthGetRequestToken?scope=https://mail.google.com/%20https://www.googleapis.com/auth/userinfo%23email',
    :access_token_path => '/accounts/OAuthGetAccessToken',
    :authorize_path => '/accounts/OAuthAuthorizeToken'
  )
  
  if !session[:oauth][:request_token].nil? && !session[:oauth][:request_token_secret].nil?
    @request_token = OAuth::RequestToken.new(@consumer, session[:oauth][:request_token], session[:oauth][:request_token_secret])
  end
  
  if !session[:oauth][:access_token].nil? && !session[:oauth][:access_token_secret].nil?
    @access_token = OAuth::AccessToken.new(@consumer, session[:oauth][:access_token], session[:oauth][:access_token_secret])
  end
  
end

helpers do
  include Rack::Utils
  alias_method :h, :escape_html
end

get "/" do
  if @access_token #if we have received an access token on our request (meaning we have authenticated)
    gmail = Gmail.connect(:xoauth, "email address here:", #use your personal one at your own risk
			:token           => @access_token.token,
			:secret          => @access_token.secret,
			:consumer_key    => 'anonymous',
			:consumer_secret => 'anonymous'
		)
		# As long as you have @access_token.token and @access_token.secret, you can authenticate into gmail
		
		
		# After authentication, you can test out the functions you want to retrieve emails:
		# look in mailbox.rb of def emails in the gmail gem to see the options available
		
		@inbox = gmail.inbox.emails(:search => "custom email text")
		# gmail.inbox.emails(:search => "custom email").collect { |x| x.uid }
		# gmail.inbox.emails(:to => "Me")
		
    haml :index
  else #otherwise, sign in at /request
    '<a href="/request">Sign On</a>'
  end
end

get "/request" do #send us to gmail to get an auth_request token and secret
  @request_token = @consumer.get_request_token(:oauth_callback => "#{request.scheme}://#{request.host}:#{request.port}/auth") #redirect_url is at /auth
  session[:oauth][:request_token] = @request_token.token
  session[:oauth][:request_token_secret] = @request_token.secret
  redirect @request_token.authorize_url
end

get "/auth" do #once we've been redirected here, receive the access token and secret and use it to authenticate to gmail: 
  @access_token = @request_token.get_access_token :oauth_verifier => params[:oauth_verifier] 
  session[:oauth][:access_token] = @access_token.token
  session[:oauth][:access_token_secret] = @access_token.secret
  redirect "/"
end

get "/logout" do
  session[:oauth] = {}
  redirect "/"
end
