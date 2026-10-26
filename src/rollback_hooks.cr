module CQL
  # :nodoc:
  # Undo steps for in-memory state (such as a table declaration changed by `Schema#alter`) that the work inside one
  # transaction changed. Only the fiber that runs the transaction touches them.
  class RollbackHooks
    @hooks = [] of ->

    def <<(hook : ->) : self
      @hooks << hook
      self
    end

    # The transaction rolled back: undoes the changes, newest first.
    def run : Nil
      hooks, @hooks = @hooks, [] of ->
      hooks.reverse_each(&.call)
    end

    # The transaction committed. An enclosing transaction can still roll the work back, so the hooks move to its
    # *parent* hooks; after the outermost commit there is no parent and they are dropped.
    def hand_to(parent : RollbackHooks?) : Nil
      @hooks.each { |hook| parent << hook } if parent
      @hooks.clear
    end
  end
end
