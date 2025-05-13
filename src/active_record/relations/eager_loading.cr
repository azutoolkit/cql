module CQL::ActiveRecord::Relations
  # EagerLoading provides methods to prevent N+1 queries by loading associations in bulk
  module EagerLoading
    # Preloads associations using separate queries
    # This is more memory efficient but uses multiple queries
    # - **param** : records (Array(T)) - The parent records
    # - **param** : associations (Array(Symbol)) - The associations to preload
    # - **return** : Array(T)
    #
    # **Example**
    #
    # ```
    # users = User.all
    # EagerLoading.preload(users, [:posts, :comments])
    # ```
    def self.preload(records : Array(T), associations : Array(Symbol)) forall T
      return records if records.empty?

      associations.each do |association|
        preload_association(records, association)
      end

      records
    end

    # Preloads a single association
    # - **param** : records (Array(T)) - The parent records
    # - **param** : association (Symbol) - The association to preload
    # - **return** : Nil
    private def self.preload_association(records : Array(T), association : Symbol) forall T
      return if records.empty?

      # Get the association metadata
      association_metadata = T.association_metadata[association]
      target_class = association_metadata.target_class
      foreign_key = association_metadata.foreign_key
      primary_key = association_metadata.primary_key

      # Get all parent IDs
      parent_ids = records.map(&.id!)

      # Load all associated records in a single query
      associated_records = target_class.where({foreign_key => parent_ids}).all

      # Group associated records by foreign key
      grouped_records = associated_records.group_by(&.attributes[foreign_key])

      # Set the loaded associations on each parent record
      records.each do |record|
        record_id = record.id!
        if grouped_records[record_id]?
          record.set_loaded_association(association, grouped_records[record_id])
        else
          record.set_loaded_association(association, [] of T)
        end
      end
    end

    # Eager loads associations using JOIN queries
    # This is more efficient for small to medium datasets but uses more memory
    # - **param** : records (Array(T)) - The parent records
    # - **param** : associations (Array(Symbol)) - The associations to include
    # - **return** : Array(T)
    #
    # **Example**
    #
    # ```
    # users = User.all
    # EagerLoading.includes(users, [:posts, :comments])
    # ```
    def self.includes(records : Array(T), associations : Array(Symbol)) forall T
      return records if records.empty?

      # Build the base query
      query = T.query

      # Add JOINs for each association
      associations.each do |association|
        association_metadata = T.association_metadata[association]
        target_class = association_metadata.target_class
        foreign_key = association_metadata.foreign_key
        primary_key = association_metadata.primary_key

        # Add JOIN to the query
        query = query.join(target_class.table, "#{T.table}.#{primary_key} = #{target_class.table}.#{foreign_key}")
      end

      # Execute the query and load all records
      loaded_records = query.all(T)

      # Set the loaded associations
      loaded_records.each do |record|
        associations.each do |association|
          association_metadata = T.association_metadata[association]
          target_class = association_metadata.target_class
          foreign_key = association_metadata.foreign_key
          primary_key = association_metadata.primary_key

          # Find associated records for this parent
          associated_records = loaded_records.select do |r|
            r.attributes[primary_key] == record.attributes[primary_key]
          end

          record.set_loaded_association(association, associated_records)
        end
      end

      loaded_records
    end
  end
end
