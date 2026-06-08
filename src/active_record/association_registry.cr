module CQL
  module ActiveRecord
    # Compile-time only namespace populated by relation macros.
    #
    # Each association macro emits a small metadata module here. Model(Pk)'s
    # late macro finalizer reads those modules after all model files have been
    # parsed, which lets CQL validate relationships whose target classes are
    # declared later in the program.
    module AssociationRegistry
    end
  end
end
