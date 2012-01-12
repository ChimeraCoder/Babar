module Babar

  class Location < UserList

    attr_accessor :id
    attr_accessor :json_parsed

    def initialize(authenticator, json_parsed)
      super(authenticator, json_parsed)
      @id = json_parsed["id"].to_i
    end

    %w(name description lat lon).each do |field|
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
