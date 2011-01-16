# A brutally simple test suite to verify desired functionality for +my+ application.
# TODO: Generalize, and make unit tests.
# NOTE: These tests are meant to be run against a white-listed account.  
# To authorize with Twitter, you need to copy the oauth.yaml.example to oauth.yaml
# and populate it with the OAuth credentials for a white-listed account.

BASE_DIR="#{File.dirname(__FILE__)}/../lib"
$: << BASE_DIR
require 'typho-twitter'
require 'test/unit'
include Test::Unit::Assertions
include WDD::Utils

UNKNOWN_ID = 'mixtercox'
TEST_USER_IDS = [ 
  UNKNOWN_ID,
  "bdoughty", 
  "joshuabaer", 
  "jotto", 
  "hoonpark", 
  "aplusk", 
  "barackobama", 
  "oprah",
  "damon",
  "TreyPlaysTunes",
  "fiveredwoods",
  "austinonrails",
  "remlap42",
  ]

# basic test that all is functioning and that we can lookup an array of screen_names successfully
def test_users_show_multi
  screen_names = TEST_USER_IDS
  screen_name_array = screen_names
  # 10.times do |i|
  #   screen_name_array += screen_names.map{|c| c+i}
  # end
  twitter = TyphoTwitter.new( @oauth_options )
  # responses = twitter.typho_twitter_batch screen_name_array
  responses = twitter.get_users_show( screen_name_array )
  responses.each do |key, value|
    puts "#{key} => "
    if key == UNKNOWN_ID
      assert_instance_of( TyphoTwitter::TwitterException, value )
    end
    puts "#{value}"
  end
  puts "# Responses: #{responses.size}"
  assert_equal( responses.size, screen_name_array.size )
end

# Verify that things still function correctly if we are only looking up one user.
def test_users_show_single
  screen_names = [ 
    "bdoughty"
    ]
  screen_name_array = screen_names
  # screen_name_array += screen_names
  twitter = TyphoTwitter.new( @oauth_options )
  responses = twitter.get_users_show( screen_name_array )
  responses.each do |key, value|
    puts "#{key} => "
    puts "#{value}"
  end
  puts "# Responses: #{responses.size}"
  assert_equal( responses.size, screen_name_array.size )
end

# Test getting timelines passing a block to process_statuses_user_timeline.
def test_process_statuses_user_timeline
  screen_names = TEST_USER_IDS
  screen_name_array = screen_names
  # screen_name_array += screen_names
  twitter = TyphoTwitter.new( @oauth_options )
  user_updates = {}
  twitter.process_statuses_user_timeline( screen_name_array ) do |screen_name, updates|
    if screen_name == UNKNOWN_ID
      assert_instance_of( TyphoTwitter::TwitterException, updates )
      puts "Verified that #{UNKNOWN_ID} is unknown."
      false
    else
      user_updates[screen_name] ||= []
      user_updates[screen_name] += updates
      true
    end
  end
  user_updates.each do |key, value|
    puts "#{key} => "
    puts value.length
  end
  # puts "# Responses: #{responses.size}"
  assert_equal( user_updates.size, screen_name_array.size - 1)
end  

# Test getting timelines from get_statuses_user_timeline
def test_get_statuses_user_timeline
  screen_names = TEST_USER_IDS
  screen_name_array = screen_names
  # screen_name_array += screen_names
  twitter = TyphoTwitter.new( @oauth_options )
  user_updates = twitter.get_statuses_user_timeline( screen_name_array )
  user_updates.each do |key, value|
    puts "#{key} => "
    if key == UNKNOWN_ID
      assert_instance_of( TyphoTwitter::TwitterException, value )
      puts "Verified that #{UNKNOWN_ID} is unknown."
    else
      case value.class.to_s
      when 'TyphoTwitter::TwitterException'
        puts value.inspect
      else
        puts value.length
      end
    end
    # pp value
  end
  # puts "# Responses: #{responses.size}"
  assert_equal( user_updates.size, screen_name_array.size )
end

# Test getting followers
def test_get_statuses_followers
  # screen_names = ['hoonpark', 'bdoughty', 'jotto']
  screen_names = ['bdoughty']
  screen_name_array = screen_names
  # screen_name_array += screen_names
  twitter = TyphoTwitter.new( @oauth_options )
  followers = twitter.get_statuses_followers( screen_name_array )
  followers.each do |screen_name, results|
    puts "#{screen_name}:"
    puts "#{results.length} followers:"
    results.each do |follower|
      printvar :follower, follower
    end
    # pp value
  end
  assert_equal( followers.size,  screen_name_array.size )

  screen_names = ['basdkhasdf']
  screen_name_array = screen_names
  # screen_name_array += screen_names
  twitter = TyphoTwitter.new( @oauth_options )
  followers = twitter.get_statuses_followers( screen_name_array )
  followers.each do |screen_name, results|
    puts "#{screen_name}:"
    assert_instance_of TyphoTwitter::TwitterException, results
  end
end

# Test getting followers
def test_get_statuses_followers_with_limit
  # screen_names = ['hoonpark', 'bdoughty', 'jotto']
  screen_names = ['joshuabaer']
  screen_name_array = screen_names
  # screen_name_array += screen_names
  twitter = TyphoTwitter.new( @oauth_options )
  followers_data = twitter.get_statuses_followers( screen_name_array, 100 )
  followers_data.each do |screen_name, followers|
    puts "#{screen_name}:"
    puts "#{followers.length} followers:"
    followers.each do |follower|
      printvar :follower, follower['screen_name']
    end
    assert_equal( followers.size <= 100,  true )
    # pp value
  end
  assert_equal( followers_data.size,  screen_name_array.size )

  screen_names = ['basdkhasdf']
  screen_name_array = screen_names
  # screen_name_array += screen_names
  twitter = TyphoTwitter.new( @oauth_options )
  followers = twitter.get_statuses_followers( screen_name_array )
  followers.each do |screen_name, results|
    puts "#{screen_name}:"
    assert_instance_of TyphoTwitter::TwitterException, results
  end
end

# Test getting timelines passing a block to process_statuses_user_timeline.  Process the updates and abort
# on condition
def test_process_statuses_user_timeline_with_abort
  screen_names = TEST_USER_IDS
  screen_name_array = screen_names
  # screen_name_array += screen_names
  twitter = TyphoTwitter.new( @oauth_options )
  user_updates = {}
  twitter.process_statuses_user_timeline( screen_name_array ) do |screen_name, results|
    puts "#{screen_name} =>"
    continue = true
    if results.is_a? TyphoTwitter::TwitterException
      puts "Exception for #{screen_name}: #{results.inspect}"
      continue = false
    else
      results.each do |update|
        # puts update["text"]
        if update["text"] =~ /otherinbox/i
          puts "ABORTING #{screen_name} because of tweet:"
          puts update["text"]
          continue = false
          break
        end
      end
      user_updates[screen_name] ||= []
      user_updates[screen_name] += results
    end
    
    continue
  end
  user_updates.each do |key, value|
    puts "#{key} => "
    puts value.length
    # pp value
  end
  # puts "# Responses: #{responses.size}"
  assert_equal( user_updates.size, screen_name_array.size - 1 )
end  

def time_it method_id
  et = WDD::Utils::elapsed_time do
    self.send( method_id )
  end
  puts "========================================"
  puts "#{method_id.to_s} - #{et} seconds"
  puts
end

def run_tests
  @oauth_options = YAML.load_file(File.dirname($0)+'/oauth.yaml')
  if ARGV[0] && ARGV[0] != ""
    eval ARGV[0]
  else
    time_it :test_users_show_multi
    time_it :test_users_show_single
    time_it :test_process_statuses_user_timeline
    time_it :test_get_statuses_user_timeline
    time_it :test_get_statuses_followers
    time_it :test_get_statuses_followers_with_limit
    time_it :test_process_statuses_user_timeline_with_abort
  end
end

run_tests
