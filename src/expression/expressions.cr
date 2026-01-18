# Expression module - main entry point for the expression system
# This file coordinates all expression-related components

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
  # All types and constants are defined in the imported modules
  # This file serves as the main coordinator for the expression system
end
