#!/usr/bin/ruby -w

require 'date'

class Allocation
	attr_accessor :date, :name, :amount
	attr_reader :allocid

	def initialize(allocid, date, name, amount)
		@allocid = allocid.to_i
		@date = Date.parse(date)
		@name = name.to_s
		@amount = amount.to_f
	end
end

class Expenditure
	attr_accessor :allocid, :date, :name, :amount
	attr_reader :expid

	def initialize(expid, allocid, date, name, amount)
		@expid = expid.to_i
		@allocid = allocid.to_i
		@date = Date.parse(date)
		@name = name.to_s
		@amount = amount.to_f
	end
end
