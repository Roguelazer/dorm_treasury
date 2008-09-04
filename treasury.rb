#!/usr/bin/ruby -w

require 'sqlite3'
require 'primitives'
class Treasury
	def initialize(filename)
		@db = SQLite3::Database.new(filename)
		@expenditures = []
		@allocations = []
		sync_with_database()
	end

	def sync_with_database()
		
	end

	private :sync_with_database

