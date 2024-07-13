module Sql
  module Visitor
    abstract def visit(node : SelectStatement) : String
    abstract def visit(node : InsertStatement) : String
    abstract def visit(node : WhereClause) : String
    abstract def visit(node : Column) : String
    abstract def visit(node : AndCondition) : String
    abstract def visit(node : OrCondition) : String
    abstract def visit(node : NotCondition) : String
    abstract def visit(node : ComparisonCondition) : String
    abstract def visit(node : BetweenCondition) : String
    abstract def visit(node : LikeCondition) : String
    abstract def visit(node : InCondition) : String
    abstract def visit(node : IsNullCondition) : String
    abstract def visit(node : IsNotNullCondition) : String
    abstract def visit(node : OrderByClause) : String
    abstract def visit(node : GroupByClause) : String
    abstract def visit(node : InSelectCondition) : String
    abstract def visit(node : NotInSelectCondition) : String
    abstract def visit(node : NotLikeCondition) : String
    abstract def visit(node : ExistsCondition) : String
    abstract def visit(node : HavingClause) : String
    abstract def visit(node : InnerJoin) : String
    abstract def visit(node : LeftJoin) : String
    abstract def visit(node : RightJoin) : String
    abstract def visit(node : FullJoin) : String
    abstract def visit(node : CrossJoin) : String
    abstract def visit(node : JoinClause) : String
  end
end
