#
# $HeadURL:$
# Copyright (c) 2003-2007 Untangle, Inc. 
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License, version 2,
# as published by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but
# AS-IS and WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE, TITLE, or
# NONINFRINGEMENT.  See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA 02110-1301 USA.
#
module NUCLICommon

DEFAULT_DIAG_LEVEL = 1
BRAND = "Untangle"

# Shared error messages & strings - Perhaps we'll package these another way.
ERROR_INCOMPLETE_COMMAND = "Error: incomplete command -- missing required arguments (see help.)"
ERROR_UNKNOWN_COMMAND = "Error: unknown command"
ERROR_COMMAND_FAILED = "Error: unable to execute command"
ERROR_INVALID_NODE_ID = "Error: invalid node identifier"

# Exceptions
class UserCancel < Interrupt
end

# Ruby "extensions"
module Kernel
    private
        # returns the name of the method that calls 'this_method'
        def this_method
            caller[0] =~ /`([^']*)'/ and $1
        end
end
    
end # UCLICommon

module CmdDispatcher
  #
  # Calls a method for processing the specified command.
  #
  # The name of the method should be the command name prefixed with _prefix_.
  # The command name is defined to be the first element of the _args_ array.
  # The remaining elements will be used as paramaters to the method call
  #
  
  protected
  def dispatch_cmd(args, has_tid = true, prefix = "cmd")
    catch :unknown_command do
      return dispatch_cmd_helper(prefix, has_tid, args)
    end
    raise NoMethodError, "No command handler method found for '#{args.join(' ')}'."
  end

  private
  def dispatch_cmd_helper(prefix, has_tid, args)
    cmd_name = args.empty? ? "" : format_command_name(args[0])
    tid = has_tid ? args[1] : nil
    new_args = has_tid ? args[2..-1] : args[1..-1]
    full_name = "#{prefix}_#{cmd_name}"
    matches = candidates(full_name)
    if respond_to?(full_name) and (new_args.empty? or candidates("#{full_name}_#{format_command_name(new_args[0])}") == 0) then
      begin
        return has_tid ? send(full_name, tid, *new_args) : send(full_name, *new_args)
      rescue ArgumentError => ex
        @@diag.if_level(3) {
          puts! "Dispatching failure: " + full_name + "(" + new_args.inspect  + ")"
          puts! ex
          puts! ex.backtrace
        }
        return ERROR_INCOMPLETE_COMMAND
      end
    elsif matches > 0 and args.length > 0
      return dispatch_cmd_helper(full_name, has_tid, has_tid ? [new_args[0], tid, *new_args[1..-1]] : new_args)
    end
    throw :unknown_command
  end
  
  def candidates(cmd_name)
    methods.select { |m| m =~ /^#{cmd_name}/ }.length
  end
  
  def format_command_name(cmd_name)
    cmd_name.nil? ? cmd_name : cmd_name.gsub(/-/, "_")
  end
  
end
