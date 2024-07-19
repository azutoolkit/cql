module Expression
  module Visitor
    abstract def visit(node : Query) : String
    abstract def visit(node : Insert) : String
    abstract def visit(node : Where) : String
    abstract def visit(node : Column) : String
    abstract def visit(node : And) : String
    abstract def visit(node : Or) : String
    abstract def visit(node : Not) : String
    abstract def visit(node : Compare) : String
    abstract def visit(node : Between) : String
    abstract def visit(node : Like) : String
    abstract def visit(node : NotLike) : String
    abstract def visit(node : InCondition) : String
    abstract def visit(node : OrderBy) : String
    abstract def visit(node : GroupBy) : String
    abstract def visit(node : InSelect) : String
    abstract def visit(node : Exists) : String
    abstract def visit(node : Having) : String
    abstract def visit(node : Limit) : String
    abstract def visit(node : Top) : String
    abstract def visit(node : Join) : String
    abstract def visit(node : From) : String
    abstract def visit(node : Table) : String
    abstract def visit(node : Null) : String
    abstract def visit(node : Is) : String
    abstract def visit(node : IsNull) : String
    abstract def visit(node : IsNot) : String
    abstract def visit(node : IsNotNull) : String
    abstract def visit(node : EmptyNode) : String
    abstract def visit(node : Count) : String
    abstract def visit(node : Max) : String
    abstract def visit(node : Min) : String
    abstract def visit(node : Avg) : String
    abstract def visit(node : Sum) : String
    abstract def visit(node : CompareCondition) : String
    abstract def visit(node : Setter) : String
    abstract def visit(node : Update) : String
    abstract def visit(node : Delete) : String
    abstract def visit(node : CreateTable) : String
    abstract def visit(node : DropTable) : String
    abstract def visit(node : TruncateTable) : String
    abstract def visit(node : AlterTable) : String
    abstract def visit(node : AddColumn) : String
    abstract def visit(node : DropColumn) : String
  end
end
