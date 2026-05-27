class WwccValidator
  # NSW and ACT share the same scheme (Office of the Children's Guardian)
  # VIC: Working with Children Check unit (WWW prefix)
  # QLD: Blue Card Services — numeric only, 7–10 digits
  # WA: Working with Children Check — WA prefix + alphanumeric
  # SA/TAS/NT: formats not publicly documented; use a permissive alphanumeric fallback
  PATTERNS = {
    'nsw' => /\AWWC\d{7}[A-Z]\z/,
    'act' => /\AWWC\d{7}[A-Z]\z/,
    'vic' => /\AWWW\d{7}\z/,
    'qld' => /\A\d{7,10}\z/,
    'wa'  => /\AWA[A-Z0-9]{6,10}\z/,
    'sa'  => /\A[A-Z0-9]{7,12}\z/,
    'tas' => /\A[A-Z0-9]{7,12}\z/,
    'nt'  => /\A[A-Z0-9]{7,12}\z/,
  }.freeze

  STATES = PATTERNS.keys.freeze

  def self.valid?(state, number)
    PATTERNS[state.to_s.downcase]&.match?(number.to_s.strip.upcase) || false
  end
end
