module Babar

  class Folder < UserList

    #TODO issue a warning when ID is changed
    attr_accessor :id
    attr_accessor :json_parsed

    def initialize(authenticator, json_parsed)
      super(authenticator, json_parsed)
      @id = json_parsed["id"].to_i
    end

    %w(name private archived ord).each do |field|
     define_method(field) do
        @json_parsed.fetch(field, retrieve(field))
      end
      #The following syntax only works in Ruby 1.9 and above
      define_method "#{field}=" do |value, sync_now = false|
        @json_parsed[field] = value
        synchronize if sync_now
      end
    end
    end

 end
