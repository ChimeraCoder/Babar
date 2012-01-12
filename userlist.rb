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
    end

    def retrieve(field)
      #TODO fill this in
      class_name = self.class
      ary = @authenticator.send("get_#{class_name}".downcase)
      ary.each do |obj|
        if obj.id == self.id
          result = obj
          break
        end
      end
      @json_parsed.merge!(obj.json_parsed)
      #Use json_parsed here, or else you may end up in an infinite loop of calls to retrieve 
      obj.json_parsed.fetch(field, nil)
    end

    def delete
      #TODO implement this
    end 

  end
end
