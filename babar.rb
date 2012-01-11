require 'typhoeus'
require 'json'
require 'digest/md5'
require 'cgi'



#This is a hideous hack, but it s the only way to force Ruby to issue POST requests to URLs with square brackets
module URI 
  class << self
    def parse_with_safety(uri)
      uri 
    end 
    alias parse parse_with_safety
  end 
end


module Babar
  #Babar is the Toodledo API wrapper
  class Base
   
    #Class-level instance variables - only need to be defined once for the application
    class << self; attr_accessor :toodle_app_token, :toodle_app_token_lifetime, :toodle_app_id end


    attr_accessor :session_token, :toodle_token_death

    def initialize(initial_args = {})
      #TODO rethink this initialization
      #
      ##TODO Class-level initialization
      #
      #TODO implement uid lookup from email
      if initial_args[:toodle_uid] and initial_args[:session_token] and initial_args[:toodle_password] and initial_args[:toodle_token_death]
        @toodle_uid = initial_args[:toodle_uid]
        @session_token = initial_args[:session_token]
        @toodle_password = initial_args[:toodle_password]
        @toodle_token_death = initial_args[:toodle_token_death]

      elsif initial_args[:toodle_uid] and initial_args[:toodle_password]
        #Authenticate this way
        @toodle_uid = initial_args[:toodle_uid]
        @toodle_password = initial_args[:toodle_password]
        @session_token, @toodle_token_death = self.refresh_session_token
      else
        raise ArgumentError, 'Must specify :toodle_uid and :toodle_password'
      end
      
    end

    def session_token
      refresh_session_token unless token_valid?
      return @session_token
    end
    
    #TODO add warning to this method
    #Debugging only
    def session_token=(new_token)
      @session_token = new_token
      @toodle_token_death = Time.now + Babar::Base.toodle_app_token_lifetime
      @session_token
    end

    #TODO make this a class method
    def refresh_session_token
        session_signature = Digest::MD5.hexdigest(@toodle_uid + Babar::Base.toodle_app_token) 
        session_token_url = "http://api.toodledo.com/2/account/token.php?" + self.parse_params({:userid => @toodle_uid, :appid => Babar::Base.toodle_app_id , :sig => session_signature,})
        puts session_signature, session_token_url
        @session_token = JSON.parse(Typhoeus::Request.get(session_token_url).body)["token"]
        @toodle_token_death = Time.now + Babar::Base.toodle_app_token_lifetime
        [@session_token, @toodle_token_death]
    end

    def token_valid?
      @session_token and @toodle_token_death > Time.now
    end

    def key
      refresh_key unless key_valid?
      #TODO figure out how to refresh key correctly
      @key
    end

    #For debugging purposes only!
    #If you set the key manually, you are responsible for tracking its expiry responsibly
    def key=(new_key)
      @key = new_key
    end

    def key_valid?
      token_valid? and @key
    end
    
    def refresh_key
      refresh_session_token unless token_valid?
      @key = Digest::MD5.hexdigest( Digest::MD5.hexdigest(@toodle_password) + Babar::Base.toodle_app_token + @session_token)
    end

    def parse_params(mapping, *args)
      if args.length == 0
        args = mapping.keys
      end
      args.collect{ |a| CGI::escape(a.to_s) + "=" + CGI::escape(mapping[a].to_s)}.join(";")
    end

    def post_params(array_of_objects_to_post)
      #Each object in the array must support to_json
      array_of_objects_to_post.collect{|task| task.to_json}.to_s
    end
    
    def get(endpoint, param_map, *args)
      url = "http://api.toodledo.com/2/#{endpoint}/get.php?key=#{self.key};" + parse_params(param_map, *args) 
      JSON.parse(Typhoeus::Request.get(url).body)
    end

    def modify(endpoint, action, desired_class,  array_of_hashes, array_field_name, delete_first_result, *args)
      #TODO whether to omit first
      #TODO check if this is even right
      #action is 'add', 'edit', or 'delete'
      url = "http://api.toodledo.com/2/#{endpoint}/#{action}.php?key=#{self.key};#{array_field_name}=" + CGI::escape(post_params(array_of_hashes, *args).gsub("\\", "").gsub(/\s?([\{\}])\s?/, '\1').gsub(/"\{/, '{').gsub(/\}"/, '}'))
      array_of_results = JSON.parse(Typhoeus::Request.post(url).body)
      array_of_results.delete_at(0) if delete_first_result
      array_of_results.collect{|json_result| desired_class.new(self, json_result}
    end


    def add(endpoint, desired_class, array_of_hashes, array_field_name, delete_first_result, *args)
      #url = "http://api.toodledo.com/2/#{endpoint}/add.php?key=#{self.key};#{array_field_name}=" + CGI::escape(post_params(array_of_hashes, *args).gsub("\\", "").gsub(/\s?([\{\}])\s?/, '\1').gsub(/"\{/, '{').gsub(/\}"/, '}'))
      modify(endpoint, 'add', desired_class, array_of_hashes, array_field_name, delete_first_result, *args)
    end

    def edit(endpoint, desired_class, array_of_hashes, array_field_name, delete_first_result, *args)
      modify(endpoint, 'edit', desired_class, array_of_hashes, array_field_name, delete_first_result, *args)
      #url = "http://api.toodledo.com/2/#{endpoint}/edit.php?key=#{self.key};#{array_field_name}=" + CGI::escape(post_params(array_of_hashes, *args).gsub("\\", "").gsub(/\s?([\{\}])\s?/, '\1').gsub(/"\{/, '{').gsub(/\}"/, '}'))
    end

    def delete(endpoint, desired_class, array_of_hashes, array_field_name, delete_first_result, *args)
      modify(endpoint, 'delete', desired_class, array_of_hashes, array_field_name, delete_first_result, *args)
      #url = "http://api.toodledo.com/2/#{endpoint}/delete.php?key=#{self.key};" + post_params(list_of_hash_endpoint_objs, *args) 
      Typhoeus::Request.post(url)
    end
    
    def get_tasks(param_map, *args)
      #Strip off the first element, since it is not a Task
      array_of_json_tasks = get("tasks", param_map, *args)
      array_of_json_tasks[1..-1].collect{|json_task| Babar::Task.new(self, json_task)}
    end


    def add_task(list_of_hash_tasks, *args)
      #Can accept either a single task (as a Hash) or an Array of tasks (each represented as a Hash)
      list_of_hash_tasks = [list_of_hash_tasks,] if list_of_hash_tasks.is_a Hash
      #TODO enforce presence of :title attribute
      #TODO fix ugly regexes
      #TODO use proper abstraction to call a general .add() method
      #url = "http://api.toodledo.com/2/tasks/add.php?key=#{self.key};tasks=" + CGI::escape(post_params(list_of_hash_tasks, *args).gsub("\\", "").gsub(/\s?([\{\}])\s?/, '\1').gsub(/"\{/, '{').gsub(/\}"/, '}'))
      add('tasks', Babar::Task, list_of_hash_tasks, 'tasks', false)
    end
    def edit_tasks(list_of_hash_tasks, *args)
      #TODO implement error checking on :id and object type
      list_of_hash_tasks = [list_of_hash_tasks,] if list_of_hash_tasks.is_a Hash
      edit("tasks", Babar::Task, list_of_hash_tasks, 'tasks', false, *args)
    end

       
    def delete_tasks(list_of_task_ids, *args)
      #TODO check that this will work because array is of IDs, not hashes
      modify(endpoint, 'delete', desired_class, array_of_hashes, array_field_name, delete_first_result, *args*)
    end


    def get_locations(param_map={}, *args)
      array_of_json_locations = get('locations', {}, *args)
      array_of_json_locations.collect{|json_location| Babar::Location.new(self, json_location)}
    end

    def add_locations(single_location_hash, *args)
      #TODO enforce :name presence
      #Currently, it appears that the API only supports adding one location at a time
      #However, this will be treated as a list, for the sake of modularity (and potential future compatibility)
      list_of_hash_locations = [single_location_hash,] if list_of_hash_locations.is_a Hash
      add('locations', Babar::Location, list_of_hash_locations, 'locations', false)
    end


  end

end


