module RuleHelper
  ## Not using a hash because hashes are not sorted
  FilterTypes = [[ "Source Address".t, "s-addr" ], 
                 [ "Destined Local".t, "d-local" ], [ "Destination Address".t, "d-addr" ],
                 [ "Source Port".t, "s-port" ], [ "Destination Port".t, "d-port" ],
                 [ "Source Interface".t, "s-intf" ],
                 ## Destination interface is too tricky to handle, and
                 ## it doesn't provide a lot of benefit.
                 ## [ "Destination Interface".t, "d-intf" ],
                 ## Time is presently not supported.
                 ## [ "Time".t, "time" ], [ "Day of Week".t, "day-of-week" ],
                 [ "Protocol".t, "protocol" ]]
  
  DayOfWeek = [[ "sunday", "Sunday".t ],
               [ "monday", "Monday".t ],
               [ "tuesday", "Tuesday".t ],
               [ "wednesday", "Wednesday".t ],
               [ "thursday", "Thursday".t ],
               [ "friday", "Friday".t ],
               [ "saturday", "Saturday".t ]]

  DayOfWeekJavascript = DayOfWeek.map { |d| "new Array( '#{d[0]}', '#{d[1]}' )" }.join( ", " )
  
  ProtocolList = [[ "icmp", "icmp".t ],
                  [ "tcp", "tcp".t ],
                  [ "udp", "udp".t ],
                  [ "gre", "gre".t ],
                  [ "esp", "esp".t ],
                  [ "ah", "ah".t ],
                  [ "sctp", "sctp".t ]]

  ProtocolListJavascript = ProtocolList.map { |d| "new Array( '#{d[0]}', '#{d[1]}' )" }.join( ", " )

  Scripts = [ "rule_builder", "rule/textbox", "rule/checkbox", "rule/ip_address", "rule/port", "rule/interface", "rule/day", "rule/time", "rule/protocol" ]

  # Returns a list of interfaces and an array of
  def self.get_edit_fields( params )
    interfaces = Interface.find( :all )
    interfaces.sort! { |a,b| a.index <=> b.index }
    
    ## This is a javascript array of the interfaces
    interfaces = interfaces.map { |i| "new Array( '#{i.index}', '#{i.name.t}' )" }

    filters = params[:filters]

    unless ApplicationHelper.null?( filters )
      parameter_list = filters.split( "|" ).map do |f| 
        rule = Rule.new
        rule.parameter, rule.value = f.split( ":" )
        rule
      end
    end

    if ( parameter_list.nil? || parameter_list.empty? )
      r = Rule.new
      r.parameter, r.value = FilterTypes[0][1], ""
      parameter_list = [r]
    end

    [ interfaces, parameter_list ]
  end
end
