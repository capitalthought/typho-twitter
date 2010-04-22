# Note the tests at the bottom.  You can test this class by running it standalone in the interpreter.

require 'rubygems'
require 'wdd-ruby-ext'
require "cgi"
require "net/http"
require "uri"
require "time"
require "typhoeus"
require "pp"
require 'json'
require 'base64'
require 'logger'

# Class to abstract access to Twitter's Web Traffic API.
# Makes use of the Typhoeus gem to enable concurrent API calls.

class TyphoTwitter
  
  include WDD::Utilities
  
  private
  
  def logger  
    @logger
  end
  
  def puts message
    logger.debug message
  end
  
  public
  
  class HTTPException < RuntimeError
    attr :code
    attr :body
    
    def initialize( code, body )
      @code = code
      @body = body
      super( "#{code} - #{body}" )
    end
  end
  
  class TwitterException < RuntimeError
    attr :code
    attr :body
    
    def initialize( code, body )
      @code = code
      @body = body
      super( "#{code} - #{body}" )
    end
  end
    
  attr :login
  attr :password
  attr :headers
  
  # Constants 
  DEFAULT_REQUEST_TIMEOUT = 10000
  DEFAULT_CONCURRENCY_LIMIT = 40
  
  # +login+ - Twitter account login to use for authentication
  # +password+ - Password for Twitter login
  # +options+ - :request_timeout Request timeout value in miliseconds
  # +options+ - :concurrency_limit Maximum number of concurrent Typhoeus requests
  # +options+ - :logger Logger to use - defaults to standard out with DEBUG level if not specified.
  def initialize login, password, options={}
    @login, @password = login, password
    b64_encoded = Base64.b64encode("#{login}:#{password}")
    @headers = {"Authorization" => "Basic #{b64_encoded}"}
    @request_timeout = options[:request_timeout] || DEFAULT_REQUEST_TIMEOUT
    @concurrency_limit = options[:concurrency_limit] || DEFAULT_CONCURRENCY_LIMIT
    @logger = options[:logger]
    if @logger.nil?
      $stdout.sync = true
      @logger = Logger.new( $stdout )
      @logger.level = Logger::DEBUG
    end
  end

  # Executes a batch of Twitter calls.  Automatically handles retries when possible on failures.
  # Returns a hash where each +data_array+ element is a key mapping to either 
  # a hash containing the results of the twitter call or a TwitterException object of the twitter call failed.
  # If +data_array+ is bigger than the concurrency_limit set in the TyphoTwitter constructor, it is broken
  # up into batches of requests by Typhoeus automatically.
  # +data_array+ - An array of data inputs, one for each twitter call
  # +&block+ - A block that accepts an element of +data_array+ and returns a Tyhpoeus::Request object.
  def typho_twitter_batch data_array, &block
    json_results = {}
    retries = 0
    hydra = Typhoeus::Hydra.new(:max_concurrency => @concurrency_limit)
    hydra.disable_memoization
    
    data_array.each do |data_input|
      request = yield( data_input )
      # printvar :request, request
      request.on_complete do |response|
        puts "[#{response.code}] - #{request.url}"
        case response.code
        when 200:
          begin
            json_object = JSON.parse( response.body )
            json_results[data_input] = json_object
            retries = 0
          rescue JSON::ParserError
            puts response.body
            puts "TWITTER: #{$!.inspect}"
            retries += 1
            sleep_time = retries ** 2
            puts "Will retrying after sleeping for #{sleep_time} seconds"
            sleep sleep_time
            hydra.queue request
          end
        when 0:
          puts "**** Twitter Timeout for #{data_input}."
          retries += 1
          sleep_time = retries ** 2
          puts "Will retry after sleeping for #{sleep_time} seconds"
          sleep sleep_time
          hydra.queue request          
        when 400:
          puts "**** Twitter Rate Limit Exceeded for #{data_input}."
          retries += 1
          sleep_time = retries ** 2
          puts "Will retry after sleeping for #{sleep_time} seconds"
          sleep sleep_time
          hydra.queue request          
        when 401:
          puts "**** Twitter Authorization Failed for #{data_input}."
          puts "Request URL: #{request.url}"
          json_results[data_input] = TwitterException.new(response.code, response.body)
        when 404:
          puts "Unknown data_input: #{data_input}"              
          puts "Request URL: #{request.url}"
          json_results[data_input] = TwitterException.new(response.code, response.body)
        when 502:
          puts "Twitter Over capacity for data_input: #{data_input}.  Will retry."
          puts "Request URL: #{request.url}"
          retries += 1
          sleep_time = retries ** 2
          puts "Will retry after sleeping for #{sleep_time} seconds"
          sleep sleep_time
          hydra.queue request
        when 500:
          puts "Twitter server error for data_input: #{data_input}.  Will retry."
          puts "Request URL: #{request.url}"
          retries += 1
          sleep_time = retries ** 2
          puts "Will retry after sleeping for #{sleep_time} seconds"
          sleep sleep_time
          hydra.queue request
        else
          logger.error "Unexpected HTTP result code: #{response.code}\n#{response.body}"
          logger.error "Request URL: #{request.url}"
          json_results[data_input] = TwitterException.new(response.code, response.body)
        end        
      end
      hydra.queue request
    end
    hydra.run
    json_results
  end  
  

  # Retrieves the user data for a group of screen_names from Twitter.
  # +id_array+ = An array twitter user ids, one for each user to get data for.  Can be user_ids or screen_names.
  # Returns a Hash of objects from Twitter
  def get_users_show id_array
    typho_twitter_batch( id_array ) do |twitter_id|
      if twitter_id.is_a? Fixnum
        request = Typhoeus::Request.new("http://twitter.com/users/show.json?user_id=#{twitter_id}",
          :headers => @headers,
          :timeout => @request_timeout # miliseconds          
        )
      else
        request = Typhoeus::Request.new("http://twitter.com/users/show.json?screen_name=#{twitter_id}",
          :timeout => @request_timeout, # miliseconds          
          :headers => @headers
        )
      end
      request
    end
  end  

  # Retrieves the followers records for a group of twitter_ids from Twitter.
  # +twitter_id_array+ = An array twitter user ids, one for each user to get data for
  def get_statuses_followers twitter_id_array, limit=nil
    master_results = {}
    process_statuses_followers( twitter_id_array ) do |twitter_id, results|
      master_results[twitter_id] ||= []
      if results.is_a? TwitterException
        master_results[twitter_id] = results
        false
      else
        master_results[twitter_id] += results
        if limit && master_results[twitter_id].length >= limit
          master_results[twitter_id] = master_results[twitter_id].slice(0, limit)
          continue = false
        else
          continue = true
        end
        puts "#{twitter_id} - #{master_results[twitter_id].length} followers retrieved."
        continue
      end
    end
    master_results
  end  

  # Retrieves the followers records for a group of twitter_ids from Twitter and feeds them to the supplied
  # block one page at a time.  The block passed is expected to return a true or false value.  If it 
  # returns true, fetching of followers will continue for that twitter_id.  If it returns false, fetching
  # of followers will be aborted for that twitter_id only.  This allows a batch of fetches to be started for
  # multiple users.  Fetching of individual user's followers may be aborted while continuing the others.
  # +twitter_ids+ = An array twitter twitter_ids, one for each user to get data for.
  #
  # Returns nil.
  #
  # eg.
  #
  # process_statuses_followers( ['bdoughty', 'joshuabaer'] ) do |twitter_id, followers|
  #   puts "Twitter user #{twitter_id}"
  #   continue = true
  #   followers.each do |follower|
  #     continue = false if follower[:twitter_id] == 'needle'
  #   end
  #   continue 
  # end
  def process_statuses_followers twitter_id_array, &block

    raise "You must supply a block to this method." if !block_given?    
    # Track the proper Twitter API cursor for each twitter_id.  Twitter requests an initial cursor of -1 (to begin paging)
    cursor_tracker = {}
    twitter_id_array.each do |twitter_id|
      cursor_tracker[twitter_id] = -1
    end
    
    while( cursor_tracker.size > 0 )
      twitter_results = typho_twitter_batch( cursor_tracker.keys ) do |twitter_id|
        if twitter_id.is_a? Fixnum
          request = Typhoeus::Request.new("http://twitter.com/statuses/followers.json?cursor=#{cursor_tracker[twitter_id]}&user_id=#{twitter_id}",
            :headers => @headers,
            :timeout => @request_timeout
          )
        else
          request = Typhoeus::Request.new("http://twitter.com/statuses/followers.json?cursor=#{cursor_tracker[twitter_id]}&screen_name=#{twitter_id}",
            :timeout => @request_timeout,
            :headers => @headers
          )
        end
      end
      cursor_tracker = {}
      twitter_results.each do |twitter_id, results|
        next_cursor = 0
        if results.is_a?( Hash ) && results['users'] && results['users'].length > 0
          next_cursor = results["next_cursor"]
          continue = yield( twitter_id, results['users'] )
        else
          continue = yield( twitter_id, results ) # return the exception
        end
        if next_cursor != 0 && continue
          cursor_tracker[twitter_id] = next_cursor
        else
          cursor_tracker.delete( twitter_id ) # remove the twitter_id from processing
        end
      end
    end
        
    nil
  end  

  # Retrieves the followers ids for a group of twitter_ids from Twitter and feeds them to the supplied
  # block one page at a time.  The block passed is expected to return a true or false value.  If it 
  # returns true, fetching of follower ids will continue for that twitter_id.  If it returns false, fetching
  # of follower ids will be aborted for that twitter_id only.  This allows a batch of fetches to be started for
  # multiple users.  Fetching of individual user's followers ids may be aborted while continuing the others.
  # +twitter_ids+ = An array twitter twitter_ids, one for each user to get data for.
  #
  # Returns nil.
  #
  # eg.
  #
  # process_followers_ids( ['bdoughty', 'joshuabaer'] ) do |twitter_id, follower_ids|
  #   puts "Twitter user #{twitter_id}"
  #   continue = true
  #   follower_ids.each do |follower_id|
  #     continue = false if follower_id == SOME_TWITTER_USER_ID
  #   end
  #   continue 
  # end
  def process_followers_ids twitter_id_array, &block

    raise "You must supply a block to this method." if !block_given?    
    # Track the proper Twitter API cursor for each twitter_id.  Twitter requests an initial cursor of -1 (to begin paging)
    cursor_tracker = {}
    twitter_id_array.each do |twitter_id|
      cursor_tracker[twitter_id] = -1
    end
    
    while( cursor_tracker.size > 0 )
      twitter_results = typho_twitter_batch( cursor_tracker.keys ) do |twitter_id|
        if twitter_id.is_a? Fixnum
          request = Typhoeus::Request.new("http://twitter.com/followers/ids.json?cursor=#{cursor_tracker[twitter_id]}&user_id=#{twitter_id}",
            :headers => @headers,
            :timeout => @request_timeout
          )
        else
          request = Typhoeus::Request.new("http://twitter.com/followers/ids.json?cursor=#{cursor_tracker[twitter_id]}&screen_name=#{twitter_id}",
            :headers => @headers,
            :timeout => @request_timeout
          )
        end
      end
      cursor_tracker = {}
      twitter_results.each do |twitter_id, results|
        next_cursor = 0
        if results.is_a?( Hash ) && results['ids'] && results['ids'].length > 0
          next_cursor = results["next_cursor"]
          continue = yield( twitter_id, results['ids'] )
        else
          continue = yield( twitter_id, results ) # return the exception
        end
        if next_cursor != 0 && continue
          cursor_tracker[twitter_id] = next_cursor
        else
          cursor_tracker.delete( twitter_id ) # remove the twitter_id from processing
        end
      end
    end
        
    nil
  end  

  # Retrieves all timeline updates for a group of twitter_ids from Twitter.
  # This method calls process_statuses_user_timeline() with a block to aggregate the updates.
  # +twitter_id_array+ = An array twitter user ids, one for each user to get data for
  # Returns aggregated updates as a Hash with twitter_ids as keys, and arrays of updates as values.
  # If an unresolvable exception occurred fetching a particular twitter_id, then the resulting TwitterException
  # is returned for that screen name instead of an array of updates.
  def get_statuses_user_timeline twitter_id_array
    master_results = {}
    process_statuses_user_timeline( twitter_id_array ) do |twitter_id, results|
      master_results[twitter_id] ||= []
      if results.is_a? TwitterException
        master_results[twitter_id] = results
        false
      else
        master_results[twitter_id] += results
        true
      end
    end
    master_results
  end
  
  # Retrieves the timeline updates for a group of twitter_ids from Twitter and feeds them to the supplied
  # block one page at a time.  The block passed is expected to return a true or false value.  If it 
  # returns true, fetching of updates will continue for that twitter_id.  If it returns false, fetching
  # of updates will be aborted for that twitter_id only.  This allows a batch of fetches to be started for
  # multiple users.  Fetching of individual user's updates may be aborted while continuing the others.
  # +twitter_ids+ = An array twitter user ids, one for each user to get data for.
  #
  # Returns nil.
  #
  # eg.
  #
  # process_statuses_user_timeline( ['bdoughty', 'joshuabaer'] ) do |twitter_id, updates|
  #   puts "Twitter user #{twitter_id}"
  #   updates.each do |update|
  #     # do something with each status update
  #   end
  #   (twitter_id == 'bdoughty')  # block return value - aborts 'joshuabaer' after the first page, continues 'bdoughty'
  # end
  def process_statuses_user_timeline twitter_ids, &block
    page = 0
    count = 200
    while twitter_ids.length > 0
      page += 1 # Twitter starts with page 1
      puts "Getting page #{page} for timelines."
      twitter_results = typho_twitter_batch( twitter_ids ) do |twitter_id|
        if twitter_id.is_a? Fixnum
          request = Typhoeus::Request.new("http://twitter.com/statuses/user_timeline.json?user_id=#{twitter_id}&page=#{page}&count=#{count}",
            :headers => @headers,
            :timeout => @request_timeout
          )
        else
          request = Typhoeus::Request.new("http://twitter.com/statuses/user_timeline.json?screen_name=#{twitter_id}&page=#{page}&count=#{count}",
            :headers => @headers,
            :timeout => @request_timeout
          )
        end
      end

      twitter_ids = []
      twitter_results.each do |twitter_id, results|
        if results && !( results.respond_to?( :length ) && results.length == 0 )
          if block_given? 
            continue = yield( twitter_id, results )
          else
            raise "You must supply a block to this method."
          end
          # keep fetching for this twitter_id only if the block said to and there are more updates.
          twitter_ids << twitter_id if continue && !results.is_a?( TwitterException ) && results.length != 0
        end
      end
    end
    nil
  end  

end

