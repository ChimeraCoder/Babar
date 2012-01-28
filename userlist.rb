module Babar

  class UserList
    
    #TODO enforce IMMEDIATE save when ID is defined/not known
    #Otherwise, retrieve will not work
    #Also, it is a bad idea not to have an ID defined
    #
    #
    #This constructor should NEVER be called to initialize a new object by the user
    #The user should create all objects through the User object
    #For example, Babar::User.new_context()
    #The .new_#{foo} method will call the appropriate constructor internally
    #The .new_#{foo} method will also hit the /add endpoint, so that this constructor can be used internally without infinite recursion
    def initialize(authenticator, json_parsed)
      @authenticator, @json_parsed = authenticator, json_parsed

      @brand_new = true
      @edited = false
      @deleted  = false

      #TODO fold last_mod into @edited, to avoid overlapping functionality
      #This records the last time modified LOCALLY
      #Will be nil if there have been no local modifications since the last sync
      @last_mod = nil
    end

    ##
    #Query the Toodledo API to refresh all fields for the UserList object, and return the specified field (or nil if it does not exist)
    def retrieve(field)
      #TODO figure out a less hacky way to do this
      #The module may be included in the class name, and we don't want that
      class_name = classname 
      ary = @authenticator.send("get_#{class_name}s".downcase)
      result = nil
      ary.each do |obj|
        if obj.id == self.id
          result = obj
          break
        end
      end
      @json_parsed.merge!(result.json_parsed)
      #Use json_parsed here, or else you may end up in an infinite loop of calls to retrieve 
      result.json_parsed.fetch(field, nil)
    end

    ##
    #Return the class name of the object (not including the module name)
    #--
    #TODO find a less hacky way?
    def classname
      self.class.name.split("::")[-1]
    end

    ##
    # Return a boolean indicating whether the list has been modified locally since the last sync  (returns true unless @last_mod is nil)
    def edited?
      @last_mod ? true : false 
    end

    ##
    #Return the time at which the task was last modified locally, or nil if the task has not been modified locally since the last sync
    def last_mod
      @last_mod
    end

    def edit_saved
      @last_mod = nil
    end

    ##
    #Delete the UserList. Deletion will occur on the next synchronization with the Toodledo server 
    def delete!
      @deleted = true
    end

    ##
    #Return a boolean indicating whether the current list has been marked for deletion
    def deleted?
      #TODO check if this introduces security error by returning a mutable value
      @deleted
    end

    ##
    #Return a boolean indicating whether the list has been synchronized since it was created locally
    def brand_new?
      @brand_new
    end

    def no_longer_new!
      @brand_new = false
    end
     
  end
end
