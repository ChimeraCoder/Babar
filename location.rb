module Babar

  class Location

    def initialize(toodledo, json_parsed)
      @toodledo, @json_parsed = toodledo, json_parsed
      @id = json_parsed["id"].to_i
    end

    def id
      @json_parsed['id']
    end

    def name
      @json_parsed['name']
    end

    def description
      @json_parsed['description']
    end

    def lat
      #TODO find an appropriate type for this variable
      @json_parsed['lat']
    end
    
    def lon
      @json_parsed['lon']
    end
end
