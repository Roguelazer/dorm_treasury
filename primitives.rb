#!/usr/bin/ruby -w

require 'date'

class Allocation
	attr_accessor :date, :name, :amount
	attr_reader :allocid

	def initialize(allocid, date, name, amount)
		@allocid = allocid.to_i
		if(date.is_a?(Date))
			@date = date
		else
			@date = Date.parse(date)
		end
		@name = name.to_s
		@amount = amount.to_f
	end

	def to_s
		return "Allocation #{@allocid}: $#{@amount} for #{@name} on #{@date.to_s}"
	end
end

class Expenditure
	attr_accessor :allocid, :date, :name, :amount, :check_no
	attr_reader :expid

	def initialize(expid, allocid, date, name, amount, check_no=nil)
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
	end

	def to_s
		return "Expenditure ##{@expid}: $#{@amount} to #{@name} for Allocation ##{@allocid} on #{@date.to_s}"
	end
end

class Check
	attr_accessor :cashed
	attr_reader :expenditure, :check_no

	def initialize(number, expenditure, cashed)
		@check_no = number
		@expenditure = expenditure
		if (cashed.to_i > 0)
			@cashed = true
		else
			@cashed = false
		end
	end

	def to_s
		"Check ##{check_no}: $#{expenditure.amount} to #{expenditure.name}"
	end
end
