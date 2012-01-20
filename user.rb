module Babar
  require 'set'


  Taskfields = Set.new [:id,
                        :title,
                        :tag,
                        :folder,
                        :context,
                        :goal,
                        :location,
                        :parent,
                        :children,
                        :order,
                        :duedate,
                        :duedatemod,
                        :startdate,
                        :duetime,
                        :starttime,
                        :remind,
                        :repeat,
                        :repeatfrom,
                        :status,
                        :length,
                        :priority,
                        :star,
                        :modified,
                        :completed,
                        :added,
                        :timer,
                        :timeron,
                        :note,
                        :meta,
  ]




  class User
   
    attr_accessor :authenticator
    attr_accessor :contexts, :goals, :folders, :locations, :new_tasks, :edited_tasks

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

      @last_sync = Time.now
    end


    def sync_tasks

        #Add any tasks that needed to be added
        new_tasks = @tasks.select{|task| task.brand_new?}
        @authenticator.add_tasks(new_tasks.collect {|task| task.json_parsed}) unless @new_tasks.new_tasks.empty?

        #Record that the tasks have already been added
        new_tasks.each {|task| task.no_longer_new}

        #Delete any tasks that were marked as deleted locally but not yet removed from @tasks
        deleted_tasks = @tasks.select{|task| task.deleted?}
        @authenticator.delete_tasks(deleted_tasks.collect {|task| task.id}) unless deleted_tasks.empty?
      
        if lastedit_task > @last_sync
           #Get (recently edited) tasks
           tasks = @authenticator.get_tasks {:after => lastedit_task}
           
           #TODO we may need to put this in a loop and load tasks page by page
           tasks.each do |task|
             if not @tasks[task.id]
               @tasks[task.id] = task
             else
                 #Compare modification times, update local copy when necessary, and resolve editing conflicts
                 #TODO allow either server-override-local or local-override-server
                 if task.modified > @tasks[task.id].modified
                   @tasks[task.id] = task
                 end
             end

             #The task has been edited more recently on the server, so no need to resync those changes back again
             task.edit_saved
           end
        end

        if lastdelete_task > @last_sync
          #Query the deleted tasks (on the Toodledo server) and delete them here locally
          @user.get_deleted_tasks.collect{|task| task.id}.each do |id| 
            #The delete boolean will be set just in case there are other references to the task, in which case it would not be garbage-collected
            @tasks[id].delete!
            @tasks.delete(id)
          end
        end

        #Find the tasks which were edited most recently locally, and send them to the Toodledo server
        locally_edited = @tasks.select{|task| task.edited?}
        @user.edit_tasks(locally_edited.collect{|task| task.json_parsed}) unless locally_edited.empty?
        
        #TODO check if there were repeating tasks that needed to be rescheduled
    end

    def lastedit_task
        #TODO implement this
    end

    def lastdelete_task
        #TODO implement this
    end

    def new_task(params = {})
        #TODO figure out what to do about adding single/many tasks
        raise ArgumentError if not params[:title] or params["title"]

        params.keys.each do |key|
          raise ArgumentError if not Taskfields.include? key.to_sym
        end

        #Query the API to add the task
        task = Babar::Task.new(@authenticator, params) 
        @new_tasks.push(task)
        @tasks[task.id] = task
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
