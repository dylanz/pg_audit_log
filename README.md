# pg_audit_log

NOTE: this repo is a fork of https://github.com/dylanz/pg_audit_log. The original Gem was on Github at casecommons/pg_audit_log, but it has since been taken down. This fork has been maintained only to the extent that it has been updated to be compatible with Rails <5.3.

## Description

PostgreSQL-only database-level audit logging of all databases changes using a completely transparent stored procedure and triggers.
Comes with specs for your project and a rake task to generate the reverse SQL to undo changes logged.

All SQL `INSERT`s, `UPDATE`s, and `DELETE`s will be captured. Record columns that do not change do not generate an audit log entry.

## Installation

- Generate the appropriate Rails files:

        rails generate pg_audit_log:install

- Install the PostgreSQL function and triggers for your project:

        rake pg_audit_log:install

## Usage

The PgAuditLog::Entry ActiveRecord model represents a single entry in the audit log table. Each entry represents a single change to a single field of a record in a table. So if you change 3 columns of a record, that will generate 3 corresponding PgAuditLog::Entry records.

You can see the SQL it injects on every query by running with LOG_AUDIT_SQL

### Migrations

TODO

### schema.rb and development_structure.sql

Since schema.rb cannot represent TRIGGERs or FUNCTIONs you will need to set your environment to generate SQL instead of Ruby for your database schema and structure. In your application environment put the following:

    config.active_record.schema_format = :sql

And you can generate this sql using:

    rake db:structure:dump

## Uninstalling

    rake pg_audit_log:uninstall

## Performance

On a 2.93GHz i7 with PostgreSQL 9.1 the audit log has an overhead of about 0.0035 seconds to each `INSERT`, `UPDATE`, or `DELETE`.

## Requirements

- ActiveRecord
- PostgreSQL
- Rails 3.2, 4.x, <5.3

## LICENSE

Copyright © 2010–2014 Case Commons, LLC. Licensed under the MIT license, available in the “LICENSE” file.
