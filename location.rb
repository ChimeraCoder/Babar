module Babar

  class Location

    def initialize(toodledo, json_parsed)
      @toodledo, @json_parsed = toodledo, json_parsed
      @id = json_parsed["id"].to_i
    end

    %w(name description lat long).each do |field|
      define_method(field) { retrieve field unless @json_parsed.has_key?(field) }
      #The following syntax only works in Ruby 1.9 and above
      define_method "#{field}=" do |sync_now = false|
        @json_parsed.has_key?(field)
        synchronize if sync_now
      end
    end


    def synchronize
      #TODO fill this in
    end

end
