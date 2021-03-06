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

    def initialize(user_obj, toodle_uid, toodle_password, session_token = nil, toodle_token_death = nil)
      #TODO rethink this initialization
      #
      ##TODO Class-level initialization
      #
      #TODO implement uid lookup from email

      @user = user_obj
      @toodle_uid = toodle_uid
      @toodle_password = toodle_password

      if session_token and toodle_token_death
        @session_token, @toodle_token_death = session_token, toodle_token_death
      else
        @session_token, @toodle_token_death = refresh_session_token
      end
      
    end

    ##
    #Return a valid session token. Refresh the session token the existing token has expired.
    #
    #
    
    def session_token
      refresh_session_token unless token_valid?
      return @session_token
    end
   
     
    #--
    #TODO add warning to this method
    #Debugging only
    def session_token=(new_token)
      @session_token = new_token
      @toodle_token_death = Time.now + Babar::Base.toodle_app_token_lifetime
      @session_token
    end

    ##
    #Refresh the session token
    
    def refresh_session_token
      session_signature = Digest::MD5.hexdigest(@toodle_uid + Babar::Base.toodle_app_token) 
      session_token_url = "http://api.toodledo.com/2/account/token.php?" + self.parse_params({:userid => @toodle_uid, :appid => Babar::Base.toodle_app_id , :sig => session_signature,})
      puts session_signature, session_token_url
      @session_token = JSON.parse(Typhoeus::Request.get(session_token_url).body)["token"]
      @toodle_token_death = Time.now + Babar::Base.toodle_app_token_lifetime
      [@session_token, @toodle_token_death]
    end

    ##
    #Return true if the current session token has not yet expired
    def token_valid?
      @session_token and @toodle_token_death > Time.now
    end

    ##
    #Return a valid key. Refresh the key if the existing session token is invalid.
    def key
      refresh_key unless key_valid?
      @key
    end

    #--
    #For debugging purposes only
    #If you set the key manually, you are responsible for tracking its expiry responsibly
    def key=(new_key)
      @key = new_key
    end

    ##
    #Return true if the current key is valid

    def key_valid?
      token_valid? and @key
    end
    
    ##
    #Refresh the key. The session token will be refreshed first if it has expired.

    def refresh_key
      refresh_session_token unless token_valid?
      @key = Digest::MD5.hexdigest( Digest::MD5.hexdigest(@toodle_password) + Babar::Base.toodle_app_token + @session_token)
    end

    ##
    #Given a Hash, return a string representation of the key => value pairs encoded as GET parameters

    def parse_params(mapping, *args)
      if args.length == 0
        args = mapping.keys
      end
      args.collect{ |a| CGI::escape(a.to_s) + "=" + CGI::escape(mapping[a].to_s)}.join(";")
    end

    ##
    #Given an array of JSON-able objects, create a JSON representation of the array and its objects.

    def post_params(array_of_objects_to_post)
      #Each object in the array must support to_json
      array_of_objects_to_post.collect{|task| task.to_json}.to_s
    end
   
    def get(endpoint, param_map, desired_class=nil, delete_first_result=false, desired_fields = [])
      #TODO figure out a proper way to make desired_class optional
      url = "http://api.toodledo.com/2/#{endpoint}/get.php?key=#{self.key};" + parse_params(param_map, desired_fields) 
      array_of_results = JSON.parse(Typhoeus::Request.get(url).body)
      array_of_results.delete_at(0) if delete_first_result
      if desired_class
        array_of_results.collect{|json_result| desired_class.new(self.user, self, json_result)}
      else
        array_of_results
      end
    end

    def get_account
      url = "http://api.toodledo.com/2/account/get.php?key=#{self.key}"
      JSON.parse(Typhoeus::Request.post(url).body)
    end

    def modify_single(endpoint, action, param_map, desired_class=nil, delete_first_result=false)
      url = "http://api.toodledo.com/2/#{endpoint}/#{action}.php?key=#{self.key};" + parse_params(param_map) 
      array_of_results = JSON.parse(Typhoeus::Request.post(url).body)
      array_of_results.delete_at(0) if delete_first_result
      if desired_class
        array_of_results.collect{|json_result| desired_class.new(self.user, self, json_result)}
      else
        array_of_results
      end
    end


    def modify(endpoint, action, desired_class,  array_of_hashes, array_field_name, delete_first_result, *args)
      #TODO whether to omit first
      #TODO check if this is even right
      #action is 'add', 'edit', or 'delete'
      url = "http://api.toodledo.com/2/#{endpoint}/#{action}.php?key=#{self.key};#{array_field_name}=" + CGI::escape(post_params(array_of_hashes, *args).gsub("\\", "").gsub(/\s?([\{\}])\s?/, '\1').gsub(/"\{/, '{').gsub(/\}"/, '}'))
      array_of_results = JSON.parse(Typhoeus::Request.post(url).body)
      array_of_results.delete_at(0) if delete_first_result
      array_of_results.collect{|json_result| desired_class.new(self.user, self, json_result)}
    end

    #--
    #The following methods are not strictly needed, but they have been included to facilitate further refactoring, which may be necessary

    def add(endpoint, desired_class, array_of_hashes, array_field_name, delete_first_result, *args)
      modify(endpoint, 'add', desired_class, array_of_hashes, array_field_name, delete_first_result, *args)
    end

    def edit(endpoint, desired_class, array_of_hashes, array_field_name, delete_first_result, *args)
      modify(endpoint, 'edit', desired_class, array_of_hashes, array_field_name, delete_first_result, *args)
    end

    def delete(endpoint, desired_class, array_of_hashes, array_field_name, delete_first_result, *args)
      modify(endpoint, 'delete', desired_class, array_of_hashes, array_field_name, delete_first_result, *args)
    end
   
    ##
    #Get the user's tasks from the Toodledo API
    #

    def get_tasks(param_map, *args)
      #Strip off the first element, since it is not a Task
      get("tasks", param_map, Babar::Task, true, *args)
    end

    def get_deleted_tasks(param_map, *args)
      url = "http://api.toodledo.com/2/tasks/deleted.php?key=#{self.key};" + parse_params(param_map) 
      deleted_tasks = JSON.parse(Typhoeus::Request.get(url).body)
      deleted_tasks = deleted_tasks.delete_at(0)
      deleted_tasks.collect{|json_result| Babar::Task.new(self.user, self, json_result)}
    end

    ##
    #Add a single task through the Toodledo API

    def add_task(hash_task, *args)
      add_tasks([hash_task,], *args)
    end

    ##
    #Add a list of up to 50 tasks through the Toodledo API

    def add_tasks(list_of_hash_tasks, *args)
      list_of_hash_tasks = [list_of_hash_tasks,] if list_of_hash_tasks.is_a Hash
      raise ArgumentError, 'Only 50 tasks may be added in a single call' if list_of_hash_tasks.length > 50
      list_of_hash_tasks.each do |task|
        raise ArgumentError, 'A title must be specified when a task is added' if unless task.has_key? :title or task.has_key 'title'
      end
      add('tasks', Babar::Task, list_of_hash_tasks, 'tasks', false)
    end

    #Edit a single task through the Toodledo API, using the values specified in the Hash
    #

    def edit_task(hash_task, *args)
      edit_tasks([hash_task,], *args)
    end

    #Edit a list of up to 50 Task objects through the Toodledo API, using the values specified in the list of Hash objects
    #

    def edit_tasks(list_of_hash_tasks, *args)
      list_of_hash_tasks = [list_of_hash_tasks,] if list_of_hash_tasks.is_a Hash
      list_of_hash_tasks.each do |task|
        raise ArgumentError, 'An id must be specified when a task is edited' if unless task.has_key? :id or task.has_key 'id'
      end
      edit("tasks", Babar::Task, list_of_hash_tasks, 'tasks', false, *args)
    end

    
    #Given a list of Task ids, delete all the corresponding tasks from the Toodledo API   
    def delete_tasks(list_of_task_ids, *args)
      #TODO modify this to accept Task objects as well
      #TODO check that this will work because array is of IDs, not hashes
      modify(endpoint, 'delete', desired_class, array_of_hashes, array_field_name, delete_first_result, *args)
    end


    #Implement add/edit/delete methods for each of the following Toodledo User-defined lists: Context, Folder, Goal, Location
    %w(context folder goal location).each do |list|
      current_class = Babar::const_get(list.capitalize)
      define_method("get_#{list}s") { get("#{list}s", param_map = {}, desired_class = current_class, delete_first_result = false) }
      %w(add edit delete).each do |mod_endp|
        #Hash_goal is a Hash representation of the (desired) list AFTER it is added/edited/deleted
        #TODO in the case of deletion, make sure an ID suffices
        define_method("#{mod_endp}_#{list}") { |hash_goal| modify_single( endpoint = "#{list}s", action = mod_endp, param_map = hash_goal, desired_class = current_class, delete_first_result = false)}
      end
    end

  end

end


