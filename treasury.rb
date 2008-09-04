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

	def allocation(allocid)
		@db.execute("SELECT date,name,amount FROM allocations WHERE ROWID=#{allocid}") { |allocation|
			return Allocation.new(allocid, allocation[0], allocation[1], allocation[2])
		}
	end

	def expenditure(expid)
		@db.execute("SELECT allocid,date,name,amount,check_no FROM expenditures WHERE ROWID=#{expid}") { |e|
			return Expenditure.new(expid, e[0], e[1], e[2], e[3],e[4])
		}
	end

	def each_allocation 
		@allocations.each { |a| yield a }
	end

	def each_expenditure
		@expenditures.each { |e| yield e }
	end

	def expenditures_for(allocid)
		@db.execute("SELECT ROWID,date,name,amount,check_no FROM expenditures WHERE allocid=#{allocid}") { |expenditure|
			yield Expenditure.new(expenditure[0],allocid,expenditure[1],expenditure[2],expenditure[3],expenditure[4])
		}
	end

	def check(check_no)
		@db.execute("SELECT expenditures.ROWID,checks.check_no,checks.cashed FROM expenditures,checks WHERE expenditures.check_no IS NOT NULL AND expenditures.check_no=checks.check_no") { |e|
			expenditure = @expenditures.select{|item| item.expid==e[0].to_i }
			return Check.new(e[1],expenditure[0],e[2])
		}
	end

	def each_check
		@db.execute("SELECT expenditures.ROWID,checks.check_no,checks.cashed FROM expenditures,checks WHERE expenditures.check_no IS NOT NULL AND expenditures.check_no=checks.check_no") { |e|
			expenditure = @expenditures.select{|item| item.expid==e[0].to_i }
			if (expenditure.size != 1)
				puts "ERROR!!!"
			else
				yield Check.new(e[1], expenditure[0], e[2])
			end
		}
	end

	def add_allocation(date, name, amount)
		@db.execute("INSERT INTO allocations (date, name, amount) VALUES('#{date}', '#{name}', #{amount})")
		allocid = @db.last_insert_row_id
		allocation = Allocation.new(allocid, date, name, amount)
		@allocations.push(allocation)
		allocation
	end

	def add_expenditure(allocid, date, name, amount, check_no = "NULL")
		@db.execute("INSERT INTO expenditures (allocid, date, name, amount,check_no) VALUES(#{allocid}, '#{date}', '#{name}', #{amount}, #{check_no})")
		expid = @db.last_insert_row_id
		if (check_no == "NULL")
			expenditure = Expenditure.new(expid, allocid, date, name, amount,nil)
		else
			expenditure = Expenditure.new(expid,allocid,date,name,amount,check_no)
			@db.execute("INSERT INTO checks (check_no, cashed) VALUES(#{check_no}, 0)")
		end
		puts "Added expenditure #{expenditure}"
		@expenditures.push(expenditure)
		expenditure
	end

	def cash_check(check_no)
		@db.execute("UPDATE checks SET cashed=1 WHERE check_no=#{check_no}")
	end

	def delete_allocation(allocid)
		if (!allocid.nil?)
			@db.execute("DELETE FROM allocations WHERE ROWID=#{allocid}")
		end
	end

	def delete_expenditure(expid)
		if (!expid.nil?)
			@db.execute("SELECT check_no FROM expenditures WHERE ROWID=#{expid}") { |e|
				if (!e[0].nil?)
					@db.execute("DELETE FROM checks WHERE check_no=#{e[0]}")
				end
			}
			@db.execute("DELETE FROM expenditures WHERE ROWID=#{expid}")
		end
	end

	def delete_check(check_no)
		if (!check_no.nil?)
			@db.execute("SELECT ROWID from expenditures WHERE check_no=#{check_no}") {|e|
				if (!e[0].nil?)
					@db.execute("DELETE FROM expenditures WHERE ROWID=#{e[0]}")
				end
			}
			@db.execute("DELETE FROM checks WHERE check_no=#{check_no}")
		end
	end

	private :sync_with_database
end

