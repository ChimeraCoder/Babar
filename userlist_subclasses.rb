module Babar

  #Now, let's define the subclasses and their accessible fields

  defined_subclasses = %w(context location folder goal)
  
  defined_fields = {
      "context" => %w(name),
      "location" => %w(name description lat lon),
      "folder" => %w(name private archived ord),
      "goal" => %w(name level archived contributes note),
  }

  defined_subclasses.each do |s|

      fields = defined_fields[s]
      cls = Class.new(UserList) do
        #TODO issue a warning when ID is changed
        attr_accessor :id
        attr_accessor :json_parsed

        def initialize(authenticator, json_parsed)
          super(authenticator, json_parsed)
          @id = json_parsed["id"].to_i
        end
        
        fields.each do |field|
          define_method(field) do
            #The || is used to force retrieve to be evaluated lazily
            #Otherwise, a new query will happen even if field is defined
            @json_parsed.fetch(field, nil) || retrieve(field)
          end
          #The following syntax only works in Ruby 1.9 and above
          define_method "#{field}=" do |value|
            @json_parsed[field] = value
            @last_mod = Time.now
            @edited = true
          end
        end
      end
      Babar.const_set(s.capitalize, cls)
  end



end
