class StaticArp < ActiveRecord::Base
  def validate
    unless hw_addr && ApplicationHelper.mac?( hw_addr )
      errors.add( :hw_addr, "is missing or invalid" )
    end
    
    unless hostname && ApplicationHelper.ip_address?( hostname )
      errors.add( :hostname, "is missing or invalid" )
    end
  end

  def StaticArp.get_active( os )
    return os["arps_manager"].get_active
  end

end
