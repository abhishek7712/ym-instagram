require "sinatra"
require "instagram"
require 'net/ssh'
require 'net/sftp'
require 'data_mapper'

# Enable sinatra sessions (so we stay logged in)
enable :sessions
#set :bind, '172.16.0.11'

# This is where Instagram will redirect us after authorization
CALLBACK_URL = "http://0.0.0.0:4567/oauth/callback"

# Set up instagram client
# Client secret is read from a file outside of the repo
Instagram.configure do |config|
  config.client_id = "54cb4da7c4eb4a2fa6e8c0116a1f53d7"
  config.client_secret = "d1207e8a96754f439100285917531b8a" #File.open(File.expand_path(File.dirname(__FILE__), "client_secret")).read
end





DataMapper.setup(:default, {
	:adapter  => 'mysql',
	:host     => 'localhost',
	:username => 'root' ,
	:password => '',
	:database => 'yminst_development'})  

DataMapper::Logger.new(STDOUT, :debug)
#DataMapper::Model.raise_on_save_failure = true

class InstagramImage
  include DataMapper::Resource
  property :id,				Serial
  property :caption,		String, :length => 255
  property :created_time,	DateTime
  property :user,			Serial
  property :location,		Text
  property :images,			Text
  property :instagram_id, 	String

end

class User
	include DataMapper::Resource
	property :id,				Serial
	property :full_name,		String, :length => 255
	property :profile_picture,	String, :length => 255
	property :website,			String, :length => 255
	property :username,			String, :length => 255
	property :bio,				Text
	property :instagram_id,		String, :length => 255
end

DataMapper.finalize
DataMapper.auto_upgrade!


module Instagram
	class Client
		module InstanceMethodsHack
	  		def multipage_user_media_feed(*args)
				options = args.first.is_a?(Hash) ? args.pop : {}
				response = get('users/self/feed',options)

				next_max_id = response.pagination.next_max_id

		  		while true
					begin
						puts next_max_id
						next_response = get('users/self/feed',{:count => 1000, :max_id => next_max_id})
			 			response.data = response.data + next_response["data"]
						if !next_response.pagination.next_max_id
							break
						else
							next_max_id = next_response.pagination.next_max_id
						end
					rescue Instagram::NotFound => e
			  			#No more pages available, let's return.
			  			puts e.inspect
			 			break
					end
		  		end
				puts response.data.length
				response
	  		end
		end
		include InstanceMethodsHack
	end
end

# Strip unused fields from media_item hash
def strip h
	h.reject {|a| [
		"tags",
		"type",
		"filter",
		"comments",
		"filtered",
		"created_time",
		"link",
		"likes",
		"user_has_liked",
		"id",
		"user",
	].include? a}
end

def upload local_file
	Net::SSH.start('172.16.0.11', 'knight', :password => 'broadway') do |ssh|
		ssh.sftp.connect do |sftp|
			sftp.upload!(local_file, "/data/www/apache2/htdocs/instagram/feed.json")  
		end
	end
end

# Select only photos with valid tags
def valid_tags? tags
	tags.select{ |tag| ["ym", "yourmajestyco"].include? tag }.length > 0
end

def valid_text? text
	["#ym", "#yourmajestyco"].include? text
end


def valid_item? media_item
	if valid_tags?(media_item.tags)
		return true
	end
	unless media_item.caption.nil?
		if valid_text?(media_item.caption.text)
			return true
		end
	end
	if media_item.comments.count > 0
		for comment in media_item.comments.data
			 if valid_text?(comment.text)
			 	return true
			 end
		end
	end
	return false
end

# Sinatra stuff for authorization
get "/" do
	'<a href="/oauth/connect">Connect with Instagram</a>'
end

get "/oauth/connect" do
	redirect Instagram.authorize_url(:redirect_uri => CALLBACK_URL)
end

get "/oauth/callback" do
	response = Instagram.get_access_token(params[:code], :redirect_uri => CALLBACK_URL, :grant_type => 'authorization_code')
	session[:access_token] = response.access_token

	Instagram.configure do |config|
  		config.access_token = response.access_token
	end

	redirect "/feed"
end

# Writes the photo feed to a json file.
# The feed route will refresh itself every 5 minutes using JS, to keep the feed fresh!
get "/feed" do
	client = Instagram.client(:access_token => session[:access_token])

	# Use our hack method to get up to 5 "pages" of the photo feed. Then select only photos tagged with "ym".
	feed = client.multipage_user_media_feed({:count => 1000}).data
	#feed = Instagram.user_media_feed.data
	# Write feed as json
	#open(File.expand_path(File.dirname(__FILE__) + "/../middleman/build/feed.json"), 'w') { |f| f << feed.map{|h| strip h }.to_json }
	#upload(File.expand_path(File.dirname(__FILE__) + "/../middleman/build/feed.json"))


	# Also render photos for fun
	html = "<h1>#{client.user.username}'s recent photos</h1>"

	for media_item in feed
		if valid_item?(media_item)
			html << "<img src='#{media_item.images.thumbnail.url}'>"
			begin
				img = InstagramImage.create(:caption => media_item.caption.nil? ? '' : media_item.caption.text,
											:created_time => DateTime.strptime(media_item.created_time,'%s'),
											:user => media_item.user.to_json,
											:instagram_id => media_item.id,
											:location => media_item.location.nil? ? '' : media_item.location.to_json,
											:images => media_item.images.to_json)			
			rescue Exception => e
				puts e.inspect
				puts "\n\n"
				puts media_item
			end
		end
	end
  
  # Refresh every 5 minutes
  html << <<-EOS 
	<script type='text/javascript'>
	
	function loadXMLDoc()
	{
		var xmlhttp;
		if (window.XMLHttpRequest)
		{// code for IE7+, Firefox, Chrome, Opera, Safari
			xmlhttp=new XMLHttpRequest();
		}
		else
		{// code for IE6, IE5
			xmlhttp=new ActiveXObject("Microsoft.XMLHTTP");
		}
		xmlhttp.onreadystatechange=function()
		{
			if (xmlhttp.readyState==4 && xmlhttp.status==200)
			{
				//document.getElementById("myDiv").innerHTML=xmlhttp.responseText;
		  	}
		}
		xmlhttp.open("GET","/feed",true);
		xmlhttp.send();
	}  
	setInterval("loadXMLDoc()", 300000);
	//setTimeout('location.reload(true);', 300000);
	</script>
  EOS
  
end