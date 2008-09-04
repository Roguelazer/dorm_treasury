#!/usr/bin/ruby

require 'sqlite3'
require 'primitives'

class Treasury
	def initialize(filename)
		@db = SQLite3::Database.new(filename)
		@expenditures = []
		@expenditures_dirty = false
		@allocations = []
		@allocations_dirty = false
		sync_with_database()
	end

	def close
		@db.close
	end

	def sync_with_database()
		@db.execute("SELECT ROWID,date,name,amount from allocations") { |allocation|
			@allocations.push(Allocation.new(allocation[0], allocation[1], allocation[2], allocation[3]))
		}
		@db.execute("SELECT ROWID,date,name,amount,allocid FROM expenditures") { |expenditure|
			@expenditures.push(Expenditure.new(expenditure[0],expenditure[4],expenditure[1],expenditure[2],expenditure[3]))
		}
	end

	def allocations
		@allocations.each { |a|
			yield a
		}
	end


	def expenditures
		@expenditures.each { |e|
			yield e
		}
	end

	def add_allocation(date, name, amount)
		@db.execute("INSERT INTO allocations (date, name, amount) VALUES('#{date}', '#{name}', #{amount})")
		allocid = @db.last_insert_row_id
		allocation = Allocation.new(allocid, date, name, amount)
		@allocations.push(allocation)
		allocation
	end

	def add_expenditure(allocid, date, name, amount)
		@db.execute("INSERT INTO expenditures (allocid, date, name, amount) VALUES(#{allocid}, '#{date}', '#{name}', #{amount})")
		expid = @db.last_insert_row_id
		expenditure = Expenditure.new(expid, allocid, date, name, amount)
		@expenditures.push(expenditure)
		expenditure
	end

	private :sync_with_database
end

