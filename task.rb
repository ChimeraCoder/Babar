module Babar
  class Task
    attr_accessor :user, :json_parsed, :toodledo

    @@instances = {}

    #This indirect initialization is necessary to ensure that two separate Task instances cannot have the same userid-taskid combination
    #An attempt to create a new Task instance with an existing userid-taskid combination will return the existing instance
    def new(user, toodledo, json_parsed)
      key = [user.userid, json_parsed["id"].to_i]
      return @@instances[key] if @@instances.has_key? key and @@instances[key].weakref_alive?
      instance = self.allocate
      instance.send :initialize user, toodledo, json_parsed
      return instance
    end

    def initialize(user, toodledo, json_parsed)
      @user, @authenticator, @json_parsed = toodledo, json_parsed
      #TODO add error message
      raise ArgumentError unless json_parsed["title"] or json_parsed[:title]
      @id = json_parsed["id"].to_i

      @brand_new = true

      #TODO check if this will cause problems when tasks are undeleted
      @deleted = false

      #Has the task been edited locally since the last sync from the Toodledo server?
      #TODO remove duplicate functionality
      @edited = false
      @last_mod = Time.now

      #Task ids are only guaranteed to be unique to a user, so both userid and task id must be used as the key
      #Freeze the array so it can be used as a key (since Ruby does not support tuples)
      instance_key = [@user.userid, @id].freeze

      #Use a weakref or else the object will never be garbage-collected!
      @@instances[instance_key] = Weakref.new(self)
    end

    def retrieve(fields)
      #Cann accept either an Array of fields or a single item that supports the .to_s method
      fields = [fields,] unless fields.is_a? Array
      #fields is a list of the desired/required fields
      fields = fields.collect!{|f| f.to_s}.join(',')
      
      #Merge will settle collisions in favor of the SECOND (retrieved) hash 
      @json_parsed.merge!(@authenticator.query_tasks({:id => @id.to_s, :fields => fields}))
    end

    def refresh 
      #Removes all fields and reloads core fields (id, title. modified, completed). All other fields are retrieved lazily
      @json_parsed = @authenticator.query_tasks( {:id => @id.to_s})
    end

    def edited?
      @edited
    end

    def edit_saved
      @edited = false
    end

    def delete!
      @deleted = true
    end

    def deleted?
      #TODO check if this introduces security error by returning a mutable value
      @deleted
    end

    def brand_new?
      @brand_new
    end

    def no_longer_new!
      @brand_new = false
    end
     
    #Define the setter and getter methods for each of the API-defined fields 
    Babar::Taskfields.each do |field|
        define_method(field.to_s) do
          retrieve field unless @json_parsed.has_key? field.to_s
          @json_parsed[field.to_s]
        end

        define_method("#{field.to_s}=") do |new_val|
          @json_parsed[field.to_s] = new_val
          @edited = true 
        end
    end

    def parent_id
      retrieve 'parent' unless @json_parsed.has_key?('parent')
      id = @json_parsed['parent'].to_i
    end

    def duetime_set?
      retrieve 'duetime' unless @json_parsed.has_key?('duetime')
      @json_parsed['due_time'].to_i != 0
    end

    def starttime_set?
      retrieve 'starttime' unless @json_parsed.has_key?('starttime')
      @json_parsed['start_time'].to_i != 0
    end

    def completion_time
      if completed?
        return Time.at @json_parsed['completed'].to_i
      
        #TODO find an exception type for this
        nil
      end
    end


  end
end
