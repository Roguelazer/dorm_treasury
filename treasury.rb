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

	private :sync_with_database
end

