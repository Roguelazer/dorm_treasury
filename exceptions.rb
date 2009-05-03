class CheckNotFoundError < RuntimeError
	def initialize(check_no)
		@check_no = check_no
	end

	def to_s
		"Check ##{@check_no} not found!"
	end
end

class DuplicateCheckError < RuntimeError
	attr_reader :check
	def initialize(check_no, check)
		@check_no = check_no
		@check = check
	end

	def to_s
		"Check ##{@check_no} has duplicates!"
	end
end

