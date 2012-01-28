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


 
  #Account fields (except those that should be stored as Time objects)
  Accounttextfields = Set.new [:userid,
                               :alias,
                               :pro,
                               :dateformat,
                               :timezone,
                               :hidemonths,
                               :hotlistpriority,
                               :hotlistduedate,
                               :showtabnums,
  ]

  #Account fields that should be stored as Time objects
  Accounttimestamps = Set.new [ 
                               :lastedit_folder,
                               :lastedit_context,
                               :lastedit_goal,
                               :lastedit_task,
                               :lastdelete_task,
                               :lastedit_notebook,
                               :lastdelete_notebooks,

  ]

  Accountfields = Accounttimestamps.union Accounttextfields 

  class User
   
    attr_accessor :authenticator
    attr_accessor :contexts, :goals, :folders, :locations, :new_tasks, :edited_tasks

    def initialize(toodle_uid, toodle_password, session_token = nil, toodle_token_death = nil)
      if session_token and toodle_token_death
       @authenticator = Babar::Base.new(toodle_uid, toodle_password, session_token, toodle_token_death)
      else
       @authenticator = Babar::Base.new(toodle_uid, toodle_password) 
      end

      @account_info = @authenticator.get_account

      @tasks = {}
      @contexts = {}
      @goals = {}
      @folders = {}
      @locations {}

      @last_task_sync = Time.now
      @last_location_sync = Time.now
      @last_context_sync = Time.now
      @last_goal_sync = Time.now
      @last_folder_sync = Time.now

    end


    def sync_tasks

        #TODO make this line optional
        @account_info = @authenticator.get_account

        #Add any tasks that needed to be added
        new_tasks = @tasks.keys.select{|task| task.brand_new?}
        @authenticator.add_tasks(new_tasks.collect {|task| task.json_parsed}) unless @new_tasks.new_tasks.empty?

        #Record that the tasks have already been added
        new_tasks.each {|task| task.no_longer_new}

        #Delete any tasks that were marked as deleted locally but not yet removed from @tasks
        deleted_tasks = @tasks.keys.select{|task| task.deleted?}
        @authenticator.delete_tasks(deleted_tasks.collect {|task| task.id}) unless deleted_tasks.empty?
      
        if lastedit_task > @last_task_sync
           #Get (recently edited) tasks
           tasks = @authenticator.get_tasks {:after => lastedit_task}
           
           locally_edited = []

           #TODO we may need to put this in a loop and load tasks page by page
           tasks.each do |task|
             if not @tasks[task.id]
               #If for some reason the task doesn't exist yet locally, add it
               @tasks[task.id] = task
             else
               #Compare modification times, update local copy when necessary, and resolve editing conflicts
               #Do NOT use task.last_mod, because that will just refer to the time that the get_tasks function was called!
               #Instead, we care about the time that the last edits were actually saved on the Toodledo server
               if task.modified > @tasks[task.id].last_mod
                 #The server-stored task was modified more recently than the local task
                 #TODO make sure all other locations are properly mutating the task, rather than creating parallel/outdated instances
                 #If we simply overwrote the task instead of updating task.json_parsed, any past references to the task would point to an invalid/outdated
                 @tasks[task.id].json_parsed = task.json_parsed
                 @tasks[task.id].edit_saved
               else
                 #The local task was modified more recently than the server-stored task
                 #Realistically, the two timestamps cannot be the same, but if they are, we will assume the local copy is more accurate
                 locally_edited.push(@tasks[task.id])
               end
             end
           end
        end

        if lastdelete_task > @last_task_sync
          #Query the deleted tasks (on the Toodledo server) and delete them here locally
          @user.get_deleted_tasks.collect{|task| task.id}.each do |id| 
            #The delete boolean will be set just in case there are other references to the task, in which case it would not be garbage-collected
            @tasks[id].delete!
            @tasks[id].edit_saved #Make sure it won't be edited-saved in the future
            @tasks.delete(id)
          end
        end

        locally_edited = locally_edited.select{|task| not task.deleted?}
        @user.edit_tasks(locally_edited.collect{|task| task.json_parsed}) unless locally_edited.empty?
       
        #After this, the modified timestamp on the server will be the current time, which is later than the task.last_mod for any task stored locally
        
        #TODO check if there were repeating tasks that needed to be rescheduled
        
        #Remove any deleted tasks from @tasks. There may still be references elsewhere to them (depending on the application), so they may not necessarily be garbage-collected
        @tasks = @tasks.select{|task| not task.deleted?}

        @last_task_sync = Time.now
    end





    def sync_list(list_type)
       
        #Update account_info 
        #TODO make sure this isn't called four times if all lists are syncghronized together
        @account_info = @authenticator.get_account

        
        #lists_array is the array that stores the user's lists of the given type
        #For example, @locations
        
        lists_array = self.send("#{list_type}s")
        

        #Add any new locations
        new_lists = lists_array.keys.select{|list| list.brand_new}
        
        #TODO rewrite this to use only one API query, if API supports it
        unless new_lists.empty?  #Won't be redundant if/when the loop is eliminated
          new_lists.each do |list| 
            @authenticator.send("add_#{list_type}", list.json_parsed)
            list.no_longer_new!
          end
        end
          
        #Delete any deleted locations 

        #Get all the lists that have been deleted locally 
        del_lists = lists_array.values.select{|list| list.deleted}

        unless del_lists.empty?
          del_lists.each do |list|
            @authenticator.send("delete_#{list_type}", list.json_parsed)}
            lists_array.delete(list.id)
            list.delete!
            list.edit_saved
          end
        end
       
        #TODO delete the lists locally if they have been deleted on the server

        #Only fetch from server and do conflict resolution if the last edit on the server was later than the last sync for the list
       
        if self.send("lastedit_#{list_type}") > self.send("last_#{list_type}_sync") 

          #Get the lists
          lists = @authenticator.send("get_#{list}s")

          locally_edited = []
          
          lists.each do |list|
            if not lists_array[list.id]
              #If for some reason we don't have the list locally, store the list locally and move on.
              lists_array[list.id]
            else
              #Otherwise, compare modification times, update local copy when necessary, and resolve editing conflicts
              
              if self.send("lastedit_#{list}") > lists_array[task.id].last_mod
                #The server-stored list was modified more recently than the local task
                #TODO make sure the list object is unique by ID
                
                lists_array[list.id].json_parsed = list.json_parsed
                lists_array[list.id].edit_saved
              else
                #The local list was modified more recently than the server-stored task
                #Assume the local copy is more accurate if the two timestamps are somehow the same
                locally_edited.push(lists_array[task.id])
                @authenticator.send("edit_#{list}", list.json_parsed) unless list.deleted?
                list.edit_saved
              end
            end
          end
        end


        #TODO will this work if it is not public?
        self.send("last#{list_type}_sync=", Time.now)
        
        #Remove all locally deleted lists of this type
        self.send("#{list_type}s=", lists_array.values.select{|list| not list.deleted})
    end 



    #Define getters (no setters) for each of the account fields
    Babar::Accountfields.each do |field|
        define_method(field.to_s) do
            #The timestamps should be stored as Time objects
            if field in Babar::Accounttimestamps
              Time.at @account_info[field.to_s]
            else
              @account_info[field.to_s]
            end
        end
    end

    def new_task(params = {})
        raise ArgumentError if not params[:title] or params["title"]

        params.keys.each do |key|
          raise ArgumentError if not Taskfields.include? key.to_sym
        end

        #Create a new Task object and push it onto the array of tasks to be added upon the next sync
        task = Babar::Task.new(@authenticator, params) 
        @new_tasks.push(task)
        @tasks[task.id] = task
    end

    def add_tasks(tasklist)
        tasklist.each{ |task| new_task(task)}
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
