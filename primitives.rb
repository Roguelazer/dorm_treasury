# East Dorm Treasury Primitives
#
# Copyright (C) 2008-2009 James Brown <jbrown@cs.hmc.edu>
#
# This file is part of East Dorm Treasury.
#
# East Dorm Treasury is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by the
# Free Software Foundation, either version 3 of the License, or (at your
# option) any later version.
#
# East Dorm Treasury is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with East Dorm Treasury.  If not, see <http://www.gnu.org/licenses/>.

require 'date'

module Dirtyable
	def protected_attr(*symbols)
		symbols.each { |s|
			assigner = (s.to_s + "=").to_sym
			varname = ("@" + s.to_s).to_sym
			define_method(assigner) { |value|
				instance_variable_set(varname, value)
				@listeners.each { |l|
					l.call(self)
				}
			}
			define_method(s) {
				instance_variable_get(varname)
			}
		}
	end

end

class Allocation
	extend Dirtyable
	#attr_reader :date, :name, :amount, :closed
	protected_attr :date, :name, :amount, :closed
	attr_reader :allocid

	def initialize(allocid, date, name, amount, closed, &block)
		@allocid = allocid.to_i
		if(date.is_a?(Date))
			@date = date
		else
			@date = Date.parse(date)
		end
		@name = name.to_s
		@amount = amount.to_f
		if (closed == "0" || closed == 0 || closed == false)
			@closed = false
		else
			@closed = true
		end
		@listeners = [block]
	end

	def to_s
		if (closed)
			return "Allocation #{@allocid}: closed (originally for $#{@amount})"
		else
			return "Allocation #{@allocid}: $#{@amount} for #{@name} on #{@date.to_s}"
		end
	end

	def add_listener(&block)
		@listeners.push(block)
	end
end

class Expenditure
	extend Dirtyable
	protected_attr :allocid, :date, :name, :amount, :check
	attr_reader :expid

	def initialize(expid, allocid, date, name, amount, check, &block)
		@expid = expid.to_i
		@allocid = allocid.to_i
		if (date.is_a?(Date))
			@date = date
		else
			@date = Date.parse(date)
		end
		@name = name.to_s
		@amount = amount.to_f
		@check = check
		@listeners = [block]
	end

	def check_no
		if (@check)
			return @check.check_no
		else
			return nil
		end
	end

	def cid
		if (@check)
			return @check.cid
		else
			return nil
		end
	end

	def deposit?
		return @check.deposit?
	end

	def to_s
		return "Expenditure ##{@expid}: $#{@amount} to #{@name} for Allocation ##{@allocid} on #{@date.to_s}"
	end

	def add_listener(&block)
		@listeners.push(block)
	end
end

class Check
	extend Dirtyable
	protected_attr :cashed
	attr_reader :check_no, :cid

	def initialize(number, cashed, cid, &block)
		@check_no = number.to_i
		if (cashed.to_i > 0)
			@cashed = true
		else
			@cashed = false
		end
		@cid = cid.to_i
		@listeners = [block]
	end

	def to_s
		"Check ##{@check_no}; CID #{@cid} " + (@cashed ? " (Cashed)" : "")
	end

	def add_listener(&block)
		@listeners.push(block)
	end

	def deposit?
		return (@check_no == -1)
	end
end
