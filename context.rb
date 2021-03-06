module Babar

  class Context < UserList

    #TODO issue a warning when ID is changed
    attr_accessor :id
    attr_accessor :json_parsed

    def initialize(authenticator, json_parsed)
      super(authenticator, json_parsed)
      @id = json_parsed["id"].to_i
    end

    %w(name).each do |field|
      define_method(field) do
        #The || is used to force retrieve to be evaluated lazily
        #Otherwise, a new query will happen even if field is defined
        @json_parsed.fetch(field, nil) || retrieve(field)
      end
      #The following syntax only works in Ruby 1.9 and above
      define_method "#{field}=" do |value, sync_now = false|
        @json_parsed[field] = value
        synchronize if sync_now
      end
    end
    end

 end
