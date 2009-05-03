#!/usr/bin/ruby

require 'sqlite3'
require 'primitives'
require 'exceptions'

class Treasury
	def initialize(filename)
		@db = SQLite3::Database.new(filename)
		@expenditures = []
		@dirty_expenditures = []
		@allocations = []
		@dirty_allocations = []
		@checks = []
		@dirty_checks = []
		read_db()
	end

	def close
		write_db
		@db.close
	end

	def write_db
		@dirty_allocations.each { |a|
			@db.execute("UPDATE allocations SET date=?,name=?,amount=?,closed=? WHERE ROWID=?", a.date, a.name,
					   a.amount, a.closed ? "1" : "0", a.allocid) { |res|
			}
		}
		@dirty_allocations = []
		@dirty_expenditures.each { |e|
			@db.execute("UPDATE expenditures SET allocid=?,date=?,name=?,amount=? WHERE ROWID=?",
					   e.allocid,e.date,e.name,e.amount,e.expid) { |res|
			}
		}
		@dirty_expenditures = []
		@dirty_checks.each { |c|
			@db.execute("UPDATE checks SET cashed=? WHERE check_no=?",
						c.cashed, c.check_no) { |res|
			}
		}
		@dirty_checks = []
	end

	def read_db
		@db.execute("SELECT ROWID,date,name,amount,closed from allocations") { |allocation|
			a = Allocation.new(allocation[0], allocation[1], allocation[2], allocation[3], allocation[4]) { 
				@dirty_allocations.push(a)
			}
			@allocations.push(a)
		}
		@db.execute("SELECT ROWID,date,name,amount,allocid,check_no FROM expenditures") { |expenditure|
			if (expenditure[5].nil?)
				e = Expenditure.new(expenditure[0],expenditure[4],expenditure[1],expenditure[2],expenditure[3], nil) {
					@dirty_expenditures.push(e)
				}
				@expenditures.push(e)
			else
				cno = @db.get_first_row("SELECT check_no FROM checks WHERE ROWID=#{expenditure[5]}")[0]
				e = Expenditure.new(expenditure[0],expenditure[4],expenditure[1],expenditure[2],expenditure[3],cno) {
					@dirty_expenditures.push(e)
				}
				@expenditures.push(e)
			end
		}
		@db.execute("SELECT expenditures.ROWID,checks.check_no,checks.cashed,checks.ROWID FROM expenditures,checks WHERE expenditures.check_no IS NOT NULL AND expenditures.check_no=checks.ROWID") { |e|
			expenditure = @expenditures.select{|item| item.expid==e[0].to_i }
			c = Check.new(e[1],expenditure[0],e[2],e[3]) {
				@dirty_checks.push(c)
			}
			@checks.push(c)
		}
	end

	def allocation(allocid)
		a = @allocations.select { |item| item.allocid == allocid.to_i }
		if (a.size == 0)
			puts "No such allocation (#{allocid}) found"
			return nil
		elsif (a.size > 1)
			STDERR.puts "Error! Multiple identically-numbered allocations detected!"
			Kernel.exit(1)
		end
		return a[0]
		#@db.execute("SELECT date,name,amount,closed FROM allocations WHERE ROWID=#{allocid}") { |allocation|
		#	return Allocation.new(allocid, allocation[0], allocation[1], allocation[2], allocation[3])
		#}
	end

	def expenditure(expid)
		e = @expenditures.select { |item| item.expid == expid.to_i }
		if (e.size == 0)
			puts "No such expenditure (##{expid}) found"
			return nil
		elsif (e.size > 1)
			STDERR.puts "Error! Multiple identically-numbered expenditures detected!"
			Kernel.exit(1)
		end
		return e[0]
		#@db.execute("SELECT expenditures.allocid,expenditures.date,expenditures.name,expenditures.amount,expenditures.check_no,checks.check_no FROM expenditures,checks WHERE expenditures.ROWID=#{expid} AND checks.ROWID=expenditures.check_no") { |e|
		#	return Expenditure.new(expid, e[0], e[1], e[2], e[3],e[4])
		#}
	end

	def each_allocation(open_only=false)
		@allocations.sort_by { |alloc| alloc.date }
		if (open_only)
			@allocations.each { |a|
				if (!a.closed)
					yield a
				end
			}
		else
			@allocations.each { |a| yield a }
		end
	end

	def each_expenditure
		@expenditures.each { |e| yield e }
	end

	def expenditures_for(allocid)
		@expenditures.each { |e|
			if (e.allocid == allocid.to_i)
				yield e
			end
		}
		#@db.execute("SELECT expenditures.ROWID,date,name,amount,expenditures.check_no FROM expenditures WHERE allocid=#{allocid}") { |expenditure|
		#
		#	if (expenditure[4].nil?)
		#		yield Expenditure.new(expenditure[0], allocid, expenditure[1], expenditure[2], expenditure[3], nil)
		#	else
		#		cno = @db.get_first_row("SELECT check_no FROM checks WHERE ROWID=#{expenditure[4]}")[0]
		#		yield Expenditure.new(expenditure[0],allocid,expenditure[1],expenditure[2],expenditure[3], cno)
		#	end
		#}
	end

	def check(check_no)
		c = @checks.select {|item| item.check_no == check_no.to_i }
		if (c.size == 0)
			raise CheckNotFoundError.new(check_no)
		elsif (c.size > 1)
			raise DuplicateCheckError.new(check_no)
		end
		return c[0]
	end

	def each_check
		@checks.each { |c| yield c }
		#@db.execute("SELECT expenditures.ROWID,checks.check_no,checks.cashed,checks.ROWID,expenditures.date FROM expenditures,checks WHERE expenditures.check_no IS NOT NULL AND expenditures.check_no=checks.ROWID ORDER BY checks.check_no, date") { |e|
		#	expenditure = @expenditures.select{|item| item.expid==e[0].to_i }
		#	if (expenditure.size != 1)
		#		STDERR.puts "Error; expenditures to checks is not 1-to-1"
		#	else
		#		yield Check.new(e[1], expenditure[0], e[2],e[3])
		#	end
		#}
	end

	def add_allocation(date, name, amount, closed=false)
		if (closed)
			c = 1
		else
			c = 0
		end
		@db.execute("INSERT INTO allocations (date, name, amount, closed) VALUES('#{date}', '#{name}', #{amount}, #{c})")
		allocid = @db.last_insert_row_id
		allocation = Allocation.new(allocid, date, name, amount, closed)
		@allocations.push(allocation)
		allocation
	end

	def add_expenditure(allocid, date, name, amount, check_no = "NULL")
		if (check_no != "NULL")
			@db.execute("INSERT INTO checks (check_no, cashed) VALUES(#{check_no}, 0)")
			checkid = @db.last_insert_row_id
			@db.execute("INSERT INTO expenditures (allocid, date, name, amount,check_no) VALUES(#{allocid}, '#{date}', '#{name}', #{amount}, #{checkid})")
		else
			@db.execute("INSERT INTO expenditures (allocid, date, name, amount) VALUES(#{allocid}, '#{date}', '#{name}', #{amount})")
		end
		expid = @db.last_insert_row_id
		if (check_no == "NULL")
			expenditure = Expenditure.new(expid, allocid, date, name, amount,nil)
		else
			expenditure = Expenditure.new(expid,allocid,date,name,amount,check_no)
		end
		puts "Added expenditure #{expenditure}"
		@expenditures.push(expenditure)
		expenditure
	end

	def cash_check(check_no)
		check(check_no).cashed = true
		#@db.execute("UPDATE checks SET cashed=1 WHERE check_no=#{check_no}")
	end

	def delete_allocation(allocid)
		if (!allocid.nil?)
			@db.execute("DELETE FROM allocations WHERE ROWID=#{allocid}")
		end
		@allocations.delete_if { |a| a.allocid == allocid.to_i } 
	end

	def delete_expenditure(expid)
		if (!expid.nil?)
			@db.execute("SELECT check_no FROM expenditures WHERE ROWID=#{expid}") { |e|
				if (!e[0].nil?)
					@db.execute("DELETE FROM checks WHERE check_no=#{e[0]}")
				end
				@checks.delete_if { |c| c.check_no == e[0].to_i }
			}
			@db.execute("DELETE FROM expenditures WHERE ROWID=#{expid}")
			@expenditures.delete_if { |e| e.expid == expid.to_i }
		end
	end

	def delete_check(check_no)
		if (!check_no.nil?)
			@db.execute("SELECT ROWID from expenditures WHERE check_no=#{check_no}") {|e|
				if (!e[0].nil?)
					@db.execute("DELETE FROM expenditures WHERE ROWID=#{e[0]}")
					@expenditures.delete_if { |e| e.expid == e[0] }
				end
			}
			@db.execute("DELETE FROM checks WHERE check_no=#{check_no}")
			@checks.delete_if { |c| c.check_no == check_no.to_i }
		end
	end

	def balance
		#return @db.get_first_row("SELECT sum(-amount) FROM expenditures")[0]
		s = 0
		@expenditures.each do |e|
			s -= e.amount
		end
		return s
	end

	def checks_uncashed
		#return @db.get_first_row("SELECT
		#						 SUM(expenditures.amount),expenditures.ROWID,checks.check_no,checks.cashed,checks.ROWID
		#						 FROM expenditures,checks WHERE
		#						 expenditures.check_no IS NOT NULL AND
		#						 expenditures.check_no=checks.ROWID AND
		#						 checks.cashed=0")[0].to_f
		accum = 0.0
		@expenditures.each { |e|
			if (!e.check_no.nil?)
				c = check(e.check_no)
				if (!c.cashed)
					accum += e.amount
				end
			end
		}
		return accum
	end

	def checks_cashed
		accum = 0.0
		@expenditures.each { |e|
			if (!e.check_no.nil?)
				c = check(e.check_no)
				if (c.cashed)
					accum += e.amount
				end
			end
		}
		return accum
		#return @db.get_first_row("SELECT SUM(expenditures.amount),expenditures.ROWID,checks.check_no,checks.cashed,checks.ROWID FROM expenditures,checks WHERE expenditures.check_no IS NOT NULL AND expenditures.check_no=checks.ROWID AND checks.cashed=1")[0].to_f
	end

	def total_allocations
		#return @db.get_first_row("SELECT sum(amount) FROM allocations")[0].to_f
		s = 0
		@allocations.each do |a|
			s += a.amount
		end
		return s
	end

	def total_open_allocations
		#return @db.get_first_row("SELECT sum(amount) FROM allocations WHERE closed=0")[0].to_f
		s = 0
		@allocations.each do |a|
			if (!a.closed)
				s += a.amount
			end
		end
		return s
	end

	def total_spent_for_allocations
		#return @db.get_first_row("SELECT SUM(expenditures.amount) FROM
		#expenditures,allocations WHERE
		#allocations.ROWID=expenditures.allocid")[0]
		accum = 0.0
		@expenditures.each { |e|
			if (e.allocid != 0)
				accum += e.amount
			end
		}
		return accum
	end

	def close_allocation(allocid)
		if (allocation(allocid).closed)
			return
		end
		allocation(allocid).closed = true
		#@db.execute("UPDATE allocations SET closed=1 WHERE ROWID=#{allocid}")
	end

	private :write_db, :read_db
end

