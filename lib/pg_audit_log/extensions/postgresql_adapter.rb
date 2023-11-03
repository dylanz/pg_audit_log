require 'active_record/connection_adapters/postgresql_adapter'

# Did not want to reopen the class but sending an include seemingly is not working.
class ActiveRecord::ConnectionAdapters::PostgreSQLAdapter
  def create_table_with_auditing(table_name, options = {}, &block)
    create_table_without_auditing(table_name, **options, &block)
    unless options[:temporary] ||
      PgAuditLog::IGNORED_TABLES.include?(table_name) ||
      PgAuditLog::IGNORED_TABLES.any? { |table| table =~ table_name if table.is_a? Regexp } ||
      PgAuditLog::Triggers.tables_with_triggers.include?(table_name)
      PgAuditLog::Triggers.create_for_table(table_name)
    end
  end

  alias_method :create_table_without_auditing, :create_table
  alias_method :create_table, :create_table_with_auditing

  def drop_table_with_auditing(table_name)
    if PgAuditLog::Triggers.tables_with_triggers.include?(table_name)
      PgAuditLog::Triggers.drop_for_table(table_name)
    end
    drop_table_without_auditing(table_name)
  end

  alias_method :drop_table_without_auditing, :drop_table
  alias_method :drop_table, :drop_table_with_auditing

  def rename_table_with_auditing(table_name, new_name)
    if PgAuditLog::Triggers.tables_with_triggers.include?(table_name)
      PgAuditLog::Triggers.drop_for_table(table_name)
    end
    rename_table_without_auditing(table_name, new_name)
    unless PgAuditLog::IGNORED_TABLES.include?(table_name) ||
      PgAuditLog::IGNORED_TABLES.any? { |table| table =~ table_name if table.is_a? Regexp } ||
      PgAuditLog::Triggers.tables_with_triggers.include?(new_name)
      PgAuditLog::IGNORED_TABLES.any? { |table| table =~ table_name if table.is_a? Regexp } ||
        PgAuditLog::Triggers.tables_with_triggers.include?(new_name)
      PgAuditLog::Triggers.create_for_table(new_name)
    end
  end
  alias_method :rename_table_without_auditing, :rename_table
  alias_method :rename_table, :rename_table_with_auditing

  def execute_with_pg_audit_log(sql, name = nil)
    set_audit_user_id_and_name
    execute_without_pg_audit_log(sql, name)
  end

  alias_method :execute_without_pg_audit_log, :execute
  alias_method :execute, :execute_with_pg_audit_log

  def exec_query_with_pg_audit_log(sql, name = 'SQL', binds = [], prepare = false)
    set_audit_user_id_and_name
    exec_query_without_pg_audit_log(sql, name, binds)
  end

  alias_method :exec_query_without_pg_audit_log, :exec_query
  alias_method :exec_query, :exec_query_with_pg_audit_log

  def exec_update_with_pg_audit_log(sql, name = 'SQL', binds = [])
    set_audit_user_id_and_name
    exec_update_without_pg_audit_log(sql, name, binds)
  end

  alias_method :exec_update_without_pg_audit_log, :exec_update
  alias_method :exec_update, :exec_update_with_pg_audit_log

  def exec_no_cache_with_pg_audit_log(*args, **opts)
    set_audit_user_id_and_name
    exec_no_cache_without_pg_audit_log(*args, **opts)
  end

  alias_method :exec_no_cache_without_pg_audit_log, :exec_no_cache
  alias_method :exec_no_cache, :exec_no_cache_with_pg_audit_log


  def reconnect_with_pg_audit_log!(*args, **opts)
    reconnect_without_pg_audit_log!(*args, **opts)
    @last_user_id = @last_unique_name = nil
  end

  alias_method :reconnect_without_pg_audit_log!, :reconnect!
  alias_method :reconnect!, :reconnect_with_pg_audit_log!

  def exec_delete_with_pg_audit_log(sql, name = 'SQL', binds = [])
    set_audit_user_id_and_name
    exec_delete_without_pg_audit_log(sql, name, binds)
  end

  alias_method :exec_delete_without_pg_audit_log, :exec_delete
  alias_method :exec_delete, :exec_delete_with_pg_audit_log

  def set_audit_user_id_and_name
    user_id, unique_name = user_id_and_name
    return true if (@last_user_id && @last_user_id == user_id) && (@last_unique_name && @last_unique_name == unique_name)
    execute_without_pg_audit_log PgAuditLog::Function::user_identifier_temporary_function(user_id)
    execute_without_pg_audit_log PgAuditLog::Function::user_unique_name_temporary_function(unique_name)
    @last_user_id     = user_id
    @last_unique_name = unique_name

    true
  end

  def set_user_id(user_id = nil)
    execute_without_pg_audit_log PgAuditLog::Function::user_identifier_temporary_function(user_id || @last_user_id)
  end

  def blank_audit_user_id_and_name
    @last_user_id = @last_unique_name = nil
    true
  end

  private

  def user_id_and_name
    current_user     = Thread.current[:current_user] || RequestStore[:current_user]
    user_id          = current_user.try(:id) || "-1"
    user_unique_name = current_user.try(:unique_name) || "UNKNOWN"
    [user_id, user_unique_name]
  end
end
