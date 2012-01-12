module Babar
  class User
   
    attr_accessor :authenticator
    attr_accessor :contexts, :goals, :folders, :locations 

    def initialize(toodle_uid, toodle_password, session_token = nil, toodle_token_death = nil)
      if session_token and toodle_token_death
       @authenticator = Babar::Base.new(toodle_uid, toodle_password, session_token, toodle_token_death)
      else
       @authenticator = Babar::Base.new(toodle_uid, toodle_password) 
      end

      @contexts = {}
      @goals = {}
      @folders = {}
      @locations {}
    end


  end
end
