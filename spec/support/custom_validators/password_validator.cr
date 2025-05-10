# Custom validator for password confirmation
class PasswordValidator < CQL::ActiveRecord::Validations::CustomValidator
  def initialize(@record : TestUser)
  end

  def valid? : Array(CQL::ActiveRecord::Validations::Error)
    errors = [] of CQL::ActiveRecord::Validations::Error

    record = @record
    if !record.password.nil? && !record.password_confirmation.nil? && record.password != record.password_confirmation
      errors << CQL::ActiveRecord::Validations::Error.new(:password_confirmation, "doesn't match Password")
    end

    errors
  end
end
