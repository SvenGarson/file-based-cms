class User
	def initialize(name, password, signed_in)
		self.name = name
		self.password = password
		self.signed_in = signed_in
	end

	def toggle_signed_in
		self.signed_in = !signed_in
	end

	def signed_in?
		signed_in
	end

	def signed_out?
		!signed_in
	end

	def sign_in
		self.signed_in = true
	end

	def signing_credentials_match?(username, password)
		self.name == username && self.password == password
	end

	attr_reader(:name, :password)

	private

	attr_reader(:signed_in)
	attr_writer(:name, :password, :signed_in)
end