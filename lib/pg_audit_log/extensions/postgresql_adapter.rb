require 'active_record/connection_adapters/postgresql_adapter'

# Did not want to reopen the class but sending an include seemingly is not working.
class ActiveRecord::ConnectionAdapters::PostgreSQLAdapter

  module Auditing
    def create_table(table_name, options = {}, &block)
      super(table_name, options, &block)
      unless options[:temporary] ||
        PgAuditLog::IGNORED_TABLES.include?(table_name) ||
        PgAuditLog::IGNORED_TABLES.any? { |table| table =~ table_name if table.is_a? Regexp } ||
        PgAuditLog::Triggers.tables_with_triggers.include?(table_name)
        PgAuditLog::Triggers.create_for_table(table_name)
      end
    end

    def drop_table(table_name)
      if PgAuditLog::Triggers.tables_with_triggers.include?(table_name)
        PgAuditLog::Triggers.drop_for_table(table_name)
      end
      super(table_name)
    end

    def rename_table(table_name, new_name)
      if PgAuditLog::Triggers.tables_with_triggers.include?(table_name)
        PgAuditLog::Triggers.drop_for_table(table_name)
      end
      super(table_name, new_name)
      unless PgAuditLog::IGNORED_TABLES.include?(table_name) ||
        PgAuditLog::IGNORED_TABLES.any? { |table| table =~ table_name if table.is_a? Regexp } ||
        PgAuditLog::Triggers.tables_with_triggers.include?(new_name)
        PgAuditLog::Triggers.create_for_table(new_name)
      end

    end
  end


  module PgAuditLog
    def reconnect!
      super
      @last_user_id = @last_unique_name = nil
    end

    def execute(sql, name = nil)
      set_audit_user_id_and_name
      super(sql, name)
    end

    def exec_query(*args, &block)
      set_audit_user_id_and_name
      super(*args, &block)
    end

    def exec_update(*args, &block)
      set_audit_user_id_and_name
      super(*args, &block)
    end

    def exec_delete(*args, &block)
      set_audit_user_id_and_name
      super(*args, &block)
    end
  end

  prepend ActiveRecord::ConnectionAdapters::PostgreSQLAdapter::Auditing
  prepend ActiveRecord::ConnectionAdapters::PostgreSQLAdapter::PgAuditLog

  def set_audit_user_id_and_name
    user_id, unique_name = user_id_and_name
    return true if (@last_user_id && @last_user_id == user_id) && (@last_unique_name && @last_unique_name == unique_name)

    PgAuditLog.execute PgAuditLog::Function::user_identifier_temporary_function(user_id)
    PgAuditLog.execute PgAuditLog::Function::user_unique_name_temporary_function(unique_name)
    @last_user_id     = user_id
    @last_unique_name = unique_name

    true
  end

  def set_user_id(user_id = nil)
    PgAuditLog.execute PgAuditLog::Function::user_identifier_temporary_function(user_id || @last_user_id)
  end

  def blank_audit_user_id_and_name
    @last_user_id = @last_unique_name = nil
    true
  end

  private

  def user_id_and_name
    current_user     = Thread.current[:current_user]
    user_id          = current_user.try(:id) || "-1"
    user_unique_name = current_user.try(:unique_name) || "UNKNOWN"
    [user_id, user_unique_name]
  end
end
