module CQL
  # The table `Migrator#print_applied_migrations` and its siblings print: one row per migration, with a status mark.
  private struct MigrationTable
    def initialize(@records : Array(MigrationRecord), @status : String)
    end

    def print : Nil
      m, status = @records, @status
      return if m.empty?

      # Calculate dynamic column widths
      status_width = 6 # Reduced from 8 for better fit
      version_width = [7, m.max_of?(&.version.to_s.size) || 7].max
      name_width = [20, m.max_of?(&.name.size) || 20].max

      # Ensure reasonable limits
      name_width = [name_width, 45].min # Reduced max width

      # Table header
      puts
      puts "┌#{"─" * (status_width + 2)}┬#{"─" * (name_width + 2)}┬#{"─" * (version_width + 2)}┐"
      puts "│ #{"Status".center(status_width)} │ #{"Migration".ljust(name_width)} │ #{"Version".rjust(version_width)} │"
      puts "├#{"─" * (status_width + 2)}┼#{"─" * (name_width + 2)}┼#{"─" * (version_width + 2)}┤"

      # Table rows
      m.each do |migration|
        # Format migration.name (truncate if too long)
        formatted_name = migration.name

        # Center status within exact width
        formatted_status = status.center(status_width)

        # Right-align version numbers for better readability
        formatted_version = migration.version.to_s.rjust(version_width)

        puts "│ #{formatted_status} │ #{formatted_name} │ #{formatted_version} │"
      end

      # Table footer
      puts "└#{"─" * (status_width + 2)}┴#{"─" * (name_width + 2)}┴#{"─" * (version_width + 2)}┘"
      puts
    end
  end
end
