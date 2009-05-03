#!/usr/bin/ruby -w

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
	protected_attr :allocid, :date, :name, :amount, :check_no
	attr_reader :expid

	def initialize(expid, allocid, date, name, amount, check_no, &block)
		@expid = expid.to_i
		@allocid = allocid.to_i
		if (date.is_a?(Date))
			@date = date
		else
			@date = Date.parse(date)
		end
		@name = name.to_s
		@amount = amount.to_f
		@check_no = check_no
		@listeners = [block]
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
	attr_reader :expenditure, :check_no, :cid

	def initialize(number, expenditure, cashed, cid, &block)
		@check_no = number.to_i
		@expenditure = expenditure
		if (cashed.to_i > 0)
			@cashed = true
		else
			@cashed = false
		end
		@cid = cid.to_i
		@listeners = [block]
	end

	def to_s
		"Check ##{check_no}: $#{expenditure.amount} to #{expenditure.name}"
	end

	def add_listener(&block)
		@listeners.push(block)
	end
end
