module Babar
  class Task
    attr_accessor :json_parsed, :toodledo

    def initialize(toodledo, json_parsed)
      @authenticator, @json_parsed = toodledo, json_parsed
      #TODO add error message
      raise ArgumentError unless json_parsed["title"] or json_parsed[:title]
      @id = json_parsed["id"].to_i
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

    def save
      #TODO implement this
      #Issue the POST request
      #Store the actual JSON response that is returned as the result
      #Store the ID
    end

    def delete
      @authenticator.user.delete_task(@id)
    end
      
    def id
      @json_parsed['id']
    end

    def title
      @json_parsed['title']
    end

    def tag
      #TODO check if this is correct
      retrieve 'tag' unless @json_parsed.has_key?('tag')
      @json_parsed['tag']
    end

    def folder
      retrieve 'folder' unless @json_parsed.has_key?('folder')
      @json_parsed['folder'].to_i
    end

    def context
      retrieve 'context' unless @json_parsed.has_key?('context')
      @json_parsed['context'].to_i
    end

    def goal
      #TODO debug potential nil error
      #Returns 0 if no goal is defined
      retrieve 'goal' unless @json_parsed.has_key?('goal')
      @json_parsed['goal'].to_i
    end


    def location
      retrieve 'location' unless @json_parsed.has_key?('location')
      @json_parsed['location']
    end

    def parent
      #TODO Debug potential nil case
      #FIXME query_tasks does not exist
      parent_task_json = self.query_tasks({:id => parent_id})
      Babar::Task.new(@authenticator, parent_task_json)
    end

    def parent_id
      retrieve 'parent' unless @json_parsed.has_key?('parent')
      id = @json_parsed['parent'].to_i
    end

    def children
      #Returns the *number* of children subtasks, not the child subtasks themselves
      retrieve 'children' unless @json_parsed.has_key?('children')
      @json_parsed['children'].to_i
    end

    def order
      retrieve 'order' unless @json_parsed.has_key?('order')
      @json_parsed['order'].to_i
    end

    def duedate
      retrieve 'duedate' unless @json_parsed.has_key?('duedate')
      Time.at @json_parsed['duedate'].to_i
    end

    def duedatemod
      retrieve 'duedatemod' unless @json_parsed.has_key?('duedatemod')
      @json_parsed['duedatemod']
    end

    def startdate
      retrieve 'startdate' unless @json_parsed.has_key?('startdate')
      Time.at @json_parsed['startdate']
    end

    def duetime
      retrieve 'duetime' unless @json_parsed.has_key?('duetime')
      Time.at @json_parsed['due_time']
    end

    def duetime_set?
      retrieve 'duetime' unless @json_parsed.has_key?('duetime')
      @json_parsed['due_time'].to_i != 0
    end

    def starttime
      retrieve 'starttime' unless @json_parsed.has_key?('starttime')
      Time.at @json_parsed['start_time']
    end

    def starttime_set?
      retrieve 'starttime' unless @json_parsed.has_key?('starttime')
      @json_parsed['start_time'].to_i != 0
    end

    def remind
      retrieve 'remind' unless @json_parsed.has_key?('remind')
      @json_parsed['remind'].to_i
    end

    def remind?
      retrieve 'remind' unless @json_parsed.has_key?('remind')
      self.reminder != 0
    end

    def repeat
      #TODO FIGURE THIS OUT
    end
    
    def repeatfrom
      retrieve 'repeatfrom' unless @json_parsed.has_key?('repeatfrom')
      @json_parsed['repeatfrom'].to_i
    end

    def status
      retrieve 'status' unless @json_parsed.has_key?('status')
      @json_parsed['status'].to_i
    end

    def length
      retrieve 'length' unless @json_parsed.has_key?('length')
      @json_parsed['length'].to_i
    end

    def priority
      retrieve 'priority' unless @json_parsed.has_key?('priority')
      @json_parsed['priority'].to_i
    end

    def star
      retrieve 'star' unless @json_parsed.has_key?('star')
      if @json['star'] == "1"
        return true
      else
        return false
      end
    end
    
    def modified
      retrieve 'modified' unless @json_parsed.has_key?('modified')
      Time.at @json_parsed['modified'].to_i
    end

    def completed?
      retrieve 'completed' unless @json_parsed.has_key?('completed')
      time = @json_parsed['completed']
      if time == '0' or time == 0
        return false
      else
        return true
      end
    end

    def completion_time
      if completed?
        return Time.at @json_parsed['completed'].to_i
      else
        #TODO find an exception type for this
        nil
      end
    end

    def added
      retrieve 'added' unless @json_parsed.has_key?('added')
      Time.at @json_parsed['added'].to_i
    end

    def timer
      retrieve 'timer' unless @json_parsed.has_key?('timer')
      @json_parsed['timer'].to_i
    end

    def timeron
      #TODO figure out what the default value is
      retrieve 'timeron' unless @json_parsed.has_key?('timeron')
      @json_parsed['timeron'].to_i
    end

    def note
      retrieve 'note' unless @json_parsed.has_key?('note')
      @json_parsed['note']
    end

    def meta
      retrieve 'meta' unless @json_parsed.has_key?('meta')
      @json_parsed['meta']
    end
  end
end
