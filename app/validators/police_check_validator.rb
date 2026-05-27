class PoliceCheckValidator
  # ACIC National Police Check certificate numbers are 10 alphanumeric characters
  PATTERN = /\A[A-Z0-9]{10}\z/.freeze

  def self.valid?(number)
    PATTERN.match?(number.to_s.strip.upcase)
  end
end
