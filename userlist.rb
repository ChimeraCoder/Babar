module Babar

  class UserList
    
    def initialize(authenticator, json_parsed)
      @authenticator, @json_parsed = authenticator, json_parsed
    end

    def synchronize
      #TODO fill this in
    end

    def retrieve(field)
      #TODO fill this in
      return :retrieve
    end
  end
end
