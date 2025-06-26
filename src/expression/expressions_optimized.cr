require "./base_expression"
require "./logical_operators"
require "./comparison_operators"
require "./columns"
require "./aggregate_functions"
require "./query_structure"
require "./data_manipulation"
require "./schema_operations"

# Import all the visitor components
require "./visitor"
require "./generator"
require "./condition_builder"
require "./aggregator_builder"
require "./filter_builder"
require "./having_builder"

module Expression
  # Re-export key constants for backward compatibility
  COMPARISON_OPERATORS = {
    "==" => "=",
    "!=" => "!=",
    "<=" => "<=",
    "<"  => "<",
    ">"  => ">",
    ">=" => ">=",
  }

  # Enums for common types
  enum OrderDirection
    ASC
    DESC
  end

  enum JoinType
    INNER
    LEFT
    RIGHT
  end
end
