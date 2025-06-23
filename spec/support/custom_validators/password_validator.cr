require "../../../src/active_record/validations"

# Custom validator for password confirmation
class PasswordValidator < CQL::ActiveRecord::Validations::CustomValidator
  def initialize(@record : TestUser)
  end

  def valid? : Array(CQL::ActiveRecord::Validations::Error)
    errors = [] of CQL::ActiveRecord::Validations::Error

    record = @record

    # Only require password confirmation if a password is provided
    if !record.password.nil? && !record.password.to_s.empty?
      if record.password_confirmation.nil? || record.password_confirmation.to_s.empty?
        errors << CQL::ActiveRecord::Validations::Error.new(:password_confirmation, "Password confirmation is required")
      elsif record.password != record.password_confirmation
        errors << CQL::ActiveRecord::Validations::Error.new(:password_confirmation, "doesn't match Password")
      end
    end

    errors
  end
end
