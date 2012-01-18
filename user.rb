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

      @tasks = {}
      @contexts = {}
      @goals = {}
      @folders = {}
      @locations {}
    end

    def new_task(params = {})
        #TODO figure out what to do about adding single/many tasks
        raise ArgumentError if not params[:title] or params["title"]

        #Query the API to add the task
        task = @authenticator.add_task(params)
        @tasks[task.id] = task
    end

    def edit_task(params = {})
        #TODO figure out what to do about editing single/many tasks
        raise ArgumentError if not params[:id] or params["id"]
        #Query the API to edit the task
        task = @authenticator.edit_task(params)
        @tasks[task.id] = task
    end

    #TODO figure out what to do with the deleted object itself
    def delete_task(id)
      result = @authenticator.delete_tasks(id)
      result.each{|del_task| @tasks.delete(del_task.id)}
      result
    end

    %w(context folder goal location).each do |list|
       define_method("new_#{list}") do |params|  
         #TODO figure out how to access instance variable by name properly
         result = @authenticator.send("add_#{list}", params)
         self.send("#{list}s").store(result.id, result)
       end

       define_method("edit_#{list}") do |params|
         raise ArgumentError if not params[:id] or params["id"]
         result = @authenticator.send("edit_#{list}", params)
         self.send("#{list}s").store(result.id, result)
       end

       define_method("delete_#{list}") do |id||
         result = @authenticator.send("delete_#{list}", id)
         result.each{|del_list| self.send("#{list}s").delete(del_list.id)}
       end
    end

        

  end
end
